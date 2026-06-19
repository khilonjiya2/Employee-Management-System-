import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/app_models.dart'; // already there, just ensure SupervisorPayrollModel is imported

import '../../core/theme/app_theme.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Color? bgColor;
  final String? subtitle;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.bgColor,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor ?? theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.secondary200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  height: 42,
                  width: 42,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 22,
                  ),
                ),
              ],
            ),

            const Spacer(),

            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Inter',
                ),
              ),
            ),

            const SizedBox(height: 6),

            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),

            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.secondary100,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.secondary400, size: 40),
            ),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;

  const LoadingOverlay({super.key, required this.isLoading, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x55000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    switch (status.toLowerCase()) {
      case 'approved':
      case 'active':
      case 'present':
      case 'paid':
        bg = AppColors.success50; fg = AppColors.success700;
        break;
      case 'rejected':
      case 'inactive':
      case 'absent':
        bg = AppColors.error50; fg = AppColors.error600;
        break;
      case 'pending':
      case 'half_day':
      case 'processed':
        bg = AppColors.accent50; fg = AppColors.accent600;
        break;
      case 'leave':
        bg = AppColors.primary50; fg = AppColors.primary700;
        break;
      default:
        bg = AppColors.secondary100; fg = AppColors.secondary600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.replaceAll('_', ' ').toUpperCase(),
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.w700, fontFamily: 'Inter', letterSpacing: 0.5),
      ),
    );
  }
}

class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback? onClear;
  final ValueChanged<String>? onChanged;

  const SearchBar({
    super.key,
    required this.controller,
    required this.hint,
    this.onClear,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: onClear)
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        fillColor: AppColors.secondary50,
      ),
    );
  }
}

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmLabel;
  final Color? confirmColor;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel,
    this.confirmColor,
  });

  static Future<bool?> show(BuildContext context, {
    required String title,
    required String message,
    String? confirmLabel,
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        confirmColor: confirmColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: confirmColor ?? AppColors.error500),
          child: Text(confirmLabel ?? 'Confirm'),
        ),
      ],
    );
  }
}


/// Shared UPI payment flow used by both expense and payroll PAY buttons.
/// Launches the recipient's UPI app via deep link, then asks the admin to
/// confirm whether the payment succeeded and optionally enter a UTR number.
class UpiPaymentHelper {
  UpiPaymentHelper._();

  static Future<void> payExpense(
    BuildContext context,
    WidgetRef ref,
    ExpenseModel expense,
  ) async {
    final client = ref.read(supabaseProvider);
    final sup = await client
        .from('supervisors')
        .select('name, upi_id')
        .eq('id', expense.supervisorId)
        .maybeSingle();

    final upiId = sup?['upi_id'] as String?;
    final name = sup?['name'] as String? ?? expense.supervisorName ?? 'Supervisor';

    if (upiId == null || upiId.trim().isEmpty) {
      if (context.mounted) _showNoUpiDialog(context, name);
      return;
    }

    await _launchAndConfirm(
      context: context,
      ref: ref,
      payeeName: name,
      upiId: upiId,
      amount: expense.amount,
      referenceNote: 'Expense ${expense.expenseName}',
      onConfirmed: (utr) async {
        await ref.read(paymentRepositoryProvider).confirmExpensePayment(
              expense.id,
              utrReference: utr,
            );
        await ref.read(paymentRepositoryProvider).logPayment(
              referenceType: 'expense',
              referenceId: expense.id,
              supervisorId: expense.supervisorId,
              amount: expense.amount,
              upiId: upiId,
              paymentStatus: 'paid',
              utrReference: utr,
            );
      },
    );
  }

