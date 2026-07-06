import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../shared/widgets.dart' as w;
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import 'payroll_list_screen.dart' show selectedPayrollMonthProvider, payrollListProvider, supervisorPayrollListProvider, allSupervisorsForPayrollProvider;

/// Item 8: Payroll overview detail screen \u{2014} shows all payroll records for a
/// month, filterable by type (Employees / Supervisors) and status.
class PayrollOverviewDetailScreen extends ConsumerStatefulWidget {
  final String filter; // 'liability', 'pending', 'paid'
  const PayrollOverviewDetailScreen({super.key, required this.filter});

  @override
  ConsumerState<PayrollOverviewDetailScreen> createState() =>
      _PayrollOverviewDetailScreenState();
}

class _PayrollOverviewDetailScreenState
    extends ConsumerState<PayrollOverviewDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String get _title {
    switch (widget.filter) {
      case 'paid': return 'Paid Payroll';
      case 'pending': return 'Pending Payroll';
      default: return 'Total Liability';
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _matchesFilter(String status) {
    switch (widget.filter) {
      case 'paid': return status == 'paid';
      case 'pending': return status == 'processed' || status == 'pending';
      default: return true; // liability = all
    }
  }

  @override
  Widget build(BuildContext context) {
    final month = ref.watch(selectedPayrollMonthProvider);
    final empPayrollAsync = ref.watch(payrollListProvider(month));
    final supPayrollAsync = ref.watch(supervisorPayrollListProvider(month));
    final supervisors = ref.watch(allSupervisorsForPayrollProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title),
            Text(DateFormat('MMMM yyyy').format(month),
                style: const TextStyle(fontSize: 11, color: AppColors.secondary400)),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Employees'), Tab(text: 'Supervisors')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // --- Employees ---
          empPayrollAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (all) {
              final list = all.where((p) => _matchesFilter(p.status)).toList();
              final total = list.fold<double>(0, (s, p) => s + p.netWage);
              if (list.isEmpty) return const Center(child: w.EmptyState(title: 'No records', icon: Icons.payments_outlined));
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(payrollListProvider(month)),
                child: Column(children: [
                  _SummaryBar(total: total, count: list.length, label: 'Employee Payroll'),
                  Expanded(
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _EmpPayrollRow(payroll: list[i]),
                    ),
                  ),
                ]),
              );
            },
          ),
          // --- Supervisors ---
          supPayrollAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (all) {
              final list = all.where((p) => _matchesFilter(p.status)).toList();
              final total = list.fold<double>(0, (s, p) => s + p.netAmount);
              if (list.isEmpty) return const Center(child: w.EmptyState(title: 'No records', icon: Icons.payments_outlined));
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(supervisorPayrollListProvider(month)),
                child: Column(children: [
                  _SummaryBar(total: total, count: list.length, label: 'Supervisor Payroll'),
                  Expanded(
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final record = list[i];
                        final sup = supervisors.firstWhere((s) => s.id == record.supervisorId,
                            orElse: () => SupervisorModel(id: record.supervisorId, profileId: '', supervisorCode: record.supervisorCode ?? '', name: record.supervisorName ?? 'Supervisor', email: '', isActive: true, monthlySalary: record.monthlySalary, createdAt: record.createdAt, updatedAt: record.createdAt));
                        return _SupPayrollRow(record: record, supervisor: sup);
                      },
                    ),
                  ),
                ]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final double total;
  final int count;
  final String label;
  const _SummaryBar({required this.total, required this.count, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: AppColors.primary50,
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.secondary500)),
          Text(CurrencyUtils.format(total), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Inter', color: AppColors.primary600)),
        ])),
        Text('$count record(s)', style: const TextStyle(fontSize: 12, color: AppColors.secondary500)),
      ]),
    );
  }
}

class _EmpPayrollRow extends ConsumerWidget {
  final PayrollModel payroll;
  const _EmpPayrollRow({required this.payroll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentEnabled = ref.watch(paymentModuleEnabledProvider);
    return GestureDetector(
      onTap: () => context.push('/payroll/${payroll.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.secondary200),
        ),
        child: Column(children: [
          Row(children: [
            w.GenderAvatar(radius: 20, photoUrl: payroll.employeePhotoUrl, gender: payroll.employeeGender),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(payroll.employeeName ?? 'Employee', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${payroll.presentDays.toStringAsFixed(0)} days \u{2022} ${DateFormat('MMM yyyy').format(DateTime(payroll.payrollYear, payroll.payrollMonth))}',
                  style: const TextStyle(fontSize: 12, color: AppColors.secondary500)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(CurrencyUtils.format(payroll.netWage), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary600)),
              w.StatusBadge(status: payroll.status),
            ]),
          ]),
          if (payroll.status == 'processed' && paymentEnabled) ...[
            const SizedBox(height: 10),
            w.CashfreePayButton(
              referenceType: 'payroll',
              referenceId: payroll.id,
              payeeName: payroll.employeeName ?? 'Employee',
              amount: payroll.netWage,
              currentPaymentStatus: payroll.paymentStatus ?? 'unpaid',
              onMarkPaid: () async {
                await ref.read(payrollRepositoryProvider).update(payroll.id, {
                  'payment_status': 'paid',
                  'payment_method': 'cash',
                  'paid_at': DateTime.now().toIso8601String(),
                  'status': 'paid',
                });
                ref.invalidate(payrollListProvider);
              },
            ),
          ],
        ]),
      ),
    );
  }
}

class _SupPayrollRow extends ConsumerWidget {
  final SupervisorPayrollModel record;
  final SupervisorModel supervisor;
  const _SupPayrollRow({required this.record, required this.supervisor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentEnabled = ref.watch(paymentModuleEnabledProvider);
    return GestureDetector(
      onTap: () => context.push('/supervisors/${supervisor.id}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.secondary200),
        ),
        child: Column(children: [
          Row(children: [
            w.GenderAvatar(radius: 20, photoUrl: supervisor.profilePhotoUrl, gender: supervisor.gender),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(supervisor.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${DateFormat('MMM yyyy').format(DateTime(record.payrollYear, record.payrollMonth))} \u{2022} Fixed salary',
                  style: const TextStyle(fontSize: 12, color: AppColors.secondary500)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(CurrencyUtils.format(record.netAmount), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary600)),
              w.StatusBadge(status: record.status),
            ]),
          ]),
          if (record.status == 'processed' && paymentEnabled) ...[
            const SizedBox(height: 10),
            w.CashfreePayButton(
              referenceType: 'supervisor_payroll',
              referenceId: record.id,
              payeeName: supervisor.name,
              amount: record.netAmount,
              currentPaymentStatus: record.paymentStatus ?? 'unpaid',
              onMarkPaid: () async {
                await ref.read(supervisorPayrollRepositoryProvider).markAsPaid(record.id);
                ref.invalidate(supervisorPayrollListProvider);
              },
            ),
          ],
        ]),
      ),
    );
  }
}
