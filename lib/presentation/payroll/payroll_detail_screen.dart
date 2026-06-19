import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;

class PayrollDetailScreen extends ConsumerWidget {
  final String id;
  const PayrollDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<PayrollModel?>(
      future: _loadPayroll(ref),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final p = snapshot.data;
        if (p == null) return const Scaffold(body: Center(child: Text('Not found')));

        return Scaffold(
          appBar: AppBar(title: const Text('Payroll Details')),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, p),
                const SizedBox(height: 16),
                _buildAttendanceSummary(context, p),
                const SizedBox(height: 16),
                _buildWageCalculation(context, p),
                const SizedBox(height: 24),
                _buildPaymentSection(context, ref, p),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<PayrollModel?> _loadPayroll(WidgetRef ref) async {
    final client = ref.read(supabaseProvider);
    final data = await client.from('payroll').select('*, employees(name, employee_code)').eq('id', id).maybeSingle();
    if (data == null) return null;
    return PayrollModel.fromJson(data as Map<String, dynamic>);
  }

  Widget _buildHeader(BuildContext context, PayrollModel p) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary600, AppColors.primary400]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.employeeName ?? 'Employee', style: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w600)),
                    Text(p.employeeCode ?? '', style: const TextStyle(color: Color(0xCCFFFFFF), fontFamily: 'Inter', fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(DateFormat('MMMM yyyy').format(DateTime(p.payrollYear, p.payrollMonth)), style: const TextStyle(color: Color(0xBBFFFFFF), fontFamily: 'Inter', fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyUtils.format(p.netWage), style: const TextStyle(color: Colors.white, fontFamily: 'Inter', fontSize: 24, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  w.StatusBadge(status: p.isPaid ? 'paid' : p.status),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceSummary(BuildContext context, PayrollModel p) {
    return _Card(
      title: 'Attendance Summary',
      children: [
        _PayRow(label: 'Present Days', value: '${p.presentDays} days', bold: false),
        _PayRow(label: 'Half Days', value: '${p.halfDays} days', bold: false),
        _PayRow(label: 'Absent Days', value: '${p.absentDays} days', bold: false),
        _PayRow(label: 'Leave Days', value: '${p.leaveDays} days', bold: false),
        const Divider(),
        _PayRow(label: 'Effective Days', value: '${p.effectiveDays.toStringAsFixed(1)} days', bold: true),
        _PayRow(label: 'Daily Wage Rate', value: CurrencyUtils.format(p.dailyWageRate), bold: false),
      ],
    );
  }

  Widget _buildWageCalculation(BuildContext context, PayrollModel p) {
    return _Card(
      title: 'Wage Calculation',
      children: [
        _PayRow(label: 'Basic Wage', value: CurrencyUtils.format(p.effectiveDays * p.dailyWageRate)),
        if (p.overtimeAmount > 0) _PayRow(label: 'Overtime', value: '+ ${CurrencyUtils.format(p.overtimeAmount)}', valueColor: AppColors.success600),
        if (p.bonus > 0) _PayRow(label: 'Bonus', value: '+ ${CurrencyUtils.format(p.bonus)}', valueColor: AppColors.success600),
        if (p.advanceDeduction > 0) _PayRow(label: 'Advance Deduction', value: '- ${CurrencyUtils.format(p.advanceDeduction)}', valueColor: AppColors.error600),
        if (p.penaltyDeduction > 0) _PayRow(label: 'Penalty', value: '- ${CurrencyUtils.format(p.penaltyDeduction)}', valueColor: AppColors.error600),
        const Divider(),
        _PayRow(label: 'Gross Wage', value: CurrencyUtils.format(p.grossWage)),
        _PayRow(label: 'Net Wage', value: CurrencyUtils.format(p.netWage), bold: true, valueColor: AppColors.primary600),
      ],
    );
  }

  Widget _buildPaymentSection(BuildContext context, WidgetRef ref, PayrollModel p) {
  if (p.isPaid) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success100),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: AppColors.success600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              p.utrReference != null
                  ? 'Paid via UPI · UTR: ${p.utrReference}'
                  : 'Marked as Paid',
              style: const TextStyle(
                  color: AppColors.success700,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  final paymentEnabled = ref.watch(paymentModuleEnabledProvider);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (paymentEnabled)
        ElevatedButton.icon(
          icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
          label: Text('Pay ${CurrencyUtils.format(p.netWage)} via UPI'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.success500),
          onPressed: () => w.UpiPaymentHelper.payPayroll(context, ref, p),
        ),
      if (paymentEnabled) const SizedBox(height: 10),
      OutlinedButton.icon(
        icon: const Icon(Icons.done_rounded, size: 18),
        label: const Text('Mark as Paid'),
        onPressed: () => _markAsPaid(context, ref, p),
      ),
    ],
  );
}

Future<void> _markAsPaid(
    BuildContext context, WidgetRef ref, PayrollModel p) async {
  final confirm = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Mark as Paid?'),
        content: Text(
          'Mark ${p.employeeName ?? "employee"}\'s salary of '
          '${CurrencyUtils.format(p.netWage)} as paid?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext, rootNavigator: true).pop(true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.success500),
            child: const Text('Mark Paid'),
          ),
        ],
      ),
    ),
  );

  if (confirm != true || !context.mounted) return;

  try {
    await ref.read(payrollRepositoryProvider).markAsPaid(p.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Marked as paid'),
          backgroundColor: AppColors.success500));
      context.pop();
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error500));
    }
  }
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Card({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Divider(),
          ...children,
        ],
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  const _PayRow({required this.label, required this.value, this.bold = false, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: bold ? Theme.of(context).textTheme.titleMedium : Theme.of(context).textTheme.bodyMedium)),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: bold ? 15 : 14,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color: valueColor ?? Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}