import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';
import '../../core/errors/exceptions.dart' as app_errors;

import '../models/app_models.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Auth state changes stream
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

// Current user profile
final currentProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  final client = ref.watch(supabaseProvider);
  final user = client.auth.currentUser;
  if (user == null) return null;

  final data = await client.from('profiles').select().eq('id', user.id).maybeSingle();
  if (data == null) return null;
  return ProfileModel.fromJson(data);
});

final currentUserRoleProvider = Provider<String>((ref) {
  final profile = ref.watch(currentProfileProvider);
  return profile.valueOrNull?.role ?? 'supervisor';
});

// Auth repository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseProvider));
});

class AuthRepository {
  final SupabaseClient _client;
  AuthRepository(this._client);

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      return await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw app_errors.AuthException(e.message);
    }
  }

  Future<AuthResponse> signInWithEmployeeId(
    String employeeId,
    String password,
  ) async {
    try {
      final supervisorData = await _client
          .from('supervisors')
          .select('email,is_active')
          .eq('supervisor_code', employeeId.trim().toUpperCase())
          .maybeSingle();

      if (supervisorData == null) {
        throw app_errors.AuthException('Invalid ID or password');
      }

      if (supervisorData['is_active'] != true) {
        throw app_errors.AuthException('Supervisor account is inactive');
      }

      return await _client.auth.signInWithPassword(
        email: supervisorData['email'] as String,
        password: password,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw app_errors.AuthException('Sign in failed: $e');
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw app_errors.AuthException(e.message);
    }
  }

  Future<UserResponse> updatePassword(String newPassword) async {
    try {
      return await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw app_errors.AuthException(e.message);
    }
  }

  Future<void> signOut() async {
  try {
    await _client.auth.signOut();

    print('LOGOUT SUCCESS');
    print(_client.auth.currentSession);
  } on AuthException catch (e) {
    throw app_errors.AuthException(e.message);
  }
}

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  Future<ProfileModel?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final data = await _client.from('profiles').select().eq('id', user.id).maybeSingle();
    if (data == null) return null;
    return ProfileModel.fromJson(data);
  }

  Future<void> saveFcmToken(
    String token,
    String platform,
  ) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      await _client.from('fcm_tokens').upsert(
        {
          'user_id': user.id,
          'token': token,
          'platform': platform,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'token',
      );
    } catch (_) {
      // Ignore token save failures
    }
  }
}

// Employees repository
final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository(ref.watch(supabaseProvider));
});

class EmployeeRepository {
  final SupabaseClient _client;
  EmployeeRepository(this._client);

