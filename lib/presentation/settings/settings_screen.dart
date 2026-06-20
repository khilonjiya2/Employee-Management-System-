import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/repositories/auth_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  File? _newPhotoFile;
  bool _isUploadingPhoto = false;

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 800, imageQuality: 80);
    if (file == null) return;

    setState(() {
      _newPhotoFile = File(file.path);
      _isUploadingPhoto = true;
    });

    try {
      final client = ref.read(supabaseProvider);
      final user = client.auth.currentUser;
      if (user == null) return;

      final bytes = await _newPhotoFile!.readAsBytes();
      final path = 'profiles/${user.id}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await client.storage
          .from('employee_photos')
          .uploadBinary(path, bytes);

      final url = client.storage.from('employee_photos').getPublicUrl(path);

      await client.from('profiles').update({'profile_photo_url': url}).eq('id', user.id);

      ref.invalidate(currentProfileProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Photo updated'),
            backgroundColor: AppColors.success500));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error500));
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showEditName(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Name',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Full Name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isEmpty) return;
                final client = ref.read(supabaseProvider);
                final user = client.auth.currentUser;
                if (user == null) return;
                await client
                    .from('profiles')
                    .update({'full_name': name}).eq('id', user.id);
                ref.invalidate(currentProfileProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Profile section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary200),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadPhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.primary100,
                          backgroundImage: _newPhotoFile != null
                              ? FileImage(_newPhotoFile!) as ImageProvider
                              : profile?.profilePhotoUrl != null
                                  ? NetworkImage(profile!.profilePhotoUrl!)
                                  : null,
                          child: _newPhotoFile == null &&
                                  profile?.profilePhotoUrl == null
                              ? Text(
                                  (profile?.fullName ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: AppColors.primary600,
                                    fontFamily: 'Inter',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : null,
                        ),
                        if (_isUploadingPhoto)
                          const Positioned.fill(
                            child: CircleAvatar(
                              backgroundColor: Colors.black38,
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.primary500,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.camera_alt_rounded,
                                color: Colors.white, size: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile?.fullName ?? '',
                            style: theme.textTheme.titleMedium),
                        Text(
                          StringUtils.capitalize(profile?.role ?? ''),
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.primary600),
                        ),
                        if (profile?.mobile != null)
                          Text(profile!.mobile!,
                              style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  if (profile?.isAdmin == true)
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          color: AppColors.primary500),
                      onPressed: () => _showEditName(
                          context, ref, profile?.fullName ?? ''),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Security
          _SectionTitle(title: 'Security'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showChangePassword(context, ref),
          ),

          // Admin sections
          if (profile?.isAdmin == true) ...[
            _SectionTitle(title: 'Administration'),
            ListTile(
              leading: const Icon(Icons.business_outlined),
              title: const Text('Company Settings'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showCompanySettings(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.people_outline_rounded),
              title: const Text('Manage Employees'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/employees'),
            ),
            ListTile(
              leading: const Icon(Icons.supervisor_account_outlined),
              title: const Text('Manage Supervisors'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push('/supervisors'),
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Manage Locations'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showManageLocations(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.apartment_outlined),
              title: const Text('Manage Departments'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showManageDepartments(context, ref),
            ),
          ],
ListTile(
              leading: const Icon(Icons.payment_outlined),
              title: const Text('Payment Module'),
              subtitle: const Text('Enable/disable UPI payment feature'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showPaymentModuleSettings(context, ref),
            ),

          // About
          _SectionTitle(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('App Version'),
            trailing: Text('1.0.0',
                style: TextStyle(
                    color: AppColors.secondary500, fontFamily: 'Inter')),
          ),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded,
                  color: AppColors.error500, size: 18),
              label: const Text('Sign Out',
                  style: TextStyle(color: AppColors.error500)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error500)),
              onPressed: () async => _confirmSignOut(context, ref),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

void _showPaymentModuleSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PaymentModuleSheet(ref: ref),
    );
  }

  void _showChangePassword(BuildContext context, WidgetRef ref) {
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change Password',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: newController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'New Password'),
                validator: ValidationUtils.validatePassword,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm Password'),
                validator: (v) =>
                    v != newController.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  try {
                    await ref
                        .read(authRepositoryProvider)
                        .updatePassword(newController.text);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Password updated'),
                            backgroundColor: AppColors.success500),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: AppColors.error500));
                    }
                  }
                },
                child: const Text('Update Password'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompanySettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Company Settings',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FutureBuilder(
              future: ref
                  .read(supabaseProvider)
                  .from('company_settings')
                  .select()
                  .maybeSingle(),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final settings = snapshot.data as Map<String, dynamic>?;
                final nameController = TextEditingController(
                    text: settings?['company_name'] as String? ?? '');
                return Column(
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration:
                          const InputDecoration(labelText: 'Company Name'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await ref
                            .read(supabaseProvider)
                            .from('company_settings')
                            .update({'company_name': nameController.text}).eq(
                                'id', settings?['id'] as String);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showManageLocations(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        expand: false,
        builder: (ctx, controller) => _LocationsManager(
            scrollController: controller, ref: ref),
      ),
    );
  }

  void _showManageDepartments(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        expand: false,
        builder: (ctx, controller) => _DepartmentsManager(
            scrollController: controller, ref: ref),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authRepositoryProvider).signOut();
    ref.invalidate(currentProfileProvider);
    ref.invalidate(dashboardStatsProvider);
    if (!context.mounted) return;
    context.go('/login');
  }
}

