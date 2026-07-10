import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../expenses/expenses_list_screen.dart' show ExpenseMonthDrilldownScreen;

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;

final supervisorsProvider = StateNotifierProvider.autoDispose<
    SupervisorsNotifier, AsyncValue<List<SupervisorModel>>>((ref) {
  return SupervisorsNotifier(
      ref.watch(supervisorRepositoryProvider), ref.watch(supabaseProvider));
});

class SupervisorsNotifier
    extends StateNotifier<AsyncValue<List<SupervisorModel>>> {
  final SupervisorRepository _repo;
  final dynamic _client;
  RealtimeChannel? _realtimeSub;

  SupervisorsNotifier(this._repo, this._client) : super(const AsyncLoading()) {
    load();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _realtimeSub = _client
        .channel('supervisors_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'supervisors',
          callback: (_) => load(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    // Guard against a channel that never finished subscribing / was already
    // torn down — passing null into removeChannel() throws.
    final sub = _realtimeSub;
    if (sub != null) {
      _client.removeChannel(sub);
    }
    super.dispose();
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

// \u{2500}\u{2500}\u{2500} Supervisor Payroll providers \u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}

final _supervisorPayrollProvider = FutureProvider.autoDispose
    .family<List<SupervisorPayrollModel>, String>((ref, supervisorId) {
  return ref
      .read(supervisorPayrollRepositoryProvider)
      .getForSupervisor(supervisorId);
});

// \u{2500}\u{2500}\u{2500} List Screen \u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}

class SupervisorsListScreen extends ConsumerStatefulWidget {
  const SupervisorsListScreen({super.key});

  @override
  ConsumerState<SupervisorsListScreen> createState() =>
      _SupervisorsListScreenState();
}

class _SupervisorsListScreenState
    extends ConsumerState<SupervisorsListScreen> {
  final _searchController = TextEditingController();
  bool? _activeFilter; // null=all, true=active, false=inactive

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
          PopupMenuButton<bool?>(
            icon: Icon(
              Icons.filter_list_rounded,
              color: _activeFilter != null ? AppColors.primary500 : null,
            ),
            tooltip: 'Filter by status',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              setState(() => _activeFilter = value);
              ref.read(supervisorsProvider.notifier).load(isActive: value);
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem<bool?>(value: null, checked: _activeFilter == null, child: const Text('All')),
              CheckedPopupMenuItem<bool?>(value: true, checked: _activeFilter == true, child: const Text('Active')),
              CheckedPopupMenuItem<bool?>(value: false, checked: _activeFilter == false, child: const Text('Inactive')),
            ],
          ),
          TextButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Supervisor'),
            onPressed: () async {
              await context.push('/supervisors/new');
              ref.read(supervisorsProvider.notifier).refresh();
            },
          ),
          const SizedBox(width: 4),
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
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
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
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _SupervisorCard(
                          supervisor: list[i],
                          onTap: () async {
                            await context
                                .push('/supervisors/${list[i].id}');
                            ref
                                .read(supervisorsProvider.notifier)
                                .refresh();
                          },
                        ),
                      ),
                    ),
            ),
          ),
        ],
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
            w.GenderAvatar(
              radius: 24,
              photoUrl: supervisor.profilePhotoUrl,
              gender: supervisor.gender,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supervisor.name,
                      style: theme.textTheme.titleMedium),
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

