import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';

final _monthAttendanceProvider = FutureProvider.autoDispose
    .family<List<AttendanceDetailModel>, _MonthQuery>((ref, query) async {
  final monthStart = DateTime(query.month.year, query.month.month, 1);
  final monthEnd = DateTime(query.month.year, query.month.month + 1, 0);
  return ref.read(employeeRepositoryProvider).getOwnAttendance(
        query.employeeId,
        fromDate: monthStart,
        toDate: monthEnd,
      );
});

class _MonthQuery {
  final String employeeId;
  final DateTime month;
  const _MonthQuery(this.employeeId, this.month);

  @override
  bool operator ==(Object other) =>
      other is _MonthQuery &&
      other.employeeId == employeeId &&
      other.month.year == month.year &&
      other.month.month == month.month;

  @override
  int get hashCode => Object.hash(employeeId, month.year, month.month);
}

/// Item 21: month-wise attendance history for the logged-in employee,
/// showing each day in the month as Present or Absent.
class EmployeeAttendanceHistoryScreen extends ConsumerStatefulWidget {
  final String employeeId;
  const EmployeeAttendanceHistoryScreen({super.key, required this.employeeId});

  @override
  ConsumerState<EmployeeAttendanceHistoryScreen> createState() =>
      _EmployeeAttendanceHistoryScreenState();
}

class _EmployeeAttendanceHistoryScreenState
    extends ConsumerState<EmployeeAttendanceHistoryScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final query = _MonthQuery(widget.employeeId, _selectedMonth);
    final attendanceAsync = ref.watch(_monthAttendanceProvider(query));

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance History')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_monthAttendanceProvider(query));
          await ref.read(_monthAttendanceProvider(query).future);
        },
        child: Column(
          children: [
            _MonthSwitcher(
              month: _selectedMonth,
              onChanged: (m) => setState(() => _selectedMonth = m),
            ),
            Expanded(
              child: attendanceAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (list) {
                  final byDate = <String, AttendanceDetailModel>{};
                  for (final d in list) {
                    if (d.attendanceDate != null) {
                      byDate[DateFormat('yyyy-MM-dd').format(d.attendanceDate!)] = d;
                    }
                  }

                  final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
                  final today = DateTime.now();
                  final isCurrentMonth = _selectedMonth.year == today.year && _selectedMonth.month == today.month;
                  final lastDay = isCurrentMonth ? today.day : daysInMonth;

                  final presentCount = byDate.values.where((d) => d.status == 'present').length;
                  final absentCount = byDate.values.where((d) => d.status == 'absent').length;

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          Expanded(child: _SummaryChip(label: 'Present', count: presentCount, color: AppColors.success500)),
                          const SizedBox(width: 10),
                          Expanded(child: _SummaryChip(label: 'Absent', count: absentCount, color: AppColors.error500)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...List.generate(lastDay, (i) {
                        final day = DateTime(_selectedMonth.year, _selectedMonth.month, i + 1);
                        final key = DateFormat('yyyy-MM-dd').format(day);
                        final record = byDate[key];
                        final status = record?.status;
                        return _DayRow(day: day, status: status);
                      }).reversed,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  const _MonthSwitcher({required this.month, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = month.year == now.year && month.month == now.month;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
          ),
          Text(DateFormat('MMMM yyyy').format(month),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, fontFamily: 'Inter')),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: isCurrentMonth ? null : () => onChanged(DateTime(month.year, month.month + 1)),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _SummaryChip({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, fontFamily: 'Inter', color: color)),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontFamily: 'Inter')),
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final DateTime day;
  final String? status;
  const _DayRow({required this.day, this.status});

  @override
  Widget build(BuildContext context) {
    final isPresent = status == 'present';
    final isAbsent = status == 'absent';
    final hasRecord = status != null;

    final color = isPresent
        ? AppColors.success500
        : isAbsent
            ? AppColors.error500
            : AppColors.secondary300;
    final label = isPresent ? 'Present' : (isAbsent ? 'Absent' : 'No record');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.secondary200),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(DateFormat('dd').format(day), style: const TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Inter')),
                Text(DateFormat('EEE').format(day), style: const TextStyle(fontSize: 11, color: AppColors.secondary400)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: hasRecord ? color.withOpacity(0.12) : AppColors.secondary100,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                isPresent ? 'P' : (isAbsent ? 'A' : '-'),
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: hasRecord ? AppColors.secondary700 : AppColors.secondary400, fontFamily: 'Inter')),
        ],
      ),
    );
  }
}