class _LocationsManager extends StatefulWidget {
  final ScrollController scrollController;
  final WidgetRef ref;
  const _LocationsManager(
      {required this.scrollController, required this.ref});

  @override
  State<_LocationsManager> createState() => _LocationsManagerState();
}

class _LocationsManagerState extends State<_LocationsManager> {
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = true;
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final data = await widget.ref
          .read(supabaseProvider)
          .from('locations')
          .select()
          .order('name');
      setState(() {
        _locations = (data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleLocation(String id, bool currentActive) async {
    await widget.ref
        .read(supabaseProvider)
        .from('locations')
        .update({'is_active': !currentActive}).eq('id', id);
    _loadLocations();
  }

  Future<void> _addLocation(BuildContext dialogContext) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    // Close the dialog FIRST using its own context, before any async work.
    // This is the fix for bug #6: the old code called Navigator.pop(context)
    // using the _LocationsManagerState's context (the bottom sheet's context)
    // instead of the dialog's own context, so the dialog never actually
    // closed even though the insert succeeded.
    Navigator.of(dialogContext).pop();

    final user = widget.ref.read(supabaseProvider).auth.currentUser;
    try {
      await widget.ref.read(supabaseProvider).from('locations').insert({
        'name': name,
        'address': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        'is_active': true,
        'created_by': user?.id,
      });
      _nameController.clear();
      _addressController.clear();
      if (mounted) _loadLocations();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error adding location: $e'),
              backgroundColor: AppColors.error500),
        );
      }
    }
  }

  void _showAddLocation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Location'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Location Name *'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(labelText: 'Address'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => _addLocation(dialogContext),
              child: const Text('Add')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Manage Locations',
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(80, 36)),
                onPressed: _showAddLocation,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _locations.isEmpty
                  ? const Center(child: Text('No locations found'))
                  : ListView.separated(
                      controller: widget.scrollController,
                      itemCount: _locations.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final loc = _locations[i];
                        final isActive = loc['is_active'] as bool? ?? true;
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.success50
                                  : AppColors.secondary100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.location_on_rounded,
                                color: isActive
                                    ? AppColors.success600
                                    : AppColors.secondary400,
                                size: 20),
                          ),
                          title: Text(loc['name'] as String? ?? ''),
                          subtitle: loc['address'] != null
                              ? Text(loc['address'] as String,
                                  style: const TextStyle(fontSize: 12))
                              : null,
                          trailing: Switch(
                            value: isActive,
                            onChanged: (_) =>
                                _toggleLocation(loc['id'] as String, isActive),
                            activeColor: AppColors.success500,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: AppColors.primary500),
      ),
    );
  }
}

