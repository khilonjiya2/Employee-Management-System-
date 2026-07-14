import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;
import '../../data/models/app_models.dart';
import '../supervisors/supervisor_wallet_screen.dart';


final _unreadNotificationCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  return ref.read(notificationRepositoryProvider).getUnreadCount();
});

class _NotificationBell extends ConsumerWidget {
  final Color iconColor;
  const _NotificationBell({this.iconColor = Colors.white});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(_unreadNotificationCountProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: iconColor),
          onPressed: () async {
            await context.push('/notifications');
            ref.invalidate(_unreadNotificationCountProvider);
          },
        ),
        unread.when(
          data: (count) => count > 0
              ? Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error500,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  // NOTE: this mirrors the fix already applied to the supervisor dashboard
  // below in this same file (see _SupervisorDashboardScreenState). This
  // state was previously missing all three of the same protections:
  //  1) A properly-typed nullable RealtimeChannel? instead of `dynamic` —
  //     `dynamic` hid the fact that a still-null value was being handed to
  //     removeChannel(), which requires a non-null RealtimeChannel and
  //     throws (a null-check failure) when it isn't one.
  //  2) A FIXED channel topic name ('admin_dashboard_rt'). If you log out
  //     and back in quickly — logout → login WITHOUT a full app restart —
  //     a new AdminDashboardScreen can mount and call channel() with the
  //     exact same topic before the previous instance's channel has
  //     finished being torn down server-side, which is exactly what was
  //     producing "Null check operator used on a null value" errors when
  //     re-entering the dashboard after logout/login. Using a
  //     per-instance-unique topic (timestamp suffix) avoids the collision
  //     entirely, the same way the supervisor dashboard already does.
  //  3) No `mounted` guard in the post-frame callback, so a very fast
  //     navigation away (e.g. immediate logout right after login) could
  //     still run _subscribeRealtime() after the widget was disposed.
  RealtimeChannel? _realtimeSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribeRealtime());
  }

  void _subscribeRealtime() {
    if (!mounted) return;
    final client = ref.read(supabaseProvider);
    _realtimeSub = client
        .channel('admin_dashboard_rt_${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'payroll', callback: (_) => ref.invalidate(dashboardStatsProvider))
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'expenses', callback: (_) => ref.invalidate(dashboardStatsProvider))
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'employees', callback: (_) => ref.invalidate(dashboardStatsProvider))
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'attendance', callback: (_) => ref.invalidate(dashboardStatsProvider))
        .subscribe();
  }

  @override
  void dispose() {
    // Guard against removing a channel that never finished subscribing (the
    // subscribe call above is scheduled via addPostFrameCallback, so a very
    // fast navigation away — e.g. an immediate logout — could otherwise
    // reach dispose() while _realtimeSub is still null).
    final sub = _realtimeSub;
    if (sub != null) {
      ref.read(supabaseProvider).removeChannel(sub);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(dashboardStatsProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          _NotificationBell(iconColor: AppColors.secondary700),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // Never show an error card or a manual "Retry" button — a failure
        // here right after login/logout is expected to be a transient
        // timing race (RLS/JWT context still propagating), and it's
        // already wrapped in its own retry loop (see dashboardStatsProvider
        // in auth_repository.dart). Keep the spinner up and retry silently
        // until it resolves.
        error: (e, stack) => w.AutoRetryLoader(
          onRetry: () => ref.invalidate(dashboardStatsProvider),
        ),
        data: (data) => RefreshIndicator(
          // Awaits the actual refetch so the spinner stays until fresh data
          // arrives \u{2014} this is the real-time/refresh fix for bug #4.
          onRefresh: () async {
            ref.invalidate(dashboardStatsProvider);
            ref.invalidate(_unreadNotificationCountProvider);
            await ref.read(dashboardStatsProvider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary700, AppColors.primary400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary500.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      w.GenderAvatar(
                        radius: 28,
                        photoUrl: profile?.profilePhotoUrl,
                        gender: profile?.gender,
                        isAdmin: profile?.gender == null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome back,',
                              style: TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontSize: 13,
                                fontFamily: 'Inter',
                              ),
                            ),
                            Text(
                              profile?.fullName ?? 'Admin',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Inter',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, dd MMMM yyyy')
                                  .format(DateTime.now()),
                              style: const TextStyle(
                                color: Color(0xCCFFFFFF),
                                fontFamily: 'Inter',
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _DashboardBody(stats: data, monthLabel: monthLabel),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final Map<String, dynamic> stats;
  final String monthLabel;
  const _DashboardBody({required this.stats, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          _sectionLabel('Admin Actions'),
          const SizedBox(height: 12),
          _QuickActions(),
          const SizedBox(height: 24),
          _sectionLabel("Today's Overview"),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Total Employees',
                  value: '${stats['total_employees']}',
                  icon: Icons.people_rounded,
                  iconColor: AppColors.primary500,
                  iconBg: AppColors.primary50,
                  onTap: () => context.push('/employees'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Active',
                  value: '${stats['active_employees']}',
                  icon: Icons.person_rounded,
                  iconColor: AppColors.secondary500,
                  iconBg: const Color(0xFFEEF2FF),
                  onTap: () => context.push('/employees/active'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Present Today',
                  value: '${stats['today_present']}',
                  icon: Icons.check_circle_rounded,
                  iconColor: AppColors.success500,
                  iconBg: const Color(0xFFE8F5E9),
                  onTap: () => context.push('/attendance/today/present'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Absent Today',
                  value: '${stats['today_absent']}',
                  icon: Icons.cancel_rounded,
                  iconColor: AppColors.error500,
                  iconBg: const Color(0xFFFFEBEE),
                  onTap: () => context.push('/attendance/today/absent'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel("Expense Overview \u{B7} $monthLabel"),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Pending',
                  value: CurrencyUtils.formatCompact(stats['expense_pending'] ?? 0),
                  icon: Icons.pending_rounded,
                  iconColor: AppColors.accent500,
                  iconBg: const Color(0xFFFFF8E1),
                  onTap: () => context.push('/expenses/filter/pending'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Approved',
                  value: CurrencyUtils.formatCompact(stats['expense_approved'] ?? 0),
                  icon: Icons.check_circle_rounded,
                  iconColor: AppColors.success500,
                  iconBg: const Color(0xFFE8F5E9),
                  onTap: () => context.push('/expenses/filter/approved'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel("Payroll Overview \u{B7} $monthLabel"),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Liability',
                  value: CurrencyUtils.formatCompact(stats['payroll_liability'] ?? 0),
                  icon: Icons.account_balance_rounded,
                  iconColor: AppColors.primary500,
                  iconBg: AppColors.primary50,
                  onTap: () => context.push('/payroll/overview/liability'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Paid',
                  value: CurrencyUtils.formatCompact(stats['payroll_paid'] ?? 0),
                  icon: Icons.payments_rounded,
                  iconColor: AppColors.success500,
                  iconBg: const Color(0xFFE8F5E9),
                  onTap: () => context.push('/payroll/overview/paid'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  title: 'Pending',
                  value: CurrencyUtils.formatCompact(stats['payroll_pending'] ?? 0),
                  icon: Icons.hourglass_bottom_rounded,
                  iconColor: AppColors.accent500,
                  iconBg: const Color(0xFFFFF8E1),
                  onTap: () => context.push('/payroll/overview/pending'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        fontFamily: 'Inter',
        color: Color(0xFF1A1A2E),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: Color(0xFFC4C7D4)),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFamily: 'Inter',
                color: Color(0xFF1A1A2E),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
              color: Color(0xFF8A8FA3),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionItem(Icons.people_rounded, 'Employees', '/employees'),
      _ActionItem(Icons.supervisor_account_rounded, 'Supervisors', '/supervisors'),
      _ActionItem(Icons.calendar_today_rounded, 'Attendance', '/attendance'),
      _ActionItem(Icons.receipt_long_rounded, 'Expenses', '/expenses'),
      _ActionItem(Icons.payments_rounded, 'Payroll', '/payroll'),
      _ActionItem(Icons.bar_chart_rounded, 'Reports', '/reports'),
      _ActionItem(Icons.account_balance_wallet_rounded, 'Advance', '/advance-payment'),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.9,
      children: actions.map((a) => _QuickActionBtn(item: a)).toList(),
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final String path;
  _ActionItem(this.icon, this.label, this.path);
}

class _QuickActionBtn extends StatelessWidget {
  final _ActionItem item;
  const _QuickActionBtn({required this.item});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(item.path),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: AppColors.primary500, size: 20),
            ),
            const SizedBox(height: 6),
            Text(
              item.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
                color: Color(0xFF4A4A6A),
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// Supervisor dashboard stats \u2014 a proper autoDispose FutureProvider keyed by
// profile id, exactly like [dashboardStatsProvider] above. This replaces an
// older pattern that cached the stats Future by hand in State fields
// (`_statsFuture` / `_loadedForProfileId`). That manual cache was the root
// cause of the "dashboard breaks after logout, only fixed by restarting the
// app" bug: those fields lived on the State object, so if the widget was
// ever rebuilt/reused across a logout->login cycle faster than the guard
// logic expected, the screen could keep showing (or crash trying to read)
// data tied to the PREVIOUS session. A watched autoDispose provider has no
// such window \u2014 it is disposed the instant nothing observes it (e.g. on
// logout, when this screen leaves the tree) and always recomputes fresh for
// whatever profile id it's called with.
final _supervisorDashboardStatsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String?>((ref, profileId) async {
  if (profileId == null) {
    return {
      'total_employees': 0,
      'today_submitted': false,
      'pending_today': 0,
      'approved_today': 0,
    };
  }

  final client = ref.read(supabaseProvider);

  // Reuses the supervisor row already fetched as part of the single
  // combined login fetch (see sessionContextProvider in
  // auth_repository.dart) instead of running a separate query with its
  // own retry loop for the same "row not committed yet" race. Falls back
  // to a direct lookup only if that combined fetch didn't have it for
  // some reason, so this stays just as reliable, just faster on the
  // normal path.
  final ctx = await ref.watch(sessionContextProvider.future);
  String? supervisorId = ctx?.supervisor?.id;
  if (supervisorId == null) {
    for (var attempt = 0; attempt < 4; attempt++) {
      final sup = await client
          .from('supervisors')
          .select('id')
          .eq('profile_id', profileId)
          .maybeSingle();
      if (sup != null) {
        supervisorId = sup['id'] as String;
        break;
      }
      if (attempt < 3) await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  if (supervisorId == null) {
    return {
      'total_employees': 0,
      'today_submitted': false,
      'pending_today': 0.0,
      'approved_today': 0.0,
    };
  }

  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final now = DateTime.now();
  final monthStart = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
  final monthEnd = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month + 1, 0));

  final results = await withRetry(() => Future.wait<dynamic>([
        client.from('supervisor_employees').select('id').eq('supervisor_id', supervisorId) as Future<dynamic>,
        client
            .from('attendance')
            .select('id')
            .eq('supervisor_id', supervisorId)
            .eq('attendance_date', today)
            .maybeSingle() as Future<dynamic>,
        client
            .from('expenses')
            .select('id, amount')
            .eq('supervisor_id', supervisorId)
            .gte('expense_date', monthStart)
            .lte('expense_date', monthEnd)
            .eq('status', 'pending') as Future<dynamic>,
        client
            .from('expenses')
            .select('id, amount')
            .eq('supervisor_id', supervisorId)
            .gte('expense_date', monthStart)
            .lte('expense_date', monthEnd)
            .eq('status', 'approved') as Future<dynamic>,
      ]));

  final employees = results[0];
  final todayAtt = results[1];
  final pendingThisMonth = results[2];
  final approvedThisMonth = results[3];

  double sumAmount(List rows) => rows.fold<double>(
      0, (sum, r) => sum + ((r['amount'] as num?)?.toDouble() ?? 0));

  return {
    'supervisor_id': supervisorId,
    'total_employees': (employees as List).length,
    'today_submitted': todayAtt != null,
    'pending_today': sumAmount(pendingThisMonth as List),
    'approved_today': sumAmount(approvedThisMonth as List),
  };
});

class SupervisorDashboardScreen extends ConsumerStatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  ConsumerState<SupervisorDashboardScreen> createState() =>
      _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState
    extends ConsumerState<SupervisorDashboardScreen> {
  // Only the realtime channel subscription is genuinely stateful here; the
  // stats themselves now live entirely in [_supervisorDashboardStatsProvider]
  // (see above) and are read via ref.watch in build(), never cached by hand.
  RealtimeChannel? _realtimeSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribeRealtime());
  }

  void _subscribeRealtime() {
    if (!mounted) return;
    final client = ref.read(supabaseProvider);
    _realtimeSub = client
        .channel('sup_dashboard_rt_${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'attendance', callback: (_) => _refresh())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'expenses', callback: (_) => _refresh())
        .onPostgresChanges(event: PostgresChangeEvent.all, schema: 'public', table: 'supervisor_wallet', callback: (_) => _refresh())
        .subscribe();
  }

  @override
  void dispose() {
    // Guard against removing a channel that never finished subscribing (the
    // subscribe call above is scheduled via addPostFrameCallback, so a very
    // fast navigation away \u2014 e.g. an immediate logout \u2014 could otherwise
    // reach dispose() while _realtimeSub is still null).
    final sub = _realtimeSub;
    if (sub != null) {
      ref.read(supabaseProvider).removeChannel(sub);
    }
    super.dispose();
  }

  void _refresh() {
    final profileId = ref.read(currentProfileProvider).valueOrNull?.id;
    // _supervisorDashboardStatsProvider now reads the supervisor record via
    // sessionContextProvider — invalidating just the stats provider alone
    // would still see the same cached session context, so this needs
    // invalidating too for a real refetch (e.g. after this supervisor's own
    // photo was just updated in Settings).
    ref.invalidate(sessionContextProvider);
    ref.invalidate(_supervisorDashboardStatsProvider(profileId));
    ref.invalidate(_unreadNotificationCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime.now());

    // Show loading until the profile itself is ready. Once it is, stats are
    // watched straight from the provider below \u2014 no manual gating needed.
    if (profile == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F6FA),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final statsAsync = ref.watch(_supervisorDashboardStatsProvider(profile.id));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          _NotificationBell(iconColor: AppColors.secondary700),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        // Never show an error or a manual "Retry" button here — see the
        // matching comment on the admin dashboard's stats.when() above.
        error: (e, _) => w.AutoRetryLoader(onRetry: _refresh),
        data: (stats) {
          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await ref.read(_supervisorDashboardStatsProvider(profile.id).future);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary700, AppColors.primary400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary500.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        w.GenderAvatar(
                          radius: 28,
                          photoUrl: profile?.profilePhotoUrl,
                          gender: profile?.gender,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Welcome back,',
                                style: TextStyle(
                                  color: Color(0xCCFFFFFF),
                                  fontSize: 13,
                                  fontFamily: 'Inter',
                                ),
                              ),
                              Text(
                                profile?.fullName ?? 'Supervisor',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Inter',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                                style: const TextStyle(
                                  color: Color(0xCCFFFFFF),
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    "Today's Status",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                      color: Color(0xFF1A1A2E),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'My Employees',
                          value: '${stats['total_employees']}',
                          icon: Icons.people_rounded,
                          iconColor: AppColors.primary500,
                          iconBg: AppColors.primary50,
                          onTap: () {
                            final supervisorId = stats['supervisor_id'] as String?;
                            if (supervisorId != null) {
                              context.push('/supervisors/$supervisorId/employees');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Attendance',
                          value: stats['today_submitted'] == true ? 'Done \u{2713}' : 'Pending',
                          icon: Icons.calendar_today_rounded,
                          iconColor: stats['today_submitted'] == true
                              ? AppColors.success500
                              : AppColors.accent500,
                          iconBg: stats['today_submitted'] == true
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFF8E1),
                          onTap: () => context.push('/attendance'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Wallet balance card
                  SupervisorDashboardWalletCard(
                      supervisorId: stats['supervisor_id'] as String?),

                  const SizedBox(height: 12),

                  Text(
                    "Expenses \u{B7} $monthLabel",
                    style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      fontFamily: 'Inter', color: Color(0xFF8A8FA3),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Pending Expenses',
                          value: CurrencyUtils.formatCompact(stats['pending_today'] ?? 0),
                          icon: Icons.receipt_long_rounded,
                          iconColor: AppColors.accent500,
                          iconBg: const Color(0xFFFFF8E1),
                          // Item 10: navigate to expenses filtered to pending (supervisor's own)
                          onTap: () => context.push('/expenses/filter/pending'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Approved Expenses',
                          value: CurrencyUtils.formatCompact(stats['approved_today'] ?? 0),
                          icon: Icons.check_circle_rounded,
                          iconColor: AppColors.success500,
                          iconBg: const Color(0xFFE8F5E9),
                          // Item 10: navigate to expenses filtered to approved (supervisor's own)
                          onTap: () => context.push('/expenses/filter/approved'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.calendar_today_rounded, size: 18),
                          label: const Text('Mark Attendance'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary500,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => context.push('/attendance/new'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Expense'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent500,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => context.push('/expenses/new'),
                        ),
                      ),
                    ],
                  ),
const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                      label: const Text('Add Employee'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary600,
                        side: const BorderSide(color: AppColors.primary400),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => context.push('/employees/new'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.receipt_outlined, size: 18),
                      label: const Text('My Payslips'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary600,
                        side: const BorderSide(color: AppColors.primary400),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showMyPayslips(context),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.account_balance_outlined, size: 18),
                      label: const Text('My Bank Details'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary600,
                        side: const BorderSide(color: AppColors.primary400),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => context.push('/my-bank-details'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Item 12: Supervisor can reset passwords of their assigned employees
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.lock_reset_rounded, size: 18),
                      label: const Text('Reset Employee Password'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.warning600,
                        side: const BorderSide(color: AppColors.warning500),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _showSupervisorResetPassword(context, ref),
                    ),
                  ),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showSupervisorResetPassword(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        expand: false,
        builder: (ctx, controller) =>
            _SupervisorResetPasswordSheet(scrollController: controller, ref: ref),
      ),
    );
  }

void _showMyPayslips(BuildContext context) {
    final profileId = ref.read(currentProfileProvider).valueOrNull?.id;
    if (profileId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SupervisorPayslipsScreen(profileId: profileId),
      ),
    );
  }

}


class _SupervisorPayslipsScreen extends ConsumerWidget {
  final String profileId;
  const _SupervisorPayslipsScreen({required this.profileId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Payslips')),
      body: FutureBuilder(
        future: ref.read(supabaseProvider)
            .from('supervisors')
            .select('id, monthly_salary')
            .eq('profile_id', profileId)
            .maybeSingle(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final sup = snapshot.data as Map<String, dynamic>?;
          if (sup == null) {
            return const w.EmptyState(
              title: 'No supervisor record found',
              icon: Icons.person_off_outlined,
            );
          }
          final supervisorId = sup['id'] as String;
          return _PayslipList(supervisorId: supervisorId);
        },
      ),
    );
  }
}

// Item 12: Supervisor can reset passwords of their assigned employees only
class _SupervisorResetPasswordSheet extends StatefulWidget {
  final ScrollController scrollController;
  final WidgetRef ref;
  const _SupervisorResetPasswordSheet({required this.scrollController, required this.ref});

  @override
  State<_SupervisorResetPasswordSheet> createState() => _SupervisorResetPasswordSheetState();
}

class _SupervisorResetPasswordSheetState extends State<_SupervisorResetPasswordSheet> {
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  bool _isResetting = false;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final client = widget.ref.read(supabaseProvider);
    final profile = widget.ref.read(currentProfileProvider).valueOrNull;
    if (profile == null) return;
    try {
      // Get supervisor record
      final sup = await client.from('supervisors').select('id').eq('profile_id', profile.id).maybeSingle();
      if (sup == null) { setState(() => _isLoading = false); return; }
      // Get only assigned employees
      final rows = await client
          .from('supervisor_employees')
          .select('employees(id, name, employee_code, profile_id, gender, employee_photo_url)')
          .eq('supervisor_id', sup['id']);
      final emps = <Map<String, dynamic>>[];
      for (final row in rows as List) {
        final emp = row['employees'] as Map<String, dynamic>?;
        if (emp != null && emp['profile_id'] != null) {
          emps.add({'profile_id': emp['profile_id'], 'name': emp['name'], 'code': emp['employee_code'], 'role': 'Employee', 'gender': emp['gender'], 'photo': emp['employee_photo_url']});
        }
      }
      emps.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      if (mounted) setState(() { _employees = emps; _filtered = emps; _isLoading = false; });
    } catch (_) { if (mounted) setState(() => _isLoading = false); }
  }

  void _filter(String q) => setState(() {
    _filtered = q.isEmpty ? _employees : _employees.where((p) =>
      (p['name'] as String).toLowerCase().contains(q.toLowerCase()) ||
      (p['code'] as String).toLowerCase().contains(q.toLowerCase())).toList();
  });

  Future<void> _reset(Map<String, dynamic> person) async {
    final confirm = await showDialog<bool>(context: context, builder: (d) => AlertDialog(
      title: const Text('Reset Password?'),
      content: Text('Password for ${person['name']} will be reset to default: Abcd@123\n\nThey will be asked to change it on next login.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(d).pop(false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.of(d).pop(true), child: const Text('Reset')),
      ],
    ));
    if (confirm != true || !mounted) return;
    setState(() => _isResetting = true);
    try {
      final profile = widget.ref.read(currentProfileProvider).valueOrNull;
      final response = await widget.ref.read(supabaseProvider).functions.invoke('admin-reset-password',
          body: {'user_id': person['profile_id'], 'admin_profile_id': profile?.id});
      final data = response.data as Map<String, dynamic>?;
      if (data?['success'] != true) throw Exception(data?['error'] ?? 'Failed');
      if (mounted) await showDialog(context: context, builder: (d) => AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppColors.success50,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.success500, size: 40),
          ),
          const SizedBox(height: 16),
          const Text('Password Reset Successfully',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                  fontFamily: 'Inter'),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: AppColors.secondary600, height: 1.5),
              children: [
                TextSpan(text: '${person['name']}\'s password has been reset to:\n\n'),
                const TextSpan(text: 'Abcd@123',
                    style: TextStyle(fontWeight: FontWeight.w800,
                        fontFamily: 'Inter', color: AppColors.primary600,
                        fontSize: 16)),
                const TextSpan(text: '\n\nThey will be asked to change it on next login.'),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(d).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.friendly(e)), backgroundColor: AppColors.error500));
    } finally { if (mounted) setState(() => _isResetting = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Reset Employee Password', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('Only your assigned employees are shown.', style: TextStyle(fontSize: 12, color: AppColors.secondary500)),
          const SizedBox(height: 12),
          TextField(controller: _searchController, onChanged: _filter,
              decoration: const InputDecoration(hintText: 'Search by name or code', prefixIcon: Icon(Icons.search_rounded))),
        ]),
      ),
      const Divider(height: 1),
      if (_isResetting) const LinearProgressIndicator(),
      Expanded(
        child: _isLoading ? const Center(child: CircularProgressIndicator())
            : _filtered.isEmpty ? const Center(child: Text('No assigned employees found'))
            : ListView.separated(
                controller: widget.scrollController,
                itemCount: _filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = _filtered[i];
                  return ListTile(
                    leading: w.GenderAvatar(
                      radius: 18,
                      photoUrl: p['photo'] as String?,
                      gender: p['gender'] as String?,
                    ),
                    title: Text(p['name'] as String),
                    subtitle: Text('Employee \u{2022} ${p['code']}'),
                    trailing: const Icon(Icons.lock_reset_rounded, size: 20),
                    onTap: _isResetting ? null : () => _reset(p),
                  );
                }),
      ),
    ]);
  }
}

class _PayslipList extends ConsumerWidget {
  final String supervisorId;
  const _PayslipList({required this.supervisorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payrollAsync = ref.watch(
        _supervisorPayslipProvider(supervisorId));

    return payrollAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) {
        if (list.isEmpty) {
          return const w.EmptyState(
            title: 'No payslips yet',
            subtitle: 'Your admin will process your monthly salary here',
            icon: Icons.payments_outlined,
          );
        }
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(_supervisorPayslipProvider(supervisorId)),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = list[i];
              final monthName = DateFormat('MMMM yyyy')
                  .format(DateTime(p.payrollYear, p.payrollMonth));
              return InkWell(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                  builder: (_) => DraggableScrollableSheet(
                    initialChildSize: 0.65, expand: false,
                    builder: (_, ctrl) => ListView(controller: ctrl, padding: const EdgeInsets.all(24), children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.secondary300, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 16),
                      Text('Payslip \u{2014} $monthName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Inter')),
                      const SizedBox(height: 4),
                      w.StatusBadge(status: p.status),
                      const SizedBox(height: 20),
                      _PayslipDetailRow('Monthly Salary', CurrencyUtils.format(p.monthlySalary)),
                      _PayslipDetailRow('Bonus', '+ ${CurrencyUtils.format(p.bonus)}', color: AppColors.success600),
                      _PayslipDetailRow('Deduction', '- ${CurrencyUtils.format(p.deduction)}', color: AppColors.error600),
                      const Divider(height: 24),
                      _PayslipDetailRow('Net Amount', CurrencyUtils.format(p.netAmount), bold: true, color: AppColors.primary600),
                      if (p.paidAt != null) ...[
                        const SizedBox(height: 12),
                        Row(children: [
                          const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success500),
                          const SizedBox(width: 6),
                          Text('Paid on ${DateFormat('dd MMM yyyy').format(p.paidAt!.toLocal())}', style: const TextStyle(fontSize: 13, color: AppColors.success600)),
                        ]),
                      ],
                      const SizedBox(height: 20),
                    ]),
                  ),
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.secondary200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(monthName,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                              'Base: ${CurrencyUtils.format(p.monthlySalary)}'
                              '  Bonus: ${CurrencyUtils.format(p.bonus)}'
                              '  Ded: ${CurrencyUtils.format(p.deduction)}',
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(CurrencyUtils.format(p.netAmount),
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary600)),
                        const SizedBox(height: 4),
                        w.StatusBadge(status: p.isPaid ? 'paid' : p.status),
                      ],
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.secondary400),
                  ],
                ),
              ),
              );
            },
          ),
        );
      },
    );
  }
}

final _supervisorPayslipProvider = FutureProvider.autoDispose
    .family<List<SupervisorPayrollModel>, String>((ref, supervisorId) {
  return ref
      .read(supervisorPayrollRepositoryProvider)
      .getForSupervisor(supervisorId);
});

class _PayslipDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;
  const _PayslipDetailRow(this.label, this.value, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: AppColors.secondary600, fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, fontFamily: 'Inter', color: color ?? AppColors.secondary800)),
      ]),
    );
  }
}