  Future<List<EmployeeModel>> getAll({
    String? search,
    String? status,
    int page = 0,
    int limit = 20,
  }) async {
    // Build a filter builder first, apply all filters, then add ordering and pagination.
    // In postgrest 2.7.x, filter methods (eq, or, gte, lte) are only available on
    // PostgrestFilterBuilder. Once .order() or .range() is called, the builder becomes
    // a PostgrestTransformBuilder which no longer exposes those methods.
    var filterQuery = _client
        .from('employees')
        .select('*, departments(name)');

    if (status != null) {
      filterQuery = filterQuery.eq('status', status);
    }

    if (search != null && search.isNotEmpty) {
      filterQuery = filterQuery.or('name.ilike.%$search%,employee_code.ilike.%$search%');
    }

    final data = await filterQuery
        .order('name')
        .range(page * limit, (page + 1) * limit - 1);

    return (data as List).map((e) => EmployeeModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<EmployeeModel?> getById(String id) async {
    final data = await _client
        .from('employees')
        .select('*, departments(name)')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return EmployeeModel.fromJson(data);
  }

  Future<EmployeeModel> create(Map<String, dynamic> data) async {
  final code = await _client.rpc('generate_employee_code') as String;

  data['employee_code'] = code;
  data['created_by'] = _client.auth.currentUser?.id;

  final result = await _client
      .from('employees')
      .insert(data)
      .select('*, departments(name)')
      .single();

  if (data['supervisor_id'] != null) {
    await _client.from('supervisor_employees').insert({
      'supervisor_id': data['supervisor_id'],
      'employee_id': result['id'],
    });
  }

  await _logAudit(
    'employee_created',
    'employees',
    result['id'] as String,
    null,
    result,
  );

  return EmployeeModel.fromJson(result);
}

  Future<EmployeeModel> update(String id, Map<String, dynamic> data) async {
  final supervisorId = data.remove('supervisor_id');

  final result = await _client
      .from('employees')
      .update(data)
      .eq('id', id)
      .select('*, departments(name)')
      .single();

  if (supervisorId != null) {
    await _client
        .from('supervisor_employees')
        .delete()
        .eq('employee_id', id);

    await _client
        .from('supervisor_employees')
        .insert({
          'employee_id': id,
          'supervisor_id': supervisorId,
        });
  }

  await _logAudit(
    'employee_updated',
    'employees',
    id,
    null,
    result,
  );

  return EmployeeModel.fromJson(result);
}

  Future<void> delete(String id) async {
    await _client.from('employees').delete().eq('id', id);
    await _logAudit('employee_deleted', 'employees', id, null, null);
  }

  // Fix #2: Uint8List.fromList instead of unsafe cast
  Future<void> uploadPhoto(String employeeId, List<int> fileBytes, String fileName) async {
    final userId = _client.auth.currentUser?.id ?? 'unknown';
    final path = '$userId/$employeeId/$fileName';
    await _client.storage
        .from('employee_photos')
        .uploadBinary(path, Uint8List.fromList(fileBytes));
    final url = _client.storage.from('employee_photos').getPublicUrl(path);
    await _client.from('employees').update({'employee_photo_url': url}).eq('id', employeeId);
  }

  Future<int> getCount({String? status}) async {
    final data = status == null
        ? await _client.from('employees').select('id')
        : await _client.from('employees').select('id').eq('status', status);

    return (data as List).length;
  }

  Future<void> _logAudit(String action, String entity, String entityId, dynamic old, dynamic newVal) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client.rpc('create_audit_log', params: {
        'p_user_id': userId,
        'p_action': action,
        'p_entity_type': entity,
        'p_entity_id': entityId,
        'p_old_values': old,
        'p_new_values': newVal,
      });
    } catch (_) {}
  }
}

// Supervisors repository
final supervisorRepositoryProvider = Provider<SupervisorRepository>((ref) {
  return SupervisorRepository(ref.watch(supabaseProvider));
});

class SupervisorRepository {
  final SupabaseClient _client;

  SupervisorRepository(this._client);

