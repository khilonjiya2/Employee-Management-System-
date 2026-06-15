import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;

class AttendanceDetailScreen extends ConsumerWidget {
  final String attendanceId;
  const AttendanceDetailScreen({super.key, required this.attendanceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<AttendanceModel?>(
      future: ref.read(attendanceRepositoryProvider).getById(attendanceId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final att = snapshot.data;
        if (att == null) {
          return const Scaffold(body: Center(child: Text('Not found')));
        }
        return _AttendanceDetailBody(attendance: att);
      },
    );
  }
}

class _AttendanceDetailBody extends StatelessWidget {
  final AttendanceModel attendance;
  const _AttendanceDetailBody({required this.attendance});

  Future<void> _exportPdf(BuildContext context) async {
    final pdf = pw.Document();
    final details = attendance.details ?? [];

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
          pw.SizedBox(height: 8),
          pw.Text(
              'Date: ${DateFormat('dd MMMM yyyy').format(attendance.attendanceDate)}'),
          pw.Text('Supervisor: ${attendance.supervisorName ?? ''}'),
          pw.Text('Location: ${attendance.locationName ?? ''}'),
          pw.Text(
              'Status: ${attendance.isApproved ? 'Approved' : 'Pending'}'),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['#', 'Employee Code', 'Employee Name', 'Status'],
            data: details.asMap().entries.map((e) {
              final d = e.value;
              return [
                '${e.key + 1}',
                d.employeeCode ?? '',
                d.employeeName ?? '',
                d.status.toUpperCase(),
              ];
            }).toList(),
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColors.blue100),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
              'Present: ${details.where((d) => d.status == 'present').length}   '
              'Absent: ${details.where((d) => d.status == 'absent').length}   '
              'Total: ${details.length}'),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}/attendance_${DateFormat('yyyyMMdd').format(attendance.attendanceDate)}.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)],
        subject: 'Attendance Report');
  }

  @override
  Widget build(BuildContext context) {
    final details = attendance.details ?? [];
    final present = details.where((d) => d.status == 'present').length;
    final absent = details.where((d) => d.status == 'absent').length;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Attendance - ${DateFormat('dd MMM yyyy').format(attendance.attendanceDate)}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Export PDF',
            onPressed: () => _exportPdf(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary700, AppColors.primary400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy')
                          .format(attendance.attendanceDate),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          fontFamily: 'Inter'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (attendance.supervisorName != null)
                  Text('Supervisor: ${attendance.supervisorName}',
                      style: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 13,
                          fontFamily: 'Inter')),
                if (attendance.locationName != null)
                  Text('Location: ${attendance.locationName}',
                      style: const TextStyle(
                          color: Color(0xCCFFFFFF),
                          fontSize: 13,
                          fontFamily: 'Inter')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _SummaryPill('Present', present, AppColors.success500),
                    const SizedBox(width: 8),
                    _SummaryPill('Absent', absent, AppColors.error500),
                    const SizedBox(width: 8),
                    _SummaryPill('Total', details.length, Colors.white70),
                    const Spacer(),
                    w.StatusBadge(
                        status: attendance.isApproved ? 'approved' : 'pending'),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text('${details.length} Employees',
                    style: theme.textTheme.titleSmall),
              ],
            ),
          ),
          Expanded(
            child: details.isEmpty
                ? const w.EmptyState(
                    title: 'No employee records',
                    icon: Icons.people_outline)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: details.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final d = details[i];
                      final isPresent = d.status == 'present';
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isPresent
                                ? AppColors.success500.withOpacity(0.3)
                                : AppColors.error500.withOpacity(0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: isPresent
                                  ? AppColors.success500.withOpacity(0.15)
                                  : AppColors.error500.withOpacity(0.15),
                              child: Text(
                                (d.employeeName?.isNotEmpty == true)
                                    ? d.employeeName![0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: isPresent
                                      ? AppColors.success700
                                      : AppColors.error600,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Inter',
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(d.employeeName ?? 'Unknown',
                                      style: theme.textTheme.titleSmall),
                                  Text(d.employeeCode ?? '',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                              color: AppColors.primary500)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: isPresent
                                    ? AppColors.success500
                                    : AppColors.error500,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isPresent ? 'PRESENT' : 'ABSENT',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryPill(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter'),
      ),
    );
  }
}