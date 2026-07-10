import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:device_apps/device_apps.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../payroll/payroll_list_screen.dart' show payrollListProvider, supervisorPayrollListProvider;
import '../expenses/expenses_list_screen.dart' show expensesProvider;

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

class _UpiApp {
  final String name;
  final String package;
  const _UpiApp(this.name, this.package);
}

const _kUpiApps = [
  _UpiApp('Google Pay', 'com.google.android.apps.nbu.paisa.user'),
  _UpiApp('PhonePe', 'com.phonepe.app'),
  _UpiApp('Paytm', 'net.one97.paytm'),
  _UpiApp('BHIM', 'in.org.npci.upiapp'),
  _UpiApp('Amazon Pay', 'in.amazon.mShop.android.shopping'),
  _UpiApp('CRED', 'com.dreamplug.androidapp'),
  _UpiApp('WhatsApp', 'com.whatsapp'),
  _UpiApp('iMobile Pay', 'com.csam.icici.bank.imobile'),
  _UpiApp('SBI Pay', 'com.sbi.upi'),
];

/// Shared UPI payment flow used by both expense and payroll PAY buttons.
/// Launches the recipient's UPI app via deep link, then asks the admin to
/// confirm whether the payment succeeded and optionally enter a UTR number.
class UpiPaymentHelper {
  UpiPaymentHelper._();

  // ---------------------------------------------------------------------------
  // Cashfree Payouts: server-side payment initiation via edge function.
  // Used when payment_module_enabled = true in the company's settings.
  // Requires a valid payout PIN to be set and verified before proceeding.
  // ---------------------------------------------------------------------------

  static Future<void> payViaCashfree({
    required BuildContext context,
    required WidgetRef ref,
    required String referenceType, // 'payroll', 'expense', or 'supervisor_payroll'
    required String referenceId,
    required String payeeName,
    required double amount,
  }) async {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null) return;

    // ── PIN gate ──────────────────────────────────────────────────────────
    final client = ref.read(supabaseProvider);
    final companyId = profile.companyId;
    if (companyId == null) return;

    // Check if PIN is set
    final companyRow = await client
        .from('companies')
        .select('payout_pin_hash')
        .eq('id', companyId)
        .maybeSingle();

    final storedHash = companyRow?['payout_pin_hash'] as String?;

    if (!context.mounted) return;

