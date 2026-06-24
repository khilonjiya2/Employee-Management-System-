import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;

final selectedPayrollMonthProvider = StateProvider<DateTime>((_) => DateTime(DateTime.now().year, DateTime.now().month));

final payrollListProvider = FutureProvider.autoDispose.family<List<PayrollModel>, DateTime>((ref, date) {
  return ref.watch(payrollRepositoryProvider).getByMonthYear(date.month, date.year);
});

final supervisorPayrollListProvider = FutureProvider.autoDispose.family<List<SupervisorPayrollModel>, DateTime>((ref, date) {
  return ref.watch(supervisorPayrollRepositoryProvider).getByMonthYear(date.month, date.year);
});

final allSupervisorsForPayrollProvider = FutureProvider.autoDispose<List<SupervisorModel>>((ref) {
  return ref.watch(supervisorRepositoryProvider).getAll(isActive: true);
});

class PayrollListScreen extends ConsumerStatefulWidget {
  final String? initialStatusFilter; // 'paid', 'processed', null=all
  const PayrollListScreen({super.key, this.initialStatusFilter});

  @override
  ConsumerState<PayrollListScreen> createState() => _PayrollListScreenState();
}

class _PayrollListScreenState extends ConsumerState<PayrollListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatusFilter;
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(selectedPayrollMonthProvider);
    final payrollList = ref.watch(payrollListProvider(selectedMonth));
    final supervisorPayrollList =
        ref.watch(supervisorPayrollListProvider(selectedMonth));
    final allSupervisors = ref.watch(allSupervisorsForPayrollProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payroll'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            onPressed: () => context.push('/payroll/process'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Employees'),
            Tab(text: 'Supervisors'),
          ],
        ),
      ),
      body: Column(
        children: [
          _MonthSelector(
            selected: selectedMonth,
            onChanged: (m) => ref.read(selectedPayrollMonthProvider.notifier).state = m,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ---- Employees tab (existing behavior, unchanged) ----
                payrollList.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (list) {
                    final filtered = _statusFilter == null
                        ? list
                        : list.where((p) => p.status == _statusFilter).toList();
                    if (filtered.isEmpty) {
                      return w.EmptyState(
                        title: _statusFilter != null ? 'No ${_statusFilter} payroll' : 'No payroll processed',
                        subtitle: 'Process payroll for ${DateFormat('MMMM yyyy').format(selectedMonth)}',
                        icon: Icons.payments_outlined,
                        actionLabel: 'Process Payroll',
                        onAction: () => context.push('/payroll/process'),
                      );
                    }

                    final totalNet = filtered.fold<double>(0, (sum, p) => sum + p.netWage);
                    final paidCount = filtered.where((p) => p.isPaid).length;

                    return Column(
                      children: [
                        if (_statusFilter != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: Row(
                              children: [
                                Text('Filtered: ${_statusFilter!.toUpperCase()}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.primary500)),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => setState(() => _statusFilter = null),
                                  child: const Text('Clear filter'),
                                ),
                              ],
                            ),
                          ),
                        _PayrollSummaryBar(totalNet: totalNet, paidCount: paidCount, total: filtered.length),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(payrollListProvider(selectedMonth));
                              ref.invalidate(companyProvider);
                              await ref.read(payrollListProvider(selectedMonth).future);
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) => _PayrollCardWithPay(
                                payroll: filtered[i],
                                onTap: () => context.push('/payroll/${filtered[i].id}'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                // ---- Supervisors tab (new \u{2014} item 6) ----
                supervisorPayrollList.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (list) {
                    final supervisors = allSupervisors.valueOrNull ?? [];
                    final totalNet = list.fold<double>(0, (sum, p) => sum + p.netAmount);
                    final paidCount = list.where((p) => p.status == 'paid' || p.paymentStatus == 'paid').length;

                    return Column(
                      children: [
                        _PayrollSummaryBar(totalNet: totalNet, paidCount: paidCount, total: list.length),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(supervisorPayrollListProvider(selectedMonth));
                              ref.invalidate(allSupervisorsForPayrollProvider);
                              ref.invalidate(companyProvider);
                              await ref.read(supervisorPayrollListProvider(selectedMonth).future);
                            },
                            child: list.isEmpty
                                ? ListView(
                                    children: [
                                      SizedBox(
                                        height: 300,
                                        child: w.EmptyState(
                                          title: 'No supervisor payroll processed',
                                          subtitle: 'Process payroll for ${DateFormat('MMMM yyyy').format(selectedMonth)}',
                                          icon: Icons.payments_outlined,
                                          actionLabel: 'Process Supervisor Payroll',
                                          onAction: () => _showProcessSupervisorPayroll(
                                              context, ref, selectedMonth, supervisors),
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: list.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemBuilder: (_, i) {
                                      final record = list[i];
                                      final supervisor = supervisors.firstWhere(
                                        (s) => s.id == record.supervisorId,
                                        orElse: () => SupervisorModel(
                                          id: record.supervisorId,
                                          profileId: '',
                                          supervisorCode: record.supervisorCode ?? '',
                                          name: record.supervisorName ?? 'Supervisor',
                                          email: '',
                                          isActive: true,
                                          monthlySalary: record.monthlySalary,
                                          createdAt: record.createdAt,
                                          updatedAt: record.createdAt,
                                        ),
                                      );
                                      return _SupervisorPayrollCard(
                                        record: record,
                                        supervisor: supervisor,
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) => FloatingActionButton.extended(
          onPressed: () => _tabController.index == 0
              ? context.push('/payroll/process')
              : _showProcessSupervisorPayroll(
                  context, ref, selectedMonth, allSupervisors.valueOrNull ?? []),
          icon: const Icon(Icons.calculate_rounded),
          label: Text(_tabController.index == 0
              ? 'Process Payroll'
              : 'Process Supervisor'),
        ),
      ),
    );
  }

  void _showProcessSupervisorPayroll(BuildContext context, WidgetRef ref,
      DateTime month, List<SupervisorModel> supervisors) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProcessSupervisorPayrollSheet(
        month: month,
        supervisors: supervisors,
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;

  const _MonthSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: const Border(bottom: BorderSide(color: AppColors.secondary200)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => onChanged(DateTime(selected.year, selected.month - 1)),
          ),
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy').format(selected),
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: selected.isBefore(DateTime(DateTime.now().year, DateTime.now().month))
                ? () => onChanged(DateTime(selected.year, selected.month + 1))
                : null,
          ),
        ],
      ),
    );
  }
}

class _PayrollSummaryBar extends StatelessWidget {
  final double totalNet;
  final int paidCount;
  final int total;

  const _PayrollSummaryBar({required this.totalNet, required this.paidCount, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.primary50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(label: 'Total Liability', value: CurrencyUtils.formatCompact(totalNet), color: AppColors.primary600),
          _StatItem(label: 'Employees', value: '$total', color: AppColors.secondary700),
          _StatItem(label: 'Paid', value: '$paidCount', color: AppColors.success600),
          _StatItem(label: 'Pending', value: '${total - paidCount}', color: AppColors.accent600),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Inter', color: color)),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _PayrollCardWithPay extends ConsumerWidget {
  final PayrollModel payroll;
  final VoidCallback onTap;

  const _PayrollCardWithPay({required this.payroll, required this.onTap});

  // In _PayrollCardWithPay \u{2014} replace the entire build method:
@override
Widget build(BuildContext context, WidgetRef ref) {
  final theme = Theme.of(context);
  final paymentEnabled = ref.watch(paymentModuleEnabledProvider);

  return Container(
    decoration: BoxDecoration(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.secondary200),
    ),
    child: Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary100,
                  child: Text(
                    (payroll.employeeName ?? 'E')[0].toUpperCase(),
                    style: const TextStyle(
                        color: AppColors.primary600,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(payroll.employeeName ?? 'Employee',
                          style: theme.textTheme.titleMedium),
                      Text(payroll.employeeCode ?? '',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.primary500)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _DayBadge(
                              label: 'P',
                              days: payroll.presentDays,
                              color: AppColors.success500),
                          const SizedBox(width: 4),
                          _DayBadge(
                              label: 'H',
                              days: payroll.halfDays,
                              color: AppColors.accent500),
                          const SizedBox(width: 4),
                          _DayBadge(
                              label: 'A',
                              days: payroll.absentDays,
                              color: AppColors.error500),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(CurrencyUtils.format(payroll.netWage),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: AppColors.primary600)),
                    const SizedBox(height: 4),
                    w.StatusBadge(
                        status: payroll.isPaid ? 'paid' : payroll.status),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!payroll.isPaid)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: w.CashfreePayButton(
              referenceType: 'payroll',
              referenceId: payroll.id,
              payeeName: payroll.employeeName ?? 'Employee',
              amount: payroll.netWage,
              currentPaymentStatus: payroll.paymentStatus,
              onMarkPaid: () async {
                await ref.read(payrollRepositoryProvider).markAsPaid(payroll.id);
                ref.invalidate(payrollListProvider(ref.read(selectedPayrollMonthProvider)));
              },
            ),
          ),
      ],
    ),
  );
}
}

class _SupervisorPayrollCard extends ConsumerWidget {
  final SupervisorPayrollModel record;
  final SupervisorModel supervisor;

  const _SupervisorPayrollCard({required this.record, required this.supervisor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final paymentEnabled = ref.watch(paymentModuleEnabledProvider);
    final isPaid = record.status == 'paid' || record.paymentStatus == 'paid';

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.accent100,
                  child: Text(
                    supervisor.name.isNotEmpty ? supervisor.name[0].toUpperCase() : 'S',
                    style: const TextStyle(
                        color: AppColors.accent600,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(supervisor.name, style: theme.textTheme.titleMedium),
                      Text(supervisor.supervisorCode,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: AppColors.primary500)),
                      if (record.bonus > 0 || record.deduction > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${record.bonus > 0 ? '+${CurrencyUtils.format(record.bonus)} bonus  ' : ''}${record.deduction > 0 ? '-${CurrencyUtils.format(record.deduction)} deduction' : ''}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(CurrencyUtils.format(record.netAmount),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(color: AppColors.primary600)),
                    const SizedBox(height: 4),
                    w.StatusBadge(status: isPaid ? 'paid' : record.status),
                  ],
                ),
              ],
            ),
          ),
          if (!isPaid)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: w.CashfreePayButton(
                referenceType: 'expense', // supervisors are paid like expense reimbursements
                referenceId: record.id,
                payeeName: supervisor.name,
                amount: record.netAmount,
                currentPaymentStatus: record.paymentStatus,
                onMarkPaid: () async {
                  await ref.read(supervisorPayrollRepositoryProvider).markAsPaid(record.id);
                  ref.invalidate(supervisorPayrollListProvider(ref.read(selectedPayrollMonthProvider)));
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _ProcessSupervisorPayrollSheet extends ConsumerStatefulWidget {
  final DateTime month;
  final List<SupervisorModel> supervisors;
  const _ProcessSupervisorPayrollSheet({required this.month, required this.supervisors});

  @override
  ConsumerState<_ProcessSupervisorPayrollSheet> createState() =>
      _ProcessSupervisorPayrollSheetState();
}

class _ProcessSupervisorPayrollSheetState
    extends ConsumerState<_ProcessSupervisorPayrollSheet> {
  String? _selectedSupervisorId;
  final _bonusController = TextEditingController(text: '0');
  final _deductionController = TextEditingController(text: '0');
  bool _isProcessing = false;
  bool _isProcessingAll = false;

  @override
  void dispose() {
    _bonusController.dispose();
    _deductionController.dispose();
    super.dispose();
  }

  Future<void> _processAll(BuildContext sheetContext) async {
    setState(() => _isProcessingAll = true);
    try {
      final unprocessed = await ref
          .read(supervisorPayrollRepositoryProvider)
          .getUnprocessedForMonth(widget.month.month, widget.month.year);

      if (unprocessed.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('All supervisors already have payroll processed for this month')));
        }
        setState(() => _isProcessingAll = false);
        return;
      }

      // Salary is fixed per supervisor (not attendance-based), so this
      // can safely run for everyone in one pass with no bonus/deduction
      // \u{2014} those can still be added individually afterward if needed.
      for (final supervisor in unprocessed) {
        await ref.read(supervisorPayrollRepositoryProvider).processMonth(
              supervisor.id,
              widget.month.month,
              widget.month.year,
              supervisor.monthlySalary,
            );
      }
      ref.invalidate(supervisorPayrollListProvider(widget.month));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Processed payroll for ${unprocessed.length} supervisor(s)'),
            backgroundColor: AppColors.success500));
        Navigator.of(sheetContext).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.friendly(e)), backgroundColor: AppColors.error500),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAll = false);
    }
  }

  Future<void> _process(BuildContext sheetContext) async {
    if (_selectedSupervisorId == null) return;
    setState(() => _isProcessing = true);
    try {
      final supervisor =
          widget.supervisors.firstWhere((s) => s.id == _selectedSupervisorId);
      await ref.read(supervisorPayrollRepositoryProvider).processMonth(
            supervisor.id,
            widget.month.month,
            widget.month.year,
            supervisor.monthlySalary,
            bonus: double.tryParse(_bonusController.text) ?? 0,
            deduction: double.tryParse(_deductionController.text) ?? 0,
          );
      ref.invalidate(supervisorPayrollListProvider(widget.month));
      if (mounted) Navigator.of(sheetContext).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.friendly(e)), backgroundColor: AppColors.error500),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Process Supervisor Payroll', style: Theme.of(context).textTheme.titleLarge),
          Text(DateFormat('MMMM yyyy').format(widget.month),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.secondary500)),
          const SizedBox(height: 16),
          // Supervisor salary is fixed (not attendance-based), so all
          // unprocessed supervisors can be processed in one click.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: _isProcessingAll
                  ? const SizedBox(
                      height: 16, width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.bolt_rounded, size: 18),
              label: Text(_isProcessingAll ? 'Processing...' : 'Process All Supervisors (Fixed Salary)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary600,
                side: const BorderSide(color: AppColors.primary400),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _isProcessingAll ? null : () => _processAll(context),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('OR process one individually', style: TextStyle(fontSize: 12, color: AppColors.secondary500)),
              ),
              Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedSupervisorId,
            decoration: const InputDecoration(labelText: 'Supervisor'),
            items: widget.supervisors
                .map((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text('${s.name} (\u{20B9}${s.monthlySalary.toStringAsFixed(0)}/mo)')))
                .toList(),
            onChanged: (v) => setState(() => _selectedSupervisorId = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _bonusController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Bonus'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _deductionController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Deduction'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_selectedSupervisorId == null || _isProcessing)
                  ? null
                  : () => _process(context),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Process'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBadge extends StatelessWidget {
  final String label;
  final double days;
  final Color color;

  const _DayBadge({required this.label, required this.days, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
      child: Text('$label:${days.toStringAsFixed(days == days.roundToDouble() ? 0 : 1)}', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
    );
  }
}

