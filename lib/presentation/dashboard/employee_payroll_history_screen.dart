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

/// Full payroll/salary history for the logged-in employee \u{2014} note: half
/// day / leave breakdowns are intentionally not shown yet, this is a
/// simple present/absent based summary for now.
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
              itemBuilder: (_, i) => _PayslipCard(payroll: list[i]),
            );
          },
        ),
      ),
    );
  }
}

class _PayslipCard extends StatelessWidget {
  final PayrollModel payroll;
  const _PayslipCard({required this.payroll});

  @override
  Widget build(BuildContext context) {
    final isPaid = payroll.status == 'paid';
    final monthLabel = DateFormat('MMMM yyyy')
        .format(DateTime(payroll.payrollYear, payroll.payrollMonth));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(monthLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, fontFamily: 'Inter')),
              ),
              w.StatusBadge(status: payroll.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _MiniStat(label: 'Present', value: payroll.presentDays.toStringAsFixed(0)),
              _MiniStat(label: 'Absent', value: payroll.absentDays.toStringAsFixed(0)),
              _MiniStat(label: 'Net Wage', value: CurrencyUtils.format(payroll.netWage)),
            ],
          ),
          if (isPaid) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success500),
                const SizedBox(width: 6),
                Text(
                  payroll.paidAt != null
                      ? 'Paid on ${DateFormat('dd MMM yyyy').format(payroll.paidAt!.toLocal())}'
                      : 'Paid',
                  style: const TextStyle(fontSize: 12, color: AppColors.success600),
                ),
              ],
            ),
          ],
        ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'Inter')),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.secondary500)),
        ],
      ),
    );
  }
}
