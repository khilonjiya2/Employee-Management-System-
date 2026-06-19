import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;
import '../../data/models/app_models.dart';


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

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        error: (e, stack) => Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dashboard Error:',
                    style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                const SizedBox(height: 8),
                Text(e.toString(),
                    style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  onPressed: () => ref.invalidate(dashboardStatsProvider),
                ),
              ],
            ),
          ),
        ),
        data: (data) => RefreshIndicator(
          // Awaits the actual refetch so the spinner stays until fresh data
          // arrives — this is the real-time/refresh fix for bug #4.
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
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white24,
                        backgroundImage: profile?.profilePhotoUrl != null
                            ? NetworkImage(profile!.profilePhotoUrl!)
                            : null,
                        child: profile?.profilePhotoUrl == null
                            ? const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: Colors.white,
                                size: 28,
                              )
                            : null,
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel("Expense Overview · $monthLabel"),
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel("Payroll Overview · $monthLabel"),
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

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: Color(0xFF1A1A2E),
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

class SupervisorDashboardScreen extends ConsumerStatefulWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  ConsumerState<SupervisorDashboardScreen> createState() =>
      _SupervisorDashboardScreenState();
}

class _SupervisorDashboardScreenState
    extends ConsumerState<SupervisorDashboardScreen> {
  Future<Map<String, dynamic>>? _statsFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _statsFuture ??= _loadSupervisorStats(
      ref,
      ref.read(currentProfileProvider).valueOrNull?.id,
    );
  }

  Future<void> _refresh() async {
    final future = _loadSupervisorStats(
      ref,
      ref.read(currentProfileProvider).valueOrNull?.id,
    );
    setState(() => _statsFuture = future);
    ref.invalidate(_unreadNotificationCountProvider);
    // Await so RefreshIndicator's spinner stays until data actually arrives
    // (real-time/refresh fix for bug #4, supervisor side).
    await future;
  }

  @override
  Widget build(BuildContext context) {
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
      body: FutureBuilder<Map<String, dynamic>>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final stats = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refresh,
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
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white24,
                          backgroundImage: profile?.profilePhotoUrl != null
                              ? NetworkImage(profile!.profilePhotoUrl!)
                              : null,
                          child: profile?.profilePhotoUrl == null
                              ? Text(
                                  (profile?.fullName.isNotEmpty ?? false)
                                      ? profile!.fullName[0].toUpperCase()
                                      : 'S',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
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
                          title: 'Employees',
                          value: '${stats['total_employees']}',
                          icon: Icons.people_rounded,
                          iconColor: AppColors.primary500,
                          iconBg: AppColors.primary50,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Attendance',
                          value: stats['today_submitted'] == true ? 'Done ✓' : 'Pending',
                          icon: Icons.calendar_today_rounded,
                          iconColor: stats['today_submitted'] == true
                              ? AppColors.success500
                              : AppColors.accent500,
                          iconBg: stats['today_submitted'] == true
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFFF8E1),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Text(
                    "Expenses · $monthLabel",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      color: Color(0xFF8A8FA3),
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Pending Expenses',
                          value: '${stats['pending_today']}',
                          icon: Icons.receipt_long_rounded,
                          iconColor: AppColors.accent500,
                          iconBg: const Color(0xFFFFF8E1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Approved Expenses',
                          value: '${stats['approved_today']}',
                          icon: Icons.check_circle_rounded,
                          iconColor: AppColors.success500,
                          iconBg: const Color(0xFFE8F5E9),
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

                  const SizedBox(height: 100),
                ],
              ),
            ),
          );
        },
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

  Future<Map<String, dynamic>> _loadSupervisorStats(
    WidgetRef ref,
    String? profileId,
  ) async {
    if (profileId == null) {
      return {
        'total_employees': 0,
        'today_submitted': false,
        'pending_today': 0,
        'approved_today': 0,
      };
    }

    final client = ref.read(supabaseProvider);

    final sup = await client
        .from('supervisors')
        .select('id')
        .eq('profile_id', profileId)
        .maybeSingle();

    if (sup == null) {
      return {
        'total_employees': 0,
        'today_submitted': false,
        'pending_today': 0,
        'approved_today': 0,
      };
    }

    final supervisorId = sup['id'] as String;

    final employees = await client
        .from('supervisor_employees')
        .select('id')
        .eq('supervisor_id', supervisorId);

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final now = DateTime.now();
    final monthStart = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month, 1));
    final monthEnd = DateFormat('yyyy-MM-dd').format(DateTime(now.year, now.month + 1, 0));

    final todayAtt = await client
        .from('attendance')
        .select('id')
        .eq('supervisor_id', supervisorId)
        .eq('attendance_date', today)
        .maybeSingle();

    // Current-month scoped (bug #4 fix on supervisor side too — was 'today' only before)
    final pendingThisMonth = await client
        .from('expenses')
        .select('id')
        .eq('supervisor_id', supervisorId)
        .gte('expense_date', monthStart)
        .lte('expense_date', monthEnd)
        .eq('status', 'pending');

    final approvedThisMonth = await client
        .from('expenses')
        .select('id')
        .eq('supervisor_id', supervisorId)
        .gte('expense_date', monthStart)
        .lte('expense_date', monthEnd)
        .eq('status', 'approved');

    return {
      'total_employees': (employees as List).length,
      'today_submitted': todayAtt != null,
      'pending_today': (pendingThisMonth as List).length,
      'approved_today': (approvedThisMonth as List).length,
    };
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
              return Container(
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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: AppColors.primary600)),
                        const SizedBox(height: 4),
                        w.StatusBadge(
                            status: p.isPaid ? 'paid' : p.status),
                      ],
                    ),
                  ],
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