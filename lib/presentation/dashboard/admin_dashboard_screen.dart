import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(dashboardStatsProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: AppColors.primary600,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              title: null,
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary700,
                      AppColors.primary500,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor:
                                  Colors.white.withOpacity(
                                0.2,
                              ),
                              child: const Icon(
                                Icons.business_center_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Welcome Admin',
                                    style: TextStyle(
                                      color:
                                          Color(0xBBFFFFFF),
                                      fontSize: 12,
                                      fontFamily:
                                          'Inter',
                                    ),
                                  ),
                                  Text(
                                    profile?.fullName ??
                                        'Admin',
                                    maxLines: 1,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.white,
                                      fontSize: 15,
                                      fontWeight:
                                          FontWeight
                                              .w600,
                                      fontFamily:
                                          'Inter',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons
                                    .notifications_outlined,
                                color: Colors.white,
                              ),
                              onPressed: () => context
                                  .push(
                                      '/notifications'),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.settings_outlined,
                                color: Colors.white,
                              ),
                              onPressed: () => context
                                  .push('/settings'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          DateFormat(
                            'EEEE, dd MMMM yyyy',
                          ).format(DateTime.now()),
                          style: const TextStyle(
                            color: Color(0xBBFFFFFF),
                            fontSize: 12,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: stats.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child:
                      CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Text(
                  'Error loading stats: $e',
                ),
              ),
              data: (data) =>
                  _DashboardBody(stats: data),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final Map<String, dynamic> stats;

  const _DashboardBody({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const w.SectionHeader(
            title: 'Admin Actions',
          ),

          const SizedBox(height: 12),

          _QuickActions(),

          const SizedBox(height: 24),

          const w.SectionHeader(
            title: 'Today\'s Overview',
          ),

          const SizedBox(height: 12),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              w.StatCard(
                title: 'Total Employees',
                value: '${stats['total_employees']}',
                icon: Icons.people_outline_rounded,
                color: AppColors.primary500,
              ),
              w.StatCard(
                title: 'Present Today',
                value: '${stats['today_present']}',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success500,
              ),
              w.StatCard(
                title: 'Absent Today',
                value: '${stats['today_absent']}',
                icon: Icons.cancel_outlined,
                color: AppColors.error500,
              ),
              w.StatCard(
                title: 'Active Employees',
                value: '${stats['active_employees']}',
                icon: Icons.person_outline_rounded,
                color: AppColors.secondary500,
              ),
            ],
          ),

          const SizedBox(height: 24),

          const w.SectionHeader(
            title: 'Today\'s Expense Overview',
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: w.StatCard(
                  title: 'Pending',
                  value: CurrencyUtils.formatCompact(
                    stats['expense_pending'] ?? 0,
                  ),
                  icon: Icons.pending_outlined,
                  color: AppColors.accent500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: w.StatCard(
                  title: 'Approved',
                  value: CurrencyUtils.formatCompact(
                    stats['expense_approved'] ?? 0,
                  ),
                  icon: Icons.check_circle_outline,
                  color: AppColors.success500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          const w.SectionHeader(
            title: 'Payroll Overview',
          ),

          const SizedBox(height: 12),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.9,
            children: [
              w.StatCard(
                title: 'Liability',
                value: CurrencyUtils.formatCompact(
                  stats['payroll_liability'] ?? 0,
                ),
                icon: Icons.account_balance_outlined,
                color: AppColors.primary500,
              ),
              w.StatCard(
                title: 'Paid',
                value: CurrencyUtils.formatCompact(
                  stats['payroll_paid'] ?? 0,
                ),
                icon: Icons.payments_outlined,
                color: AppColors.success500,
              ),
              w.StatCard(
                title: 'Pending',
                value: CurrencyUtils.formatCompact(
                  stats['payroll_pending'] ?? 0,
                ),
                icon: Icons.hourglass_bottom_rounded,
                color: AppColors.accent500,
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _QuickActionBtn(
              icon: Icons.people_rounded,
              label: 'Employees',
              onTap: () => context.push('/employees'),
            ),
            const SizedBox(width: 8),
            _QuickActionBtn(
              icon: Icons.supervisor_account_rounded,
              label: 'Supervisors',
              onTap: () => context.push('/supervisors'),
            ),
            const SizedBox(width: 8),
            _QuickActionBtn(
              icon: Icons.calendar_today_rounded,
              label: 'Attendance',
              onTap: () => context.push('/attendance'),
            ),
            const SizedBox(width: 8),
            _QuickActionBtn(
              icon: Icons.receipt_long_rounded,
              label: 'Expenses',
              onTap: () => context.push('/expenses'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _QuickActionBtn(
              icon: Icons.payments_rounded,
              label: 'Payroll',
              onTap: () => context.push('/payroll'),
            ),
            const SizedBox(width: 8),
            _QuickActionBtn(
              icon: Icons.bar_chart_rounded,
              label: 'Reports',
              onTap: () => context.push('/reports'),
            ),
            const SizedBox(width: 8),
            _QuickActionBtn(
              icon: Icons.settings_rounded,
              label: 'Settings',
              onTap: () => context.push('/settings'),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: SizedBox(),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.secondary200),
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary500, size: 22),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.labelSmall, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
            ],
          ),
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
    setState(() {
      _statsFuture = _loadSupervisorStats(
        ref,
        ref.read(currentProfileProvider).valueOrNull?.id,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.primary600,
                          AppColors.primary400,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
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
                                    fontSize: 24,
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
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const w.SectionHeader(title: 'Today\'s Status'),

                  const SizedBox(height: 12),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      w.StatCard(
                        title: 'Employees',
                        value: '${stats['total_employees']}',
                        icon: Icons.people_outline,
                        color: AppColors.primary500,
                      ),
                      w.StatCard(
                        title: 'Attendance Today',
                        value: stats['today_submitted'] == true ? 'Submitted' : 'Pending',
                        icon: Icons.calendar_today_outlined,
                        color: stats['today_submitted'] == true
                            ? AppColors.success500
                            : AppColors.accent500,
                      ),
                      w.StatCard(
                        title: 'Pending Expenses',
                        value: '${stats['pending_today']}',
                        subtitle: 'Today',
                        icon: Icons.receipt_long_outlined,
                        color: AppColors.accent500,
                      ),
                      w.StatCard(
                        title: 'Approved Expenses',
                        value: '${stats['approved_today']}',
                        subtitle: 'Today',
                        icon: Icons.check_circle_outline,
                        color: AppColors.success500,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today_rounded, size: 18),
                          label: const Text('Mark Attendance'),
                          onPressed: () => context.push('/attendance/new'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('Add Expense'),
                          onPressed: () => context.push('/expenses/new'),
                        ),
                      ),
                    ],
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

    final todayAtt = await client
        .from('attendance')
        .select('id')
        .eq('supervisor_id', supervisorId)
        .eq('attendance_date', today)
        .maybeSingle();

    final pendingToday = await client
        .from('expenses')
        .select('id')
        .eq('supervisor_id', supervisorId)
        .eq('expense_date', today)
        .eq('status', 'pending');

    final approvedToday = await client
        .from('expenses')
        .select('id')
        .eq('supervisor_id', supervisorId)
        .eq('expense_date', today)
        .eq('status', 'approved');

    return {
      'total_employees': (employees as List).length,
      'today_submitted': todayAtt != null,
      'pending_today': (pendingToday as List).length,
      'approved_today': (approvedToday as List).length,
    };
  }
}