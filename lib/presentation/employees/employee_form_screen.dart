import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../shared/widgets.dart' as w;

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import 'employees_list_screen.dart' show employeesProvider;

final _employeeDetailProvider = FutureProvider.autoDispose.family<EmployeeModel?, String>((ref, id) {
  return ref.watch(employeeRepositoryProvider).getById(id);
});

final _supervisorsProvider =
    FutureProvider.autoDispose<List<SupervisorModel>>((ref) async {
  return ref
      .read(supervisorRepositoryProvider)
      .getAll(isActive: true);
});

final _departmentsProvider = FutureProvider.autoDispose<List<DepartmentModel>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final data = await client.from('departments').select().eq('is_active', true).order('name');
  return (data as List).map((d) => DepartmentModel.fromJson(d as Map<String, dynamic>)).toList();
});

final _employeeLocationsProvider = FutureProvider.autoDispose<List<LocationModel>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final data = await client.from('locations').select().eq('is_active', true).order('name');
  return (data as List).map((d) => LocationModel.fromJson(d as Map<String, dynamic>)).toList();
});

class EmployeeFormScreen extends ConsumerStatefulWidget {
  final String? employeeId;
  const EmployeeFormScreen({super.key, this.employeeId});

  @override
  ConsumerState<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _addressController = TextEditingController();
  final _aadhaarController = TextEditingController();
  final _designationController = TextEditingController();
  final _wageController = TextEditingController();
  final _upiController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _bankNameController = TextEditingController();

  DateTime _joiningDate = DateTime.now();
  String? _departmentId;
  String? _locationId;
  String? _supervisorId;
  String _status = 'active';
  File? _photoFile;
  String? _existingPhotoUrl;
  bool _isLoading = false;
  bool _showBankDetails = false;

