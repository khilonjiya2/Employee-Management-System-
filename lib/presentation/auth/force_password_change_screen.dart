import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/repositories/auth_repository.dart';

class ForcePasswordChangeScreen extends ConsumerStatefulWidget {
  const ForcePasswordChangeScreen({super.key});

  @override
  ConsumerState<ForcePasswordChangeScreen> createState() =>
      _ForcePasswordChangeScreenState();
}

class _ForcePasswordChangeScreenState
    extends ConsumerState<ForcePasswordChangeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _completed = false; // guard against double-trigger/double-navigation

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_completed) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await ref
          .read(authRepositoryProvider)
          .updatePassword(_newPasswordController.text);

      final client = ref.read(supabaseProvider);
      final user = client.auth.currentUser;
      if (user != null) {
        await client
            .from('profiles')
            .update({'must_change_password': false}).eq('id', user.id);
      }

      _completed = true;

      ref.invalidate(currentProfileProvider);
      await ref.read(currentProfileProvider.future);

      // Wait for GoRouter's auth stream to settle \u{2014} employees trigger
      // two stream events (password + user_metadata), causing a stale
      // redirect on the second event without this delay.
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) context.go('/dashboard');
    } catch (e) {
      _completed = false;
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
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_reset_rounded,
                    size: 48, color: AppColors.primary500),
                const SizedBox(height: 16),
                Text('Change Your Password',
                    style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'This is your first login. Please set a new password to continue.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.secondary500),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNew
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),
                  ),
                  validator: ValidationUtils.validatePassword,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password *',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) => v != _newPasswordController.text
                      ? 'Passwords do not match'
                      : null,
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
                      : const Text('Set New Password'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