// \u{2500}\u{2500}\u{2500} Form Screen \u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}

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
  final _upiController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _salaryController = TextEditingController(text: '0');
  bool _isActive = true;
  bool _isLoading = false;
  bool _showBankDetails = false;
  String _gender = 'male';
  File? _photoFile;
  String? _existingPhotoUrl;
  List<String> _selectedLocationIds = [];
  List<LocationModel> _availableLocations = [];

  bool get isEditing => widget.supervisorId != null;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    if (isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSupervisor());
    }
  }

  Future<void> _loadLocations() async {
    try {
      final data = await ref
          .read(supabaseProvider)
          .from('locations')
          .select()
          .eq('is_active', true)
          .order('name');
      if (mounted) {
        setState(() {
          _availableLocations = (data as List)
              .map((d) => LocationModel.fromJson(d as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {}
    if (isEditing) {
      try {
        final ids = await ref
            .read(supervisorRepositoryProvider)
            .getAssignedLocationIds(widget.supervisorId!);
        if (mounted) setState(() => _selectedLocationIds = ids);
      } catch (_) {}
    }
  }

  Future<void> _loadSupervisor() async {
    final sup = await ref
        .read(supervisorRepositoryProvider)
        .getById(widget.supervisorId!);
    if (sup == null || !mounted) return;
    _nameController.text = sup.name;
    _usernameController.text = sup.email.replaceAll('@ems.com', '');
    _mobileController.text = sup.mobile ?? '';
    _upiController.text = sup.upiId ?? '';
    _bankAccountController.text = sup.bankAccountNumber ?? '';
    _bankIfscController.text = sup.bankIfsc ?? '';
    _bankNameController.text = sup.bankName ?? '';
    _salaryController.text = sup.monthlySalary.toStringAsFixed(0);
    _isActive = sup.isActive;
    _gender = sup.gender ?? 'male';
    _existingPhotoUrl = sup.profilePhotoUrl;
    _showBankDetails =
        sup.hasUpi || (sup.bankAccountNumber?.isNotEmpty ?? false);
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _mobileController.dispose();
    _upiController.dispose();
    _bankAccountController.dispose();
    _bankIfscController.dispose();
    _bankNameController.dispose();
    _salaryController.dispose();
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

      final mobile = _mobileController.text.trim();
      if (!isEditing && mobile.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mobile number is required for creating a supervisor'),
          backgroundColor: AppColors.error500,
        ));
        return;
      }

      // Username is now the mobile number: mobile@ems.com
      // For editing, the email/login is already set and cannot be changed.
      final email = isEditing
          ? null
          : '$mobile@ems.com';

      final selectedLocationNames = _availableLocations
          .where((l) => _selectedLocationIds.contains(l.id))
          .map((l) => l.name)
          .join(', ');

      final data = {
        'name': _nameController.text.trim(),
        if (!isEditing) 'email': email,
        'mobile': mobile.isEmpty ? null : mobile,
        'assigned_area':
            selectedLocationNames.isEmpty ? null : selectedLocationNames,
        'is_active': _isActive,
        'upi_id': _upiController.text.trim().isEmpty
            ? null
            : _upiController.text.trim(),
        'bank_account_number': _bankAccountController.text.trim().isEmpty
            ? null
            : _bankAccountController.text.trim(),
        'bank_ifsc': _bankIfscController.text.trim().isEmpty
            ? null
            : _bankIfscController.text.trim().toUpperCase(),
        'bank_name': _bankNameController.text.trim().isEmpty
            ? null
            : _bankNameController.text.trim(),
        'monthly_salary':
            double.tryParse(_salaryController.text) ?? 0,
        'gender': _gender,
      };

      SupervisorModel supervisor;
      if (isEditing) {
        supervisor = await repo.update(widget.supervisorId!, data);
      } else {
        supervisor = await repo.create(data, 'Abcd@123');
      }

      // Item 3: sync the many-to-many assignment. Empty selection is
      // valid and means "unrestricted" (can submit for any location).
      await repo.setAssignedLocations(supervisor.id, _selectedLocationIds);

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
                : 'Supervisor created. Login: $mobile / Abcd@123'),
            backgroundColor: AppColors.success500,
          ),
        );
        ref.invalidate(supervisorsProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(ErrorUtils.friendly(e)),
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
                      _photoFile != null
                          ? CircleAvatar(
                              radius: 48,
                              backgroundImage: FileImage(_photoFile!),
                            )
                          : w.GenderAvatar(
                              radius: 48,
                              photoUrl: _existingPhotoUrl,
                              gender: _gender,
                            ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary500,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2),
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
                validator: (v) =>
                    ValidationUtils.validateRequired(v, 'Name'),
              ),
              const SizedBox(height: 16),
              // Gender selector
              Row(children: [
                const Icon(Icons.wc_rounded, color: AppColors.secondary400, size: 20),
                const SizedBox(width: 12),
                const Text('Gender', style: TextStyle(fontSize: 13, color: AppColors.secondary600)),
                const SizedBox(width: 20),
                ...['male', 'female', 'other'].map((g) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(g[0].toUpperCase() + g.substring(1)),
                    selected: _gender == g,
                    onSelected: (_) => setState(() => _gender = g),
                    selectedColor: AppColors.primary100,
                    labelStyle: TextStyle(
                      color: _gender == g ? AppColors.primary700 : AppColors.secondary600,
                      fontWeight: _gender == g ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                )),
              ]),
              const SizedBox(height: 16),
              // is now built automatically from the mobile number:
              // mobile@ems.com. Mobile is mandatory for supervisors.
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                readOnly: isEditing,
                decoration: InputDecoration(
                    labelText: 'Mobile Number *',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    helperText: isEditing
                        ? 'Mobile / login cannot be changed'
                        : 'This becomes the supervisor\'s login'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Mobile number is required';
                  if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) return 'Enter a valid 10-digit mobile number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Assigned Location(s) \u{2014} optional',
                  prefixIcon: Icon(Icons.map_outlined),
                  helperText:
                      'Leave empty to allow attendance submission for ANY location',
                  helperMaxLines: 2,
                ),
                child: _availableLocations.isEmpty
                    ? const Text('No locations added yet',
                        style: TextStyle(color: Colors.grey))
                    : Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _availableLocations.map((loc) {
                          final selected =
                              _selectedLocationIds.contains(loc.id);
                          return FilterChip(
                            label: Text(
                              loc.name,
                              style: TextStyle(
                                color: selected ? Colors.white : AppColors.secondary800,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            selected: selected,
                            showCheckmark: false,
                            backgroundColor: AppColors.secondary100,
                            selectedColor: AppColors.primary500,
                            side: BorderSide(
                              color: selected ? AppColors.primary500 : AppColors.secondary300,
                            ),
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedLocationIds.add(loc.id);
                                } else {
                                  _selectedLocationIds.remove(loc.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _salaryController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Monthly Salary (\u{20B9})',
                  prefixIcon:
                      Icon(Icons.account_balance_wallet_outlined),
                  helperText:
                      'Fixed monthly salary for this supervisor',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (double.tryParse(v) == null)
                    return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => setState(
                      () => _showBankDetails = !_showBankDetails),
                  child: Row(
                    children: [
                      Text(
                        'Payment Details',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: AppColors.primary500),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _showBankDetails
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
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
                  'UPI ID required to pay salary/expenses via UPI',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.secondary400),
                ),
              ),
              if (_showBankDetails) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _upiController,
                  decoration: const InputDecoration(
                    labelText: 'UPI ID',
                    hintText: 'name@bankupi',
                    prefixIcon: Icon(
                        Icons.account_balance_wallet_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!v.contains('@'))
                      return 'Enter a valid UPI ID (e.g. name@bank)';
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
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.accent600),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active Status'),
                subtitle: Text(_isActive
                    ? 'Supervisor is active'
                    : 'Supervisor is inactive'),
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
                            strokeWidth: 2,
                            color: Colors.white))
                    : Text(isEditing
                        ? 'Update Supervisor'
                        : 'Add Supervisor'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// \u{2500}\u{2500}\u{2500} Detail Screen \u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}

class SupervisorDetailScreen extends ConsumerWidget {
  final String id;
  const SupervisorDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentEnabled = ref.watch(paymentModuleEnabledProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Details'),
        actions: [
          IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await context.push('/supervisors/$id/edit');
              }),
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
                      w.GenderAvatar(
                        radius: 52,
                        photoUrl: sup.profilePhotoUrl,
                        gender: sup.gender,
                      ),
                      const SizedBox(height: 12),
                      Text(sup.name,
                          style:
                              Theme.of(context).textTheme.headlineMedium),
                      Text(sup.supervisorCode,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: AppColors.accent600)),
                      const SizedBox(height: 8),
                      w.StatusBadge(
                          status:
                              sup.isActive ? 'active' : 'inactive'),
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
                _InfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Monthly Salary',
                    value: CurrencyUtils.format(sup.monthlySalary)),
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
                  label: const Text('Expense Log'),
                  onPressed: () => _showExpenseLog(context, ref, sup),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('Salary History'),
                  onPressed: () => _showSalaryHistory(
                      context, ref, sup, paymentEnabled),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                  label: const Text('Advance Wallet'),
                  onPressed: () => context.push(
                    '/supervisors/${sup.id}/wallet',
                    extra: sup.name,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showExpenseLog(
      BuildContext context, WidgetRef ref, SupervisorModel sup) async {
    final expenses = await ref
        .read(expenseRepositoryProvider)
        .getAll(supervisorId: sup.id);
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

  void _showSalaryHistory(BuildContext context, WidgetRef ref,
      SupervisorModel sup, bool paymentEnabled) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupervisorSalaryScreen(
          supervisor: sup,
          paymentEnabled: paymentEnabled,
        ),
      ),
    );
  }

  void _showAssignedEmployees(
      BuildContext context, WidgetRef ref, SupervisorModel sup) async {
    final employees = await ref
        .read(supervisorRepositoryProvider)
        .getAssignedEmployees(sup.id);
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
                            leading: w.GenderAvatar(
                              radius: 18,
                              photoUrl: e.employeePhotoUrl,
                              gender: e.gender,
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

// \u{2500}\u{2500}\u{2500} Supervisor Salary Screen (admin view) \u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}

class SupervisorSalaryScreen extends ConsumerStatefulWidget {
  final SupervisorModel supervisor;
  final bool paymentEnabled;
  const SupervisorSalaryScreen(
      {super.key, required this.supervisor, required this.paymentEnabled});

  @override
  ConsumerState<SupervisorSalaryScreen> createState() =>
      _SupervisorSalaryScreenState();
}

class _SupervisorSalaryScreenState
    extends ConsumerState<SupervisorSalaryScreen> {
  bool _isProcessing = false;

  Future<void> _processMonth() async {
    final bonusCtrl = TextEditingController();
    final deductionCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            'Process Salary \u{2014} ${DateFormat('MMMM yyyy').format(DateTime.now())}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Base Salary: ${CurrencyUtils.format(widget.supervisor.monthlySalary)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bonusCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Bonus (\u{20B9})'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: deductionCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Deduction (\u{20B9})'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: remarksCtrl,
                decoration: const InputDecoration(labelText: 'Remarks'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Process')),
        ],
      ),
    );

    if (result != true || !mounted) return;

    setState(() => _isProcessing = true);
    try {
      final now = DateTime.now();
      await ref.read(supervisorPayrollRepositoryProvider).processMonth(
            widget.supervisor.id,
            now.month,
            now.year,
            widget.supervisor.monthlySalary,
            bonus: double.tryParse(bonusCtrl.text) ?? 0,
            deduction: double.tryParse(deductionCtrl.text) ?? 0,
            remarks: remarksCtrl.text.trim().isEmpty
                ? null
                : remarksCtrl.text.trim(),
          );
      ref.invalidate(_supervisorPayrollProvider(widget.supervisor.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Salary processed'),
            backgroundColor: AppColors.success500));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error500));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payrollAsync =
        ref.watch(_supervisorPayrollProvider(widget.supervisor.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.supervisor.name} \u{2014} Salary'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: const Text('Process'),
            onPressed: _isProcessing ? null : _processMonth,
          ),
        ],
      ),
      body: payrollAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const w.EmptyState(
              title: 'No salary records',
              subtitle: 'Process this month\'s salary to get started',
              icon: Icons.payments_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _SalaryCard(
              record: list[i],
              supervisor: widget.supervisor,
              paymentEnabled: widget.paymentEnabled,
              onRefresh: () => ref.invalidate(
                  _supervisorPayrollProvider(widget.supervisor.id)),
            ),
          );
        },
      ),
    );
  }
}

class _SalaryCard extends ConsumerWidget {
  final SupervisorPayrollModel record;
  final SupervisorModel supervisor;
  final bool paymentEnabled;
  final VoidCallback onRefresh;

  const _SalaryCard({
    required this.record,
    required this.supervisor,
    required this.paymentEnabled,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final monthName = DateFormat('MMMM yyyy')
        .format(DateTime(record.payrollYear, record.payrollMonth));

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(monthName,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                          'Base: ${CurrencyUtils.format(record.monthlySalary)}  '
                          'Bonus: ${CurrencyUtils.format(record.bonus)}  '
                          'Ded: ${CurrencyUtils.format(record.deduction)}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(CurrencyUtils.format(record.netAmount),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: AppColors.primary600)),
                    const SizedBox(height: 4),
                    w.StatusBadge(
                        status: record.isPaid ? 'paid' : record.status),
                  ],
                ),
              ],
            ),
          ),
          if (!record.isPaid)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                'Payment pending — process via Payroll screen',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.secondary400),
              ),
            ),
        ],
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
              Text(value,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }
}
