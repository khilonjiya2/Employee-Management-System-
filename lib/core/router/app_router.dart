import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

import '../../data/repositories/auth_repository.dart';

import '../../presentation/startup/splash_screen.dart';

import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/forgot_password_screen.dart';

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
  final authStream =
      Supabase.instance.client.auth.onAuthStateChange;

  return GoRouter(
    refreshListenable: GoRouterRefreshStream(authStream),
    initialLocation: '/splash',

    redirect: (context, state) {
      final session = ref.read(authRepositoryProvider).currentSession;

      final isLoggedIn = session != null;

      final isPublicRoute = [
  '/splash',
  '/login',
  '/forgot-password',
].contains(state.matchedLocation);

      if (!isLoggedIn && !isPublicRoute) {
        return '/login';
      }

      if (isLoggedIn &&
    (state.matchedLocation == '/login' ||
        state.matchedLocation == '/forgot-password')) {
  return '/dashboard';
}

      return null;
    },

    routes: [
      GoRoute(
        name: 'splash',
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),

      GoRoute(
        name: 'login',
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),

      GoRoute(
        name: 'forgot-password',
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),

      

      ShellRoute(
        builder: (context, state, child) {
          return MainShell(child: child);
        },
        routes: [
          GoRoute(
            name: 'dashboard',
            path: '/dashboard',
            builder: (context, state) {
              final profile =
                  ref.watch(currentProfileProvider);

              return profile.when(
                loading: () => const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, __) => const Scaffold(
                  body: Center(
                    child: Text('Failed to load profile'),
                  ),
                ),
                data: (profile) {
                  if (profile?.role == 'admin') {
                    return const AdminDashboardScreen();
                  }

                  return const SupervisorDashboardScreen();
                },
              );
            },
          ),

          GoRoute(
            name: 'employees',
            path: '/employees',
            builder: (_, __) =>
                const EmployeesListScreen(),
            routes: [
              GoRoute(
                name: 'employee-new',
                path: 'new',
                builder: (_, __) =>
                    const EmployeeFormScreen(),
              ),
              GoRoute(
                name: 'employee-detail',
                path: ':id',
                builder: (_, state) =>
                    EmployeeDetailScreen(
                  id: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                name: 'employee-edit',
                path: ':id/edit',
                builder: (_, state) =>
                    EmployeeFormScreen(
                  employeeId:
                      state.pathParameters['id']!,
                ),
              ),
            ],
          ),

          GoRoute(
            name: 'supervisors',
            path: '/supervisors',
            builder: (_, __) =>
                const SupervisorsListScreen(),
            routes: [
              GoRoute(
                name: 'supervisor-new',
                path: 'new',
                builder: (_, __) =>
                    const SupervisorFormScreen(),
              ),
              GoRoute(
                name: 'supervisor-detail',
                path: ':id',
                builder: (_, state) =>
                    SupervisorDetailScreen(
                  id: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                name: 'supervisor-edit',
                path: ':id/edit',
                builder: (_, state) =>
                    SupervisorFormScreen(
                  supervisorId:
                      state.pathParameters['id']!,
                ),
              ),
            ],
          ),

          GoRoute(
            name: 'attendance',
            path: '/attendance',
            builder: (_, __) =>
                const AttendanceListScreen(),
            routes: [
              GoRoute(
                name: 'attendance-new',
                path: 'new',
                builder: (_, __) =>
                    const AttendanceEntryScreen(),
              ),
              GoRoute(
                name: 'attendance-map',
                path: ':id/map',
                builder: (_, state) =>
                    AttendanceMapScreen(
                  attendanceId:
                      state.pathParameters['id']!,
                ),
              ),
            ],
          ),

          GoRoute(
            name: 'expenses',
            path: '/expenses',
            builder: (_, __) =>
                const ExpensesListScreen(),
            routes: [
              GoRoute(
                name: 'expense-new',
                path: 'new',
                builder: (_, __) =>
                    const ExpenseFormScreen(),
              ),
              GoRoute(
                name: 'expense-detail',
                path: ':id',
                builder: (_, state) =>
                    ExpenseDetailScreen(
                  id: state.pathParameters['id']!,
                ),
              ),
              GoRoute(
                name: 'expense-edit',
                path: ':id/edit',
                builder: (_, state) =>
                    ExpenseFormScreen(
                  expenseId:
                      state.pathParameters['id']!,
                ),
              ),
            ],
          ),

          GoRoute(
            name: 'payroll',
            path: '/payroll',
            builder: (_, __) =>
                const PayrollListScreen(),
            routes: [
              GoRoute(
                name: 'payroll-process',
                path: 'process',
                builder: (_, __) =>
                    const PayrollProcessScreen(),
              ),
              GoRoute(
                name: 'payroll-detail',
                path: ':id',
                builder: (_, state) =>
                    PayrollDetailScreen(
                  id: state.pathParameters['id']!,
                ),
              ),
            ],
          ),

          GoRoute(
            name: 'reports',
            path: '/reports',
            builder: (_, __) => const ReportsScreen(),
          ),

          GoRoute(
            name: 'settings',
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),

          GoRoute(
            name: 'notifications',
            path: '/notifications',
            builder: (_, __) =>
                const NotificationsScreen(),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Page Not Found'),
        ),
        body: Center(
          child: Text(
            state.error?.toString() ??
                'Unknown routing error',
          ),
        ),
      );
    },
  );
});


class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();

    _subscription = stream
        .asBroadcastStream()
        .listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