  Future<List<SupervisorModel>> getAll({
    String? search,
    bool? isActive,
  }) async {
    // Apply all filters on the PostgrestFilterBuilder before calling .order(),
    // which would promote the builder to PostgrestTransformBuilder.
    var filterQuery = _client.from('supervisors').select();

    if (isActive != null) {
      filterQuery = filterQuery.eq('is_active', isActive);
    }

    if (search != null && search.trim().isNotEmpty) {
      filterQuery = filterQuery.or(
        'name.ilike.%$search%,email.ilike.%$search%,supervisor_code.ilike.%$search%',
      );
    }

    final result = await filterQuery.order('created_at', ascending: false);

    return (result as List)
        .map((e) => SupervisorModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SupervisorModel?> getById(String id) async {
    final data = await _client
        .from('supervisors')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return SupervisorModel.fromJson(data);
  }

  Future<SupervisorModel?> getByProfileId(String profileId) async {
    final data = await _client
        .from('supervisors')
        .select()
        .eq('profile_id', profileId)
        .maybeSingle();
    if (data == null) return null;
    return SupervisorModel.fromJson(data);
  }

  Future<SupervisorModel> create(
    Map<String, dynamic> supervisorData,
    String password,
  ) async {
    final response = await _client.functions.invoke(
      'create-supervisor',
      body: {
        'email': supervisorData['email'],
        'password': password,
        'name': supervisorData['name'],
        'mobile': supervisorData['mobile'],
      },
    );

    // Fix #6: safe cast of response.data before key access
    final responseData = response.data as Map<String, dynamic>?;

    if (response.status != 200) {
      throw Exception(
        responseData?['error'] ?? 'Failed to create supervisor',
      );
    }

    // Fix #4: typed extraction of supervisor_code
    final supervisorCode = responseData!['supervisor_code'] as String;

    final supervisor = await _client
        .from('supervisors')
        .select()
        .eq('supervisor_code', supervisorCode)
        .single();

    return SupervisorModel.fromJson(supervisor);
  }

  Future<SupervisorModel> update(String id, Map<String, dynamic> data) async {
    final result = await _client
        .from('supervisors')
        .update({
          ...data,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();

    return SupervisorModel.fromJson(result);
  }

  Future<void> delete(String id) async {
    final supervisor = await _client
        .from('supervisors')
        .select('profile_id')
        .eq('id', id)
        .maybeSingle();

    await _client.from('supervisors').delete().eq('id', id);

    if (supervisor != null && supervisor['profile_id'] != null) {
      try {
        await _client.functions.invoke(
          'delete-supervisor',
          body: {'user_id': supervisor['profile_id']},
        );
      } catch (_) {}
    }
  }

  Future<List<EmployeeModel>> getAssignedEmployees(String supervisorId) async {
    final data = await _client
        .from('supervisor_employees')
        .select('employees(*, departments(name))')
        .eq('supervisor_id', supervisorId);

    return (data as List)
        .where((row) => row['employees'] != null)
        .map((row) => EmployeeModel.fromJson(row['employees'] as Map<String, dynamic>))
        .toList();
  }

  Future<void> assignEmployee(String supervisorId, String employeeId) async {
    final existing = await _client
        .from('supervisor_employees')
        .select('id')
        .eq('supervisor_id', supervisorId)
        .eq('employee_id', employeeId)
        .maybeSingle();

    if (existing != null) return;

    await _client.from('supervisor_employees').insert({
      'supervisor_id': supervisorId,
      'employee_id': employeeId,
    });
  }

  Future<void> removeEmployee(String supervisorId, String employeeId) async {
    await _client
        .from('supervisor_employees')
        .delete()
        .eq('supervisor_id', supervisorId)
        .eq('employee_id', employeeId);
  }
}

// Attendance repository
final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.watch(supabaseProvider));
});

class AttendanceRepository {
  final SupabaseClient _client;
  AttendanceRepository(this._client);

  Future<List<AttendanceModel>> getAll({
    String? supervisorId,
    DateTime? fromDate,
    DateTime? toDate,
    int page = 0,
    int limit = 20,
  }) async {
    // All filter methods (eq, gte, lte) must be called on the PostgrestFilterBuilder
    // returned by .select(), before any transform methods (.order(), .range()).
    var filterQuery = _client
        .from('attendance')
        .select('*, supervisors(name), attendance_details(*, employees(name, employee_code))');

    if (supervisorId != null) {
      filterQuery = filterQuery.eq('supervisor_id', supervisorId);
    }

    if (fromDate != null) {
      filterQuery = filterQuery.gte('attendance_date', fromDate.toIso8601String().split('T').first);
    }

    if (toDate != null) {
      filterQuery = filterQuery.lte('attendance_date', toDate.toIso8601String().split('T').first);
    }

    final data = await filterQuery
        .order('attendance_date', ascending: false)
        .range(page * limit, (page + 1) * limit - 1);

    return (data as List).map((a) => AttendanceModel.fromJson(a as Map<String, dynamic>)).toList();
  }

  Future<AttendanceModel?> getById(String id) async {
    final data = await _client
        .from('attendance')
        .select('*, supervisors(name), attendance_details(*, employees(name, employee_code))')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return AttendanceModel.fromJson(data);
  }

