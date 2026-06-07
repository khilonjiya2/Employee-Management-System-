import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/repositories/auth_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final themeMode = ref.watch(themeModeProvider);
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
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary100,
                    backgroundImage: profile?.profilePhotoUrl != null ? NetworkImage(profile!.profilePhotoUrl!) : null,
                    child: profile?.profilePhotoUrl == null
                        ? Text(
                            (profile?.fullName ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(color: AppColors.primary600, fontFamily: 'Inter', fontSize: 22, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profile?.fullName ?? '', style: theme.textTheme.titleMedium),
                        Text(StringUtils.capitalize(profile?.role ?? ''), style: theme.textTheme.bodySmall?.copyWith(color: AppColors.primary600)),
                        if (profile?.mobile != null) Text(profile!.mobile!, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Appearance
          _SectionTitle(title: 'Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Theme'),
            trailing: DropdownButton<ThemeMode>(
              value: themeMode,
              underline: const SizedBox.shrink(),
              onChanged: (v) => ref.read(themeModeProvider.notifier).setTheme(v!),
              items: const [
                DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
              ],
            ),
          ),

          // Security
          _SectionTitle(title: 'Security'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _showChangePassword(context),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint_rounded),
            title: const Text('Biometric Login'),
            subtitle: const Text('Use fingerprint to sign in'),
            value: _biometricEnabled,
            onChanged: (v) => setState(() => _biometricEnabled = v),
            activeColor: AppColors.success500,
          ),

          // Company (admin only)
          if (profile?.isAdmin == true) ...[
            _SectionTitle(title: 'Administration'),
            ListTile(
              leading: const Icon(Icons.business_outlined),
              title: const Text('Company Settings'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showCompanySettings(context),
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
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.history_rounded),
              title: const Text('Audit Logs'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showAuditLogs(context),
            ),
          ],

          // About
          _SectionTitle(title: 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('App Version'),
            trailing: Text('1.0.0', style: TextStyle(color: AppColors.secondary500, fontFamily: 'Inter')),
          ),
          const ListTile(
            leading: Icon(Icons.security_rounded),
            title: Text('Privacy Policy'),
            trailing: Icon(Icons.chevron_right_rounded),
          ),

          const SizedBox(height: 16),

          // Logout
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.logout_rounded, color: AppColors.error500, size: 18),
              label: const Text('Sign Out', style: TextStyle(color: AppColors.error500)),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error500)),
              onPressed: () => _confirmSignOut(context),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    final _currentController = TextEditingController();
    final _newController = TextEditingController();
    final _confirmController = TextEditingController();
    final _formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Change Password', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(controller: _newController, obscureText: true, decoration: const InputDecoration(labelText: 'New Password'), validator: ValidationUtils.validatePassword),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm Password'),
                validator: (v) => v != _newController.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  try {
                    await ref.read(authRepositoryProvider).updatePassword(_newController.text);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated'), backgroundColor: AppColors.success500));
                    }
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error500));
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

  void _showCompanySettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Company Settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            FutureBuilder(
              future: ref.read(supabaseProvider).from('company_settings').select().maybeSingle(),
              builder: (ctx, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final settings = snapshot.data as Map<String, dynamic>?;
                final nameController = TextEditingController(text: settings?['company_name'] as String? ?? '');
                return Column(
                  children: [
                    TextFormField(controller: nameController, decoration: const InputDecoration(labelText: 'Company Name')),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await ref.read(supabaseProvider).from('company_settings').update({'company_name': nameController.text}).eq('id', settings?['id'] as String);
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

  void _showAuditLogs(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (ctx, controller) => FutureBuilder(
          future: ref.read(supabaseProvider).from('audit_logs').select('*, profiles(full_name)').order('created_at', ascending: false).limit(50),
          builder: (ctx, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final logs = snapshot.data as List;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Audit Logs', style: Theme.of(context).textTheme.titleLarge),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final log = logs[i] as Map<String, dynamic>;
                      final userName = log['profiles'] != null ? (log['profiles'] as Map)['full_name'] as String? : 'Unknown';
                      return ListTile(
                        leading: const Icon(Icons.history_rounded, size: 20, color: AppColors.secondary400),
                        title: Text(log['action'] as String? ?? '', style: Theme.of(context).textTheme.titleSmall),
                        subtitle: Text('$userName • ${log['entity_type']}', style: Theme.of(context).textTheme.bodySmall),
                        trailing: Text(
                          _formatTime(DateTime.parse(log['created_at'] as String)),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error500),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm == true) {
  await ref.read(authRepositoryProvider).signOut();

  ref.invalidate(currentProfileProvider);

  if (mounted) {
    context.go('/splash');
  }
}
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.primary500)),
    );
  }
}
