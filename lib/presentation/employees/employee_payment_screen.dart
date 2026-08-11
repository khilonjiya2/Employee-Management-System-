import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart' as AppUtils;
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' show GenderAvatar;

/// Admin-only screen for paying an employee directly and keeping a full,
/// editable payment history — the direct parallel to
/// SupervisorWalletScreen's "Add Advance" flow, but for employees. There
/// is no running wallet balance here (employees don't spend down a
/// balance the way supervisors do via expenses) — this is a payment log
/// with a monthly rollup: "amount paid and the month paid, till date."
class EmployeePaymentScreen extends ConsumerWidget {
  final String employeeId;
  final String? employeeName;
  final String? employeeGender;
  final String? employeePhotoUrl;

  const EmployeePaymentScreen({
    super.key,
    required this.employeeId,
    this.employeeName,
    this.employeeGender,
    this.employeePhotoUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.role == 'admin';
    final totalPaidAsync = ref.watch(_employeeTotalPaidProvider(employeeId));
    final monthlyAsync = ref.watch(employeeMonthlyPaymentSummaryProvider(employeeId));
    final paymentsAsync = ref.watch(employeePaymentsProvider(employeeId));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Row(
          children: [
            GenderAvatar(
              radius: 16,
              photoUrl: employeePhotoUrl,
              gender: employeeGender,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(employeeName ?? 'Payments',
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          if (isAdmin)
            TextButton.icon(
              onPressed: () => _showAddPayment(context, ref),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Add Payment'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_employeeTotalPaidProvider(employeeId));
          ref.invalidate(employeeMonthlyPaymentSummaryProvider(employeeId));
          ref.invalidate(employeePaymentsProvider(employeeId));
          await ref.read(employeePaymentsProvider(employeeId).future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Total paid, all-time — the headline summary card.
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary700, AppColors.primary400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Paid (Till Date)',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  totalPaidAsync.when(
                    loading: () => const SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white)),
                    error: (_, __) => const Text('—',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w700)),
                    data: (total) => Text(
                      AppUtils.CurrencyUtils.format(total),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Monthly breakdown — "amount and the month paid, till date".
            const Text('Monthly Summary',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            monthlyAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Could not load monthly summary: $e',
                    style: const TextStyle(color: AppColors.error500)),
              ),
              data: (months) => months.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No payments recorded yet',
                          style: TextStyle(color: AppColors.secondary500)),
                    )
                  : Column(
                      children: months
                          .map((m) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border:
                                      Border.all(color: AppColors.secondary100),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('MMMM yyyy').format(
                                          DateTime(m.year, m.month)),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      AppUtils.CurrencyUtils
                                          .format(m.totalAmount),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.success600),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 24),

            const Text('Transaction History',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            paymentsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Could not load payments: $e',
                    style: const TextStyle(color: AppColors.error500)),
              ),
              data: (payments) => payments.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No payments recorded yet',
                          style: TextStyle(color: AppColors.secondary500)),
                    )
                  : Column(
                      children: payments
                          .map((p) => _PaymentTile(
                                payment: p,
                                canEdit: isAdmin,
                                onEdit: isAdmin
                                    ? () => _showEditPayment(context, ref, p)
                                    : null,
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPayment(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddPaymentSheet(
        employeeId: employeeId,
        employeeName: employeeName,
        onSuccess: () => _invalidateAll(ref),
      ),
    );
  }

  void _showEditPayment(
      BuildContext context, WidgetRef ref, EmployeePaymentModel payment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditPaymentSheet(
        payment: payment,
        employeeName: employeeName,
        onSuccess: () => _invalidateAll(ref),
      ),
    );
  }

  void _invalidateAll(WidgetRef ref) {
    ref.invalidate(_employeeTotalPaidProvider(employeeId));
    ref.invalidate(employeeMonthlyPaymentSummaryProvider(employeeId));
    ref.invalidate(employeePaymentsProvider(employeeId));
  }
}

final _employeeTotalPaidProvider =
    FutureProvider.autoDispose.family<double, String>((ref, employeeId) async {
  return ref.read(employeePaymentRepositoryProvider).getTotalPaid(employeeId);
});

class _PaymentTile extends StatelessWidget {
  final EmployeePaymentModel payment;
  final bool canEdit;
  final VoidCallback? onEdit;

