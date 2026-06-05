import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Attendance'),
            Tab(text: 'Expenses'),
            Tab(text: 'Payroll'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AttendanceReport(),
          _ExpenseReport(),
          _PayrollReport(),
        ],
      ),
    );
  }
}

class _AttendanceReport extends ConsumerStatefulWidget {
  const _AttendanceReport();

  @override
  ConsumerState<_AttendanceReport> createState() => _AttendanceReportState();
}

class _AttendanceReportState extends ConsumerState<_AttendanceReport> {
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  List<AttendanceModel> _data = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  Future<void> _load() async {
    setState(() { _isLoading = true; _hasSearched = true; });
    try {
      final data = await ref.read(attendanceRepositoryProvider).getAll(fromDate: _fromDate, toDate: _toDate, limit: 200);
      setState(() => _data = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error500));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportPdf() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Header(level: 0, child: pw.Text('Attendance Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
          pw.Text('Period: ${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}'),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Date', 'Supervisor', 'Location', 'Present', 'Absent', 'Status'],
            data: _data.map((a) {
              final details = a.details ?? [];
              return [
                DateFormat('dd/MM/yyyy').format(a.attendanceDate),
                a.supervisorName ?? '',
                a.locationName ?? '',
                details.where((d) => d.status == 'present').length.toString(),
                details.where((d) => d.status == 'absent').length.toString(),
                a.isApproved ? 'Approved' : 'Pending',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/attendance_report.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], subject: 'Attendance Report');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        if (_isLoading) const LinearProgressIndicator(),
        if (_hasSearched && !_isLoading) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('${_data.length} records', style: Theme.of(context).textTheme.bodySmall),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text('Export PDF'),
                  onPressed: _data.isEmpty ? null : _exportPdf,
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: _hasSearched
              ? _data.isEmpty
                  ? const w.EmptyState(title: 'No records found', icon: Icons.calendar_today_outlined)
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _data.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final a = _data[i];
                        final details = a.details ?? [];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.secondary200),
                          ),
                          child: Row(
                            children: [
                              Text(DateFormat('dd/MM').format(a.attendanceDate), style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(a.supervisorName ?? 'Supervisor', style: Theme.of(context).textTheme.titleSmall),
                                    Text(a.locationName ?? '', style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  _Badge('P', details.where((d) => d.status == 'present').length, AppColors.success500),
                                  const SizedBox(width: 4),
                                  _Badge('A', details.where((d) => d.status == 'absent').length, AppColors.error500),
                                ],
                              ),
                              const SizedBox(width: 8),
                              w.StatusBadge(status: a.isApproved ? 'approved' : 'pending'),
                            ],
                          ),
                        );
                      },
                    )
              : const Center(child: Text('Select filters and load report', style: TextStyle(color: AppColors.secondary400))),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.secondary200))),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: _fromDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                    if (d != null) setState(() => _fromDate = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'From Date', isDense: true),
                    child: Text(DateFormat('dd/MM/yyyy').format(_fromDate), style: const TextStyle(fontSize: 13, fontFamily: 'Inter')),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(context: context, initialDate: _toDate, firstDate: _fromDate, lastDate: DateTime.now());
                    if (d != null) setState(() => _toDate = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'To Date', isDense: true),
                    child: Text(DateFormat('dd/MM/yyyy').format(_toDate), style: const TextStyle(fontSize: 13, fontFamily: 'Inter')),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text('Load Report'),
              onPressed: _load,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseReport extends ConsumerStatefulWidget {
  const _ExpenseReport();

  @override
  ConsumerState<_ExpenseReport> createState() => _ExpenseReportState();
}

