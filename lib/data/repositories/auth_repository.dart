import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../../core/errors/exceptions.dart' as app_errors;
import '../../core/utils/app_utils.dart' show withRetry;

import '../models/app_models.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// Everything the app needs right after login, fetched in ONE network
/// round trip via the get_my_session_context RPC (see
/// supabase_migration_session_and_photo.sql) instead of several sequential
/// queries (profile, then — once the role is known — the employee/
/// supervisor row, then the company row), each with its own retry loop.
/// That serialized chain was a real, measurable chunk of how slow login
/// felt, especially on a fast logout->login where every one of those
/// retry loops could be hit at once. currentProfileProvider,
/// companyProvider, and the employee/supervisor "own record" providers
/// all now derive from this single cached fetch.
class SessionContext {
  final ProfileModel profile;
  final EmployeeModel? employee;
  final SupervisorModel? supervisor;
  final CompanyModel? company;
  const SessionContext({
    required this.profile,
    this.employee,
    this.supervisor,
    this.company,
  });
}

final sessionContextProvider = FutureProvider<SessionContext?>((ref) async {
  final client = ref.read(supabaseProvider);

  // THE COLD-START BUG: on a fresh app launch with an already-persisted
  // session, Supabase restores that session from local storage
  // asynchronously. `client.auth.currentSession` (which the router's
  // redirect() reads to decide whether to let you into /dashboard) can go
  // non-null a moment before `client.auth.currentUser` finishes hydrating.
  // Actively wait for currentUser to appear (bounded) instead of giving up
  // on the first synchronous read.
  var user = client.auth.currentUser;
  if (user == null) {
    for (var attempt = 0; attempt < 10 && user == null; attempt++) {
      await Future.delayed(const Duration(milliseconds: 150));
      user = client.auth.currentUser;
    }
  }
  // Still nothing after ~1.5s of waiting — genuinely logged out, not a
  // race. Return null so the router sends the user to /login.
  if (user == null) return null;

  // A brand new account is created via an edge function that creates the
  // auth user and the linked profiles (and employees/supervisors) rows in
  // quick succession. If a first login races that write, one immediate
  // call can come back empty and the user would see a blank screen even
  // though the account is valid. Retry briefly before giving up so first
  // login is reliable. Because this one RPC already returns the profile
  // AND the role-specific record together, this single retry loop covers
  // both — no separate retry chain needed for the role record anymore.
  for (var attempt = 0; attempt < 6; attempt++) {
    try {
      final result = await client.rpc('get_my_session_context');
      if (result != null) {
        final data = result as Map<String, dynamic>;
        final profile = ProfileModel.fromJson(data['profile'] as Map<String, dynamic>);
        EmployeeModel? employee;
        SupervisorModel? supervisor;
        final roleRecord = data['role_record'] as Map<String, dynamic>?;
        if (roleRecord != null) {
          if (profile.role == 'employee') {
            employee = EmployeeModel.fromJson(roleRecord);
          } else if (profile.role == 'supervisor') {
            supervisor = SupervisorModel.fromJson(roleRecord);
          }
        }
        final companyJson = data['company'] as Map<String, dynamic>?;
        final company = companyJson != null ? CompanyModel.fromJson(companyJson) : null;
        return SessionContext(
          profile: profile,
          employee: employee,
          supervisor: supervisor,
          company: company,
        );
      }
    } catch (_) {
      // Transient network/RLS hiccup right after cold start — swallow and
      // retry rather than permanently caching a null result.
    }
    if (attempt < 5) {
      await Future.delayed(Duration(milliseconds: 300 * (attempt + 1)));
    }
  }
  return null;
});

final currentProfileProvider = FutureProvider<ProfileModel?>((ref) async {
  final ctx = await ref.watch(sessionContextProvider.future);
  return ctx?.profile;
});

final currentUserRoleProvider = Provider<String>((ref) {
  final profile = ref.watch(currentProfileProvider);
  return profile.valueOrNull?.role ?? 'supervisor';
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseProvider));
});

class AuthRepository {
  final SupabaseClient _client;
  AuthRepository(this._client);

