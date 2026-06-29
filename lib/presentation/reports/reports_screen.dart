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

class _ReportsScreenState extends ConsumerState<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _isAdmin = ref.read(currentUserRoleProvider) == 'admin';
    _tabController = TabController(length: _isAdmin ? 3 : 2, vsync: this);
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
          tabs: [
            const Tab(text: 'Attendance'),
            const Tab(text: 'Expenses'),
            if (_isAdmin) const Tab(text: 'Payroll'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _AttendanceReport(),
          const _ExpenseReport(),
          if (_isAdmin) const _PayrollReport(),
        ],
      ),
    );
  }
}

// \u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500} ATTENDANCE REPORT \u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}

class _AttendanceReport extends ConsumerStatefulWidget {
  const _AttendanceReport();

  @override
  ConsumerState<_AttendanceReport> createState() => _AttendanceReportState();
}

class _AttendanceReportState extends ConsumerState<_AttendanceReport> {
  DateTime _fromDate =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  List<AttendanceModel> _data = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _dateError;

  bool _validateRange() {
    final diff = _toDate.difference(_fromDate).inDays;
    if (diff > 31) {
      setState(() => _dateError = 'Maximum range is 31 days');
      return false;
    }
    if (_toDate.isBefore(_fromDate)) {
      setState(() => _dateError = 'To date must be after From date');
      return false;
    }
    setState(() => _dateError = null);
    return true;
  }

