import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../expenses/expenses_list_screen.dart' show ExpenseMonthDrilldownScreen;

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;

final supervisorsProvider = StateNotifierProvider.autoDispose<
    SupervisorsNotifier, AsyncValue<List<SupervisorModel>>>((ref) {
  return SupervisorsNotifier(ref.watch(supervisorRepositoryProvider));
});

class SupervisorsNotifier
    extends StateNotifier<AsyncValue<List<SupervisorModel>>> {
  final SupervisorRepository _repo;

  SupervisorsNotifier(this._repo) : super(const AsyncLoading()) {
    load();
  }

  Future<void> load({bool? isActive, String? search}) async {
    try {
      final data = await _repo.getAll(search: search, isActive: isActive);
      state = AsyncData(data);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void refresh() => load();
}

class SupervisorsListScreen extends ConsumerStatefulWidget {
  const SupervisorsListScreen({super.key});

  @override
  ConsumerState<SupervisorsListScreen> createState() =>
      _SupervisorsListScreenState();
}

class _SupervisorsListScreenState
    extends ConsumerState<SupervisorsListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final supervisors = ref.watch(supervisorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisors'),
        actions: [
          IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: () => context.push('/supervisors/new')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: w.SearchBar(
              controller: _searchController,
              hint: 'Search supervisors...',
              onChanged: (v) =>
                  ref.read(supervisorsProvider.notifier).load(search: v),
              onClear: () {
                _searchController.clear();
                ref.read(supervisorsProvider.notifier).load();
              },
            ),
          ),
          Expanded(
            child: supervisors.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => list.isEmpty
                  ? w.EmptyState(
                      title: 'No supervisors found',
                      icon: Icons.supervisor_account_outlined,
                      actionLabel: 'Add Supervisor',
                      onAction: () => context.push('/supervisors/new'),
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.read(supervisorsProvider.notifier).refresh(),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _SupervisorCard(
                          supervisor: list[i],
                          onTap: () =>
                              context.push('/supervisors/${list[i].id}'),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/supervisors/new'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Supervisor'),
      ),
    );
  }
}

class _SupervisorCard extends StatelessWidget {
  final SupervisorModel supervisor;
  final VoidCallback onTap;

  const _SupervisorCard({required this.supervisor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondary200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.accent100,
              backgroundImage: supervisor.profilePhotoUrl != null
                  ? NetworkImage(supervisor.profilePhotoUrl!)
                  : null,
              child: supervisor.profilePhotoUrl == null
                  ? Text(
                      supervisor.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: AppColors.accent600,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Inter'),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supervisor.name, style: theme.textTheme.titleMedium),
                  Text(supervisor.supervisorCode,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.accent600)),
                  if (supervisor.assignedArea != null)
                    Text(supervisor.assignedArea!,
                        style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            w.StatusBadge(
                status: supervisor.isActive ? 'active' : 'inactive'),
          ],
        ),
      ),
    );
  }
}

class SupervisorFormScreen extends ConsumerStatefulWidget {
  final String? supervisorId;
  const SupervisorFormScreen({super.key, this.supervisorId});

  @override
  ConsumerState<SupervisorFormScreen> createState() =>
      _SupervisorFormScreenState();
}