  Future<AuthResponse> signInWithEmail(String email, String password) async {
    try {
      return await _client.auth
          .signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw app_errors.AuthException(e.message);
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
      return await _client.auth
          .updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw app_errors.AuthException(e.message);
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;

  Future<ProfileModel?> getCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    if (data == null) return null;
    return ProfileModel.fromJson(data);
  }

  Future<void> saveFcmToken(String token, String platform) async {
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
    } catch (_) {}
  }
}

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
    var filterQuery = _client.from('employees').select('*, departments(name), locations(name)');
    if (status != null) filterQuery = filterQuery.eq('status', status);
    if (search != null && search.isNotEmpty) {
      filterQuery = filterQuery
          .or('name.ilike.%$search%,employee_code.ilike.%$search%');
    }
    final data =
        await filterQuery.order('created_at', ascending: false).range(page * limit, (page + 1) * limit - 1);
    return (data as List)
        .map((e) => EmployeeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EmployeeModel?> getById(String id) async {
    final data = await _client
        .from('employees')
        .select('*, departments(name), locations(name)')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return EmployeeModel.fromJson(data);
  }

  Future<EmployeeModel?> getByProfileId(String profileId) async {
    // Mirrors the retry added to currentProfileProvider: an employee's
    // account is created via an edge function that creates the auth user,
    // the profiles row, and the employees row (with profile_id linking
    // them) in quick succession. A first-login/cold-start query can land
    // in the brief window before that link is fully committed, coming back
    // empty and showing "No employee record linked" (or, since the
    // dashboard's own record drives everything else it renders, an error
    // that only clears after force-closing and reopening the app). Retry
    // briefly before accepting a genuinely-empty result.
    for (var attempt = 0; attempt < 4; attempt++) {
      final data = await _client
          .from('employees')
          .select('*, departments(name), locations(name)')
          .eq('profile_id', profileId)
          .maybeSingle();
      if (data != null) return EmployeeModel.fromJson(data);
      if (attempt < 3) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    return null;
  }

  Future<String?> getSupervisorIdForEmployee(String employeeId) async {
    final data = await _client
        .from('supervisor_employees')
        .select('supervisor_id')
        .eq('employee_id', employeeId)
        .maybeSingle();
    return data?['supervisor_id'] as String?;
  }

  Future<EmployeeModel> create(Map<String, dynamic> data) async {
    final profile = _client.auth.currentUser;
    if (!data.containsKey('company_id') || data['company_id'] == null) {
      final profileRow = await _client
          .from('profiles')
          .select('company_id')
          .eq('id', profile!.id)
          .single();
      data['company_id'] = profileRow['company_id'];
    }
    final companyId = data['company_id'] as String?;
    final code = await _client.rpc(
      'generate_employee_code',
      params: {'p_company_id': companyId},
    ) as String;

    // Single atomic RPC — inserts employee + supervisor_employees in one
    // transaction. Runs as SECURITY DEFINER so RLS is bypassed for both
    // tables. Either both succeed or neither does.
    final employeeId = await _client.rpc('create_employee', params: {
      'p_employee_code': code,
      'p_name': data['name'],
      'p_mobile': data['mobile'],
      'p_address': data['address'],
      'p_aadhaar_number': data['aadhaar_number'],
      'p_designation': data['designation'],
      'p_daily_wage_rate': data['daily_wage_rate'],
      'p_joining_date': data['joining_date'],
      'p_department_id': data['department_id'],
      'p_location_id': data['location_id'],
      'p_status': (data['status'] ?? 'active').toString(),
      'p_upi_id': data['upi_id'],
      'p_bank_account_number': data['bank_account_number'],
      'p_bank_ifsc': data['bank_ifsc'],
      'p_bank_name': data['bank_name'],
      'p_company_id': companyId,
      'p_created_by': _client.auth.currentUser?.id,
      'p_supervisor_id': data['supervisor_id'],
      'p_gender': data['gender'],
    }) as String;

    final result = await _client
        .from('employees')
        .select('*, departments(name), locations(name)')
        .eq('id', employeeId)
        .single();

    await _logAudit('employee_created', 'employees', employeeId, null, result);
    return EmployeeModel.fromJson(result);
  }

  /// Creates login credentials for an existing employee record.
  Future<EmployeeModel> createLogin(String employeeId, String employeeCode) async {
    final email = '${employeeCode.toUpperCase()}@ems.com';
    final response = await _client.functions.invoke(
      'create-employee-login',
      body: {
        'email': email,
        'password': 'Abcd@123',
        'employee_id': employeeId,
        'must_change_password': true,
      },
    );
    final responseData = response.data as Map<String, dynamic>?;
    if (response.status != 200) {
      throw Exception(responseData?['error'] ?? 'Failed to create employee login');
    }
    final result = await getById(employeeId);

    // Defensive sync: this app's create-supervisor edge function was
    // found to silently drop gender entirely when creating the linked
    // profiles row (see SupervisorRepository.create()'s fix). We don't
    // have create-employee-login's source to know whether it has the
    // same gap, so rather than assume it's fine, explicitly copy this
    // employee's already-correct gender (set via create_employee's
    // p_gender) onto their new profiles row here too.
    if (result?.gender != null && result?.profileId != null) {
      try {
        await _client
            .from('profiles')
            .update({'gender': result!.gender})
            .eq('id', result.profileId!);
      } catch (_) {
        // Best-effort — the employee's own dashboard/lists read gender
        // from the employees table directly regardless, so this isn't
        // fatal if it fails.
      }
    }

    return result!;
  }

  Future<EmployeeModel> update(String id, Map<String, dynamic> data) async {
    final supervisorId = data.remove('supervisor_id');
    final result = await _client
        .from('employees')
        .update(data)
        .eq('id', id)
        .select('*, departments(name), locations(name)')
        .single();

    // Only touch the supervisor_employees link if this update actually
    // carries a supervisor_id, and only if it's actually different from
    // what's already assigned. This used to unconditionally delete then
    // re-insert the link on EVERY edit, even ones that never touched the
    // supervisor field. When a supervisor (not admin) edits their own
    // employee, the delete is blocked by RLS (supervisors don't have
    // delete rights on supervisor_employees), so it silently affects 0
    // rows — and the re-insert then collides with the still-existing row,
    // throwing "duplicate key value violates unique constraint
    // supervisor_employees_supervisor_id_employee_id_key". Checking first
    // avoids the round trip entirely in the common case, and catching a
    // duplicate-key conflict on the insert (below) makes it safe even if
    // the delete silently no-ops for some caller's role.
    if (supervisorId != null) {
      final existing = await _client
          .from('supervisor_employees')
          .select('supervisor_id')
          .eq('employee_id', id)
          .maybeSingle();
      final existingSupervisorId = existing?['supervisor_id'] as String?;
      if (existingSupervisorId != supervisorId) {
        await _client.from('supervisor_employees').delete().eq('employee_id', id);
        try {
          await _client.from('supervisor_employees').insert({
            'employee_id': id,
            'supervisor_id': supervisorId,
          });
        } on PostgrestException catch (e) {
          // The link already exists — e.g. the delete above was silently
          // blocked by RLS for this caller's role. That's the desired end
          // state anyway, so treat a duplicate-key conflict as a no-op
          // rather than surfacing it as a failed update.
          if (e.code != '23505') rethrow;
        }
      }
    }

    // Keep profiles.gender in sync — see the matching comment in
    // SupervisorRepository.update(). Employees whose login was created
    // separately (createLogin) have a profile_id linking them here.
    if (data.containsKey('gender')) {
      final profileId = result['profile_id'] as String?;
      if (profileId != null) {
        await _client
            .from('profiles')
            .update({'gender': data['gender']})
            .eq('id', profileId);
      }
    }

    await _logAudit('employee_updated', 'employees', id, null, result);
    return EmployeeModel.fromJson(result);
  }

  Future<void> delete(String id) async {
    await _client.from('employees').delete().eq('id', id);
    await _logAudit('employee_deleted', 'employees', id, null, null);
  }

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

  /// Own attendance records for the logged-in employee (bug #8)
  Future<List<AttendanceDetailModel>> getOwnAttendance(
    String employeeId, {
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    var filterQuery = _client
        .from('attendance_details')
        .select('*, attendance!inner(attendance_date, location_name, is_approved)')
        .eq('employee_id', employeeId)
        // Item 5 (new list)/correctness fix: only count attendance that
        // has actually been APPROVED \u{2014} an employee's dashboard
        // shouldn't show pending/unapproved days as if they're final,
        // since that's not what payroll will end up using either.
        .eq('attendance.is_approved', true);

    if (fromDate != null) {
      filterQuery = filterQuery.gte(
          'attendance.attendance_date', fromDate.toIso8601String().split('T').first);
    }
    if (toDate != null) {
      filterQuery = filterQuery.lte(
          'attendance.attendance_date', toDate.toIso8601String().split('T').first);
    }

    final data = await filterQuery;
    return (data as List).map((d) {
      final att = d['attendance'] as Map<String, dynamic>?;
      return AttendanceDetailModel(
        id: d['id'] as String,
        attendanceId: d['attendance_id'] as String,
        employeeId: d['employee_id'] as String,
        status: d['status'] as String,
        overtimeHours: (d['overtime_hours'] as num?)?.toDouble() ?? 0,
        remarks: d['remarks'] as String?,
        createdAt: DateTime.parse(d['created_at'] as String),
        attendanceDate: att != null && att['attendance_date'] != null
            ? DateTime.parse(att['attendance_date'] as String)
            : null,
      );
    }).toList();
  }

  Future<void> _logAudit(String action, String entity, String entityId,
      dynamic old, dynamic newVal) async {
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

final supervisorRepositoryProvider = Provider<SupervisorRepository>((ref) {
  return SupervisorRepository(ref.watch(supabaseProvider));
});

class SupervisorRepository {
  final SupabaseClient _client;
  SupervisorRepository(this._client);

  Future<List<SupervisorModel>> getAll({String? search, bool? isActive}) async {
    var filterQuery = _client.from('supervisors').select();
    if (isActive != null) filterQuery = filterQuery.eq('is_active', isActive);
    if (search != null && search.trim().isNotEmpty) {
      filterQuery = filterQuery.or(
          'name.ilike.%$search%,email.ilike.%$search%,supervisor_code.ilike.%$search%');
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
    // Mirrors EmployeeRepository.getByProfileId — this was previously a
    // single, non-retrying query, while the employee equivalent already
    // had this exact retry loop for this exact race. A supervisor account
    // is created via an edge function that writes the auth user, the
    // profiles row, and the supervisors row (linked by profile_id) in
    // quick succession; a first-login/cold-start (or a fast logout->login)
    // query can land in the brief window before that link is fully
    // committed, come back empty, and leave the supervisor dashboard
    // stuck needing a manual reload before it would land after that
    // window had already closed.
    for (var attempt = 0; attempt < 4; attempt++) {
      final data = await _client
          .from('supervisors')
          .select()
          .eq('profile_id', profileId)
          .maybeSingle();
      if (data != null) return SupervisorModel.fromJson(data);
      if (attempt < 3) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    return null;
  }

  Future<SupervisorModel> create(
      Map<String, dynamic> supervisorData, String password) async {
    final response = await _client.functions.invoke(
  'create-supervisor',
  body: {
    'email': supervisorData['email'],
    'password': password,
    'full_name': supervisorData['name'],
    'mobile': supervisorData['mobile'],
    'assigned_area': supervisorData['assigned_area'],
    'monthly_salary': supervisorData['monthly_salary'] ?? 0,
    'gender': supervisorData['gender'],
    'created_by': _client.auth.currentUser!.id,
  },
);

    final responseData = response.data as Map<String, dynamic>?;
    if (response.status != 200) {
      throw Exception(responseData?['error'] ?? 'Failed to create supervisor');
    }

    final supervisorCode = responseData!['supervisor_code'] as String;
    final supervisor = await _client
        .from('supervisors')
        .select()
        .eq('supervisor_code', supervisorCode)
        .single();

    final created = SupervisorModel.fromJson(supervisor);

    // Apply UPI/bank/salary fields that the edge function may not handle
    final extra = <String, dynamic>{};
    if (supervisorData['upi_id'] != null) extra['upi_id'] = supervisorData['upi_id'];
    if (supervisorData['bank_account_number'] != null) extra['bank_account_number'] = supervisorData['bank_account_number'];
    if (supervisorData['bank_ifsc'] != null) extra['bank_ifsc'] = supervisorData['bank_ifsc'];
    if (supervisorData['bank_name'] != null) extra['bank_name'] = supervisorData['bank_name'];
    if (supervisorData['monthly_salary'] != null) extra['monthly_salary'] = supervisorData['monthly_salary'];
    if (extra.isNotEmpty) {
      final updated = await _client
          .from('supervisors')
          .update(extra)
          .eq('id', created.id)
          .select()
          .single();
      return SupervisorModel.fromJson(updated);
    }

    return created;
  }

  Future<SupervisorModel> update(String id, Map<String, dynamic> data) async {
    final result = await _client
        .from('supervisors')
        .update({...data, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .select()
        .single();

    // Keep profiles.gender in sync — a couple of screens read gender from
    // profiles as a fallback when a role-specific record isn't loaded
    // yet, and letting it silently diverge from supervisors.gender is
    // exactly what caused gender to look "unset" in some places and
    // correctly-set in others for the same person.
    if (data.containsKey('gender')) {
      final profileId = result['profile_id'] as String?;
      if (profileId != null) {
        await _client
            .from('profiles')
            .update({'gender': data['gender']})
            .eq('id', profileId);
      }
    }

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
        await _client.functions.invoke('delete-supervisor',
            body: {'user_id': supervisor['profile_id']});
      } catch (_) {}
    }
  }

  /// Item 3: a supervisor's assigned locations are OPTIONAL and
  /// many-to-many. An empty list means "unrestricted" \u{2014} this supervisor
  /// can submit attendance for ANY location, which is the existing
  /// default behavior and must be preserved.
  Future<List<String>> getAssignedLocationIds(String supervisorId) async {
    final rows = await _client
        .from('supervisor_locations')
        .select('location_id')
        .eq('supervisor_id', supervisorId);
    return (rows as List)
        .map((r) => r['location_id'] as String)
        .toList();
  }

  Future<void> setAssignedLocations(
      String supervisorId, List<String> locationIds) async {
    // Simplest correct approach: replace the whole set. Supervisor
    // location lists are small (a handful of locations), so a
    // delete-then-insert is fine and avoids diffing complexity/bugs.
    await _client
        .from('supervisor_locations')
        .delete()
        .eq('supervisor_id', supervisorId);
    if (locationIds.isNotEmpty) {
      await _client.from('supervisor_locations').insert(locationIds
          .map((id) => {'supervisor_id': supervisorId, 'location_id': id})
          .toList());
    }
  }

  Future<void> uploadPhoto(
      String supervisorId, List<int> fileBytes, String fileName) async {
    final userId = _client.auth.currentUser?.id ?? 'unknown';
    final path = '$userId/supervisors/$supervisorId/$fileName';
    await _client.storage
        .from('employee_photos')
        .uploadBinary(path, Uint8List.fromList(fileBytes));
    final url =
        _client.storage.from('employee_photos').getPublicUrl(path);
    await _client
        .from('supervisors')
        .update({'profile_photo_url': url}).eq('id', supervisorId);
    final sup = await _client
        .from('supervisors')
        .select('profile_id')
        .eq('id', supervisorId)
        .maybeSingle();
    if (sup?['profile_id'] != null) {
      await _client
          .from('profiles')
          .update({'profile_photo_url': url}).eq('id', sup!['profile_id']);
    }
  }

  Future<List<EmployeeModel>> getAssignedEmployees(String supervisorId) async {
    final data = await _client
        .from('supervisor_employees')
        .select('employees(*, departments(name), locations(name))')
        .eq('supervisor_id', supervisorId);
    return (data as List)
        .where((row) => row['employees'] != null)
        .map((row) =>
            EmployeeModel.fromJson(row['employees'] as Map<String, dynamic>))
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
    await _client.from('supervisor_employees').insert(
        {'supervisor_id': supervisorId, 'employee_id': employeeId});
  }

  Future<void> removeEmployee(String supervisorId, String employeeId) async {
    await _client
        .from('supervisor_employees')
        .delete()
        .eq('supervisor_id', supervisorId)
        .eq('employee_id', employeeId);
  }
}

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
    var filterQuery = _client.from('attendance').select(
        '*, supervisors(name), attendance_details(*, employees(name, employee_code, gender, employee_photo_url))');
    if (supervisorId != null) {
      filterQuery = filterQuery.eq('supervisor_id', supervisorId);
    }
    if (fromDate != null) {
      filterQuery = filterQuery.gte(
          'attendance_date', fromDate.toIso8601String().split('T').first);
    }
    if (toDate != null) {
      filterQuery = filterQuery.lte(
          'attendance_date', toDate.toIso8601String().split('T').first);
    }
    final data = await filterQuery
        .order('attendance_date', ascending: false)
        .range(page * limit, (page + 1) * limit - 1);
    return (data as List)
        .map((a) => AttendanceModel.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  Future<AttendanceModel?> getById(String id) async {
    final data = await _client
        .from('attendance')
        .select(
            '*, supervisors(name), attendance_details(*, employees(name, employee_code, gender, employee_photo_url))')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return AttendanceModel.fromJson(data);
  }

  Future<AttendanceModel?> getTodayBySupervisor(String supervisorId) async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final data = await _client
        .from('attendance')
        .select(
            '*, attendance_details(*, employees(name, employee_code, gender, employee_photo_url))')
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
    final result = await _client
        .from('attendance')
        .insert(attendanceData)
        .select()
        .single();
    final attendanceId = result['id'] as String;
    final details =
        detailsData.map((d) => {...d, 'attendance_id': attendanceId}).toList();
    await _client.from('attendance_details').insert(details);

    await _notifyAdmins(
      title: 'New Attendance Submitted',
      body: 'Attendance submitted for ${attendanceData['attendance_date']}',
      type: 'attendance',
      referenceId: attendanceId,
    );

    await _logAudit('attendance_created', 'attendance', attendanceId);
    final full = await getById(attendanceId);
    return full!;
  }

  Future<AttendanceModel> updateDetails(
    String attendanceId,
    Map<String, dynamic> attendanceData,
    List<Map<String, dynamic>> detailsData,
  ) async {
    await _client.from('attendance').update({
      ...attendanceData,
      'is_approved': false,
      'approved_by': null,
      'approved_at': null,
    }).eq('id', attendanceId);

    for (final detail in detailsData) {
      await _client.from('attendance_details').upsert(
        {...detail, 'attendance_id': attendanceId},
        onConflict: 'attendance_id, employee_id',
      );
    }

    await _notifyAdmins(
      title: 'Attendance Resubmitted',
      body: 'Attendance has been edited and resubmitted for approval',
      type: 'attendance',
      referenceId: attendanceId,
    );

    await _logAudit('attendance_updated', 'attendance', attendanceId);
    final full = await getById(attendanceId);
    return full!;
  }

  Future<void> approve(String attendanceId, String adminId) async {
    final att = await _client
        .from('attendance')
        .select('supervisor_id')
        .eq('id', attendanceId)
        .maybeSingle();

    await _client.from('attendance').update({
      'is_approved': true,
      'approved_by': adminId,
      'approved_at': DateTime.now().toIso8601String(),
    }).eq('id', attendanceId);

    if (att != null) {
      await _notifySupervisor(
        supervisorId: att['supervisor_id'] as String,
        title: 'Attendance Approved',
        body: 'Your attendance submission has been approved',
        type: 'attendance_approved',
        referenceId: attendanceId,
      );
    }

    await _logAudit('attendance_approved', 'attendance', attendanceId);
  }

  /// Today's summary scoped correctly (used by dashboard, already date-filtered by definition)
  Future<Map<String, int>> getTodaySummary() async {
    final today = DateTime.now().toIso8601String().split('T').first;
    final attendance = await _client
        .from('attendance')
        .select('attendance_details(status)')
        .eq('attendance_date', today);

    final counts = <String, int>{
      'present': 0,
      'absent': 0,
      'half_day': 0,
      'leave': 0
    };

    for (final record in attendance as List) {
      final details = record['attendance_details'] as List<dynamic>? ?? [];
      for (final detail in details) {
        final status = detail['status'] as String?;
        if (status != null) counts[status] = (counts[status] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<void> _notifyAdmins({
    required String title,
    required String body,
    String? type,
    String? referenceId,
  }) async {
    try {
      final admins = await _client
          .from('profiles')
          .select('id')
          .eq('role', 'admin')
          .eq('is_active', true);

      for (final admin in admins as List) {
        await _client.from('notifications').insert({
          'user_id': admin['id'],
          'title': title,
          'body': body,
          'type': type,
          'reference_id': referenceId,
          'reference_type': type,
          'is_read': false,
        });
      }
    } catch (_) {}
  }

  Future<void> _notifySupervisor({
    required String supervisorId,
    required String title,
    required String body,
    String? type,
    String? referenceId,
  }) async {
    try {
      final sup = await _client
          .from('supervisors')
          .select('profile_id')
          .eq('id', supervisorId)
          .maybeSingle();
      if (sup?['profile_id'] != null) {
        await _client.from('notifications').insert({
          'user_id': sup!['profile_id'],
          'title': title,
          'body': body,
          'type': type,
          'reference_id': referenceId,
          'reference_type': type,
          'is_read': false,
        });
      }
    } catch (_) {}
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
    var filterQuery = _client
        .from('expenses')
        .select('*, supervisors(name, gender, profile_photo_url), expense_attachments(*)');
    if (supervisorId != null) {
      filterQuery = filterQuery.eq('supervisor_id', supervisorId);
    }
    if (status != null) filterQuery = filterQuery.eq('status', status);
    if (category != null) filterQuery = filterQuery.eq('category', category);
    if (fromDate != null) {
      filterQuery = filterQuery.gte(
          'expense_date', fromDate.toIso8601String().split('T').first);
    }
    if (toDate != null) {
      filterQuery = filterQuery.lte(
          'expense_date', toDate.toIso8601String().split('T').first);
    }
    final data = await filterQuery
        .order('created_at', ascending: false)
        .range(page * limit, (page + 1) * limit - 1);
    return (data as List)
        .map((e) => ExpenseModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ExpenseModel?> getById(String id) async {
    final data = await _client
        .from('expenses')
        .select('*, supervisors(name, gender, profile_photo_url), expense_attachments(*)')
        .eq('id', id)
        .maybeSingle();
    if (data == null) return null;
    return ExpenseModel.fromJson(data);
  }

  Future<ExpenseModel> create(Map<String, dynamic> data) async {
    final result = await _client
        .from('expenses')
        .insert(data)
        .select('*, supervisors(name, gender, profile_photo_url)')
        .single();
    final expenseId = result['id'] as String;

    // Deduct from supervisor wallet immediately on submission
    await _client.rpc('deduct_wallet_on_expense_approve',
        params: {'p_expense_id': expenseId});

    await _logAudit('expense_submitted', 'expenses', expenseId);

    await _notifyAdmins(
      title: 'New Expense Submitted',
      body: '${data['expense_name']} - Rs.${data['amount']}',
      type: 'expense',
      referenceId: expenseId,
    );

    return ExpenseModel.fromJson(result);
  }

  Future<ExpenseModel> update(String id, Map<String, dynamic> data) async {
    // If the amount is part of this update, capture the OLD amount first
    // so the wallet can be adjusted by the exact delta afterward. Without
    // this, editing an expense's amount after submission silently
    // desyncs supervisor_wallet.total_deducted/balance from reality
    // forever, since the wallet was only ever deducted once, at
    // submission time, based on the ORIGINAL amount.
    double? oldAmount;
    if (data.containsKey('amount')) {
      final existing = await _client
          .from('expenses')
          .select('amount')
          .eq('id', id)
          .maybeSingle();
      oldAmount = (existing?['amount'] as num?)?.toDouble();
    }

    final result = await _client
        .from('expenses')
        .update(data)
        .eq('id', id)
        .select('*, supervisors(name, gender, profile_photo_url)')
        .single();

    if (oldAmount != null) {
      final newAmount = (data['amount'] as num).toDouble();
      if (newAmount != oldAmount) {
        await _client.rpc('adjust_wallet_on_expense_amount_change', params: {
          'p_expense_id': id,
          'p_old_amount': oldAmount,
          'p_new_amount': newAmount,
        });
      }
    }

    return ExpenseModel.fromJson(result);
  }

  Future<void> approve(String id, String adminId, {String? remarks}) async {
    final exp = await _client
        .from('expenses')
        .select('supervisor_id, expense_name, amount')
        .eq('id', id)
        .maybeSingle();

    await _client.from('expenses').update({
      'status': 'approved',
      'reviewed_by': adminId,
      'reviewed_at': DateTime.now().toIso8601String(),
      'admin_remarks': remarks,
    }).eq('id', id);

    // Wallet already deducted on submission - no change needed on approve
    await _logAudit('expense_approved', 'expenses', id);

    if (exp != null) {
      await _notifySupervisor(
        supervisorId: exp['supervisor_id'] as String,
        title: 'Expense Approved',
        body: '${exp['expense_name']} Rs.${exp['amount']} has been approved',
        type: 'expense_approved',
        referenceId: id,
      );
    }
  }

  Future<void> reject(String id, String adminId,
      {required String remarks}) async {
    final exp = await _client
        .from('expenses')
        .select('supervisor_id, expense_name')
        .eq('id', id)
        .maybeSingle();

    await _client.from('expenses').update({
      'status': 'rejected',
      'reviewed_by': adminId,
      'reviewed_at': DateTime.now().toIso8601String(),
      'admin_remarks': remarks,
    }).eq('id', id);

    // Refund wallet balance on rejection
    await _client.rpc('refund_wallet_on_expense_reject', params: {'p_expense_id': id});

    await _logAudit('expense_rejected', 'expenses', id);

    if (exp != null) {
      await _notifySupervisor(
        supervisorId: exp['supervisor_id'] as String,
        title: 'Expense Rejected',
        body: '${exp['expense_name']} has been rejected. Reason: $remarks',
        type: 'expense_rejected',
        referenceId: id,
      );
    }
  }

  Future<String> uploadAttachment(String expenseId, List<int> bytes,
      String fileName, String mimeType,
      {bool isReceipt = false}) async {
    final userId = _client.auth.currentUser?.id ?? 'unknown';
    final path = '$userId/$expenseId/$fileName';
    await _client.storage.from('expense_receipts').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
    final url =
        _client.storage.from('expense_receipts').getPublicUrl(path);
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

  /// CURRENT MONTH ONLY summary used by dashboard (fixes bug #4 expense part)
  Future<Map<String, dynamic>> getSummary({DateTime? fromDate, DateTime? toDate}) async {
    var filterQuery = _client.from('expenses').select('status, amount');
    if (fromDate != null) {
      filterQuery = filterQuery.gte(
          'expense_date', fromDate.toIso8601String().split('T').first);
    }
    if (toDate != null) {
      filterQuery = filterQuery.lte(
          'expense_date', toDate.toIso8601String().split('T').first);
    }
    final data = await filterQuery;
    final summary = {
      'pending': 0.0,
      'approved': 0.0,
      'rejected': 0.0,
      'total': 0.0
    };
    for (final row in data as List) {
      final status = row['status'] as String;
      final amount = (row['amount'] as num).toDouble();
      summary[status] = (summary[status] ?? 0) + amount;
      summary['total'] = (summary['total'] ?? 0) + amount;
    }
    return summary;
  }

  /// Expenses grouped by supervisor then by month (bug #9 drilldown)
  Future<Map<String, List<ExpenseModel>>> getGroupedBySupervisor({
    String? status,
  }) async {
    var filterQuery = _client
        .from('expenses')
        .select('*, supervisors(name, gender, profile_photo_url), expense_attachments(*)');
    if (status != null) filterQuery = filterQuery.eq('status', status);
    final data = await filterQuery.order('expense_date', ascending: false);

    final grouped = <String, List<ExpenseModel>>{};
    for (final row in data as List) {
      final exp = ExpenseModel.fromJson(row as Map<String, dynamic>);
      grouped.putIfAbsent(exp.supervisorId, () => []).add(exp);
    }
    return grouped;
  }

  Future<void> _notifyAdmins({
    required String title,
    required String body,
    String? type,
    String? referenceId,
  }) async {
    try {
      final admins = await _client
          .from('profiles')
          .select('id')
          .eq('role', 'admin')
          .eq('is_active', true);
      for (final admin in admins as List) {
        await _client.from('notifications').insert({
          'user_id': admin['id'],
          'title': title,
          'body': body,
          'type': type,
          'reference_id': referenceId,
          'reference_type': type,
          'is_read': false,
        });
      }
    } catch (_) {}
  }

  Future<void> _notifySupervisor({
    required String supervisorId,
    required String title,
    required String body,
    String? type,
    String? referenceId,
  }) async {
    try {
      final sup = await _client
          .from('supervisors')
          .select('profile_id')
          .eq('id', supervisorId)
          .maybeSingle();
      if (sup?['profile_id'] != null) {
        await _client.from('notifications').insert({
          'user_id': sup!['profile_id'],
          'title': title,
          'body': body,
          'type': type,
          'reference_id': referenceId,
          'reference_type': type,
          'is_read': false,
        });
      }
    } catch (_) {}
  }

  Future<void> _logAudit(
      String action, String entity, String entityId) async {
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

final payrollRepositoryProvider = Provider<PayrollRepository>((ref) {
  return PayrollRepository(ref.watch(supabaseProvider));
});

class PayrollRepository {
  final SupabaseClient _client;
  PayrollRepository(this._client);

  static const _months = [
    '', 'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  static String _monthName(int m) => _months[m.clamp(1, 12)];

  Future<List<PayrollModel>> getByMonthYear(int month, int year) async {
    final data = await _client
        .from('payroll')
        .select('*, employees(name, employee_code, gender, employee_photo_url)')
        .eq('payroll_month', month)
        .eq('payroll_year', year)
        .order('created_at', ascending: false);
    return (data as List)
        .map((p) => PayrollModel.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<PayrollModel?> getByEmployeeMonth(
      String employeeId, int month, int year) async {
    final data = await _client
        .from('payroll')
        .select('*, employees(name, employee_code, gender, employee_photo_url)')
        .eq('employee_id', employeeId)
        .eq('payroll_month', month)
        .eq('payroll_year', year)
        .maybeSingle();
    if (data == null) return null;
    return PayrollModel.fromJson(data);
  }

  /// Own payroll history for logged-in employee (bug #8)
  Future<List<PayrollModel>> getOwnPayrollHistory(String employeeId, {int limit = 12}) async {
    final data = await _client
        .from('payroll')
        .select('*, employees(name, employee_code, gender, employee_photo_url)')
        .eq('employee_id', employeeId)
        .order('payroll_year', ascending: false)
        .order('payroll_month', ascending: false)
        .limit(limit);
    return (data as List)
        .map((p) => PayrollModel.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<PayrollModel> processPayroll(
      String employeeId, int month, int year) async {
    // Fetch employee joining date alongside wage rate
    final employee = await _client
        .from('employees')
        .select('daily_wage_rate, joining_date, name, employee_code')
        .eq('id', employeeId)
        .single();
    final wageRate = (employee['daily_wage_rate'] as num).toDouble();
    final employeeName = employee['name'] as String? ?? 'This employee';
    final employeeCode = employee['employee_code'] as String? ?? '';

    // Item 5: Block payroll for months before the employee joined.
    // E.g. if an employee joined in March 2026, you can't run April 2025
    // payroll for them \u{2014} there are no records and it would be meaningless.
    if (employee['joining_date'] != null) {
      final joiningDate = DateTime.parse(employee['joining_date'] as String);
      final payrollDate = DateTime(year, month);
      final joiningMonth = DateTime(joiningDate.year, joiningDate.month);
      if (payrollDate.isBefore(joiningMonth)) {
        throw Exception(
            '$employeeName ($employeeCode) joined on '
            '${joiningDate.day}/${joiningDate.month}/${joiningDate.year}. '
            'You cannot process payroll for ${_monthName(month)} $year '
            'because it is before their joining month. '
            'Payroll can only be processed from ${_monthName(joiningDate.month)} ${joiningDate.year} onwards.');
      }
    }

    final summary = await _client.rpc('get_monthly_attendance_summary', params: {
      'p_employee_id': employeeId,
      'p_month': month,
      'p_year': year,
    }) as List;

    final s = summary.isNotEmpty ? summary.first as Map : <String, dynamic>{};
    final presentDays = (s['present_days'] as num?)?.toDouble() ?? 0;
    final halfDays = (s['half_days'] as num?)?.toDouble() ?? 0;
    final absentDays = (s['absent_days'] as num?)?.toDouble() ?? 0;
    final leaveDays = (s['leave_days'] as num?)?.toDouble() ?? 0;

    // Item 5: payroll can only be processed once at least one attendance
    // day has been APPROVED for this employee this month.
    // get_monthly_attendance_summary is assumed to only count attendance
    // where is_approved = true (please verify this matches your RPC's
    // actual definition \u{2014} I don't have its source to confirm).
    if (presentDays == 0 && halfDays == 0) {
      throw Exception(
          'Cannot process payroll for $employeeName ($employeeCode) '
          'for ${_monthName(month)} $year: no approved attendance found. '
          'At least one attendance day must be marked Present and approved by admin before payroll can be processed. '
          'Check: (1) Has the supervisor submitted attendance for this month? '
          '(2) Has the admin approved those attendance records?');
    }

    // Item 5: if this employee's payroll for this month was already
    // marked PAID, and attendance has since changed, re-processing
    // should refresh the wage numbers but must NOT silently erase the
    // fact that a payment was already made \u{2014} that's financial data the
    // admin needs to see in order to manually reconcile any difference.
    final existing = await _client
        .from('payroll')
        .select('status, payment_status, paid_at, payment_confirmed_at, utr_reference, payment_method')
        .eq('employee_id', employeeId)
        .eq('payroll_month', month)
        .eq('payroll_year', year)
        .maybeSingle();
    final wasAlreadyPaid =
        existing != null && (existing['status'] == 'paid' || existing['payment_status'] == 'paid');

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
      // Keep 'paid' status visible if it was already paid \u{2014} re-processing
      // updates the wage breakdown from fresh attendance but must not
      // hide that money already changed hands at the OLD numbers. The
      // admin should review and manually reconcile any difference.
      'status': wasAlreadyPaid ? 'paid' : 'processed',
      if (wasAlreadyPaid) 'payment_status': existing['payment_status'],
      if (wasAlreadyPaid) 'paid_at': existing['paid_at'],
      if (wasAlreadyPaid) 'payment_confirmed_at': existing['payment_confirmed_at'],
      if (wasAlreadyPaid) 'utr_reference': existing['utr_reference'],
      if (wasAlreadyPaid) 'payment_method': existing['payment_method'],
      'processed_by': _client.auth.currentUser?.id,
      'processed_at': DateTime.now().toIso8601String(),
    };

    final result = await _client
        .from('payroll')
        .upsert(payrollData,
            onConflict: 'employee_id, payroll_month, payroll_year')
        .select('*, employees(name, employee_code, gender, employee_photo_url)')
        .single();

    return PayrollModel.fromJson(result);
  }

  Future<PayrollModel> update(String id, Map<String, dynamic> data) async {
    final result = await _client
        .from('payroll')
        .update(data)
        .eq('id', id)
        .select('*, employees(name, employee_code, gender, employee_photo_url)')
        .single();
    return PayrollModel.fromJson(result);
  }

  Future<void> markAsPaid(String id) async {
    await _client.from('payroll').update({
      'status': 'paid',
      'paid_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// UPI payment confirm (used by payment flow)
  Future<void> confirmPayment(String id, {String? utrReference}) async {
    await _client.from('payroll').update({
      'status': 'paid',
      'payment_status': 'paid',
      'payment_method': 'upi',
      'utr_reference': utrReference,
      'paid_at': DateTime.now().toIso8601String(),
      'payment_confirmed_at': DateTime.now().toIso8601String(),
      'payment_confirmed_by': _client.auth.currentUser?.id,
    }).eq('id', id);
  }

  /// CURRENT MONTH liability/paid/pending \u{2014} already scoped by month/year params
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

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  return PaymentRepository(ref.watch(supabaseProvider));
});

class PaymentRepository {
  final SupabaseClient _client;
  PaymentRepository(this._client);

  /// Builds the UPI deep link URL to launch a payment app
  String buildUpiUri({
    required String upiId,
    required String payeeName,
    required double amount,
    required String referenceNote,
    required String transactionRef,
  }) {
    final amt = amount.toStringAsFixed(2);
    final encodedUpiId = Uri.encodeComponent(upiId.trim());
    final encodedName = Uri.encodeComponent(payeeName);
    final encodedNote = Uri.encodeComponent(referenceNote);
    final encodedTr = Uri.encodeComponent(transactionRef);
    // tr (transaction reference) is the critical addition here \u{2014} see
    // the comment on _makeTransactionRef in widgets.dart for why.
    return 'upi://pay?pa=$encodedUpiId&pn=$encodedName&am=$amt&cu=INR&tn=$encodedNote&tr=$encodedTr';
  }

  Future<void> logPayment({
    required String referenceType,
    required String referenceId,
    String? employeeId,
    String? supervisorId,
    required double amount,
    String? upiId,
    String paymentStatus = 'initiated',
    String? utrReference,
    String? remarks,
  }) async {
    await _client.from('payment_logs').insert({
      'reference_type': referenceType,
      'reference_id': referenceId,
      'employee_id': employeeId,
      'supervisor_id': supervisorId,
      'amount': amount,
      'upi_id': upiId,
      'payment_method': 'upi',
      'payment_status': paymentStatus,
      'utr_reference': utrReference,
      'initiated_by': _client.auth.currentUser?.id,
      'confirmed_at': paymentStatus == 'paid' ? DateTime.now().toIso8601String() : null,
      'confirmed_by': paymentStatus == 'paid' ? _client.auth.currentUser?.id : null,
      'remarks': remarks,
    });
  }

  Future<List<PaymentLogModel>> getHistory({String? referenceType, String? referenceId}) async {
    var filterQuery = _client.from('payment_logs').select();
    if (referenceType != null) filterQuery = filterQuery.eq('reference_type', referenceType);
    if (referenceId != null) filterQuery = filterQuery.eq('reference_id', referenceId);
    final data = await filterQuery.order('initiated_at', ascending: false);
    return (data as List)
        .map((p) => PaymentLogModel.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<void> confirmExpensePayment(String expenseId, {String? utrReference}) async {
    await _client.from('expenses').update({
      'payment_status': 'paid',
      'payment_method': 'upi',
      'utr_reference': utrReference,
      'payment_confirmed_at': DateTime.now().toIso8601String(),
      'payment_confirmed_by': _client.auth.currentUser?.id,
    }).eq('id', expenseId);
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.watch(supabaseProvider));
});

class NotificationRepository {
  final SupabaseClient _client;
  NotificationRepository(this._client);

  Future<List<NotificationModel>> getForCurrentUser({int limit = 50}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    final data = await _client
        .from('notifications')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List)
        .map((n) => NotificationModel.fromJson(n as Map<String, dynamic>))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;
    final res = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', user.id)
        .eq('is_read', false);
    return (res as List).length;
  }

  Future<void> markRead(String id) async {
    await _client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllRead() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', user.id);
  }
}

/// Dashboard stats \u{2014} now autoDispose (bug #4 fix: stops permanent caching) and
/// expense summary is scoped to CURRENT MONTH ONLY (was all-time before).
final dashboardStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = ref.read(supabaseProvider);
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 0);

  // Wrapped in a bounded retry: right after a fast logout->login (as the
  // same or a different user), these queries can transiently fail while
  // the new session's RLS/JWT context is still propagating — that used to
  // surface as a dashboard error card requiring a manual tap of "Retry",
  // or, for anything not already behind an AsyncValue boundary, the app's
  // generic crash screen. Retrying here means it resolves itself within
  // about a second and a half with no input needed.
  final results = await withRetry(() => Future.wait<dynamic>([
        client.from('employees').select('id') as Future<dynamic>,
        client.from('employees').select('id').eq('status', 'active') as Future<dynamic>,
        ref.read(attendanceRepositoryProvider).getTodaySummary(),
        ref.read(expenseRepositoryProvider).getSummary(fromDate: monthStart, toDate: monthEnd),
        ref.read(payrollRepositoryProvider).getMonthlySummary(now.month, now.year),
        ref.read(supervisorPayrollRepositoryProvider).getMonthlySummary(now.month, now.year),
      ]));

  final totalEmp = results[0] as List;
  final activeEmp = results[1] as List;
  final todayAttendance = results[2] as Map<String, dynamic>;
  final expenseSummary = results[3] as Map<String, double>;
  final payrollSummary = results[4] as Map<String, double>;
  final supervisorPayrollSummary = results[5] as Map<String, double>;

  return {
    'total_employees': totalEmp.length,
    'active_employees': activeEmp.length,
    'today_present': todayAttendance['present'] ?? 0,
    'today_absent': todayAttendance['absent'] ?? 0,
    'expense_pending': expenseSummary['pending'] ?? 0,
    'expense_approved': expenseSummary['approved'] ?? 0,
    'expense_rejected': expenseSummary['rejected'] ?? 0,
    'payroll_liability': (payrollSummary['liability'] ?? 0) + (supervisorPayrollSummary['liability'] ?? 0),
    'payroll_paid': (payrollSummary['paid'] ?? 0) + (supervisorPayrollSummary['paid'] ?? 0),
    'payroll_pending': (payrollSummary['pending'] ?? 0) + (supervisorPayrollSummary['pending'] ?? 0),
  };
});


// Add at bottom of auth_repository.dart (after dashboardStatsProvider)

final companyProvider = FutureProvider.autoDispose<CompanyModel?>((ref) async {
  // Derives from the same single combined fetch as currentProfileProvider
  // (see sessionContextProvider) instead of running its own separate
  // company query — one less round trip, and `ref.watch` here means it
  // automatically stays in sync with whichever user/company is currently
  // signed in, including switching companies on a fast logout->login.
  final ctx = await ref.watch(sessionContextProvider.future);
  return ctx?.company;
});

final paymentModuleEnabledProvider = Provider<bool>((ref) {
  return ref.watch(companyProvider).valueOrNull?.paymentModuleEnabled ?? false;
});

final supervisorPayrollRepositoryProvider =
    Provider<SupervisorPayrollRepository>((ref) {
  return SupervisorPayrollRepository(ref.watch(supabaseProvider));
});

class SupervisorPayrollRepository {
  final SupabaseClient _client;
  SupervisorPayrollRepository(this._client);

  /// All supervisors' payroll for a given month (admin view) \u{2014} mirrors
  /// PayrollRepository.getByMonthYear for employees.
  Future<List<SupervisorPayrollModel>> getByMonthYear(
      int month, int year) async {
    final data = await _client
        .from('supervisor_payroll')
        .select('*, supervisors(name, supervisor_code)')
        .eq('payroll_month', month)
        .eq('payroll_year', year)
        .order('created_at', ascending: false);
    return (data as List)
        .map((p) =>
            SupervisorPayrollModel.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// Supervisors who don't yet have a payroll row for this month, so the
  /// admin can process them (mirrors how the employee payroll screen
  /// shows unprocessed employees).
  Future<List<SupervisorModel>> getUnprocessedForMonth(
      int month, int year) async {
    final allSupervisors = await _client
        .from('supervisors')
        .select()
        .eq('is_active', true);
    final processed = await _client
        .from('supervisor_payroll')
        .select('supervisor_id')
        .eq('payroll_month', month)
        .eq('payroll_year', year);
    final processedIds =
        (processed as List).map((p) => p['supervisor_id'] as String).toSet();
    return (allSupervisors as List)
        .map((s) => SupervisorModel.fromJson(s as Map<String, dynamic>))
        .where((s) => !processedIds.contains(s.id))
        .toList();
  }

  Future<List<SupervisorPayrollModel>> getForSupervisor(
      String supervisorId) async {
    final data = await _client
        .from('supervisor_payroll')
        .select()
        .eq('supervisor_id', supervisorId)
        .order('payroll_year', ascending: false)
        .order('payroll_month', ascending: false);
    return (data as List)
        .map((p) =>
            SupervisorPayrollModel.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  Future<SupervisorPayrollModel> processMonth(
      String supervisorId, int month, int year, double salary,
      {double bonus = 0, double deduction = 0, String? remarks}) async {
    final net = salary + bonus - deduction;
    final data = await _client
        .from('supervisor_payroll')
        .upsert({
          'supervisor_id': supervisorId,
          'payroll_month': month,
          'payroll_year': year,
          'monthly_salary': salary,
          'bonus': bonus,
          'deduction': deduction,
          'net_amount': net,
          'status': 'processed',
          'processed_by': _client.auth.currentUser?.id,
          'processed_at': DateTime.now().toIso8601String(),
          'remarks': remarks,
        }, onConflict: 'supervisor_id,payroll_month,payroll_year')
        .select()
        .single();
    return SupervisorPayrollModel.fromJson(data);
  }

  Future<void> confirmPayment(String id, {String? utrReference}) async {
    await _client.from('supervisor_payroll').update({
      'status': 'paid',
      'payment_status': 'paid',
      'payment_method': 'upi',
      'utr_reference': utrReference,
      'paid_at': DateTime.now().toIso8601String(),
      'payment_confirmed_at': DateTime.now().toIso8601String(),
      'payment_confirmed_by': _client.auth.currentUser?.id,
    }).eq('id', id);
  }

  Future<void> markAsPaid(String id) async {
    await _client.from('supervisor_payroll').update({
      'status': 'paid',
      'payment_status': 'paid',
      'payment_method': 'cash',
      'paid_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Mirrors PayrollRepository.getMonthlySummary for employees \u{2014} used so
  /// the admin dashboard's payroll Liability/Paid/Pending cards include
  /// BOTH employees and supervisors, not employees only.
  Future<Map<String, double>> getMonthlySummary(int month, int year) async {
    final data = await _client
        .from('supervisor_payroll')
        .select('net_amount, status')
        .eq('payroll_month', month)
        .eq('payroll_year', year);

    double totalLiability = 0, paid = 0, pending = 0;
    for (final row in data as List) {
      final net = (row['net_amount'] as num?)?.toDouble() ?? 0;
      totalLiability += net;
      if (row['status'] == 'paid') {
        paid += net;
      } else {
        pending += net;
      }
    }
    return {'liability': totalLiability, 'paid': paid, 'pending': pending};
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WALLET REPOSITORY
// ─────────────────────────────────────────────────────────────────────────────

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(supabaseProvider));
});

/// Provider for all supervisor wallets (admin view)
final supervisorWalletsProvider = FutureProvider.autoDispose<List<SupervisorWalletModel>>((ref) async {
  return ref.read(walletRepositoryProvider).getAllWallets();
});

/// Provider for a single supervisor's wallet
final supervisorWalletProvider = FutureProvider.autoDispose.family<SupervisorWalletModel?, String>((ref, supervisorId) async {
  return ref.read(walletRepositoryProvider).getWallet(supervisorId);
});

/// Provider for advance payment logs (all or per supervisor)
final advanceLogsProvider = FutureProvider.autoDispose.family<List<AdvancePaymentModel>, String?>((ref, supervisorId) async {
  return ref.read(walletRepositoryProvider).getAdvanceLogs(supervisorId: supervisorId);
});

class WalletRepository {
  final SupabaseClient _client;
  WalletRepository(this._client);

  Future<List<SupervisorWalletModel>> getAllWallets() async {
    final data = await _client
        .from('supervisor_wallet')
        .select('*, supervisors(name, supervisor_code)')
        .order('updated_at', ascending: false);
    return (data as List)
        .map((e) => SupervisorWalletModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SupervisorWalletModel?> getWallet(String supervisorId) async {
    final data = await _client
        .from('supervisor_wallet')
        .select('*, supervisors(name, supervisor_code)')
        .eq('supervisor_id', supervisorId)
        .maybeSingle();
    if (data == null) return null;
    return SupervisorWalletModel.fromJson(data);
  }

  Future<void> giveAdvance({
    required String supervisorId,
    required double amount,
    required String note,
    required String createdBy,
  }) async {
    await _client.rpc('give_supervisor_advance', params: {
      'p_supervisor_id': supervisorId,
      'p_amount': amount,
      'p_note': note,
      'p_created_by': createdBy,
    });
  }

  /// Edits the amount of a supervisor's MOST RECENT advance only — the
  /// server-side function re-verifies this is actually the latest advance
  /// and re-checks admin role itself, so this isn't just a client-side
  /// convention. The wallet's balance/total_advanced are adjusted by the
  /// difference automatically as part of the same RPC call.
  Future<void> editLatestAdvance({
    required String advanceId,
    required double newAmount,
  }) async {
    await _client.rpc('edit_latest_supervisor_advance', params: {
      'p_advance_id': advanceId,
      'p_new_amount': newAmount,
    });
  }

  Future<List<AdvancePaymentModel>> getAdvanceLogs({String? supervisorId}) async {
    var q = _client
        .from('supervisor_advances')
        .select('*, supervisors(name, supervisor_code), profiles(full_name)');
    if (supervisorId != null) q = q.eq('supervisor_id', supervisorId);
    final data = await q.order('created_at', ascending: false);
    return (data as List)
        .map((e) => AdvancePaymentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get combined wallet ledger for a supervisor:
  /// advances (credit) + approved expenses (debit) ordered by date
  Future<List<Map<String, dynamic>>> getWalletLedger(String supervisorId) async {
    final advances = await getAdvanceLogs(supervisorId: supervisorId);
    final expenses = await _client
        .from('expenses')
        .select('id, expense_name, amount, status, created_at, expense_date')
        .eq('supervisor_id', supervisorId)
        .inFilter('status', ['approved', 'rejected', 'pending'])
        .order('created_at', ascending: false);

    final List<Map<String, dynamic>> ledger = [];

    for (final a in advances) {
      ledger.add({
        'type': 'advance',
        'id': a.id,
        'date': a.createdAt,
        'amount': a.amount,
        'note': a.note ?? 'Advance Payment',
        'status': 'credited',
        'createdBy': a.createdByName,
      });
    }

    for (final e in (expenses as List)) {
      ledger.add({
        'type': 'expense',
        'id': e['id'],
        'date': DateTime.parse(e['created_at'] as String),
        'amount': e['amount'],
        'note': e['expense_name'],
        'status': e['status'],
        'createdBy': null,
      });
    }

    ledger.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
    return ledger;
  }
}