    if (storedHash == null || storedHash.trim().isEmpty) {
      // No PIN set — prompt to create one in settings
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Payout PIN Required'),
          content: const Text(
            'You must set a 4-digit payout PIN before initiating payments.\n\nGo to Settings → Payout PIN to create one.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // PIN is set — ask user to enter it
    if (!context.mounted) return;
    final pinVerified = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => PinVerifySheet(storedHash: storedHash, companyId: companyId),
    );

    if (pinVerified != true) return;
    if (!context.mounted) return;
    // ── PIN verified — proceed to payment ────────────────────────────────

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CashfreePaymentSheet(
        ref: ref,
        referenceType: referenceType,
        referenceId: referenceId,
        payeeName: payeeName,
        amount: amount,
        callerProfileId: profile.id,
      ),
    );
  }

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

    if (!context.mounted) return;
    if (upiId == null || upiId.trim().isEmpty) {
      _showNoUpiDialog(context, name);
      return;
    }

    await _launchAndConfirm(
      context: context,
      ref: ref,
      payeeName: name,
      upiId: upiId,
      amount: expense.amount,
      referenceNote: 'Expense ${expense.expenseName}',
      transactionRef: _makeTransactionRef('EXP', expense.id),
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

    if (!context.mounted) return;
    if (upiId == null || upiId.trim().isEmpty) {
      _showNoUpiDialog(context, name);
      return;
    }

    await _launchAndConfirm(
      context: context,
      ref: ref,
      payeeName: name,
      upiId: upiId,
      amount: payroll.netWage,
      referenceNote: 'Salary ${payroll.payrollMonth}-${payroll.payrollYear}',
      transactionRef: _makeTransactionRef('PAY', payroll.id),
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
    if (!context.mounted) return;
    if (upiId == null || upiId.trim().isEmpty) {
      _showNoUpiDialog(context, supervisor.name);
      return;
    }

    await _launchAndConfirm(
      context: context,
      ref: ref,
      payeeName: supervisor.name,
      upiId: upiId,
      amount: record.netAmount,
      referenceNote: 'Salary ${record.payrollMonth}-${record.payrollYear}',
      transactionRef: _makeTransactionRef('SUP', record.id),
      onConfirmed: (utr) async {
        await ref
            .read(supervisorPayrollRepositoryProvider)
            .confirmPayment(record.id, utrReference: utr);
        await ref.read(paymentRepositoryProvider).logPayment(
              referenceType: 'expense',
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
      builder: (ctx) => AlertDialog(
        title: const Text('No UPI ID on file'),
        content: Text(
          '$name does not have a UPI ID saved. Add one in their profile before paying via UPI.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Future<String?> _pickUpiApp(BuildContext context, List<_UpiApp> apps) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Pay with', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            ...apps.map((a) => ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text(a.name),
                  onTap: () => Navigator.pop(ctx, a.package),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

static Future<bool> _launchExplicit(String uri, String packageName) async {
    try {
      final intent = AndroidIntent(
        action: 'action_view',
        data: uri,
        package: packageName,
      );
      await intent.launch();
      return true;
    } catch (_) {
      return false;
    }
  }

  // Builds the UPI `tr` (transaction reference) parameter. Per NPCI's
  // UPI deep-linking spec this should be a unique, alphanumeric
  // reference per transaction attempt. We learned the hard way that
  // OMITTING it causes GPay/PhonePe/Paytm to treat the deep link as an
  // unrecognized/unverified request and apply much stricter fraud/risk
  // checks \u{2014} which is exactly what was producing vague "limit
  // exceeded"/"risk policy" rejections regardless of the amount, even
  // for \u{20B9}1. Using the actual record id keeps it unique AND makes it
  // traceable back to the specific expense/payroll record if you ever
  // need to reconcile a UTR against it.
  static String _makeTransactionRef(String prefix, String recordId) {
    final sanitizedId =
        recordId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
    final ref = '$prefix$sanitizedId';
    // NPCI recommends keeping tr <= 35 chars.
    return ref.length > 35 ? ref.substring(0, 35) : ref;
  }

  

  static Future<void> _launchAndConfirm({
    required BuildContext context,
    required WidgetRef ref,
    required String payeeName,
    required String upiId,
    required double amount,
    required String referenceNote,
    required String transactionRef,
    required Future<void> Function(String? utr) onConfirmed,
  }) async {
    final uri = ref.read(paymentRepositoryProvider).buildUpiUri(
          upiId: upiId,
          payeeName: payeeName,
          amount: amount,
          referenceNote: referenceNote,
          transactionRef: transactionRef,
        );

    if (Uri.tryParse(uri) == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This UPI ID looks invalid. Please check it and try again.'),
            backgroundColor: AppColors.error500,
          ),
        );
      }
      return;
    }

    // IMPORTANT: we detect installed apps by package name and launch via
    // an EXPLICIT intent (package set directly), instead of letting
    // Android resolve an implicit upi:// intent. This fixes the MIUI
    // ("GetApps"/Mi Store) hijack on Android 10 \u{2014} MIUI's resolver
    // intercepts ambiguous ACTION_VIEW+BROWSABLE intents before they
    // reach the real UPI app, but an explicit-package intent bypasses
    // that resolver entirely since there's nothing for it to disambiguate.
    final installed = <_UpiApp>[];
    for (final app in _kUpiApps) {
      try {
        if (await DeviceApps.isAppInstalled(app.package)) installed.add(app);
      } catch (_) {}
    }

    if (installed.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No UPI app found on this device. Install GPay, PhonePe, or Paytm to pay directly, or use "Mark Paid" after paying manually.'),
            backgroundColor: AppColors.error500,
          ),
        );
      }
      return;
    }

    String? chosenPackage;
    if (installed.length == 1) {
      chosenPackage = installed.first.package;
    } else {
      if (!context.mounted) return;
      chosenPackage = await _pickUpiApp(context, installed);
      if (chosenPackage == null) return;
    }

    final launched = await _launchExplicit(uri, chosenPackage);

    if (!launched) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open the selected app. Please try again or use "Mark Paid" after paying manually.'),
            backgroundColor: AppColors.error500,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    // Small delay so UPI app has time to open before we show the dialog
    await Future.delayed(const Duration(milliseconds: 500));

    if (!context.mounted) return;

    bool wasConfirmed = false;
    String? confirmedUtr;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,  // MUST not close on outside tap
      useRootNavigator: true,     // Use root navigator to avoid shell route issues
      builder: (dialogContext) => PopScope(
        canPop: false,            // Prevent back button dismissal
        child: _PaymentConfirmDialog(
          payeeName: payeeName,
          amount: amount,
          onResult: (confirmed, utr) {
            wasConfirmed = confirmed;
            confirmedUtr = utr;
            Navigator.of(dialogContext, rootNavigator: true).pop();
          },
        ),
      ),
    );

    if (!wasConfirmed) return;
    if (!context.mounted) return;

    final utr = confirmedUtr?.trim();
    try {
      await onConfirmed(utr == null || utr.isEmpty ? null : utr);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment recorded successfully'),
            backgroundColor: AppColors.success500,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error recording payment: $e'),
              backgroundColor: AppColors.error500),
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
          Text(
            'Did the UPI payment of \u{20B9}${widget.amount.toStringAsFixed(2)} to ${widget.payeeName} go through?',
          ),
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

// =============================================================================
// CASHFREE PAYMENT SHEET
// Shows payment details, initiates payout via edge function, then uses
// Supabase Realtime to watch the record for automatic status update.
// =============================================================================

class _CashfreePaymentSheet extends StatefulWidget {
  final WidgetRef ref;
  final String referenceType;
  final String referenceId;
  final String payeeName;
  final double amount;
  final String callerProfileId;

  const _CashfreePaymentSheet({
    required this.ref,
    required this.referenceType,
    required this.referenceId,
    required this.payeeName,
    required this.amount,
    required this.callerProfileId,
  });

  @override
  State<_CashfreePaymentSheet> createState() => _CashfreePaymentSheetState();
}

class _CashfreePaymentSheetState extends State<_CashfreePaymentSheet> {
  _PayState _state = _PayState.idle;
  String? _errorMessage;
  String? _utr;
  StreamSubscription<List<Map<String, dynamic>>>? _realtimeSub;
  Timer? _timeoutTimer;

  @override
  void dispose() {
    _realtimeSub?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.secondary300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Payment summary card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary200),
            ),
            child: Column(
              children: [
                Row(children: [
                  const Icon(Icons.payments_rounded, color: AppColors.primary500),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pay ${CurrencyUtils.format(widget.amount)}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800,
                          fontFamily: 'Inter', color: AppColors.primary600),
                    ),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(children: [
                  const SizedBox(width: 34),
                  Text(
                    'To: ${widget.payeeName}',
                    style: const TextStyle(color: AppColors.secondary600),
                  ),
                ]),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // State-based UI
          if (_state == _PayState.idle) ...[
            const Text(
              'Payment will be sent directly to their bank account or UPI ID via Cashfree Payouts. You will be notified automatically when it completes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondary500, fontSize: 13),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.send_rounded),
                label: const Text('Confirm & Pay Now'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.success500,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _initiatePayout,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],

          if (_state == _PayState.processing) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Initiating payment...', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'Please wait. Do not close this screen.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondary500, fontSize: 12),
            ),
          ],

          if (_state == _PayState.waiting) ...[
            const CircularProgressIndicator(color: AppColors.accent500),
            const SizedBox(height: 16),
            const Text('Payment initiated!', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text(
              'Waiting for bank confirmation via Cashfree...\nThis usually takes a few seconds to a few minutes.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondary500, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close (payment continues in background)'),
            ),
          ],

          if (_state == _PayState.success) ...[
            const Icon(Icons.check_circle_rounded, size: 64, color: AppColors.success500),
            const SizedBox(height: 12),
            const Text('Payment Successful!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.success600)),
            if (_utr != null) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('UTR: $_utr',
                      style: const TextStyle(fontSize: 13, color: AppColors.secondary600)),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    onPressed: () => Clipboard.setData(ClipboardData(text: _utr!)),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(backgroundColor: AppColors.success500),
              child: const Text('Done'),
            ),
          ],

          if (_state == _PayState.failed) ...[
            const Icon(Icons.error_rounded, size: 64, color: AppColors.error500),
            const SizedBox(height: 12),
            const Text('Payment Failed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.error600)),
            if (_errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(_errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.secondary600)),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => setState(() {
                      _state = _PayState.idle;
                      _errorMessage = null;
                    }),
                    child: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _initiatePayout() async {
    setState(() => _state = _PayState.processing);

    try {
      // Call the Supabase edge function
      final response = await widget.ref
          .read(supabaseProvider)
          .functions
          .invoke('initiate-payout', body: {
        'reference_type': widget.referenceType,
        'reference_id': widget.referenceId,
        'caller_profile_id': widget.callerProfileId,
      });

      final data = response.data as Map<String, dynamic>?;

      if (data == null || data['success'] != true) {
        throw Exception(data?['error'] ?? 'Payment initiation failed');
      }

      // Payment initiated \u{2014} now listen for the webhook result via Realtime
      if (!mounted) return;
      setState(() => _state = _PayState.waiting);
      _listenForResult();

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _PayState.failed;
        _errorMessage = ErrorUtils.friendly(e);
      });
    }
  }

  void _listenForResult() {
    _realtimeSub?.cancel();
    _timeoutTimer?.cancel();

    final String table;
    if (widget.referenceType == 'payroll') {
      table = 'payroll';
    } else if (widget.referenceType == 'supervisor_payroll') {
      table = 'supervisor_payroll';
    } else {
      table = 'expenses';
    }

    final client = widget.ref.read(supabaseProvider);

    // Poll every 5 seconds as a fallback in case Realtime misses the update
    _pollForStatus(client, table);

    // 3-minute timeout: if Cashfree webhook hasn't arrived, stop waiting
    _timeoutTimer = Timer(const Duration(minutes: 3), () {
      if (!mounted) return;
      if (_state == _PayState.waiting) {
        _realtimeSub?.cancel();
        setState(() {
          _state = _PayState.failed;
          _errorMessage =
              'Payment status is still pending after 3 minutes. Check your Cashfree dashboard and manually mark as paid if the transfer succeeded.';
        });
      }
    });

    _realtimeSub = client
        .from(table)
        .stream(primaryKey: ['id'])
        .eq('id', widget.referenceId)
        .listen((rows) {
          if (!mounted) return;
          if (rows.isEmpty) return;
          _handleStatusRow(rows.first);
        });
  }

  // Poll the DB directly every 5s — covers the case where Realtime is not
  // enabled or the webhook fires before the stream subscription is ready.
  void _pollForStatus(dynamic client, String table) {
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!mounted || _state != _PayState.waiting) {
        timer.cancel();
        return;
      }
      try {
        final row = await client
            .from(table)
            .select('payment_status, utr_reference')
            .eq('id', widget.referenceId)
            .single();
        if (!mounted) { timer.cancel(); return; }
        final status = row['payment_status'] as String?;
        if (status == 'paid' || status == 'failed') {
          timer.cancel();
          _realtimeSub?.cancel();
          _timeoutTimer?.cancel();
          _handleStatusRow(row as Map<String, dynamic>);
        }
      } catch (_) { /* ignore poll errors */ }
    });
  }

  void _handleStatusRow(Map<String, dynamic> row) {
    final status = row['payment_status'] as String?;
    final utr = row['utr_reference'] as String?;

    if (status == 'paid') {
      _realtimeSub?.cancel();
      _timeoutTimer?.cancel();
      if (widget.referenceType == 'payroll') {
        widget.ref.invalidate(payrollListProvider);
      } else if (widget.referenceType == 'supervisor_payroll') {
        widget.ref.invalidate(supervisorPayrollListProvider);
      } else {
        widget.ref.invalidate(expensesProvider);
      }
      setState(() {
        _state = _PayState.success;
        _utr = utr;
      });
    } else if (status == 'failed') {
      _realtimeSub?.cancel();
      _timeoutTimer?.cancel();
      setState(() {
        _state = _PayState.failed;
        _errorMessage =
            'Cashfree could not complete the payment. The amount will be reversed if debited. Please check the bank details and retry.';
      });
    }
  }
}