  bool get isEditing => widget.employeeId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadEmployee());
    }
  }

  Future<void> _loadEmployee() async {
    final employee =
        await ref.read(employeeRepositoryProvider).getById(
              widget.employeeId!,
            );

    if (employee == null || !mounted) return;

    _nameController.text = employee.name;
    _mobileController.text = employee.mobile ?? '';
    _addressController.text = employee.address ?? '';
    _aadhaarController.text = employee.aadhaarNumber ?? '';
    _designationController.text = employee.designation ?? '';
    _wageController.text = employee.dailyWageRate.toString();
    _upiController.text = employee.upiId ?? '';
    _bankAccountController.text = employee.bankAccountNumber ?? '';
    _bankIfscController.text = employee.bankIfsc ?? '';
    _bankNameController.text = employee.bankName ?? '';

    _joiningDate = employee.joiningDate;
    _departmentId = employee.departmentId;
    _locationId = employee.locationId;
    _status = employee.status;
    _existingPhotoUrl = employee.employeePhotoUrl;
    _showBankDetails = (employee.upiId?.isNotEmpty ?? false) ||
        (employee.bankAccountNumber?.isNotEmpty ?? false);

    final client = ref.read(supabaseProvider);

    final assignment = await client
        .from('supervisor_employees')
        .select('supervisor_id')
        .eq('employee_id', employee.id)
        .maybeSingle();

    _supervisorId = assignment?['supervisor_id'] as String?;

    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _addressController.dispose();
    _aadhaarController.dispose();
    _designationController.dispose();
    _wageController.dispose();
    _upiController.dispose();
    _bankAccountController.dispose();
    _bankIfscController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
    if (file != null) setState(() => _photoFile = File(file.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(employeeRepositoryProvider);
      final data = {
        'name': _nameController.text.trim(),
        'mobile': _mobileController.text.trim().isEmpty ? null : _mobileController.text.trim(),
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'aadhaar_number': _aadhaarController.text.trim().isEmpty ? null : _aadhaarController.text.trim(),
        'designation': _designationController.text.trim().isEmpty ? null : _designationController.text.trim(),
        'daily_wage_rate': double.parse(_wageController.text),
        'joining_date': DateFormat('yyyy-MM-dd').format(_joiningDate),
        'department_id': _departmentId,
        'location_id': _locationId,
        'supervisor_id': _supervisorId,
        'status': _status,
        'upi_id': _upiController.text.trim().isEmpty ? null : _upiController.text.trim(),
        'bank_account_number': _bankAccountController.text.trim().isEmpty ? null : _bankAccountController.text.trim(),
        'bank_ifsc': _bankIfscController.text.trim().isEmpty ? null : _bankIfscController.text.trim().toUpperCase(),
        'bank_name': _bankNameController.text.trim().isEmpty ? null : _bankNameController.text.trim(),
      };

      EmployeeModel employee;
      if (isEditing) {
        employee = await repo.update(widget.employeeId!, data);
      } else {
        employee = await repo.create(data);
      }

      if (_photoFile != null) {
        final bytes = await _photoFile!.readAsBytes();
        await repo.uploadPhoto(employee.id, bytes, 'photo_${DateTime.now().millisecondsSinceEpoch}.jpg');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Employee updated' : 'Employee created'), backgroundColor: AppColors.success500),
        );
        ref.invalidate(employeesProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.friendly(e)), backgroundColor: AppColors.error500),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final departments = ref.watch(_departmentsProvider);
    final locations = ref.watch(_employeeLocationsProvider);
    final supervisors = ref.watch(_supervisorsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Employee' : 'Add Employee')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPhotoSection(),
              const SizedBox(height: 24),
              _buildSection(theme, 'Basic Information', [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Full Name *', prefixIcon: Icon(Icons.person_outline)),
                  validator: (v) => ValidationUtils.validateRequired(v, 'Name'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: ValidationUtils.validateMobile,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _aadhaarController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Aadhaar Number', prefixIcon: Icon(Icons.credit_card_outlined)),
                  validator: (v) {
                    if (v != null && v.isNotEmpty && !StringUtils.isValidAadhaar(v)) return 'Enter valid 12-digit Aadhaar';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.location_on_outlined)),
                ),
              ]),
              const SizedBox(height: 20),
              _buildSection(theme, 'Employment Details', [
                InkWell(
                  onTap: _pickJoiningDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Joining Date *', prefixIcon: Icon(Icons.calendar_today_outlined)),
                    child: Text(DateFormat('dd/MM/yyyy').format(_joiningDate)),
                  ),
                ),
                const SizedBox(height: 16),
                departments.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (depts) => DropdownButtonFormField<String>(
                    value: _departmentId,
                    decoration: const InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.business_outlined)),
                    items: depts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
                    onChanged: (v) => setState(() => _departmentId = v),
                  ),
                ),
                const SizedBox(height: 16),
                locations.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (locs) => DropdownButtonFormField<String>(
                    value: _locationId,
                    decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.location_on_outlined)),
                    items: locs.map((l) => DropdownMenuItem(value: l.id, child: Text(l.name))).toList(),
                    onChanged: (v) => setState(() => _locationId = v),
                  ),
                ),
                const SizedBox(height: 16),
                supervisors.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (list) => DropdownButtonFormField<String>(
                    value: _supervisorId,
                    decoration: const InputDecoration(
                      labelText: 'Supervisor',
                      prefixIcon: Icon(Icons.supervisor_account_outlined),
                    ),
                    items: list
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text('${s.name} (${s.supervisorCode})'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _supervisorId = value;
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _designationController,
                  decoration: const InputDecoration(labelText: 'Designation', prefixIcon: Icon(Icons.work_outline)),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _wageController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Daily Wage Rate (₹) *', prefixIcon: Icon(Icons.currency_rupee_rounded)),
                  validator: ValidationUtils.validateAmount,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Status', prefixIcon: Icon(Icons.toggle_on_outlined)),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? 'active'),
                ),
              ]),
              const SizedBox(height: 20),
              InkWell(
                onTap: () => setState(() => _showBankDetails = !_showBankDetails),
                child: Row(
                  children: [
                    Text(
                      'Payment Details',
                      style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primary500),
                    ),
                    const Spacer(),
                    Icon(
                      _showBankDetails ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      color: AppColors.primary500,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Required for paying salary via UPI',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary400),
              ),
              if (_showBankDetails) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _upiController,
                  decoration: const InputDecoration(
                    labelText: 'UPI ID',
                    hintText: 'name@bankupi',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!v.contains('@')) return 'Enter a valid UPI ID (e.g. name@bank)';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bankAccountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Bank Account Number',
                    prefixIcon: Icon(Icons.account_balance_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bankIfscController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'IFSC Code',
                    prefixIcon: Icon(Icons.pin_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bankNameController,
                  decoration: const InputDecoration(
                    labelText: 'Bank Name',
                    prefixIcon: Icon(Icons.business_outlined),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEditing ? 'Update Employee' : 'Add Employee'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primary500)),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildPhotoSection() {
    return Center(
      child: GestureDetector(
        onTap: _pickPhoto,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.primary100,
              backgroundImage: _photoFile != null
                  ? FileImage(_photoFile!) as ImageProvider
                  : _existingPhotoUrl != null
                      ? NetworkImage(_existingPhotoUrl!)
                      : null,
              child: _photoFile == null && _existingPhotoUrl == null
                  ? const Icon(Icons.person_rounded, color: AppColors.primary400, size: 48)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary500,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickJoiningDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _joiningDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _joiningDate = date);
  }
}

class EmployeeDetailScreen extends ConsumerWidget {
  final String id;
  const EmployeeDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employee = ref.watch(_employeeDetailProvider(id));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => context.push('/employees/$id/edit'),
          ),
        ],
      ),
      body: employee.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (emp) => emp == null
            ? const Center(child: Text('Employee not found'))
            : _EmployeeDetailBody(employee: emp),
      ),
    );
  }
}