  Future<AttendanceModel?> getTodayBySupervisor(String supervisorId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final data = await _client
        .from('attendance')
        .select('*, attendance_details(*, employees(name, employee_code))')
        .eq('supervisor_id', supervisorId)
        .eq('attendance_date', today)
        .maybeSingle();
    if (data == null) return null;
    return AttendanceModel.fromJson(data);
  }

  Future<AttendanceModel> createWithDetails(
    Map<String, dynamic> attendanceData,
    List<Map<String, dynamic>> detailsData,
  ) async {
    final result = await _client.from('attendance').insert(attendanceData).select().single();
    final attendanceId = result['id'] as String;

    final details = detailsData.map((d) => {...d, 'attendance_id': attendanceId}).toList();
    await _client.from('attendance_details').insert(details);

    final full = await getById(attendanceId);
    await _logAudit('attendance_created', 'attendance', attendanceId);
    return full!;
  }

  Future<AttendanceModel> updateDetails(
    String attendanceId,
    Map<String, dynamic> attendanceData,
    List<Map<String, dynamic>> detailsData,
  ) async {
    await _client.from('attendance').update(attendanceData).eq('id', attendanceId);

    for (final detail in detailsData) {
      await _client.from('attendance_details').upsert(
        {...detail, 'attendance_id': attendanceId},
        onConflict: 'attendance_id, employee_id',
      );
    }

    final full = await getById(attendanceId);
    await _logAudit('attendance_updated', 'attendance', attendanceId);
    return full!;
  }

  Future<void> approve(String attendanceId, String adminId) async {
    await _client.from('attendance').update({
      'is_approved': true,
      'approved_by': adminId,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', attendanceId);
    await _logAudit('attendance_approved', 'attendance', attendanceId);
  }

  Future<Map<String, int>> getTodaySummary() async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final data = await _client
        .from('attendance_details')
        .select('status')
        .gte('created_at', '${today}T00:00:00')
        .lte('created_at', '${today}T23:59:59');

    final counts = {'present': 0, 'absent': 0, 'half_day': 0, 'leave': 0};
    for (final row in data as List) {
      final status = row['status'] as String;
      counts[status] = (counts[status] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _logAudit(String action, String entity, String entityId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client.rpc('create_audit_log', params: {
        'p_user_id': userId,
        'p_action': action,
        'p_entity_type': entity,
        'p_entity_id': entityId,
      });
    } catch (_) {}
  }
}

// Expense repository
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(supabaseProvider));
});

class ExpenseRepository {
  final SupabaseClient _client;
  ExpenseRepository(this._client);

  Future<List<ExpenseModel>> getAll({
    String? supervisorId,
    String? status,
    String? category,
    DateTime? fromDate,
    DateTime? toDate,
    int page = 0,
    int limit = 20,
  }) async {
    // All filter methods must be chained on the PostgrestFilterBuilder (from .select())
    // before any transform calls (.order(), .range()), which return a
    // PostgrestTransformBuilder that no longer exposes filter methods.
    var filterQuery = _client
        .from('expenses')
        .select('*, supervisors(name), expense_attachments(*)');

    if (supervisorId != null) {
      filterQuery = filterQuery.eq('supervisor_id', supervisorId);
    }

    if (status != null) {
      filterQuery = filterQuery.eq('status', status);
    }

    if (category != null) {
      filterQuery = filterQuery.eq('category', category);
    }

    if (fromDate != null) {
      filterQuery = filterQuery.gte('expense_date', fromDate.toIso8601String().split('T').first);
    }

    if (toDate != null) {
      filterQuery = filterQuery.lte('expense_date', toDate.toIso8601String().split('T').first);
    }

    final data = await filterQuery
        .order('created_at', ascending: false)
        .range(page * limit, (page + 1) * limit - 1);

    return (data as List).map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ExpenseModel?> getById(String id) async {
    final data = await _client
        .from('expenses')
        .select('*, supervisors(name), expense_attachments(*)')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return ExpenseModel.fromJson(data);
  }

  Future<ExpenseModel> create(Map<String, dynamic> data) async {
    final result = await _client.from('expenses').insert(data).select('*, supervisors(name)').single();
    await _logAudit('expense_submitted', 'expenses', result['id'] as String);
    return ExpenseModel.fromJson(result);
  }

  Future<ExpenseModel> update(String id, Map<String, dynamic> data) async {
    final result = await _client.from('expenses').update(data).eq('id', id).select('*, supervisors(name)').single();
    return ExpenseModel.fromJson(result);
  }

  Future<void> approve(String id, String adminId, {String? remarks}) async {
    await _client.from('expenses').update({
      'status': 'approved',
      'reviewed_by': adminId,
      'reviewed_at': DateTime.now().toIso8601String(),
      'admin_remarks': remarks,
    }).eq('id', id);
    await _logAudit('expense_approved', 'expenses', id);
  }

  Future<void> reject(String id, String adminId, {required String remarks}) async {
    await _client.from('expenses').update({
      'status': 'rejected',
      'reviewed_by': adminId,
      'reviewed_at': DateTime.now().toIso8601String(),
      'admin_remarks': remarks,
    }).eq('id', id);
    await _logAudit('expense_rejected', 'expenses', id);
  }

  // Fix #3: Uint8List.fromList instead of unsafe cast
  Future<String> uploadAttachment(String expenseId, List<int> bytes, String fileName, String mimeType, {bool isReceipt = false}) async {
    final userId = _client.auth.currentUser?.id ?? 'unknown';
    final path = '$userId/$expenseId/$fileName';
    await _client.storage
        .from('expense_receipts')
        .uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: mimeType),
        );
    final url = _client.storage.from('expense_receipts').getPublicUrl(path);