class _ExpenseReportState extends ConsumerState<_ExpenseReport> {
  DateTime _fromDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  String? _category;
  List<ExpenseModel> _data = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  Future<void> _load() async {
    setState(() { _isLoading = true; _hasSearched = true; });
    try {
      final data = await ref.read(expenseRepositoryProvider).getAll(category: _category, fromDate: _fromDate, toDate: _toDate, limit: 200);
      setState(() => _data = data);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportPdf() async {
    final totalAmount = _data.fold<double>(0, (s, e) => s + e.amount);
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Header(level: 0, child: pw.Text('Expense Report', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
          pw.Text('Period: ${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}'),
          pw.Text('Total: ₹${totalAmount.toStringAsFixed(2)}'),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Date', 'Name', 'Category', 'Supervisor', 'Amount', 'Status'],
            data: _data.map((e) => [
              DateFormat('dd/MM/yyyy').format(e.expenseDate),
              e.expenseName,
              StringUtils.capitalize(e.category),
              e.supervisorName ?? '',
              '₹${e.amount.toStringAsFixed(2)}',
              e.status.toUpperCase(),
            ]).toList(),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/expense_report.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], subject: 'Expense Report');
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = _data.fold<double>(0, (s, e) => s + e.amount);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.secondary200))),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(context: context, initialDate: _fromDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (d != null) setState(() => _fromDate = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'From', isDense: true),
                        child: Text(DateFormat('dd/MM/yyyy').format(_fromDate), style: const TextStyle(fontSize: 13, fontFamily: 'Inter')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(context: context, initialDate: _toDate, firstDate: _fromDate, lastDate: DateTime.now());
                        if (d != null) setState(() => _toDate = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'To', isDense: true),
                        child: Text(DateFormat('dd/MM/yyyy').format(_toDate), style: const TextStyle(fontSize: 13, fontFamily: 'Inter')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(labelText: 'Category', isDense: true),
                      items: [const DropdownMenuItem(value: null, child: Text('All')),
                        ...['travel','fuel','food','material','labour','miscellaneous']
                            .map((c) => DropdownMenuItem(value: c, child: Text(StringUtils.capitalize(c)))),
                      ],
                      onChanged: (v) => setState(() => _category = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Load Report'),
                onPressed: _load,
              ),
            ],
          ),
        ),
        if (_isLoading) const LinearProgressIndicator(),
        if (_hasSearched && !_isLoading && _data.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('Total: ${CurrencyUtils.format(totalAmount)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary600)),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text('Export PDF'),
                  onPressed: _exportPdf,
                ),
              ],
            ),
          ),
        Expanded(
          child: !_hasSearched
              ? const Center(child: Text('Select filters and load report', style: TextStyle(color: AppColors.secondary400)))
              : _data.isEmpty
                  ? const w.EmptyState(title: 'No expenses found', icon: Icons.receipt_long_outlined)
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _data.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final e = _data[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.secondary200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.expenseName, style: Theme.of(context).textTheme.titleSmall),
                                    Text('${StringUtils.capitalize(e.category)} • ${DateFormat('dd/MM').format(e.expenseDate)}', style: Theme.of(context).textTheme.bodySmall),
                                    if (e.supervisorName != null) Text(e.supervisorName!, style: Theme.of(context).textTheme.labelSmall),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(CurrencyUtils.format(e.amount), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary600)),
                                  w.StatusBadge(status: e.status),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _PayrollReport extends ConsumerStatefulWidget {
  const _PayrollReport();

  @override
  ConsumerState<_PayrollReport> createState() => _PayrollReportState();
}

class _PayrollReportState extends ConsumerState<_PayrollReport> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<PayrollModel> _data = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  Future<void> _load() async {
    setState(() { _isLoading = true; _hasSearched = true; });
    try {
      final data = await ref.read(payrollRepositoryProvider).getByMonthYear(_selectedMonth.month, _selectedMonth.year);
      setState(() => _data = data);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportPdf() async {
    final totalNet = _data.fold<double>(0, (s, p) => s + p.netWage);
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        build: (ctx) => [
          pw.Header(level: 0, child: pw.Text('Payroll Report - ${DateFormat('MMMM yyyy').format(_selectedMonth)}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
          pw.Text('Total Net Wage: ₹${totalNet.toStringAsFixed(2)}'),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Code', 'Name', 'Days', 'Rate', 'Gross', 'Deductions', 'Net', 'Status'],
            data: _data.map((p) => [
              p.employeeCode ?? '',
              p.employeeName ?? '',
              '${p.effectiveDays.toStringAsFixed(1)}',
              '₹${p.dailyWageRate.toStringAsFixed(0)}',
              '₹${p.grossWage.toStringAsFixed(2)}',
              '₹${(p.advanceDeduction + p.penaltyDeduction).toStringAsFixed(2)}',
              '₹${p.netWage.toStringAsFixed(2)}',
              p.status.toUpperCase(),
            ]).toList(),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/payroll_report.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], subject: 'Payroll Report');
  }

  @override
  Widget build(BuildContext context) {
    final totalNet = _data.fold<double>(0, (s, p) => s + p.netWage);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.secondary200))),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left_rounded), onPressed: () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1))),
                  Expanded(child: Text(DateFormat('MMMM yyyy').format(_selectedMonth), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 15))),
                  IconButton(icon: const Icon(Icons.chevron_right_rounded), onPressed: _selectedMonth.isBefore(DateTime(DateTime.now().year, DateTime.now().month)) ? () => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1)) : null),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.search_rounded, size: 18),
                label: const Text('Load Report'),
                onPressed: _load,
              ),
            ],
          ),
        ),
        if (_isLoading) const LinearProgressIndicator(),
        if (_hasSearched && !_isLoading && _data.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('Total: ${CurrencyUtils.format(totalNet)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary600)),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text('Export PDF'),
                  onPressed: _exportPdf,
                ),
              ],
            ),
          ),
        Expanded(
          child: !_hasSearched
              ? const Center(child: Text('Select month and load report', style: TextStyle(color: AppColors.secondary400)))
              : _data.isEmpty
                  ? const w.EmptyState(title: 'No payroll records', icon: Icons.payments_outlined)
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _data.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final p = _data[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.secondary200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(p.employeeName ?? '', style: Theme.of(context).textTheme.titleSmall),
                                    Text('${p.employeeCode} • ${p.effectiveDays.toStringAsFixed(1)} days', style: Theme.of(context).textTheme.bodySmall),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(CurrencyUtils.format(p.netWage), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary600)),
                                  w.StatusBadge(status: p.status),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _Badge(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(4)),
      child: Text('$label:$count', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
    );
  }
}
