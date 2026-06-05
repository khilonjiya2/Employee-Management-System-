import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';
import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/forgot_password_screen.dart';
import '../../presentation/auth/reset_password_screen.dart';
import '../../presentation/dashboard/admin_dashboard_screen.dart';
import '../../presentation/dashboard/supervisor_dashboard_screen.dart';
import '../../presentation/employees/employees_list_screen.dart';
import '../../presentation/employees/employee_form_screen.dart';
import '../../presentation/employees/employee_detail_screen.dart';
import '../../presentation/supervisors/supervisors_list_screen.dart';
import '../../presentation/supervisors/supervisor_form_screen.dart';
import '../../presentation/supervisors/supervisor_detail_screen.dart';
import '../../presentation/attendance/attendance_list_screen.dart';
import '../../presentation/attendance/attendance_entry_screen.dart';
import '../../presentation/attendance/attendance_map_screen.dart';
import '../../presentation/expenses/expenses_list_screen.dart';
import '../../presentation/expenses/expense_form_screen.dart';
import '../../presentation/expenses/expense_detail_screen.dart';
import '../../presentation/payroll/payroll_list_screen.dart';
import '../../presentation/payroll/payroll_process_screen.dart';
import '../../presentation/payroll/payroll_detail_screen.dart';
import '../../presentation/reports/reports_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../presentation/notifications/notifications_screen.dart';
import '../../presentation/shared/main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateChangesProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isLoginRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/forgot-password') ||
          state.matchedLocation.startsWith('/reset-password');

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/reset-password', builder: (_, __) => const ResetPasswordScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (context, state) {
            final role = ref.read(currentUserRoleProvider);
            return role == 'admin'
                ? const AdminDashboardScreen()
                : const SupervisorDashboardScreen();
          }),
          GoRoute(
            path: '/employees',
            builder: (_, __) => const EmployeesListScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, __) => const EmployeeFormScreen()),
              GoRoute(path: ':id', builder: (_, s) => EmployeeDetailScreen(id: s.pathParameters['id']!)),
              GoRoute(path: ':id/edit', builder: (_, s) => EmployeeFormScreen(employeeId: s.pathParameters['id']!)),
            ],
          ),
          GoRoute(
            path: '/supervisors',
            builder: (_, __) => const SupervisorsListScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, __) => const SupervisorFormScreen()),
              GoRoute(path: ':id', builder: (_, s) => SupervisorDetailScreen(id: s.pathParameters['id']!)),
              GoRoute(path: ':id/edit', builder: (_, s) => SupervisorFormScreen(supervisorId: s.pathParameters['id']!)),
            ],
          ),
          GoRoute(
            path: '/attendance',
            builder: (_, __) => const AttendanceListScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, __) => const AttendanceEntryScreen()),
              GoRoute(path: ':id/map', builder: (_, s) => AttendanceMapScreen(attendanceId: s.pathParameters['id']!)),
            ],
          ),
          GoRoute(
            path: '/expenses',
            builder: (_, __) => const ExpensesListScreen(),
            routes: [
              GoRoute(path: 'new', builder: (_, __) => const ExpenseFormScreen()),
              GoRoute(path: ':id', builder: (_, s) => ExpenseDetailScreen(id: s.pathParameters['id']!)),
              GoRoute(path: ':id/edit', builder: (_, s) => ExpenseFormScreen(expenseId: s.pathParameters['id']!)),
            ],
          ),
          GoRoute(
            path: '/payroll',
            builder: (_, __) => const PayrollListScreen(),
            routes: [
              GoRoute(path: 'process', builder: (_, __) => const PayrollProcessScreen()),
              GoRoute(path: ':id', builder: (_, s) => PayrollDetailScreen(id: s.pathParameters['id']!)),
            ],
          ),
          GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