  Future<void> _load() async {
    if (!_validateRange()) return;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });
    try {
      final profile = ref.read(currentProfileProvider).valueOrNull;
      final isSupervisor = profile?.role == 'supervisor';

      List<String>? supervisorEmployeeIds;
      if (isSupervisor) {
        // Get supervisor's own ID
        final client = ref.read(supabaseProvider);
        final sup = await client.from('supervisors').select('id').eq('profile_id', profile!.id).maybeSingle();
        if (sup != null) {
          final rows = await client.from('supervisor_employees').select('employee_id').eq('supervisor_id', sup['id']);
          supervisorEmployeeIds = (rows as List).map((r) => r['employee_id'] as String).toList();
        }
      }

      final data = await ref.read(attendanceRepositoryProvider).getAll(
            fromDate: _fromDate,
            toDate: _toDate,
            limit: 500,
          );

      // Filter to supervisor's employees only if supervisor role
      final filtered = supervisorEmployeeIds != null
          ? data.where((att) {
              att.details?.retainWhere((d) => supervisorEmployeeIds!.contains(d.employeeId));
              return att.details?.isNotEmpty == true;
            }).toList()
          : data;

      setState(() => _data = filtered);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error: $e'),
              backgroundColor: AppColors.error500),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Build summary: employee \u{2192} {present, absent, total}
  Map<String, Map<String, dynamic>> _buildEmployeeSummary() {
    final Map<String, Map<String, dynamic>> summary = {};
    for (final att in _data) {
      for (final d in att.details ?? []) {
        final key = d.employeeId;
        summary.putIfAbsent(key, () => {
              'name': d.employeeName ?? '',
              'code': d.employeeCode ?? '',
              'present': 0,
              'absent': 0,
              'supervisor': att.supervisorName ?? '',
            });
        if (d.status == 'present') {
          summary[key]!['present'] = (summary[key]!['present'] as int) + 1;
        } else {
          summary[key]!['absent'] = (summary[key]!['absent'] as int) + 1;
        }
      }
    }
    return summary;
  }

  Future<void> _sharePdf() async {
    final pdf = pw.Document();
    final summary = _buildEmployeeSummary();
    final totalPresent = summary.values
        .fold<int>(0, (s, e) => s + (e['present'] as int));
    final totalAbsent = summary.values
        .fold<int>(0, (s, e) => s + (e['absent'] as int));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text('Attendance Report',
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Text(
              'Period: ${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}'),
          pw.Text('Total Records: ${_data.length}'),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            pw.Text('Total Present: $totalPresent  ',
                style: pw.TextStyle(
                    color: PdfColors.green700,
                    fontWeight: pw.FontWeight.bold)),
            pw.Text('Total Absent: $totalAbsent',
                style: pw.TextStyle(
                    color: PdfColors.red700,
                    fontWeight: pw.FontWeight.bold)),
          ]),
          pw.SizedBox(height: 16),
          pw.Text('Employee-wise Summary',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: [
              'Code',
              'Employee Name',
              'Supervisor',
              'Days Present',
              'Days Absent',
              'Total Days'
            ],
            data: summary.values.map((e) {
              final total = (e['present'] as int) + (e['absent'] as int);
              return [
                e['code'],
                e['name'],
                e['supervisor'],
                '${e['present']}',
                '${e['absent']}',
                '$total',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.blue100),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Daily Attendance Log',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: [
              'Date',
              'Supervisor',
              'Location',
              'Present',
              'Absent',
              'Total',
              'Status'
            ],
            data: _data.map((a) {
              final details = a.details ?? [];
              final p = details.where((d) => d.status == 'present').length;
              final ab = details.where((d) => d.status == 'absent').length;
              return [
                DateFormat('dd/MM/yyyy').format(a.attendanceDate),
                a.supervisorName ?? '',
                a.locationName ?? '',
                '$p',
                '$ab',
                '${details.length}',
                a.isApproved ? 'Approved' : 'Pending',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.blue50),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/attendance_report.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)],
        subject: 'Attendance Report');
  }

  @override
  Widget build(BuildContext context) {
    final summary = _hasSearched ? _buildEmployeeSummary() : {};
    final totalPresent = summary.values
        .fold<int>(0, (s, e) => s + (e['present'] as int? ?? 0));
    final totalAbsent = summary.values
        .fold<int>(0, (s, e) => s + (e['absent'] as int? ?? 0));

    return Column(
      children: [
        _buildDateFilter(),
        if (_isLoading) const LinearProgressIndicator(),
        if (_hasSearched && !_isLoading && _data.isNotEmpty) ...[
          // Summary bar
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.primary50,
            child: Row(
              children: [
                _SummaryChip('Records', _data.length, AppColors.primary500),
                const SizedBox(width: 8),
                _SummaryChip('Present', totalPresent, AppColors.success500),
                const SizedBox(width: 8),
                _SummaryChip('Absent', totalAbsent, AppColors.error500),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.share_rounded,
                      color: AppColors.primary500),
                  tooltip: 'Share PDF',
                  onPressed: _sharePdf,
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: !_hasSearched
              ? const Center(
                  child: Text('Select date range and load report',
                      style: TextStyle(color: AppColors.secondary400)))
              : _data.isEmpty
                  ? const w.EmptyState(
                      title: 'No records found',
                      icon: Icons.calendar_today_outlined)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Employee summary section
                        Text('Employee Summary',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ...summary.values.map((e) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: AppColors.secondary200),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primary100,
                                    child: Text(
                                      (e['name'] as String).isNotEmpty
                                          ? (e['name'] as String)[0]
                                              .toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                          color: AppColors.primary600,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          fontFamily: 'Inter'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(e['name'] as String,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall),
                                        Text(
                                            '${e['code']} \u{2022} ${e['supervisor']}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        'P: ${e['present']}  A: ${e['absent']}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            fontFamily: 'Inter',
                                            color: Color(0xFF1A1A2E)),
                                      ),
                                      Text(
                                        'Total: ${(e['present'] as int) + (e['absent'] as int)} days',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )),
                        const SizedBox(height: 16),
                        Text('Daily Log',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        ..._data.map((a) {
                          final details = a.details ?? [];
                          final p = details
                              .where((d) => d.status == 'present')
                              .length;
                          final ab = details
                              .where((d) => d.status == 'absent')
                              .length;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.secondary200),
                            ),
                            child: Row(
                              children: [
                                Text(
                                    DateFormat('dd/MM')
                                        .format(a.attendanceDate),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          a.supervisorName ?? 'Supervisor',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall),
                                      Text(a.locationName ?? '',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall),
                                    ],
                                  ),
                                ),
                                Text('P:$p A:$ab',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Inter')),
                                const SizedBox(width: 8),
                                w.StatusBadge(
                                    status: a.isApproved
                                        ? 'approved'
                                        : 'pending'),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildDateFilter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
          border: Border(
              bottom: BorderSide(color: AppColors.secondary200))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                        context: context,
                        initialDate: _fromDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now());
                    if (d != null) setState(() => _fromDate = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'From Date', isDense: true),
                    child: Text(DateFormat('dd/MM/yyyy').format(_fromDate),
                        style: const TextStyle(
                            fontSize: 13, fontFamily: 'Inter')),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                        context: context,
                        initialDate: _toDate,
                        firstDate: _fromDate,
                        lastDate: DateTime.now());
                    if (d != null) setState(() => _toDate = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                        labelText: 'To Date', isDense: true),
                    child: Text(DateFormat('dd/MM/yyyy').format(_toDate),
                        style: const TextStyle(
                            fontSize: 13, fontFamily: 'Inter')),
                  ),
                ),
              ),
            ],
          ),
          if (_dateError != null) ...[
            const SizedBox(height: 6),
            Text(_dateError!,
                style: const TextStyle(
                    color: AppColors.error500, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.bar_chart_rounded, size: 18),
              label: const Text('Generate Report'),
              onPressed: _load,
            ),
          ),
        ],
      ),
    );
  }
}

