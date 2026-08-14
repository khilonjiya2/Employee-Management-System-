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
/// SupervisorWalletScreen's "Add Advance" flow (same fields: amount,
/// note, date), but for employees. There is no running wallet balance
/// here (employees don't spend down a balance the way supervisors do via
/// expenses) — this is a payment log viewed one month at a time: pick a
/// month and year to see that month's total and its transactions,
/// defaulting to the current month, so an admin can look back at any
/// past month too.
class EmployeePaymentScreen extends ConsumerStatefulWidget {
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
  ConsumerState<EmployeePaymentScreen> createState() => _EmployeePaymentScreenState();
}

class _EmployeePaymentScreenState extends ConsumerState<EmployeePaymentScreen> {
  late int _month = DateTime.now().month;
  late int _year = DateTime.now().year;

  EmployeeMonthKey get _key =>
      (employeeId: widget.employeeId, month: _month, year: _year);

  void _invalidateAll() {
    ref.invalidate(employeeMonthPaymentsProvider(_key));
    ref.invalidate(employeeMonthlyPaymentSummaryProvider(widget.employeeId));
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isAdmin = profile?.role == 'admin';
    final monthAsync = ref.watch(employeeMonthPaymentsProvider(_key));
    final now = DateTime.now();
    final months = List.generate(12, (i) => i + 1);
    final years = List.generate(5, (i) => now.year - i);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: Row(
          children: [
            GenderAvatar(
              radius: 16,
              photoUrl: widget.employeePhotoUrl,
              gender: widget.employeeGender,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.employeeName ?? 'Payments',
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          if (isAdmin)
            TextButton.icon(
              onPressed: () => _showPayMoney(context),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: const Text('Pay Money'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _invalidateAll();
          await ref.read(employeeMonthPaymentsProvider(_key).future);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Month / year selector — lets the admin look back at any
            // past month, defaulting to the current one.
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _month,
                    decoration: InputDecoration(
                      labelText: 'Month',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: months
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(DateFormat('MMMM').format(DateTime(2000, m))),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _month = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _year,
                    decoration: InputDecoration(
                      labelText: 'Year',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: years
                        .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (v) => setState(() => _year = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Total paid for the SELECTED month.
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
                  Text(
                    'Total Paid — ${DateFormat('MMMM yyyy').format(DateTime(_year, _month))}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  monthAsync.when(
                    loading: () => const SizedBox(
                        height: 28,
                        width: 28,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    error: (_, __) => const Text('—',
                        style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700)),
                    data: (m) => Text(
                      AppUtils.CurrencyUtils.format(m.total),
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('Transactions — ${DateFormat('MMMM yyyy').format(DateTime(_year, _month))}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            monthAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('Could not load payments: $e',
                    style: const TextStyle(color: AppColors.error500)),
              ),
              data: (m) => m.transactions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text('No payments recorded for this month',
                          style: TextStyle(color: AppColors.secondary500)),
                    )
                  : Column(
                      children: m.transactions
                          .map((p) => _PaymentTile(
                                payment: p,
                                canEdit: isAdmin,
                                onEdit: isAdmin ? () => _showEditPayment(context, p) : null,
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPayMoney(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PayMoneySheet(
        employeeId: widget.employeeId,
        employeeName: widget.employeeName,
        initialMonth: _month,
        initialYear: _year,
        onSuccess: (month, year) {
          // Jump the selector to whatever month the payment was actually
          // recorded for, so it's immediately visible.
          setState(() {
            _month = month;
            _year = year;
          });
          _invalidateAll();
        },
      ),
    );
  }

  void _showEditPayment(BuildContext context, EmployeePaymentModel payment) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EditPaymentSheet(
        payment: payment,
        employeeName: widget.employeeName,
        onSuccess: (month, year) {
          setState(() {
            _month = month;
            _year = year;
          });
          _invalidateAll();
        },
      ),
    );
  }
}

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
            child: const Icon(Icons.arrow_downward_rounded, color: AppColors.success600, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(payment.createdAt.toLocal()),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                if (payment.note != null && payment.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(payment.note!,
                      style: const TextStyle(fontSize: 12, color: AppColors.secondary500)),
                ],
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

class _PayMoneySheet extends ConsumerStatefulWidget {
  final String employeeId;
  final String? employeeName;
  final int initialMonth;
  final int initialYear;
  final void Function(int month, int year) onSuccess;
  const _PayMoneySheet({
    required this.employeeId,
    this.employeeName,
    required this.initialMonth,
    required this.initialYear,
    required this.onSuccess,
  });

  @override
  ConsumerState<_PayMoneySheet> createState() => _PayMoneySheetState();
}

class _PayMoneySheetState extends ConsumerState<_PayMoneySheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  late int _paymentMonth = widget.initialMonth;
  late int _paymentYear = widget.initialYear;
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
            note: _noteController.text.trim().isEmpty
                ? 'Payment'
                : _noteController.text.trim(),
            createdBy: profile.id,
            date: _selectedDate,
          );
      widget.onSuccess(_paymentMonth, _paymentYear);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Payment of ${AppUtils.CurrencyUtils.format(amount)} recorded'),
          backgroundColor: AppColors.success500,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppUtils.ErrorUtils.friendly(e)), backgroundColor: AppColors.error500));
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
          Text('Pay Money - ${widget.employeeName ?? ""}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
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
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: const Icon(Icons.note_outlined),
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
                  items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
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
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Pay Money'),
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
  final void Function(int month, int year) onSuccess;
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
  late final _noteController = TextEditingController(text: widget.payment.note ?? '');
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
    _noteController.dispose();
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
            newNote: _noteController.text.trim(),
          );
      widget.onSuccess(_paymentMonth, _paymentYear);
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
            content: Text(AppUtils.ErrorUtils.friendly(e)), backgroundColor: AppColors.error500));
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
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Inter')),
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
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: const Icon(Icons.note_outlined),
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
                  items: years.map((y) => DropdownMenuItem(value: y, child: Text('$y'))).toList(),
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
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}
