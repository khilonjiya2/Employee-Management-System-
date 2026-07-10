import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/auth_repository.dart';
import '../../presentation/auth/force_password_change_screen.dart'
    show passwordChangeInProgress;

import '../../presentation/auth/login_screen.dart';
import '../../presentation/auth/forgot_password_screen.dart';
import '../../presentation/auth/force_password_change_screen.dart';
import '../../presentation/startup/splash_screen.dart';

import '../../presentation/dashboard/admin_dashboard_screen.dart';
import '../../presentation/dashboard/supervisor_dashboard_screen.dart';
import '../../presentation/dashboard/employee_dashboard_screen.dart';

import '../../presentation/employees/employees_list_screen.dart';
import '../../presentation/employees/employee_form_screen.dart';
import '../../presentation/employees/employee_detail_screen.dart';

import '../../presentation/supervisors/supervisors_list_screen.dart';
import '../../presentation/supervisors/supervisor_employees_screen.dart';
import '../../presentation/supervisors/supervisor_wallet_screen.dart';

import '../../presentation/attendance/attendance_list_screen.dart';
import '../../presentation/attendance/attendance_entry_screen.dart';
import '../../presentation/attendance/attendance_map_screen.dart';
import '../../presentation/attendance/attendance_detail_screen.dart';

import '../../presentation/expenses/expenses_list_screen.dart';
import '../../presentation/expenses/expense_form_screen.dart';
import '../../presentation/expenses/expense_detail_screen.dart';

import '../../presentation/payroll/payroll_list_screen.dart';
import '../../presentation/payroll/payroll_process_screen.dart';
import '../../presentation/payroll/payroll_detail_screen.dart';
import '../../presentation/payroll/payroll_overview_detail_screen.dart';

import '../../presentation/reports/reports_screen.dart';
import '../../presentation/settings/settings_screen.dart';
import '../../presentation/notifications/notifications_screen.dart';

import '../../presentation/profile/my_bank_details_screen.dart';
import '../../presentation/attendance/today_attendance_screen.dart';
import '../../presentation/dashboard/employee_attendance_history_screen.dart';
import '../../presentation/dashboard/employee_payroll_history_screen.dart';