// \u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500} EXPENSE REPORT \u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}

class _ExpenseReport extends ConsumerStatefulWidget {
  const _ExpenseReport();

  @override
  ConsumerState<_ExpenseReport> createState() => _ExpenseReportState();
}

class _ExpenseReportState extends ConsumerState<_ExpenseReport> {
  DateTime _fromDate =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _toDate = DateTime.now();
  String? _category;
  String? _status;
  List<ExpenseModel> _data = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _dateError;

  bool _validateRange() {
    final diff = _toDate.difference(_fromDate).inDays;
    if (diff > 31) {
      setState(() => _dateError = 'Maximum range is 31 days');
      return false;
    }
    setState(() => _dateError = null);
    return true;
  }

  Future<void> _load() async {
    if (!_validateRange()) return;
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });
    try {
      final profile = ref.read(currentProfileProvider).valueOrNull;
      final isSupervisor = profile?.role == 'supervisor';
      String? mySupervisorId;
      if (isSupervisor) {
        final client = ref.read(supabaseProvider);
        final sup = await client.from('supervisors').select('id').eq('profile_id', profile!.id).maybeSingle();
        mySupervisorId = sup?['id'] as String?;
      }

      final data = await ref.read(expenseRepositoryProvider).getAll(
            category: _category,
            status: _status,
            fromDate: _fromDate,
            toDate: _toDate,
            limit: 500,
          );

      setState(() => _data = mySupervisorId != null
          ? data.where((e) => e.supervisorId == mySupervisorId).toList()
          : data);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Map<String, Map<String, dynamic>> _buildSupervisorSummary() {
    final Map<String, Map<String, dynamic>> summary = {};
    for (final e in _data) {
      final key = e.supervisorId;
      summary.putIfAbsent(key, () => {
            'name': e.supervisorName ?? 'Unknown',
            'total': 0.0,
            'pending': 0.0,
            'approved': 0.0,
            'rejected': 0.0,
            'count': 0,
          });
      summary[key]!['total'] =
          (summary[key]!['total'] as double) + e.amount;
      summary[key]!['count'] = (summary[key]!['count'] as int) + 1;
      summary[key]![e.status] =
          (summary[key]![e.status] as double? ?? 0.0) + e.amount;
    }
    return summary;
  }

  Future<void> _sharePdf() async {
    final totalAmount = _data.fold<double>(0, (s, e) => s + e.amount);
    final approvedAmount = _data
        .where((e) => e.status == 'approved')
        .fold<double>(0, (s, e) => s + e.amount);
    final pendingAmount = _data
        .where((e) => e.status == 'pending')
        .fold<double>(0, (s, e) => s + e.amount);

    final supervisorSummary = _buildSupervisorSummary();
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text('Expense Report',
                style: pw.TextStyle(
                    fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Text(
              'Period: ${DateFormat('dd/MM/yyyy').format(_fromDate)} - ${DateFormat('dd/MM/yyyy').format(_toDate)}'),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            pw.Text('Total: Rs.${totalAmount.toStringAsFixed(2)}  ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text(
                'Approved: Rs.${approvedAmount.toStringAsFixed(2)}  ',
                style: pw.TextStyle(color: PdfColors.green700)),
            pw.Text('Pending: Rs.${pendingAmount.toStringAsFixed(2)}',
                style: pw.TextStyle(color: PdfColors.orange700)),
          ]),
          pw.SizedBox(height: 16),
          pw.Text('Supervisor-wise Summary',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: [
              'Supervisor',
              'No. of Expenses',
              'Total Amount',
              'Approved',
              'Pending'
            ],
            data: supervisorSummary.values.map((s) => [
                  s['name'],
                  '${s['count']}',
                  'Rs.${(s['total'] as double).toStringAsFixed(2)}',
                  'Rs.${(s['approved'] as double? ?? 0).toStringAsFixed(2)}',
                  'Rs.${(s['pending'] as double? ?? 0).toStringAsFixed(2)}',
                ]).toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.amber100),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Expense Details',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: [
              'Date',
              'Name',
              'Category',
              'Supervisor',
              'Amount',
              'Status'
            ],
            data: _data
                .map((e) => [
                      DateFormat('dd/MM/yyyy').format(e.expenseDate),
                      e.expenseName,
                      StringUtils.capitalize(e.category),
                      e.supervisorName ?? '',
                      'Rs.${e.amount.toStringAsFixed(2)}',
                      e.status.toUpperCase(),
                    ])
                .toList(),
            headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.amber50),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/expense_report.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)],
        subject: 'Expense Report');
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount =
        _data.fold<double>(0, (s, e) => s + e.amount);
    final approvedAmount = _data
        .where((e) => e.status == 'approved')
        .fold<double>(0, (s, e) => s + e.amount);
    final pendingAmount = _data
        .where((e) => e.status == 'pending')
        .fold<double>(0, (s, e) => s + e.amount);

    return Column(
      children: [
        // Filters
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.secondary200))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: _fromDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now());
                        if (d != null) setState(() => _fromDate = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'From', isDense: true),
                        child: Text(
                            DateFormat('dd/MM/yyyy').format(_fromDate),
                            style: const TextStyle(
                                fontSize: 13, fontFamily: 'Inter')),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: _toDate,
                            firstDate: _fromDate,
                            lastDate: DateTime.now());
                        if (d != null) setState(() => _toDate = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'To', isDense: true),
                        child: Text(
                            DateFormat('dd/MM/yyyy').format(_toDate),
                            style: const TextStyle(
                                fontSize: 13, fontFamily: 'Inter')),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(
                          labelText: 'Category', isDense: true),
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('All Categories')),
                        ...['travel', 'fuel', 'food', 'material',
                                'labour', 'miscellaneous']
                            .map((c) => DropdownMenuItem(
                                value: c,
                                child:
                                    Text(StringUtils.capitalize(c)))),
                      ],
                      onChanged: (v) => setState(() => _category = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                          labelText: 'Status', isDense: true),
                      items: const [
                        DropdownMenuItem(
                            value: null, child: Text('All Status')),
                        DropdownMenuItem(
                            value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(
                            value: 'approved', child: Text('Approved')),
                        DropdownMenuItem(
                            value: 'rejected', child: Text('Rejected')),
                      ],
                      onChanged: (v) => setState(() => _status = v),
                    ),
                  ),
                ],
              ),
              if (_dateError != null) ...[
                const SizedBox(height: 6),
                Text(_dateError!,
                    style: const TextStyle(
                        color: AppColors.error500, fontSize: 12)),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.bar_chart_rounded, size: 18),
                  label: const Text('Generate Report'),
                  onPressed: _load,
                ),
              ),
            ],
          ),
        ),
        if (_isLoading) const LinearProgressIndicator(),
        if (_hasSearched && !_isLoading && _data.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            color: AppColors.accent50,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total: ${CurrencyUtils.format(totalAmount)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary600,
                              fontFamily: 'Inter')),
                      Text(
                          'Approved: ${CurrencyUtils.format(approvedAmount)} | Pending: ${CurrencyUtils.format(pendingAmount)}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded,
                      color: AppColors.primary500),
                  tooltip: 'Share PDF',
                  onPressed: _sharePdf,
                ),
              ],
            ),
          ),
        Expanded(
          child: !_hasSearched
              ? const Center(
                  child: Text('Select filters and generate report',
                      style:
                          TextStyle(color: AppColors.secondary400)))
              : _data.isEmpty
                  ? const w.EmptyState(
                      title: 'No expenses found',
                      icon: Icons.receipt_long_outlined)
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _data.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final e = _data[i];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.secondary200),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(e.expenseName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall),
                                    Text(
                                        '${StringUtils.capitalize(e.category)} \u{2022} ${DateFormat('dd/MM').format(e.expenseDate)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                    if (e.supervisorName != null)
                                      Text(e.supervisorName!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.end,
                                children: [
                                  Text(
                                      CurrencyUtils.format(e.amount),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              color:
                                                  AppColors.primary600)),
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

// \u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500} PAYROLL REPORT \u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}\u{2500}

class _PayrollReport extends ConsumerStatefulWidget {
  const _PayrollReport();

  @override
  ConsumerState<_PayrollReport> createState() => _PayrollReportState();
}

class _PayrollReportState extends ConsumerState<_PayrollReport> {
  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  List<PayrollModel> _employeeData = [];
  List<SupervisorPayrollModel> _supervisorData = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  Future<void> _load() async {
    setState(() { _isLoading = true; _hasSearched = true; });
    try {
      final empData = await ref.read(payrollRepositoryProvider)
          .getByMonthYear(_selectedMonth.month, _selectedMonth.year);
      final supData = await ref.read(supervisorPayrollRepositoryProvider)
          .getByMonthYear(_selectedMonth.month, _selectedMonth.year);
      setState(() {
        _employeeData = empData;
        _supervisorData = supData;
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _sharePdf() async {
    final empGross = _employeeData.fold<double>(0, (s, p) => s + p.grossWage);
    final empNet   = _employeeData.fold<double>(0, (s, p) => s + p.netWage);
    final empDed   = _employeeData.fold<double>(0, (s, p) => s + p.advanceDeduction + p.penaltyDeduction);
    final supNet   = _supervisorData.fold<double>(0, (s, p) => s + p.netAmount);
    final totalNet = empNet + supNet;

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text(
                'Payroll Report - ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            pw.Text('Emp Gross: Rs.${empGross.toStringAsFixed(2)}  ',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Text('Deductions: Rs.${empDed.toStringAsFixed(2)}  ',
                style: pw.TextStyle(color: PdfColors.red700)),
            pw.Text('Emp Net: Rs.${empNet.toStringAsFixed(2)}  ',
                style: pw.TextStyle(color: PdfColors.green700, fontWeight: pw.FontWeight.bold)),
            pw.Text('Sup Net: Rs.${supNet.toStringAsFixed(2)}  ',
                style: pw.TextStyle(color: PdfColors.blue700, fontWeight: pw.FontWeight.bold)),
            pw.Text('Total: Rs.${totalNet.toStringAsFixed(2)}',
                style: pw.TextStyle(color: PdfColors.green900, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.SizedBox(height: 16),
          pw.Text('Employee Payroll',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: ['Code', 'Name', 'Present', 'Half', 'Absent', 'Rate/Day', 'Gross', 'Advance', 'Penalty', 'Bonus', 'Net', 'Status'],
            data: _employeeData.map((p) => [
              p.employeeCode ?? '',
              p.employeeName ?? '',
              '${p.presentDays.toStringAsFixed(1)}',
              '${p.halfDays.toStringAsFixed(1)}',
              '${p.absentDays.toStringAsFixed(1)}',
              'Rs.${p.dailyWageRate.toStringAsFixed(0)}',
              'Rs.${p.grossWage.toStringAsFixed(2)}',
              'Rs.${p.advanceDeduction.toStringAsFixed(2)}',
              'Rs.${p.penaltyDeduction.toStringAsFixed(2)}',
              'Rs.${p.bonus.toStringAsFixed(2)}',
              'Rs.${p.netWage.toStringAsFixed(2)}',
              p.status.toUpperCase(),
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green100),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Supervisor Payroll',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Table.fromTextArray(
            headers: ['Code', 'Name', 'Salary', 'Bonus', 'Deduction', 'Net', 'Status'],
            data: _supervisorData.map((s) => [
              s.supervisorCode ?? '',
              s.supervisorName ?? '',
              'Rs.${s.monthlySalary.toStringAsFixed(2)}',
              'Rs.${s.bonus.toStringAsFixed(2)}',
              'Rs.${s.deduction.toStringAsFixed(2)}',
              'Rs.${s.netAmount.toStringAsFixed(2)}',
              s.status.toUpperCase(),
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
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
    final empNet  = _employeeData.fold<double>(0, (s, p) => s + p.netWage);
    final supNet  = _supervisorData.fold<double>(0, (s, p) => s + p.netAmount);
    final totalNet = empNet + supNet;
    final empGross = _employeeData.fold<double>(0, (s, p) => s + p.grossWage);
    final empPaid  = _employeeData.where((p) => p.status == 'paid').length;
    final supPaid  = _supervisorData.where((s) => s.status == 'paid').length;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.secondary200))),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => setState(() => _selectedMonth =
                        DateTime(_selectedMonth.year,
                            _selectedMonth.month - 1)),
                  ),
                  Expanded(
                    child: Text(
                        DateFormat('MMMM yyyy').format(_selectedMonth),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: _selectedMonth.isBefore(DateTime(
                            DateTime.now().year, DateTime.now().month))
                        ? () => setState(() => _selectedMonth = DateTime(
                            _selectedMonth.year, _selectedMonth.month + 1))
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.bar_chart_rounded, size: 18),
                  label: const Text('Generate Report'),
                  onPressed: _load,
                ),
              ),
            ],
          ),
        ),
        if (_isLoading) const LinearProgressIndicator(),
        if (_hasSearched && !_isLoading && (_employeeData.isNotEmpty || _supervisorData.isNotEmpty))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFE8F5E9),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Total Net: ${CurrencyUtils.format(totalNet)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.success700,
                              fontSize: 12,
                              fontFamily: 'Inter')),
                      Text(
                          'Emp: ${_employeeData.length} (${empPaid} paid) · Sup: ${_supervisorData.length} (${supPaid} paid)',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: AppColors.success600),
                  tooltip: 'Share PDF',
                  onPressed: _sharePdf,
                ),
              ],
            ),
          ),
        Expanded(
          child: !_hasSearched
              ? const Center(
                  child: Text('Select month and generate report',
                      style: TextStyle(color: AppColors.secondary400)))
              : (_employeeData.isEmpty && _supervisorData.isEmpty)
                  ? const w.EmptyState(title: 'No payroll records', icon: Icons.payments_outlined)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (_employeeData.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('Employees (${_employeeData.length})',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, fontFamily: 'Inter')),
                          ),
                          ..._employeeData.map((p) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.secondary200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(child: Text(p.employeeName ?? '', style: Theme.of(context).textTheme.titleSmall)),
                                  Text(CurrencyUtils.format(p.netWage),
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.success600)),
                                ]),
                                const SizedBox(height: 4),
                                Text('${p.employeeCode} · ${p.effectiveDays.toStringAsFixed(1)} days @ ₹${p.dailyWageRate.toStringAsFixed(0)}/day',
                                    style: Theme.of(context).textTheme.bodySmall),
                                Text('Gross: ${CurrencyUtils.format(p.grossWage)} · Advance: ${CurrencyUtils.format(p.advanceDeduction)}',
                                    style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          )),
                          const SizedBox(height: 16),
                        ],
                        if (_supervisorData.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text('Supervisors (${_supervisorData.length})',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, fontFamily: 'Inter')),
                          ),
                          ..._supervisorData.map((s) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.secondary200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Expanded(child: Text(s.supervisorName ?? '', style: Theme.of(context).textTheme.titleSmall)),
                                  Text(CurrencyUtils.format(s.netAmount),
                                      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.primary600)),
                                ]),
                                const SizedBox(height: 4),
                                Text('${s.supervisorCode} · Salary: ${CurrencyUtils.format(s.monthlySalary)}',
                                    style: Theme.of(context).textTheme.bodySmall),
                                if (s.bonus > 0 || s.deduction > 0)
                                  Text('Bonus: ${CurrencyUtils.format(s.bonus)} · Deduction: ${CurrencyUtils.format(s.deduction)}',
                                      style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          )),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryChip(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter'),
      ),
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
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4)),
      child: Text('$label:$count',
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter')),
    );
  }
}