    await _client.from('expense_attachments').insert({
      'expense_id': expenseId,
      'file_url': url,
      'file_name': fileName,
      'file_type': mimeType,
      'file_size': bytes.length,
      'is_receipt': isReceipt,
    });
    return url;
  }

  Future<Map<String, dynamic>> getSummary() async {
    final data = await _client.from('expenses').select('status, amount');
    final summary = {'pending': 0.0, 'approved': 0.0, 'rejected': 0.0, 'total': 0.0};
    for (final row in data as List) {
      final status = row['status'] as String;
      final amount = (row['amount'] as num).toDouble();
      summary[status] = (summary[status] ?? 0) + amount;
      summary['total'] = (summary['total'] ?? 0) + amount;
    }
    return summary;
  }

  Future<void> _logAudit(String action, String entity, String entityId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      await _client.rpc('create_audit_log', params: {
        'p_user_id': userId,
        'p_action': action,
        'p_entity_type': entity,
        'p_entity_id': entityId,
      });
    } catch (_) {}
  }
}

// Payroll repository
final payrollRepositoryProvider = Provider<PayrollRepository>((ref) {
  return PayrollRepository(ref.watch(supabaseProvider));
});

class PayrollRepository {
  final SupabaseClient _client;
  PayrollRepository(this._client);

  Future<List<PayrollModel>> getByMonthYear(int month, int year) async {
    final data = await _client
        .from('payroll')
        .select('*, employees(name, employee_code)')
        .eq('payroll_month', month)
        .eq('payroll_year', year)
        .order('created_at', ascending: false);
    return (data as List).map((p) => PayrollModel.fromJson(p as Map<String, dynamic>)).toList();
  }

  Future<PayrollModel?> getByEmployeeMonth(String employeeId, int month, int year) async {
    final data = await _client
        .from('payroll')
        .select('*, employees(name, employee_code)')
        .eq('employee_id', employeeId)
        .eq('payroll_month', month)
        .eq('payroll_year', year)
        .maybeSingle();
    if (data == null) return null;
    return PayrollModel.fromJson(data);
  }

