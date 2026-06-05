import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/repositories/auth_repository.dart';

final loginLoadingProvider = StateProvider<bool>((_) => false);
final loginErrorProvider = StateProvider<String?>((_) => null);
final loginTabProvider = StateProvider<int>((_) => 0); // 0=email, 1=employee ID

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with TickerProviderStateMixin {
  late final TabController _tabController;
  final _emailController = TextEditingController();
  final _idController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      ref.read(loginTabProvider.notifier).state = _tabController.index;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(loginLoadingProvider.notifier).state = true;
    ref.read(loginErrorProvider.notifier).state = null;

    try {
      final auth = ref.read(authRepositoryProvider);
      final tab = ref.read(loginTabProvider);

      if (tab == 0) {
        await auth.signInWithEmail(_emailController.text.trim(), _passwordController.text);
      } else {
        await auth.signInWithEmployeeId(_idController.text.trim(), _passwordController.text);
      }

      if (mounted) context.go('/dashboard');
    } catch (e) {
      ref.read(loginErrorProvider.notifier).state = e.toString().replaceAll('AuthException: ', '');
    } finally {
      ref.read(loginLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(loginLoadingProvider);
    final error = ref.watch(loginErrorProvider);
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
                _buildCard(theme, isLoading, error),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('Forgot Password?'),
                ),
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
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.primary500,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: AppColors.primary500.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.business_center_rounded, color: AppColors.white, size: 36),
        ),
        const SizedBox(height: 20),
        Text('AttendPay', style: theme.textTheme.displaySmall?.copyWith(letterSpacing: -0.5)),
        const SizedBox(height: 8),
        Text('Employee Management System', style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondary500)),
      ],
    );
  }

  Widget _buildCard(ThemeData theme, bool isLoading, String? error) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.secondary200),
        boxShadow: [
          BoxShadow(color: AppColors.secondary200, blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary500,
            unselectedLabelColor: AppColors.secondary500,
            indicatorColor: AppColors.primary500,
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: AppColors.secondary200,
            labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Email Login'),
              Tab(text: 'ID Login'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: ref.watch(loginTabProvider) == 0
                      ? _emailField()
                      : _idField(),
                ),
                const SizedBox(height: 16),
                _passwordField(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (v) => setState(() => _rememberMe = v ?? false),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                    Text('Remember me', style: theme.textTheme.bodyMedium),
                  ],
                ),
                if (error != null) ...[
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
                        const Icon(Icons.error_outline_rounded, color: AppColors.error600, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(error, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.error600))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: isLoading ? null : _handleLogin,
                  child: isLoading
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Sign In'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emailField() {
    return TextFormField(
      key: const ValueKey('email'),
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Email Address',
        prefixIcon: Icon(Icons.email_outlined),
      ),
      validator: ValidationUtils.validateEmail,
    );
  }

  Widget _idField() {
    return TextFormField(
      key: const ValueKey('id'),
      controller: _idController,
      textCapitalization: TextCapitalization.characters,
      textInputAction: TextInputAction.next,
      decoration: const InputDecoration(
        labelText: 'Supervisor ID (e.g. SUP0001)',
        prefixIcon: Icon(Icons.badge_outlined),
      ),
      validator: (v) => ValidationUtils.validateRequired(v, 'Supervisor ID'),
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _handleLogin(),
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: ValidationUtils.validatePassword,
    );
  }
}