class PayrollProcessScreen extends ConsumerStatefulWidget {
  const PayrollProcessScreen({super.key});

  @override
  ConsumerState<PayrollProcessScreen> createState() => _PayrollProcessScreenState();
}

class _PayrollProcessScreenState extends ConsumerState<PayrollProcessScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<EmployeeModel> _employees = [];
  Set<String> _selectedEmployees = {};
  bool _isLoading = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final employees = await ref.read(employeeRepositoryProvider).getAll(status: 'active');
      setState(() {
        _employees = employees;
        _selectedEmployees = employees.map((e) => e.id).toSet();
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _processPayroll() async {
    if (_selectedEmployees.isEmpty) return;

    final confirm = await w.ConfirmDialog.show(
      context,
      title: 'Process Payroll?',
      message: 'Process payroll for ${_selectedEmployees.length} employees for ${DateFormat('MMMM yyyy').format(_selectedMonth)}?',
      confirmLabel: 'Process',
      confirmColor: AppColors.primary500,
    );
    if (confirm != true || !mounted) return;

    setState(() => _isProcessing = true);
    int success = 0;
    List<String> errors = [];

    for (final id in _selectedEmployees) {
      try {
        await ref.read(payrollRepositoryProvider).processPayroll(id, _selectedMonth.month, _selectedMonth.year);
        success++;
      } catch (e) {
        errors.add(e.toString());
      }
    }

    if (mounted) {
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Processed $success/${_selectedEmployees.length} employees${errors.isNotEmpty ? ". ${errors.length} errors." : ""}'),
          backgroundColor: errors.isEmpty ? AppColors.success500 : AppColors.warning500,
        ),
      );
      if (errors.isEmpty) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Process Payroll'),
        actions: [
          TextButton(
            onPressed: _isProcessing ? null : _processPayroll,
            child: const Text('Process'),
          ),
        ],
      ),
      body: w.LoadingOverlay(
        isLoading: _isProcessing,
        child: Column(
          children: [
            _MonthSelector(
              selected: _selectedMonth,
              onChanged: (m) => setState(() => _selectedMonth = m),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('${_selectedEmployees.length}/${_employees.length} selected', style: Theme.of(context).textTheme.bodyMedium),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedEmployees = _employees.map((e) => e.id).toSet()),
                    child: const Text('Select All'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _selectedEmployees.clear()),
                    child: const Text('Deselect All'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _employees.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (_, i) {
                        final emp = _employees[i];
                        return CheckboxListTile(
                          value: _selectedEmployees.contains(emp.id),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) _selectedEmployees.add(emp.id);
                              else _selectedEmployees.remove(emp.id);
                            });
                          },
                          title: Text(emp.name, style: Theme.of(context).textTheme.titleMedium),
                          subtitle: Text('${emp.employeeCode} \u{2022} \u{20B9}${emp.dailyWageRate}/day', style: Theme.of(context).textTheme.bodySmall),
                          secondary: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primary100,
                            child: Text(emp.name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary600, fontFamily: 'Inter', fontSize: 13)),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          tileColor: Theme.of(context).colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _processPayroll,
                child: _isProcessing
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Process ${_selectedEmployees.length} Employees'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}