enum _PayState { idle, processing, waiting, success, failed }

// =============================================================================
// PIN UTILITIES
// Pins are stored as SHA-256(pin + ':' + companyId) so they are per-company.
// The raw PIN never leaves the device after hashing.
// =============================================================================

String _hashPin(String pin, String companyId) {
  final bytes = utf8.encode('$pin:$companyId');
  return sha256.convert(bytes).toString();
}

// =============================================================================
// PIN ENTRY SHEET — shown before every Cashfree payout
// =============================================================================
class PinVerifySheet extends ConsumerStatefulWidget {
  final String storedHash;
  final String companyId;
  const PinVerifySheet({super.key, required this.storedHash, required this.companyId});

  @override
  ConsumerState<PinVerifySheet> createState() => _PinVerifySheetState();
}

class _PinVerifySheetState extends ConsumerState<PinVerifySheet> {
  final List<String> _digits = [];
  bool _wrong = false;
  int _attempts = 0;

  void _onDigit(String d) {
    if (_digits.length >= 4) return;
    setState(() {
      _digits.add(d);
      _wrong = false;
    });
    if (_digits.length == 4) _verify();
  }

  void _onDelete() {
    if (_digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  void _verify() {
    final entered = _digits.join();
    final hash = _hashPin(entered, widget.companyId);
    if (hash == widget.storedHash) {
      Navigator.of(context).pop(true);
    } else {
      _attempts++;
      setState(() {
        _digits.clear();
        _wrong = true;
      });
      if (_attempts >= 5) {
        Navigator.of(context).pop(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppColors.secondary300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Icon(Icons.lock_rounded, size: 36, color: AppColors.primary500),
          const SizedBox(height: 12),
          const Text(
            'Enter Payout PIN',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'Inter'),
          ),
          const SizedBox(height: 6),
          Text(
            _wrong ? 'Incorrect PIN. Try again.' : 'Enter your 4-digit security PIN to proceed',
            style: TextStyle(
              color: _wrong ? AppColors.error500 : AppColors.secondary500,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // PIN dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 16, height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < _digits.length
                    ? AppColors.primary500
                    : AppColors.secondary200,
                border: _wrong ? Border.all(color: AppColors.error500) : null,
              ),
            )),
          ),
          const SizedBox(height: 28),
          // Numpad
          ...[ ['1','2','3'], ['4','5','6'], ['7','8','9'], ['','0','⌫'] ].map((row) =>
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((k) {
                  if (k == '') return const SizedBox(width: 80, height: 56);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: SizedBox(
                      width: 80, height: 56,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          side: const BorderSide(color: AppColors.secondary200),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: k == '⌫' ? _onDelete : () => _onDigit(k),
                        child: Text(
                          k,
                          style: TextStyle(
                            fontSize: k == '⌫' ? 20 : 22,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Inter',
                            color: AppColors.secondary800,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PIN SETUP SHEET — used in Settings to create or change the payout PIN
// =============================================================================

class PinSetupSheet extends ConsumerStatefulWidget {
  /// If non-null, user must first confirm the old PIN before setting a new one.
  final String? existingHash;
  final String companyId;

  const PinSetupSheet({
    super.key,
    required this.companyId,
    this.existingHash,
  });

  @override
  ConsumerState<PinSetupSheet> createState() => _PinSetupSheetState();
}

class _PinSetupSheetState extends ConsumerState<PinSetupSheet> {
  // Steps: 'verify_old' | 'enter_new' | 'confirm_new'
  String _step = 'enter_new';
  final List<String> _digits = [];
  List<String> _firstPin = [];
  bool _wrong = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _step = widget.existingHash != null ? 'verify_old' : 'enter_new';
  }

  String get _title {
    switch (_step) {
      case 'verify_old': return 'Confirm Current PIN';
      case 'enter_new': return widget.existingHash != null ? 'Enter New PIN' : 'Create Payout PIN';
      case 'confirm_new': return 'Confirm New PIN';
      default: return '';
    }
  }

  String get _subtitle {
    switch (_step) {
      case 'verify_old': return 'Enter your current 4-digit PIN to continue';
      case 'enter_new': return 'Choose a 4-digit PIN for authorising payouts';
      case 'confirm_new': return 'Enter the PIN again to confirm';
      default: return '';
    }
  }

  void _onDigit(String d) {
    if (_digits.length >= 4) return;
    setState(() {
      _digits.add(d);
      _wrong = false;
    });
    if (_digits.length == 4) _handleFull();
  }

  void _onDelete() {
    if (_digits.isEmpty) return;
    setState(() => _digits.removeLast());
  }

  void _handleFull() async {
    final entered = _digits.join();

    if (_step == 'verify_old') {
      final hash = _hashPin(entered, widget.companyId);
      if (hash == widget.existingHash) {
        setState(() { _digits.clear(); _step = 'enter_new'; _wrong = false; });
      } else {
        setState(() { _digits.clear(); _wrong = true; });
      }
      return;
    }

    if (_step == 'enter_new') {
      _firstPin = List.from(_digits);
      setState(() { _digits.clear(); _step = 'confirm_new'; _wrong = false; });
      return;
    }

    if (_step == 'confirm_new') {
      if (entered == _firstPin.join()) {
        await _save(entered);
      } else {
        setState(() { _digits.clear(); _firstPin.clear(); _step = 'enter_new'; _wrong = true; });
      }
    }
  }

  Future<void> _save(String pin) async {
    setState(() => _saving = true);
    try {
      final hash = _hashPin(pin, widget.companyId);
      await ref.read(supabaseProvider)
          .from('companies')
          .update({'payout_pin_hash': hash})
          .eq('id', widget.companyId);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() { _saving = false; _digits.clear(); _step = 'enter_new'; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PIN: $e'), backgroundColor: AppColors.error500),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AppColors.secondary300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          Icon(
            widget.existingHash != null ? Icons.lock_reset_rounded : Icons.lock_outline_rounded,
            size: 36, color: AppColors.primary500,
          ),
          const SizedBox(height: 12),
          Text(_title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
          const SizedBox(height: 6),
          Text(
            _wrong
                ? (_step == 'verify_old' ? 'Incorrect current PIN.' : 'PINs do not match. Try again.')
                : _subtitle,
            style: TextStyle(
              color: _wrong ? AppColors.error500 : AppColors.secondary500,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (_saving) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Saving PIN...'),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16, height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _digits.length ? AppColors.primary500 : AppColors.secondary200,
                  border: _wrong ? Border.all(color: AppColors.error500) : null,
                ),
              )),
            ),
            const SizedBox(height: 28),
            ...[ ['1','2','3'], ['4','5','6'], ['7','8','9'], ['','0','⌫'] ].map((row) =>
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: row.map((k) {
                    if (k == '') return const SizedBox(width: 80, height: 56);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: SizedBox(
                        width: 80, height: 56,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: AppColors.secondary200),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: k == '⌫' ? _onDelete : () => _onDigit(k),
                          child: Text(k,
                            style: TextStyle(
                              fontSize: k == '⌫' ? 20 : 22,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Inter',
                              color: AppColors.secondary800,
                            )),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (!_saving)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// CashfreePayButton \u{2014} drop-in widget used in both PayrollCardWithPay and
// ExpenseListScreen. Shows a single "Pay" button when payment module is
// enabled, otherwise falls back to the existing Mark as Paid flow.
// =============================================================================

class CashfreePayButton extends ConsumerWidget {
  final String referenceType; // 'payroll' or 'expense'
  final String referenceId;
  final String payeeName;
  final double amount;
  final String currentPaymentStatus; // 'unpaid', 'initiated', 'paid', 'failed'
  final VoidCallback onMarkPaid; // fallback for when module is off

  const CashfreePayButton({
    super.key,
    required this.referenceType,
    required this.referenceId,
    required this.payeeName,
    required this.amount,
    required this.currentPaymentStatus,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentEnabled = ref.watch(paymentModuleEnabledProvider);

    if (currentPaymentStatus == 'paid') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.success50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.success300),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success500),
            SizedBox(width: 6),
            Text('Paid', style: TextStyle(color: AppColors.success600, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (currentPaymentStatus == 'initiated') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accent50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.accent300),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent600),
            ),
            SizedBox(width: 6),
            Text('Processing...', style: TextStyle(color: AppColors.accent700, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      );
    }

    if (paymentEnabled) {
      return ElevatedButton.icon(
        icon: const Icon(Icons.send_rounded, size: 16),
        label: Text('Pay ${CurrencyUtils.format(amount)}'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success500,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: () => UpiPaymentHelper.payViaCashfree(
          context: context,
          ref: ref,
          referenceType: referenceType,
          referenceId: referenceId,
          payeeName: payeeName,
          amount: amount,
        ),
      );
    }

    // Fallback: Mark as Paid manually
    return OutlinedButton.icon(
      icon: const Icon(Icons.check_rounded, size: 16),
      label: const Text('Mark as Paid'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary600,
        side: const BorderSide(color: AppColors.primary400),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onMarkPaid,
    );
  }
}
// =============================================================================
// GENDER AVATAR — shows uploaded photo if present, otherwise a polished
// gender-based avatar. See _GenderAvatarImpl below for full details.
// =============================================================================

// Rule (applies uniformly across the whole app):
//   1) If a photo has been uploaded -> ALWAYS show the photo.
//   2) Otherwise, if a gender is on file -> show a male/female/other
//      illustrated avatar.
//   3) Otherwise (no gender on file) -> show the person's initials instead
//      of guessing a gender. Admins with no gender on file keep the
//      dedicated admin badge.
//
// The photo path is also crash-proof: a broken/expired/offline image URL
// will gracefully fall back to the gender/initials avatar instead of
// showing a broken-image glyph or throwing.
// gender: 'male' | 'female' | 'other' | null
class GenderAvatar extends StatelessWidget {
  final double radius;
  final String? photoUrl;
  final String? gender;
  final String? name;
  final bool isAdmin;

  const GenderAvatar({
    super.key,
    this.radius = 24,
    this.photoUrl,
    this.gender,
    this.name,
    this.isAdmin = false,
  });

  Widget _fallbackAvatar() {
    switch (gender) {
      case 'female':
        return _CorporateFemaleAvatar(radius: radius);
      case 'other':
        return _CorporateNeutralAvatar(radius: radius);
      case 'male':
        return _CorporateMaleAvatar(radius: radius);
      default:
        // No gender on file. Admins get a dedicated badge; everyone else
        // gets their initials rather than a guessed-at gender avatar.
        if (isAdmin) {
          return _CorporateBadgeAvatar(radius: radius);
        }
        return _InitialsAvatar(radius: radius, name: name);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Photo always takes priority when present. Rendering is wrapped in a
    // resilient loader so a broken/expired/offline URL never crashes the
    // screen or leaves a blank/broken circle — it just falls back to the
    // gender avatar below.
    if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      return _ResilientPhotoAvatar(
        radius: radius,
        photoUrl: photoUrl!,
        fallbackBuilder: _fallbackAvatar,
      );
    }

    return _fallbackAvatar();
  }
}

/// Shows a network photo inside a circle. If the image fails to load (bad
/// URL, deleted file, offline, timeout) it seamlessly swaps to the
/// gender-based fallback instead of an error glyph or a crash.
class _ResilientPhotoAvatar extends StatelessWidget {
  final double radius;
  final String photoUrl;
  final Widget Function() fallbackBuilder;

  const _ResilientPhotoAvatar({
    required this.radius,
    required this.photoUrl,
    required this.fallbackBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    return ClipOval(
      child: Image.network(
        photoUrl,
        key: ValueKey(photoUrl),
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Smooth fade-in once loaded instead of a jarring pop-in.
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: child,
          );
        },
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                fallbackBuilder(),
                SizedBox(
                  width: size * 0.4,
                  height: size * 0.4,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          );
        },
        // Never let a broken/expired/offline image crash the widget tree —
        // fall back to the gender avatar instead.
        errorBuilder: (context, error, stack) => fallbackBuilder(),
      ),
    );
  }
}

/// Shared flat pale-circle wrapper so every generated avatar
/// (male/female/neutral/admin) matches the soft, flat illustrated-portrait
/// style used elsewhere in the product, instead of a shiny gradient chip.
class _AvatarShell extends StatelessWidget {
  final double radius;
  final Color backgroundColor;
  final CustomPainter painter;

  const _AvatarShell({
    required this.radius,
    required this.backgroundColor,
    required this.painter,
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: size * 0.10,
            offset: Offset(0, size * 0.02),
          ),
        ],
      ),
      child: ClipOval(
        child: CustomPaint(
          size: Size(size, size),
          painter: painter,
        ),
      ),
    );
  }
}

// Soft, muted backdrop used behind every illustrated portrait — matches the
// pale blue-grey circle in the reference avatar art rather than a bright
// gradient chip.
const _avatarBackground = Color(0xFFDCE3F0);

class _CorporateMaleAvatar extends StatelessWidget {
  final double radius;
  const _CorporateMaleAvatar({required this.radius});

  @override
  Widget build(BuildContext context) {
    return _AvatarShell(
      radius: radius,
      backgroundColor: _avatarBackground,
      painter: _PersonAvatarPainter(style: _AvatarHairStyle.shortMale),
    );
  }
}

class _CorporateFemaleAvatar extends StatelessWidget {
  final double radius;
  const _CorporateFemaleAvatar({required this.radius});

  @override
  Widget build(BuildContext context) {
    return _AvatarShell(
      radius: radius,
      backgroundColor: _avatarBackground,
      painter: _PersonAvatarPainter(style: _AvatarHairStyle.longFemale),
    );
  }
}

class _CorporateNeutralAvatar extends StatelessWidget {
  final double radius;
  const _CorporateNeutralAvatar({required this.radius});

  @override
  Widget build(BuildContext context) {
    return _AvatarShell(
      radius: radius,
      backgroundColor: _avatarBackground,
      painter: _PersonAvatarPainter(style: _AvatarHairStyle.neutral),
    );
  }
}

class _CorporateBadgeAvatar extends StatelessWidget {
  final double radius;
  const _CorporateBadgeAvatar({required this.radius});

  @override
  Widget build(BuildContext context) {
    return _AvatarShell(
      radius: radius,
      backgroundColor: const Color(0xFF334155),
      painter: _PersonAvatarPainter(style: _AvatarHairStyle.admin),
    );
  }
}

/// Shown when no gender is on file (and the person isn't an admin): the
/// person's initials on a deterministic, pleasant flat colour — never a
/// guessed-at male/female illustration.
class _InitialsAvatar extends StatelessWidget {
  final double radius;
  final String? name;

  const _InitialsAvatar({required this.radius, this.name});

  static const _palette = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF0EA5A4),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
    Color(0xFF16A34A),
    Color(0xFF4F46E5),
    Color(0xFF0891B2),
  ];

  String _initials(String n) {
    final parts = n.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) {
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) {
      // No name available either — fall back to a plain person glyph
      // rather than showing empty/blank initials.
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: _avatarBackground,
        ),
        child: Icon(Icons.person_rounded, size: size * 0.55, color: const Color(0xFF64748B)),
      );
    }
    final color = _palette[trimmed.toLowerCase().codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
    final initials = _initials(trimmed);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

enum _AvatarHairStyle { shortMale, longFemale, neutral, admin }

/// A single, carefully-proportioned vector person silhouette used for every
/// avatar variant. Coordinates are all expressed as fractions of the circle
/// radius `r` around the true center `(cx, cy)`, so it scales cleanly at any
/// size from a 16px list icon to a 60px profile header.
class _PersonAvatarPainter extends CustomPainter {
  final _AvatarHairStyle style;
  _PersonAvatarPainter({required this.style});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Clothing colour follows the reference art: a muted plum top for the
    // female avatar, a deep teal-blue crew neck for the male avatar, and a
    // soft slate for the neutral avatar — all fully opaque.
    final Color clothingColor;
    switch (style) {
      case _AvatarHairStyle.longFemale:
        clothingColor = const Color(0xFF7C6389);
        break;
      case _AvatarHairStyle.shortMale:
        clothingColor = const Color(0xFF35617D);
        break;
      case _AvatarHairStyle.neutral:
        clothingColor = const Color(0xFF5B6B7C);
        break;
      case _AvatarHairStyle.admin:
        clothingColor = const Color(0xFFE2E8F0);
        break;
    }
    final clothing = Paint()
      ..color = clothingColor
      ..isAntiAlias = true;
    // The face itself uses a warm, neutral skin tone rather than flat white
    // so it reads as an actual illustrated face (with features) instead of
    // a plain pale oval/"egg".
    final faceSkin = Paint()
      ..color = const Color(0xFFF2C29B)
      ..isAntiAlias = true;
    // Hair is a solid, fully-opaque dark navy — previously this was a
    // near-white translucent fill, which is what made every avatar read as
    // a pale, featureless "ghost" instead of a proper illustrated portrait.
    final hairDark = Paint()
      ..color = const Color(0xFF2B2A3D)
      ..isAntiAlias = true;
    // Warm brown used for brows/eyes/mouth so the face reads as friendly and
    // human rather than a blank shape.
    const featureColor = Color(0xFF6B4A3A);

    final headCenter = Offset(cx, cy - r * 0.18);
    final headRadius = r * 0.32;

    // ---- Long hair (female): back layer flows past the shoulders ----
    if (style == _AvatarHairStyle.longFemale) {
      final backHair = Path()
        ..moveTo(cx - r * 0.50, cy + r * 0.05)
        ..cubicTo(
          cx - r * 0.58, cy + r * 0.30,
          cx - r * 0.46, cy + r * 0.78,
          cx - r * 0.30, cy + r * 0.95,
        )
        ..lineTo(cx - r * 0.14, cy + r * 0.95)
        ..cubicTo(
          cx - r * 0.24, cy + r * 0.55,
          cx - r * 0.30, cy + r * 0.10,
          cx - r * 0.22, cy - r * 0.12,
        )
        ..cubicTo(
          cx - r * 0.10, cy - r * 0.34,
          cx + r * 0.10, cy - r * 0.34,
          cx + r * 0.22, cy - r * 0.12,
        )
        ..cubicTo(
          cx + r * 0.30, cy + r * 0.10,
          cx + r * 0.24, cy + r * 0.55,
          cx + r * 0.14, cy + r * 0.95,
        )
        ..lineTo(cx + r * 0.30, cy + r * 0.95)
        ..cubicTo(
          cx + r * 0.46, cy + r * 0.78,
          cx + r * 0.58, cy + r * 0.30,
          cx + r * 0.50, cy + r * 0.05,
        )
        ..cubicTo(
          cx + r * 0.42, cy - r * 0.42,
          cx - r * 0.42, cy - r * 0.42,
          cx - r * 0.50, cy + r * 0.05,
        )
        ..close();
      canvas.drawPath(backHair, hairDark);
    }

    // ---- Shoulders / torso (clothing) ----
    final bodyPath = Path();
    switch (style) {
      case _AvatarHairStyle.longFemale:
        bodyPath
          ..moveTo(cx - r * 0.46, r * 1.02)
          ..cubicTo(cx - r * 0.44, cy + r * 0.30, cx - r * 0.30, cy + r * 0.14,
              cx - r * 0.19, cy + r * 0.06)
          ..cubicTo(cx - r * 0.08, cy - r * 0.02, cx + r * 0.08, cy - r * 0.02,
              cx + r * 0.19, cy + r * 0.06)
          ..cubicTo(cx + r * 0.30, cy + r * 0.14, cx + r * 0.44, cy + r * 0.30,
              cx + r * 0.46, r * 1.02)
          ..close();
        break;
      case _AvatarHairStyle.admin:
        bodyPath
          ..moveTo(cx - r * 0.48, r * 1.02)
          ..cubicTo(cx - r * 0.46, cy + r * 0.26, cx - r * 0.30, cy + r * 0.10,
              cx - r * 0.20, cy + r * 0.02)
          ..lineTo(cx, cy + r * 0.16)
          ..lineTo(cx + r * 0.20, cy + r * 0.02)
          ..cubicTo(cx + r * 0.30, cy + r * 0.10, cx + r * 0.46, cy + r * 0.26,
              cx + r * 0.48, r * 1.02)
          ..close();
        break;
      case _AvatarHairStyle.shortMale:
      case _AvatarHairStyle.neutral:
        bodyPath
          ..moveTo(cx - r * 0.47, r * 1.02)
          ..cubicTo(cx - r * 0.45, cy + r * 0.28, cx - r * 0.28, cy + r * 0.10,
              cx - r * 0.16, cy + r * 0.00)
          ..lineTo(cx, cy + r * 0.14)
          ..lineTo(cx + r * 0.16, cy + r * 0.00)
          ..cubicTo(cx + r * 0.28, cy + r * 0.10, cx + r * 0.45, cy + r * 0.28,
              cx + r * 0.47, r * 1.02)
          ..close();
        break;
    }
    canvas.drawPath(bodyPath, clothing);

    // ---- Necktie for admin (subtle authority cue) ----
    if (style == _AvatarHairStyle.admin) {
      final tie = Path()
        ..moveTo(cx - r * 0.05, cy + r * 0.08)
        ..lineTo(cx + r * 0.05, cy + r * 0.08)
        ..lineTo(cx + r * 0.035, cy + r * 0.34)
        ..lineTo(cx, cy + r * 0.44)
        ..lineTo(cx - r * 0.035, cy + r * 0.34)
        ..close();
      canvas.drawPath(tie, Paint()..color = const Color(0xFF334155).withOpacity(0.85));
    }

    // ---- Head ----
    canvas.drawCircle(headCenter, headRadius, faceSkin);
    // Soft chin/jaw shading for a touch of dimensionality.
    canvas.drawArc(
      Rect.fromCircle(center: headCenter, radius: headRadius),
      0.35,
      2.4,
      false,
      Paint()
        ..color = Colors.black.withOpacity(0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = headRadius * 0.14,
    );

    // ---- Face: eyebrows, eyes, nose, smiling mouth ----
    // Coordinates are relative to headCenter/headRadius so they scale with
    // the head regardless of overall avatar size. Proportions below follow
    // normal human facial spacing (eyes roughly at mid-head height, spaced
    // about one eye-width apart, small irises rather than big filled dots)
    // so the result reads as a calm human face rather than a wide-eyed/
    // "bug-like" caricature.
    final eyeY = headCenter.dy - headRadius * 0.02;
    final eyeDx = headRadius * 0.30;
    final eyeWidth = headRadius * 0.20;
    final eyeHeight = headRadius * 0.13;

    // Eyebrows: short, thin, calm — sit clearly above (not touching) the
    // eyes so they don't visually merge into one shape.
    final browPaint = Paint()
      ..color = featureColor.withOpacity(0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = headRadius * 0.05
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawLine(
      Offset(headCenter.dx - eyeDx - eyeWidth * 0.55, eyeY - headRadius * 0.32),
      Offset(headCenter.dx - eyeDx + eyeWidth * 0.55, eyeY - headRadius * 0.36),
      browPaint,
    );
    canvas.drawLine(
      Offset(headCenter.dx + eyeDx - eyeWidth * 0.55, eyeY - headRadius * 0.36),
      Offset(headCenter.dx + eyeDx + eyeWidth * 0.55, eyeY - headRadius * 0.32),
      browPaint,
    );

    // Eyes: white almond shape with a centered dark iris + tiny highlight,
    // instead of one solid dark dot — this alone is most of the difference
    // between "human face" and "insect eyes".
    final eyeWhite = Paint()..color = Colors.white..isAntiAlias = true;
    final eyeOutline = Paint()
      ..color = featureColor.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = headRadius * 0.025
      ..isAntiAlias = true;
    final irisPaint = Paint()..color = const Color(0xFF3E2B22)..isAntiAlias = true;
    final highlightPaint = Paint()..color = Colors.white..isAntiAlias = true;

    for (final dx in [-eyeDx, eyeDx]) {
      final center = Offset(headCenter.dx + dx, eyeY);
      final eyeRect = Rect.fromCenter(center: center, width: eyeWidth, height: eyeHeight);
      canvas.drawOval(eyeRect, eyeWhite);
      canvas.drawOval(eyeRect, eyeOutline);
      canvas.drawCircle(center, eyeHeight * 0.42, irisPaint);
      canvas.drawCircle(
        Offset(center.dx + eyeHeight * 0.12, center.dy - eyeHeight * 0.12),
        eyeHeight * 0.12,
        highlightPaint,
      );
    }

    // Nose: a single soft short stroke, kept subtle.
    final nosePaint = Paint()
      ..color = Colors.black.withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = headRadius * 0.05
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    canvas.drawLine(
      Offset(headCenter.dx, eyeY + headRadius * 0.14),
      Offset(headCenter.dx + headRadius * 0.05, eyeY + headRadius * 0.34),
      nosePaint,
    );

    // Mouth: a gentle, closed-lip smile — a single shallow curve rather
    // than a thick wide arc, which reads as a natural friendly expression.
    final mouthPaint = Paint()
      ..color = featureColor.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = headRadius * 0.07
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final mouthPath = Path()
      ..moveTo(headCenter.dx - headRadius * 0.24, headCenter.dy + headRadius * 0.52)
      ..quadraticBezierTo(
        headCenter.dx,
        headCenter.dy + headRadius * 0.66,
        headCenter.dx + headRadius * 0.24,
        headCenter.dy + headRadius * 0.52,
      );
    canvas.drawPath(mouthPath, mouthPaint);

    // Faint cheek blush for warmth (kept very subtle so it stays corporate,
    // not cartoonish).
    final blush = Paint()
      ..color = const Color(0xFFE8896B).withOpacity(0.14)
      ..isAntiAlias = true;
    canvas.drawCircle(
        Offset(headCenter.dx - headRadius * 0.58, headCenter.dy + headRadius * 0.30),
        headRadius * 0.14, blush);
    canvas.drawCircle(
        Offset(headCenter.dx + headRadius * 0.58, headCenter.dy + headRadius * 0.30),
        headRadius * 0.14, blush);

    // ---- Hair on top of head, per style ----
    switch (style) {
      case _AvatarHairStyle.shortMale:
        final cap = Path()
          ..moveTo(headCenter.dx - headRadius * 0.98, headCenter.dy - headRadius * 0.05)
          ..cubicTo(
            headCenter.dx - headRadius * 1.05, headCenter.dy - headRadius * 0.95,
            headCenter.dx - headRadius * 0.35, headCenter.dy - headRadius * 1.35,
            headCenter.dx, headCenter.dy - headRadius * 1.28,
          )
          ..cubicTo(
            headCenter.dx + headRadius * 0.35, headCenter.dy - headRadius * 1.35,
            headCenter.dx + headRadius * 1.05, headCenter.dy - headRadius * 0.95,
            headCenter.dx + headRadius * 0.98, headCenter.dy - headRadius * 0.05,
          )
          ..cubicTo(
            headCenter.dx + headRadius * 0.6, headCenter.dy - headRadius * 0.55,
            headCenter.dx - headRadius * 0.6, headCenter.dy - headRadius * 0.55,
            headCenter.dx - headRadius * 0.98, headCenter.dy - headRadius * 0.05,
          )
          ..close();
        canvas.drawPath(cap, hairDark);
        break;
      case _AvatarHairStyle.neutral:
        // Medium, chin-length androgynous hairstyle.
        final cap = Path()
          ..moveTo(headCenter.dx - headRadius * 1.05, headCenter.dy + headRadius * 0.55)
          ..cubicTo(
            headCenter.dx - headRadius * 1.18, headCenter.dy - headRadius * 0.25,
            headCenter.dx - headRadius * 0.55, headCenter.dy - headRadius * 1.32,
            headCenter.dx, headCenter.dy - headRadius * 1.25,
          )
          ..cubicTo(
            headCenter.dx + headRadius * 0.55, headCenter.dy - headRadius * 1.32,
            headCenter.dx + headRadius * 1.18, headCenter.dy - headRadius * 0.25,
            headCenter.dx + headRadius * 1.05, headCenter.dy + headRadius * 0.55,
          )
          ..cubicTo(
            headCenter.dx + headRadius * 0.85, headCenter.dy + headRadius * 0.15,
            headCenter.dx + headRadius * 0.7, headCenter.dy - headRadius * 0.5,
            headCenter.dx, headCenter.dy - headRadius * 0.55,
          )
          ..cubicTo(
            headCenter.dx - headRadius * 0.7, headCenter.dy - headRadius * 0.5,
            headCenter.dx - headRadius * 0.85, headCenter.dy + headRadius * 0.15,
            headCenter.dx - headRadius * 1.05, headCenter.dy + headRadius * 0.55,
          )
          ..close();
        canvas.drawPath(cap, hairDark);
        break;
      case _AvatarHairStyle.longFemale:
        // Face-framing top hair with a soft side part, plus two strands
        // that sweep down past the jaw toward the shoulders (drawn above
        // the blouse, in front of the long back-hair layer already painted).
        final topHair = Path()
          ..moveTo(headCenter.dx - headRadius * 1.02, headCenter.dy + headRadius * 0.35)
          ..cubicTo(
            headCenter.dx - headRadius * 1.15, headCenter.dy - headRadius * 0.55,
            headCenter.dx - headRadius * 0.5, headCenter.dy - headRadius * 1.38,
            headCenter.dx + headRadius * 0.1, headCenter.dy - headRadius * 1.30,
          )
          ..cubicTo(
            headCenter.dx + headRadius * 0.65, headCenter.dy - headRadius * 1.24,
            headCenter.dx + headRadius * 1.12, headCenter.dy - headRadius * 0.6,
            headCenter.dx + headRadius * 1.0, headCenter.dy + headRadius * 0.30,
          )
          ..cubicTo(
            headCenter.dx + headRadius * 0.8, headCenter.dy - headRadius * 0.05,
            headCenter.dx + headRadius * 0.6, headCenter.dy - headRadius * 0.55,
            headCenter.dx + headRadius * 0.12, headCenter.dy - headRadius * 0.62,
          )
          ..cubicTo(
            headCenter.dx - headRadius * 0.45, headCenter.dy - headRadius * 0.68,
            headCenter.dx - headRadius * 0.78, headCenter.dy - headRadius * 0.2,
            headCenter.dx - headRadius * 1.02, headCenter.dy + headRadius * 0.35,
          )
          ..close();
        canvas.drawPath(topHair, hairDark);

        // Left face-framing strand.
        final leftStrand = Path()
          ..moveTo(headCenter.dx - headRadius * 1.0, headCenter.dy + headRadius * 0.25)
          ..cubicTo(
            headCenter.dx - headRadius * 1.12, headCenter.dy + headRadius * 0.95,
            headCenter.dx - headRadius * 0.92, cy + r * 0.62,
            headCenter.dx - headRadius * 0.72, cy + r * 0.66,
          )
          ..cubicTo(
            headCenter.dx - headRadius * 0.88, cy + r * 0.30,
            headCenter.dx - headRadius * 0.86, headCenter.dy + headRadius * 0.55,
            headCenter.dx - headRadius * 0.78, headCenter.dy + headRadius * 0.15,
          )
          ..close();
        canvas.drawPath(leftStrand, hairDark);

        // Right face-framing strand (mirrored).
        final rightStrand = Path()
          ..moveTo(headCenter.dx + headRadius * 1.0, headCenter.dy + headRadius * 0.25)
          ..cubicTo(
            headCenter.dx + headRadius * 1.12, headCenter.dy + headRadius * 0.95,
            headCenter.dx + headRadius * 0.92, cy + r * 0.62,
            headCenter.dx + headRadius * 0.72, cy + r * 0.66,
          )
          ..cubicTo(
            headCenter.dx + headRadius * 0.88, cy + r * 0.30,
            headCenter.dx + headRadius * 0.86, headCenter.dy + headRadius * 0.55,
            headCenter.dx + headRadius * 0.78, headCenter.dy + headRadius * 0.15,
          )
          ..close();
        canvas.drawPath(rightStrand, hairDark);
        break;
      case _AvatarHairStyle.admin:
        canvas.drawArc(
          Rect.fromCircle(center: headCenter, radius: headRadius * 1.02),
          3.05,
          3.35,
          true,
          hairDark,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _PersonAvatarPainter oldDelegate) =>
      oldDelegate.style != style;
}