class _DepartmentsManager extends StatefulWidget {
  final ScrollController scrollController;
  final WidgetRef ref;
  const _DepartmentsManager(
      {required this.scrollController, required this.ref});

  @override
  State<_DepartmentsManager> createState() => _DepartmentsManagerState();
}

class _DepartmentsManagerState extends State<_DepartmentsManager> {
  List<Map<String, dynamic>> _departments = [];
  bool _isLoading = true;
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    try {
      final data = await widget.ref
          .read(supabaseProvider)
          .from('departments')
          .select()
          .order('name');
      setState(() {
        _departments = (data as List).cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleDepartment(String id, bool currentActive) async {
    await widget.ref
        .read(supabaseProvider)
        .from('departments')
        .update({'is_active': !currentActive}).eq('id', id);
    _loadDepartments();
  }

  Future<void> _addDepartment(BuildContext dialogContext) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    // Close using the dialog's own context BEFORE any async work — same
    // fix pattern as Locations (see _LocationsManagerState._addLocation).
    Navigator.of(dialogContext).pop();

    final profile = widget.ref.read(currentProfileProvider).valueOrNull;
    try {
      await widget.ref.read(supabaseProvider).from('departments').insert({
        'name': name,
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'is_active': true,
        'company_id': profile?.companyId,
      });
      _nameController.clear();
      _descriptionController.clear();
      if (mounted) _loadDepartments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error adding department: $e'),
              backgroundColor: AppColors.error500),
        );
      }
    }
  }

  void _showAddDepartment() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Department'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Department Name *'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => _addDepartment(dialogContext),
              child: const Text('Add')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Manage Departments',
                  style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add'),
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size(80, 36)),
                onPressed: _showAddDepartment,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _departments.isEmpty
                  ? const Center(child: Text('No departments found'))
                  : ListView.separated(
                      controller: widget.scrollController,
                      itemCount: _departments.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final dept = _departments[i];
                        final isActive = dept['is_active'] as bool? ?? true;
                        return ListTile(
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AppColors.success50
                                  : AppColors.secondary100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.apartment_rounded,
                                color: isActive
                                    ? AppColors.success600
                                    : AppColors.secondary400,
                                size: 20),
                          ),
                          title: Text(dept['name'] as String? ?? ''),
                          subtitle: dept['description'] != null
                              ? Text(dept['description'] as String,
                                  style: const TextStyle(fontSize: 12))
                              : null,
                          trailing: Switch(
                            value: isActive,
                            onChanged: (_) => _toggleDepartment(
                                dept['id'] as String, isActive),
                            activeColor: AppColors.success500,
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}


class _PaymentModuleSheet extends StatefulWidget {
  final WidgetRef ref;
  const _PaymentModuleSheet({required this.ref});

  @override
  State<_PaymentModuleSheet> createState() => _PaymentModuleSheetState();
}

class _PaymentModuleSheetState extends State<_PaymentModuleSheet> {
  bool? _enabled;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _enabled = widget.ref.read(paymentModuleEnabledProvider);
  }

  Future<void> _toggle(bool value) async {
    setState(() { _enabled = value; _isSaving = true; });
    try {
      final profile = widget.ref.read(currentProfileProvider).valueOrNull;
      if (profile?.companyId == null) return;
      await widget.ref.read(supabaseProvider)
          .from('companies')
          .update({'payment_module_enabled': value})
          .eq('id', profile!.companyId!);
      widget.ref.invalidate(companyProvider);
    } catch (e) {
      setState(() => _enabled = !value); // revert
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error500));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Module', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'When enabled, admins can pay employee salaries and supervisor expenses directly via UPI from within the app.',
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('UPI Payment Module'),
            subtitle: Text(_enabled == true
                ? 'Pay via UPI is active for this company'
                : 'Only Mark as Paid is available'),
            value: _enabled ?? false,
            onChanged: _isSaving ? null : _toggle,
            activeColor: AppColors.success500,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
