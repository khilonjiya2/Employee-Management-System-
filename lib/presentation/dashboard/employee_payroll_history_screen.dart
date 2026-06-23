import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;

final _fullPayrollHistoryProvider = FutureProvider.autoDispose
    .family<List<PayrollModel>, String>((ref, employeeId) {
  return ref
      .read(payrollRepositoryProvider)
      .getOwnPayrollHistory(employeeId, limit: 24);
});

class EmployeePayrollHistoryScreen extends ConsumerWidget {
  final String employeeId;
  const EmployeePayrollHistoryScreen({super.key, required this.employeeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final payrollAsync = ref.watch(_fullPayrollHistoryProvider(employeeId));

    return Scaffold(
      appBar: AppBar(title: const Text('Payroll History')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_fullPayrollHistoryProvider(employeeId));
          await ref.read(_fullPayrollHistoryProvider(employeeId).future);
        },
        child: payrollAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(
                    height: 400,
                    child: w.EmptyState(
                      title: 'No payroll history yet',
                      subtitle: 'Processed payslips will appear here',
                      icon: Icons.receipt_long_outlined,
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _PayslipCard(
                payroll: list[i],
                onTap: () => _showPayslipDetail(context, list[i]),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showPayslipDetail(BuildContext context, PayrollModel p) {
    final month = DateFormat('MMMM yyyy')
        .format(DateTime(p.payrollYear, p.payrollMonth));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        expand: false,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.secondary300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Payslip \u{2014} $month',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'Inter')),
            const SizedBox(height: 4),
            w.StatusBadge(status: p.status),
            const SizedBox(height: 20),
            _PayslipRow(label: 'Daily Wage Rate', value: CurrencyUtils.format(p.dailyWageRate)),
            _PayslipRow(label: 'Present Days', value: p.presentDays.toStringAsFixed(1)),
            _PayslipRow(label: 'Absent Days', value: p.absentDays.toStringAsFixed(1)),
            _PayslipRow(label: 'Half Days', value: p.halfDays.toStringAsFixed(1)),
            _PayslipRow(label: 'Overtime Hours', value: p.overtimeHours.toStringAsFixed(1)),
            _PayslipRow(label: 'Overtime Amount', value: CurrencyUtils.format(p.overtimeAmount)),
            const Divider(height: 24),
            _PayslipRow(label: 'Gross Wage', value: CurrencyUtils.format(p.grossWage)),
            _PayslipRow(label: 'Advance Deduction', value: '- ${CurrencyUtils.format(p.advanceDeduction)}',
                valueColor: AppColors.error600),
            _PayslipRow(label: 'Penalty', value: '- ${CurrencyUtils.format(p.penaltyDeduction)}',
                valueColor: AppColors.error600),
            _PayslipRow(label: 'Bonus', value: '+ ${CurrencyUtils.format(p.bonus)}',
                valueColor: AppColors.success600),
            const Divider(height: 24),
            _PayslipRow(
              label: 'Net Wage',
              value: CurrencyUtils.format(p.netWage),
              bold: true,
              valueColor: AppColors.primary600,
            ),
            if (p.paidAt != null) ...[
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success500),
                const SizedBox(width: 6),
                Text('Paid on ${DateFormat('dd MMM yyyy').format(p.paidAt!.toLocal())}',
                    style: const TextStyle(color: AppColors.success600, fontSize: 13)),
              ]),
            ],
            if (p.remarks != null && p.remarks!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Note: ${p.remarks}',
                  style: const TextStyle(fontSize: 12, color: AppColors.secondary500)),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _PayslipRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  const _PayslipRow({required this.label, required this.value, this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(label,
            style: TextStyle(
                fontSize: 13, color: AppColors.secondary600,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
        Text(value,
            style: TextStyle(
                fontSize: 13, fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                fontFamily: 'Inter', color: valueColor ?? AppColors.secondary800)),
      ]),
    );
  }
}

class _PayslipCard extends StatelessWidget {
  final PayrollModel payroll;
  final VoidCallback onTap;
  const _PayslipCard({required this.payroll, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPaid = payroll.status == 'paid';
    final monthLabel = DateFormat('MMMM yyyy')
        .format(DateTime(payroll.payrollYear, payroll.payrollMonth));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondary200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(monthLabel,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15, fontFamily: 'Inter'))),
              w.StatusBadge(status: payroll.status),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.secondary400),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              _MiniStat(label: 'Present', value: payroll.presentDays.toStringAsFixed(0)),
              _MiniStat(label: 'Absent', value: payroll.absentDays.toStringAsFixed(0)),
              _MiniStat(label: 'Net Wage', value: CurrencyUtils.format(payroll.netWage)),
            ]),
            if (isPaid) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success500),
                const SizedBox(width: 6),
                Text(
                  payroll.paidAt != null
                      ? 'Paid on ${DateFormat('dd MMM yyyy').format(payroll.paidAt!.toLocal())}'
                      : 'Paid',
                  style: const TextStyle(fontSize: 12, color: AppColors.success600),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'Inter')),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.secondary500)),
      ]),
    );
  }
}