import '../../presentation/shared/main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authStream = Supabase.instance.client.auth.onAuthStateChange;
  final refreshListenable = GoRouterRefreshStream(authStream);

  // redirect() only re-runs when this listenable fires, which used to
  // happen only on Supabase auth events. On a fresh app launch with an
  // already-persisted session, no auth event fires, so the router could
  // get stuck showing a blank/loading dashboard while the profile was
  // still resolving, or skip the mustChangePassword redirect entirely.
  // Notifying on every profile change closes that gap.
  ref.listen(currentProfileProvider, (previous, next) {
    refreshListenable.notify();
  });

  return GoRouter(
    refreshListenable: refreshListenable,
    initialLocation: '/splash',

    redirect: (context, state) {
      // THE COLD-START FIX: SplashScreen used to exist in the codebase but
      // was never actually registered as a route, so the app booted
      // straight into '/login' and this redirect() would send a logged-in
      // user to '/dashboard' the instant `currentSession` went non-null —
      // with no wait for the user's profile to actually finish loading.
      // That race (session restored a beat before currentUser/profile
      // hydration finished) is what produced a broken/wrong dashboard on
      // first cold launch but a working one after restart. SplashScreen
      // now explicitly awaits the profile before navigating anywhere, so
      // let it own its own navigation here rather than fighting it.
      if (state.matchedLocation == '/splash') return null;

      final session = ref.read(authRepositoryProvider).currentSession;
      final isLoggedIn = session != null;

      final isPublicRoute = [
        '/login',
        '/forgot-password',
        '/change-password',
      ].contains(state.matchedLocation);

      if (!isLoggedIn && !isPublicRoute) return '/login';
      if (isLoggedIn &&
          (state.matchedLocation == '/login' ||
              state.matchedLocation == '/forgot-password')) {
        return '/dashboard';
      }

      // Force password change check.
      // IMPORTANT: only redirect TO /change-password using the cached profile
      // value (AsyncValue.valueOrNull). We deliberately do NOT redirect AWAY
      // from /change-password here \u{2014} that responsibility belongs solely to
      // ForcePasswordChangeScreen itself after it confirms the profile was
      // actually updated (see force_password_change_screen.dart _save()).
      // This avoids the double-prompt bug where a stale cached profile
      // (still showing mustChangePassword: true during the brief
      // invalidate/refetch window) would bounce the user back here right
      // after they just changed their password.
      if (isLoggedIn && state.matchedLocation != '/change-password') {
        // Don't redirect if a password change is actively in progress —
        // the auth state change from updatePassword would otherwise bounce
        // the user back here on the stale cached profile value.
        if (passwordChangeInProgress) return null;

        final profileAsync = ref.read(currentProfileProvider);
        // Only act on a profile we're CONFIDENT about: it must have data
        // AND not be in the middle of a refetch (isRefreshing == true means
        // Riverpod is still serving the PREVIOUS value while a new fetch is
        // in flight \u{2014} acting on that stale value is what caused the
        // "asked to change password twice" bug).
        if (profileAsync.hasValue && !profileAsync.isRefreshing) {
          final profile = profileAsync.value;
          if (profile?.mustChangePassword == true) {
            return '/change-password';
          }
        }
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
      GoRoute(
        name: 'change-password',
        path: '/change-password',
        builder: (_, __) => const ForcePasswordChangeScreen(),
      ),

      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            name: 'dashboard',
            path: '/dashboard',
            builder: (context, state) => const DashboardRouterWidget(),
          ),

          GoRoute(
            name: 'employees',
            path: '/employees',
            builder: (_, __) => const EmployeesListScreen(),
            routes: [
              GoRoute(
                name: 'employee-active',
                path: 'active',
                builder: (_, __) => const EmployeesListScreen(initialStatus: 'active'),
              ),
              GoRoute(
                name: 'employee-new',
                path: 'new',
                builder: (_, __) => const EmployeeFormScreen(),
              ),
              GoRoute(
                name: 'employee-detail',
                path: ':id',
                builder: (_, state) =>
                    EmployeeDetailScreen(id: state.pathParameters['id']!),
              ),
              GoRoute(
                name: 'employee-edit',
                path: ':id/edit',
                builder: (_, state) => EmployeeFormScreen(
                    employeeId: state.pathParameters['id']!),
              ),
            ],
          ),

          GoRoute(
            name: 'supervisors',
            path: '/supervisors',
            builder: (_, __) => const SupervisorsListScreen(),
            routes: [
              GoRoute(
                name: 'supervisor-new',
                path: 'new',
                builder: (_, __) => const SupervisorFormScreen(),
              ),
              GoRoute(
                name: 'supervisor-detail',
                path: ':id',
                builder: (_, state) =>
                    SupervisorDetailScreen(id: state.pathParameters['id']!),
              ),
              GoRoute(
                name: 'supervisor-edit',
                path: ':id/edit',
                builder: (_, state) => SupervisorFormScreen(
                    supervisorId: state.pathParameters['id']!),
              ),
              GoRoute(
                name: 'supervisor-employees',
                path: ':id/employees',
                builder: (_, state) => SupervisorEmployeesScreen(
                    supervisorId: state.pathParameters['id']!),
              ),
              GoRoute(
                name: 'supervisor-wallet',
                path: ':id/wallet',
                builder: (_, state) => SupervisorWalletScreen(
                  supervisorId: state.pathParameters['id']!,
                  supervisorName: state.extra as String?,
                ),
              ),
            ],
          ),

          GoRoute(
            name: 'attendance',
            path: '/attendance',
            builder: (_, __) => const AttendanceListScreen(),
            routes: [
              GoRoute(
                name: 'attendance-today',
                path: 'today',
                builder: (_, __) => const TodayAttendanceScreen(),
                routes: [
                  GoRoute(
                    name: 'attendance-today-filter',
                    path: ':filter',
                    builder: (_, state) => TodayAttendanceScreen(
                        initialFilter: state.pathParameters['filter']),
                  ),
                ],
              ),
              GoRoute(
                name: 'attendance-new',
                path: 'new',
                builder: (_, __) => const AttendanceEntryScreen(),
              ),
              GoRoute(
                name: 'attendance-edit',
                path: ':id/edit',
                builder: (_, state) => AttendanceEntryScreen(
                    attendanceId: state.pathParameters['id']!),
              ),
              GoRoute(
                name: 'attendance-detail',
                path: ':id/detail',
                builder: (_, state) => AttendanceDetailScreen(
                    attendanceId: state.pathParameters['id']!),
              ),
              GoRoute(
                name: 'attendance-map',
                path: ':id/map',
                builder: (_, state) =>
                    AttendanceMapScreen(attendanceId: state.pathParameters['id']!),
              ),
            ],
          ),

          GoRoute(
            name: 'expenses',
            path: '/expenses',
            builder: (_, __) => const ExpensesListScreen(),
            routes: [
              GoRoute(
                name: 'expense-filter',
                path: 'filter/:status',
                builder: (_, state) => ExpensesListScreen(
                    initialFilter: state.pathParameters['status']),
              ),
              GoRoute(
                name: 'expense-new',
                path: 'new',
                builder: (_, __) => const ExpenseFormScreen(),
              ),
              GoRoute(
                name: 'expense-detail',
                path: ':id',
                builder: (_, state) =>
                    ExpenseDetailScreen(id: state.pathParameters['id']!),
              ),
              GoRoute(
                name: 'expense-edit',
                path: ':id/edit',
                builder: (_, state) =>
                    ExpenseFormScreen(expenseId: state.pathParameters['id']!),
              ),
            ],
          ),

          GoRoute(
            name: 'payroll',
            path: '/payroll',
            builder: (_, __) => const PayrollListScreen(),
            routes: [
              GoRoute(
                name: 'payroll-filter',
                path: 'filter/:status',
                builder: (_, state) => PayrollListScreen(
                    initialStatusFilter: state.pathParameters['status']),
              ),
              GoRoute(
                name: 'payroll-overview',
                path: 'overview/:filter',
                builder: (_, state) => PayrollOverviewDetailScreen(
                    filter: state.pathParameters['filter'] ?? 'liability'),
              ),
              GoRoute(
                name: 'payroll-process',
                path: 'process',
                builder: (_, __) => const PayrollProcessScreen(),
              ),
              GoRoute(
                name: 'payroll-detail',
                path: ':id',
                builder: (_, state) =>
                    PayrollDetailScreen(id: state.pathParameters['id']!),
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
            name: 'advance-payment',
            path: '/advance-payment',
            builder: (_, __) => const AdvancePaymentScreen(),
          ),
          GoRoute(
            name: 'advance-payment-supervisor',
            path: '/advance-payment/:id',
            builder: (_, state) => AdvancePaymentScreen(
              supervisorId: state.pathParameters['id'],
            ),
          ),
          GoRoute(
            name: 'notifications',
            path: '/notifications',
            builder: (_, __) => const NotificationsScreen(),
          ),
          GoRoute(
            name: 'myBankDetails',
            path: '/my-bank-details',
            builder: (_, __) => const MyBankDetailsScreen(),
          ),
          GoRoute(
            name: 'employeeAttendanceHistory',
            path: '/my-attendance-history',
            builder: (_, state) => EmployeeAttendanceHistoryScreen(
                employeeId: state.extra as String),
          ),
          GoRoute(
            name: 'employeePayrollHistory',
            path: '/my-payroll-history',
            builder: (_, state) => EmployeePayrollHistoryScreen(
                employeeId: state.extra as String),
          ),
        ],
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
          child: Text(state.error?.toString() ?? 'Unknown routing error')),
    ),
  );
});

class DashboardRouterWidget extends ConsumerWidget {
  const DashboardRouterWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    return profile.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Failed to load profile: $e'))),
      data: (profile) {
        if (profile?.role == 'admin') return const AdminDashboardScreen();
        if (profile?.role == 'employee') return const EmployeeDashboardScreen();
        return const SupervisorDashboardScreen();
      },
    );
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription =
        stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  void notify() => notifyListeners();

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
