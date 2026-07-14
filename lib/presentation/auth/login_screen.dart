import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/repositories/auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authRepositoryProvider);
      // Username is the mobile number \u{2014} we convert it to an email for
      // Supabase auth by appending @ems.com, matching how accounts are
      // created (see create-supervisor / create-employee edge functions).
      final mobile = _emailController.text.trim();
      final email = '$mobile@ems.com';

      await auth.signInWithEmail(email, _passwordController.text);

      // Invalidate and wait for fresh profile
      ref.invalidate(currentProfileProvider);
      final profile = await ref.read(currentProfileProvider.future);

      if (!mounted) return;

      if (profile == null) {
        setState(() => _error = 'Could not load your profile. Please try again.');
        await auth.signOut();
        return;
      }

      if (!profile.isActive) {
        setState(() => _error = 'Your account has been deactivated. Contact your administrator.');
        await auth.signOut();
        return;
      }

      // NOTE: We deliberately do NOT navigate to '/change-password' here.
      // The router's redirect() is the single source of truth for this
      // decision (see app_router.dart).

      // NOTE: We also don't warm the role-specific record here anymore.
      // The router's central auth-event listener (see app_router.dart)
      // already does that in reaction to this exact sign-in event — doing
      // it here too would just be a second, redundant fetch racing the
      // first one for no benefit. DashboardRouterWidget and each role's
      // dashboard already show their own loading state via AsyncValue
      // while that resolves, so there's nothing left to gate on here.
      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = e.toString().replaceAll('AuthException: ', '').replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 56),
                _buildHeader(theme),
                const SizedBox(height: 48),
                _buildCard(theme),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary500.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/images/logo.png',
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary100,
                ),
                child: const Icon(Icons.business_center_rounded,
                    size: 48, color: AppColors.primary500),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: [AppColors.primary600, AppColors.primary400],
          ).createShader(bounds),
          child: const Text(
            'Employee Management',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'SYSTEM',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
            color: AppColors.secondary400,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary200),
        boxShadow: [
          BoxShadow(
              color: AppColors.secondary200,
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.phone,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  hintText: '10-digit mobile number',
                  prefixIcon: Icon(Icons.phone_outlined)),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Mobile number is required';
                if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) {
                  return 'Enter a valid 10-digit mobile number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              enabled: !_isLoading,
              onFieldSubmitted: (_) => _handleLogin(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: ValidationUtils.validatePassword,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error500.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.error600)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Sign In'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}