  Future<PayrollModel> processPayroll(String employeeId, int month, int year) async {
    // Get attendance summary
    final summary = await _client.rpc('get_monthly_attendance_summary', params: {
      'p_employee_id': employeeId,
      'p_month': month,
      'p_year': year,
    }) as List;

    final employee = await _client.from('employees').select('daily_wage_rate').eq('id', employeeId).single();
    final wageRate = (employee['daily_wage_rate'] as num).toDouble();

    final s = summary.isNotEmpty ? summary.first as Map : <String, dynamic>{};
    final presentDays = (s['present_days'] as num?)?.toDouble() ?? 0;
    final halfDays = (s['half_days'] as num?)?.toDouble() ?? 0;
    final absentDays = (s['absent_days'] as num?)?.toDouble() ?? 0;
    final leaveDays = (s['leave_days'] as num?)?.toDouble() ?? 0;

    // Get pending advances
    // Fix #5: .filter('payroll_id', 'is', null) instead of deprecated .isFilter()
    final advances = await _client
        .from('payroll_transactions')
        .select('amount')
        .eq('employee_id', employeeId)
        .eq('transaction_type', 'advance')
        .filter('payroll_id', 'is', null);

    double totalAdvance = 0;
    for (final a in advances as List) {
      totalAdvance += (a['amount'] as num).toDouble();
    }

    final payrollData = {
      'employee_id': employeeId,
      'payroll_month': month,
      'payroll_year': year,
      'daily_wage_rate': wageRate,
      'present_days': presentDays,
      'half_days': halfDays,
      'absent_days': absentDays,
      'leave_days': leaveDays,
      'overtime_hours': 0,
      'overtime_amount': 0,
      'advance_deduction': totalAdvance,
      'penalty_deduction': 0,
      'bonus': 0,
      'status': 'processed',
      'processed_by': _client.auth.currentUser?.id,
      'processed_at': DateTime.now().toIso8601String(),
    };

    final result = await _client
        .from('payroll')
        .upsert(payrollData, onConflict: 'employee_id, payroll_month, payroll_year')
        .select('*, employees(name, employee_code)')
        .single();

    return PayrollModel.fromJson(result);
  }

  Future<PayrollModel> update(String id, Map<String, dynamic> data) async {
    final result = await _client
        .from('payroll')
        .update(data)
        .eq('id', id)
        .select('*, employees(name, employee_code)')
        .single();
    return PayrollModel.fromJson(result);
  }

  Future<void> markAsPaid(String id) async {
    await _client.from('payroll').update({
      'status': 'paid',
      'paid_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<Map<String, double>> getMonthlySummary(int month, int year) async {
    final data = await _client
        .from('payroll')
        .select('gross_wage, net_wage, status')
        .eq('payroll_month', month)
        .eq('payroll_year', year);

    double totalLiability = 0, paid = 0, pending = 0;
    for (final row in data as List) {
      final net = (row['net_wage'] as num).toDouble();
      totalLiability += net;
      if (row['status'] == 'paid') paid += net;
      else pending += net;
    }
    return {'liability': totalLiability, 'paid': paid, 'pending': pending};
  }
}

// Dashboard stats provider
final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final now = DateTime.now();

  // Employee counts
  final totalEmp =
      await client.from('employees').select('id');

  final activeEmp =
      await client.from('employees')
          .select('id')
          .eq('status', 'active');

  // Today attendance
  final todayAttendance = await ref.watch(attendanceRepositoryProvider).getTodaySummary();

  // Expense summary
  final expenseSummary = await ref.watch(expenseRepositoryProvider).getSummary();

  // Payroll summary
  final payrollSummary = await ref.watch(payrollRepositoryProvider).getMonthlySummary(now.month, now.year);

  return {
    'total_employees': (totalEmp as List).length,
    'active_employees': (activeEmp as List).length,
    'today_present': todayAttendance['present'] ?? 0,
    'today_absent': todayAttendance['absent'] ?? 0,
    'expense_pending': expenseSummary['pending'] ?? 0,
    'expense_approved': expenseSummary['approved'] ?? 0,
    'expense_rejected': expenseSummary['rejected'] ?? 0,
    'payroll_liability': payrollSummary['liability'] ?? 0,
    'payroll_paid': payrollSummary['paid'] ?? 0,
    'payroll_pending': payrollSummary['pending'] ?? 0,
  };
});