  const _PaymentTile({required this.payment, required this.canEdit, this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary100),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.success50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_downward_rounded,
                color: AppColors.success600, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'For ${DateFormat('MMMM yyyy').format(DateTime(payment.paymentYear, payment.paymentMonth))}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  'Paid on ${DateFormat('dd MMM yyyy').format(payment.createdAt.toLocal())}'
                  '${payment.note != null && payment.note!.isNotEmpty ? " · ${payment.note}" : ""}',
                  style: const TextStyle(fontSize: 12, color: AppColors.secondary500),
                ),
              ],
            ),
          ),
          Text(
            AppUtils.CurrencyUtils.format(payment.amount),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          if (canEdit) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Edit',
              onPressed: onEdit,
            ),
          ],
        ],
      ),
    );
  }
}

class _AddPaymentSheet extends ConsumerStatefulWidget {
  final String employeeId;
  final String? employeeName;
  final VoidCallback onSuccess;
  const _AddPaymentSheet({
    required this.employeeId,
    this.employeeName,
    required this.onSuccess,
  });

  @override
  ConsumerState<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends ConsumerState<_AddPaymentSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  late int _paymentMonth = DateTime.now().month;
  late int _paymentYear = DateTime.now().year;
  bool _loading = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      // No future dates — payments can only be dated up to today.
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null) return;

    setState(() => _loading = true);
    try {
      await ref.read(employeePaymentRepositoryProvider).givePayment(
            employeeId: widget.employeeId,
            amount: amount,
            month: _paymentMonth,
            year: _paymentYear,
            note: _noteController.text.trim(),
            createdBy: profile.id,
            date: _selectedDate,
          );
      widget.onSuccess();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Payment of ${AppUtils.CurrencyUtils.format(amount)} recorded'),
          backgroundColor: AppColors.success500,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppUtils.ErrorUtils.friendly(e)),
            backgroundColor: AppColors.error500));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = List.generate(12, (i) => i + 1);
    final years = List.generate(5, (i) => now.year - i);

    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Payment - ${widget.employeeName ?? ""}',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Amount *',
              prefixIcon: const Icon(Icons.currency_rupee_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _paymentMonth,
                  decoration: InputDecoration(
                    labelText: 'For Month',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: months
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(DateFormat('MMMM').format(DateTime(2000, m))),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _paymentMonth = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _paymentYear,
                  decoration: InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: years
                      .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (v) => setState(() => _paymentYear = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: const Icon(Icons.note_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date Paid *',
                prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Record Payment'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditPaymentSheet extends ConsumerStatefulWidget {
  final EmployeePaymentModel payment;
  final String? employeeName;
  final VoidCallback onSuccess;
  const _EditPaymentSheet({
    required this.payment,
    this.employeeName,
    required this.onSuccess,
  });

  @override
  ConsumerState<_EditPaymentSheet> createState() => _EditPaymentSheetState();
}

class _EditPaymentSheetState extends ConsumerState<_EditPaymentSheet> {
  late final _amountController =
      TextEditingController(text: widget.payment.amount.toStringAsFixed(0));
  late DateTime _selectedDate = widget.payment.createdAt.toLocal();
  late int _paymentMonth = widget.payment.paymentMonth;
  late int _paymentYear = widget.payment.paymentYear;
  bool _loading = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newAmount = double.tryParse(_amountController.text.trim());
    if (newAmount == null || newAmount < 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(employeePaymentRepositoryProvider).editPayment(
            paymentId: widget.payment.id,
            newAmount: newAmount,
            newDate: _selectedDate,
            newMonth: _paymentMonth,
            newYear: _paymentYear,
          );
      widget.onSuccess();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Payment updated'),
          backgroundColor: AppColors.success500,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppUtils.ErrorUtils.friendly(e)),
            backgroundColor: AppColors.error500));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = List.generate(12, (i) => i + 1);
    final years = List.generate(5, (i) => now.year - i);

    return Padding(
      padding: EdgeInsets.only(
          left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit Payment - ${widget.employeeName ?? ""}',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'New Amount *',
              prefixIcon: const Icon(Icons.currency_rupee_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _paymentMonth,
                  decoration: InputDecoration(
                    labelText: 'For Month',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: months
                      .map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(DateFormat('MMMM').format(DateTime(2000, m))),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _paymentMonth = v!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _paymentYear,
                  decoration: InputDecoration(
                    labelText: 'Year',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: years
                      .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
                  onChanged: (v) => setState(() => _paymentYear = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Date Paid *',
                prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(DateFormat('dd MMM yyyy').format(_selectedDate)),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}