  static Future<void> payPayroll(
    BuildContext context,
    WidgetRef ref,
    PayrollModel payroll,
  ) async {
    final client = ref.read(supabaseProvider);
    final emp = await client
        .from('employees')
        .select('name, upi_id')
        .eq('id', payroll.employeeId)
        .maybeSingle();

    final upiId = emp?['upi_id'] as String?;
    final name = emp?['name'] as String? ?? payroll.employeeName ?? 'Employee';

    if (upiId == null || upiId.trim().isEmpty) {
      if (context.mounted) _showNoUpiDialog(context, name);
      return;
    }

    await _launchAndConfirm(
      context: context,
      ref: ref,
      payeeName: name,
      upiId: upiId,
      amount: payroll.netWage,
      referenceNote:
          'Salary ${payroll.payrollMonth}-${payroll.payrollYear}',
      onConfirmed: (utr) async {
        await ref.read(payrollRepositoryProvider).confirmPayment(
              payroll.id,
              utrReference: utr,
            );
        await ref.read(paymentRepositoryProvider).logPayment(
              referenceType: 'payroll',
              referenceId: payroll.id,
              employeeId: payroll.employeeId,
              amount: payroll.netWage,
              upiId: upiId,
              paymentStatus: 'paid',
              utrReference: utr,
            );
      },
    );
  }

static Future<void> paySupervisorSalary(
    BuildContext context,
    WidgetRef ref,
    SupervisorPayrollModel record,
    SupervisorModel supervisor,
  ) async {
    final upiId = supervisor.upiId;
    if (upiId == null || upiId.trim().isEmpty) {
      if (context.mounted) _showNoUpiDialog(context, supervisor.name);
      return;
    }

    await _launchAndConfirm(
      context: context,
      ref: ref,
      payeeName: supervisor.name,
      upiId: upiId,
      amount: record.netAmount,
      referenceNote:
          'Salary ${record.payrollMonth}-${record.payrollYear}',
      onConfirmed: (utr) async {
        await ref
            .read(supervisorPayrollRepositoryProvider)
            .confirmPayment(record.id, utrReference: utr);
        await ref.read(paymentRepositoryProvider).logPayment(
              referenceType: 'expense', // use expense type for supervisor
              referenceId: record.id,
              supervisorId: record.supervisorId,
              amount: record.netAmount,
              upiId: upiId,
              paymentStatus: 'paid',
              utrReference: utr,
              remarks: 'Supervisor salary',
            );
      },
    );
  }

  static void _showNoUpiDialog(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('No UPI ID on file'),
        content: Text(
          '$name does not have a UPI ID saved. Add one in their profile before paying via UPI.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Future<void> _launchAndConfirm({
    required BuildContext context,
    required WidgetRef ref,
    required String payeeName,
    required String upiId,
    required double amount,
    required String referenceNote,
    required Future<void> Function(String? utr) onConfirmed,
  }) async {
    final uri = ref.read(paymentRepositoryProvider).buildUpiUri(
          upiId: upiId,
          payeeName: payeeName,
          amount: amount,
          referenceNote: referenceNote,
        );

    final launched = await launchUrl(
      Uri.parse(uri),
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open a UPI app. Is one installed?'),
            backgroundColor: AppColors.error500,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    // Ask the admin to confirm the payment after returning from the UPI app.
    // The result is delivered via a callback that explicitly closes the
    // dialog using its OWN context (dialogContext), never the outer screen
    // context — this is the same fix pattern used for the Manage Locations
    // bug: relying on an ambient/implicit context for Navigator.pop is
    // fragile and can silently fail to close the correct route.
    String? confirmedUtr;
    bool wasConfirmed = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _PaymentConfirmDialog(
        payeeName: payeeName,
        amount: amount,
        onResult: (confirmed, utr) {
          wasConfirmed = confirmed;
          confirmedUtr = utr;
          Navigator.of(dialogContext).pop();
        },
      ),
    );

    if (!wasConfirmed) return;

    final utr = confirmedUtr?.trim();
    try {
      await onConfirmed(utr == null || utr.isEmpty ? null : utr);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded'),
            backgroundColor: AppColors.success500,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording payment: $e'), backgroundColor: AppColors.error500),
        );
      }
    }
  }
}

class _PaymentConfirmDialog extends StatefulWidget {
  final String payeeName;
  final double amount;
  final void Function(bool confirmed, String? utr) onResult;

  const _PaymentConfirmDialog({
    required this.payeeName,
    required this.amount,
    required this.onResult,
  });

  @override
  State<_PaymentConfirmDialog> createState() => _PaymentConfirmDialogState();
}

class _PaymentConfirmDialogState extends State<_PaymentConfirmDialog> {
  final _utrController = TextEditingController();

  @override
  void dispose() {
    _utrController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirm Payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Did the UPI payment of Rs.${widget.amount.toStringAsFixed(2)} to ${widget.payeeName} go through?'),
          const SizedBox(height: 16),
          TextField(
            controller: _utrController,
            decoration: const InputDecoration(
              labelText: 'UTR / Reference (optional)',
              hintText: 'e.g. 123456789012',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => widget.onResult(false, null),
          child: const Text('Not Yet'),
        ),
        FilledButton(
          onPressed: () => widget.onResult(true, _utrController.text),
          style: FilledButton.styleFrom(backgroundColor: AppColors.success500),
          child: const Text('Yes, Paid'),
        ),
      ],
    );
  }
}