class _EmployeeDetailBody extends ConsumerStatefulWidget {
  final EmployeeModel employee;
  const _EmployeeDetailBody({required this.employee});

  @override
  ConsumerState<_EmployeeDetailBody> createState() => _EmployeeDetailBodyState();
}

class _EmployeeDetailBodyState extends ConsumerState<_EmployeeDetailBody> {
  bool _isCreatingLogin = false;

  Future<void> _createLogin() async {
    final confirm = await w.ConfirmDialog.show(
      context,
      title: 'Create Employee Login?',
      message:
          'This will create login credentials for ${widget.employee.name}.\n\n'
          'Username: ${widget.employee.employeeCode}\n'
          'Password: Abcd@123 (must change on first login)',
      confirmLabel: 'Create Login',
      confirmColor: AppColors.primary500,
    );
    if (confirm != true || !mounted) return;

    setState(() => _isCreatingLogin = true);
    try {
      await ref
          .read(employeeRepositoryProvider)
          .createLogin(widget.employee.id, widget.employee.employeeCode);

      if (mounted) {
        // Refresh the detail provider so the button disappears
        ref.invalidate(_employeeDetailProvider(widget.employee.id));

        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Login Created Successfully'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Share these credentials with the employee:'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 16, color: AppColors.primary600),
                          const SizedBox(width: 8),
                          Text(
                            'Username: ${widget.employee.employeeCode}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                              color: AppColors.primary700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Row(
                        children: [
                          Icon(Icons.lock_outline,
                              size: 16, color: AppColors.primary600),
                          SizedBox(width: 8),
                          Text(
                            'Password: Abcd@123',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                              color: AppColors.primary700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '* Employee must change password on first login',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.secondary500,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error500),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingLogin = false);
    }
  }

  Future<void> _toggleStatus() async {
    final confirm = await w.ConfirmDialog.show(
      context,
      title: widget.employee.isActive
          ? 'Deactivate Employee?'
          : 'Activate Employee?',
      message:
          'Are you sure you want to ${widget.employee.isActive ? 'deactivate' : 'activate'} ${widget.employee.name}?',
      confirmLabel: widget.employee.isActive ? 'Deactivate' : 'Activate',
      confirmColor: widget.employee.isActive
          ? AppColors.error500
          : AppColors.success500,
    );
    if (confirm != true || !context.mounted) return;

    try {
      await ref.read(employeeRepositoryProvider).update(widget.employee.id, {
        'status': widget.employee.isActive ? 'inactive' : 'active',
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Status updated'),
              backgroundColor: AppColors.success500),
        );
        ref.invalidate(employeesProvider);
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error500),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final employee = widget.employee;
    final hasLogin = employee.profileId != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary100,
                  backgroundImage: employee.employeePhotoUrl != null
                      ? NetworkImage(employee.employeePhotoUrl!)
                      : null,
                  child: employee.employeePhotoUrl == null
                      ? Text(employee.name[0].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary500,
                              fontFamily: 'Inter'))
                      : null,
                ),
                const SizedBox(height: 12),
                Text(employee.name, style: theme.textTheme.headlineMedium),
                const SizedBox(height: 4),
                Text(employee.employeeCode,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.primary500)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    w.StatusBadge(status: employee.status),
                    if (employee.designation != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: AppColors.secondary100,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(employee.designation!,
                            style: theme.textTheme.labelSmall),
                      ),
                    ],
                    const SizedBox(width: 8),
                    // Login status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: hasLogin
                            ? AppColors.success50
                            : AppColors.accent50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasLogin
                                ? Icons.lock_open_rounded
                                : Icons.lock_outline_rounded,
                            size: 10,
                            color: hasLogin
                                ? AppColors.success700
                                : AppColors.accent600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasLogin ? 'LOGIN ACTIVE' : 'NO LOGIN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter',
                              color: hasLogin
                                  ? AppColors.success700
                                  : AppColors.accent600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Create Login banner — only shown when no login exists
          if (!hasLogin) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.accent50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accent200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: AppColors.accent600, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'No app login created yet',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Create a login so this employee can access the app to view their attendance and payslips.',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.accent600,
                        fontFamily: 'Inter'),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: _isCreatingLogin
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.person_add_rounded, size: 18),
                      label: Text(_isCreatingLogin
                          ? 'Creating...'
                          : 'Create Employee Login'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent600,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isCreatingLogin ? null : _createLogin,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          _DetailCard(
            title: 'Contact Information',
            rows: [
              if (employee.mobile != null)
                _DetailRow(
                    icon: Icons.phone_outlined,
                    label: 'Mobile',
                    value: employee.mobile!),
              if (employee.address != null)
                _DetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Address',
                    value: employee.address!),
            ],
          ),
          const SizedBox(height: 12),
          _DetailCard(
            title: 'Employment Information',
            rows: [
              _DetailRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Joining Date',
                  value: DateFormat('dd/MM/yyyy').format(employee.joiningDate)),
              if (employee.departmentName != null)
                _DetailRow(
                    icon: Icons.business_outlined,
                    label: 'Department',
                    value: employee.departmentName!),
              if (employee.locationName != null)
                _DetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: employee.locationName!),
              _DetailRow(
                  icon: Icons.currency_rupee_rounded,
                  label: 'Daily Wage',
                  value: '₹${employee.dailyWageRate.toStringAsFixed(2)}'),
            ],
          ),
          if (employee.hasUpi || employee.bankAccountNumber != null) ...[
            const SizedBox(height: 12),
            _DetailCard(
              title: 'Payment Details',
              rows: [
                if (employee.hasUpi)
                  _DetailRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'UPI ID',
                      value: employee.upiId!),
                if (employee.bankAccountNumber != null)
                  _DetailRow(
                      icon: Icons.account_balance_outlined,
                      label: 'Account No.',
                      value: employee.bankAccountNumber!),
                if (employee.bankIfsc != null)
                  _DetailRow(
                      icon: Icons.pin_outlined,
                      label: 'IFSC',
                      value: employee.bankIfsc!),
                if (employee.bankName != null)
                  _DetailRow(
                      icon: Icons.business_outlined,
                      label: 'Bank',
                      value: employee.bankName!),
              ],
            ),
          ],
          if (employee.aadhaarNumber != null) ...[
            const SizedBox(height: 12),
            _DetailCard(
              title: 'Documents',
              rows: [
                _DetailRow(
                    icon: Icons.credit_card_outlined,
                    label: 'Aadhaar',
                    value: StringUtils.maskAadhaar(employee.aadhaarNumber!)),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                  onPressed: () =>
                      context.push('/employees/${employee.id}/edit'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.toggle_on_outlined, size: 18),
                  label:
                      Text(employee.isActive ? 'Deactivate' : 'Activate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: employee.isActive
                        ? AppColors.error500
                        : AppColors.success500,
                  ),
                  onPressed: _toggleStatus,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
class _DetailCard extends StatelessWidget {
  final String title;
  final List<_DetailRow> rows;
  const _DetailCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          ...rows.map((r) => r.build(context)),
        ],
      ),
    );
  }
}

class _DetailRow {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.secondary400),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelSmall),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}