class _SupervisorFormScreenState
    extends ConsumerState<SupervisorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _areaController = TextEditingController();
  final _upiController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _bankNameController = TextEditingController();
  bool _isActive = true;
  bool _isLoading = false;
  bool _showBankDetails = false;
  File? _photoFile;
  String? _existingPhotoUrl;
  String? _existingSupervisorId;

  bool get isEditing => widget.supervisorId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _loadSupervisor());
    }
  }

  Future<void> _loadSupervisor() async {
    final sup =
        await ref.read(supervisorRepositoryProvider).getById(widget.supervisorId!);
    if (sup == null || !mounted) return;
    _nameController.text = sup.name;
    // Extract username from email (remove @ems.com)
    _usernameController.text = sup.email.replaceAll('@ems.com', '');
    _mobileController.text = sup.mobile ?? '';
    _areaController.text = sup.assignedArea ?? '';
    _upiController.text = sup.upiId ?? '';
    _bankAccountController.text = sup.bankAccountNumber ?? '';
    _bankIfscController.text = sup.bankIfsc ?? '';
    _bankNameController.text = sup.bankName ?? '';
    _isActive = sup.isActive;
    _existingPhotoUrl = sup.profilePhotoUrl;
    _existingSupervisorId = sup.id;
    _showBankDetails = sup.hasUpi || (sup.bankAccountNumber?.isNotEmpty ?? false);
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _mobileController.dispose();
    _areaController.dispose();
    _upiController.dispose();
    _bankAccountController.dispose();
    _bankIfscController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
    if (file != null) setState(() => _photoFile = File(file.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final repo = ref.read(supervisorRepositoryProvider);
      final username = _usernameController.text.trim().toUpperCase();
      final email = '$username@ems.com';

      final data = {
        'name': _nameController.text.trim(),
        'email': email,
        'mobile': _mobileController.text.trim().isEmpty
            ? null
            : _mobileController.text.trim(),
        'assigned_area': _areaController.text.trim().isEmpty
            ? null
            : _areaController.text.trim(),
        'is_active': _isActive,
        'upi_id': _upiController.text.trim().isEmpty ? null : _upiController.text.trim(),
        'bank_account_number': _bankAccountController.text.trim().isEmpty ? null : _bankAccountController.text.trim(),
        'bank_ifsc': _bankIfscController.text.trim().isEmpty ? null : _bankIfscController.text.trim().toUpperCase(),
        'bank_name': _bankNameController.text.trim().isEmpty ? null : _bankNameController.text.trim(),
      };

      SupervisorModel supervisor;
      if (isEditing) {
        supervisor = await repo.update(widget.supervisorId!, data);
      } else {
        // Default password Abcd@123, must_change_password = true
        supervisor = await repo.create(data, 'Abcd@123');
      }

      // Upload photo if selected
      if (_photoFile != null) {
        final bytes = await _photoFile!.readAsBytes();
        await repo.uploadPhoto(
          supervisor.id,
          bytes,
          'photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditing
                ? 'Supervisor updated'
                : 'Supervisor created. Default password: Abcd@123'),
            backgroundColor: AppColors.success500,
          ),
        );
        context.pop();
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
          title:
              Text(isEditing ? 'Edit Supervisor' : 'Add Supervisor')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.accent100,
                        backgroundImage: _photoFile != null
                            ? FileImage(_photoFile!) as ImageProvider
                            : _existingPhotoUrl != null
                                ? NetworkImage(_existingPhotoUrl!)
                                : null,
                        child: _photoFile == null && _existingPhotoUrl == null
                            ? const Icon(Icons.person_rounded,
                                color: AppColors.accent400, size: 48)
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
                          child: const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => ValidationUtils.validateRequired(v, 'Name'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                textCapitalization: TextCapitalization.characters,
                readOnly: isEditing,
                decoration: InputDecoration(
                  labelText: 'Username *',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  helperText: isEditing ? 'Username cannot be changed' : null,
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Username is required';
                  }
                  if (v.contains('@') || v.contains(' ')) {
                    return 'Username cannot contain @ or spaces';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    prefixIcon: Icon(Icons.phone_outlined)),
                validator: ValidationUtils.validateMobile,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _areaController,
                decoration: const InputDecoration(
                    labelText: 'Assigned Area',
                    prefixIcon: Icon(Icons.map_outlined)),
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => setState(() => _showBankDetails = !_showBankDetails),
                  child: Row(
                    children: [
                      Text(
                        'Payment Details',
                        style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primary500),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _showBankDetails ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        color: AppColors.primary500,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Required for paying expense reimbursements via UPI',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondary400),
                ),
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
              const SizedBox(height: 16),
              if (!isEditing)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.accent200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.accent600, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Default password: Abcd@123\nSupervisor will be prompted to change on first login.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.accent600),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active Status'),
                subtitle: Text(
                    _isActive ? 'Supervisor is active' : 'Supervisor is inactive'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                activeColor: AppColors.success500,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(isEditing ? 'Update Supervisor' : 'Add Supervisor'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupervisorDetailScreen extends ConsumerWidget {
  final String id;
  const SupervisorDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Details'),
        actions: [
          IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/supervisors/$id/edit')),
        ],
      ),
      body: FutureBuilder(
        future: ref.read(supervisorRepositoryProvider).getById(id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sup = snapshot.data;
          if (sup == null) return const Center(child: Text('Not found'));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: AppColors.accent100,
                        backgroundImage: sup.profilePhotoUrl != null
                            ? NetworkImage(sup.profilePhotoUrl!)
                            : null,
                        child: sup.profilePhotoUrl == null
                            ? Text(
                                sup.name[0].toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.accent600,
                                    fontFamily: 'Inter'),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(sup.name,
                          style: Theme.of(context).textTheme.headlineMedium),
                      Text(sup.supervisorCode,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.accent600)),
                      const SizedBox(height: 8),
                      w.StatusBadge(
                          status: sup.isActive ? 'active' : 'inactive'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _InfoRow(
                    icon: Icons.alternate_email_rounded,
                    label: 'Username',
                    value: sup.email.replaceAll('@ems.com', '')),
                if (sup.mobile != null)
                  _InfoRow(
                      icon: Icons.phone_outlined,
                      label: 'Mobile',
                      value: sup.mobile!),
                if (sup.assignedArea != null)
                  _InfoRow(
                      icon: Icons.map_outlined,
                      label: 'Area',
                      value: sup.assignedArea!),
                if (sup.hasUpi)
                  _InfoRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'UPI ID',
                      value: sup.upiId!),
                if (sup.bankAccountNumber != null)
                  _InfoRow(
                      icon: Icons.account_balance_outlined,
                      label: 'Account No.',
                      value: sup.bankAccountNumber!),
                if (sup.bankIfsc != null)
                  _InfoRow(
                      icon: Icons.pin_outlined,
                      label: 'IFSC',
                      value: sup.bankIfsc!),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: const Icon(Icons.people_rounded, size: 18),
                  label: const Text('Assigned Employees'),
                  onPressed: () =>
                      _showAssignedEmployees(context, ref, sup),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long_rounded, size: 18),
                  label: const Text('Expense Log & Summary'),
                  onPressed: () => _showExpenseLog(context, ref, sup),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showExpenseLog(BuildContext context, WidgetRef ref, SupervisorModel sup) async {
    final expenses = await ref.read(expenseRepositoryProvider).getAll(supervisorId: sup.id);
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseMonthDrilldownScreen(
          supervisorId: sup.id,
          supervisorName: sup.name,
          allExpenses: expenses,
        ),
      ),
    );
  }

  void _showAssignedEmployees(
      BuildContext context, WidgetRef ref, SupervisorModel sup) async {
    final employees =
        await ref.read(supervisorRepositoryProvider).getAssignedEmployees(sup.id);
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (_, ctrl) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assigned Employees (${employees.length})',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Expanded(
                child: employees.isEmpty
                    ? const Center(child: Text('No employees assigned'))
                    : ListView.builder(
                        controller: ctrl,
                        itemCount: employees.length,
                        itemBuilder: (_, i) {
                          final e = employees[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary100,
                              backgroundImage: e.employeePhotoUrl != null
                                  ? NetworkImage(e.employeePhotoUrl!)
                                  : null,
                              child: e.employeePhotoUrl == null
                                  ? Text(e.name[0].toUpperCase(),
                                      style: const TextStyle(
                                          color: AppColors.primary600,
                                          fontFamily: 'Inter'))
                                  : null,
                            ),
                            title: Text(e.name),
                            subtitle: Text(e.employeeCode),
                            trailing: w.StatusBadge(status: e.status),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.secondary400),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelSmall),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}