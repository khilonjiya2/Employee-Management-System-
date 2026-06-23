import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;

// Provider for today's attendance details with optional status filter
final _todayAttendanceDetailProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String?>((ref, statusFilter) async {
  final client = ref.read(supabaseProvider);
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // Fetch today's attendance records with employee details
  var query = client
      .from('attendance_details')
      .select(
          '*, employees(name, employee_code, designation), attendance!inner(attendance_date, location_name, is_approved, supervisors(name, supervisor_code))')
      .eq('attendance.attendance_date', today);

  if (statusFilter != null) {
    query = query.eq('status', statusFilter);
  }

  final data = await query.order('created_at', ascending: false);
  return (data as List).cast<Map<String, dynamic>>();
});

class TodayAttendanceScreen extends ConsumerStatefulWidget {
  final String? initialFilter; // 'present' or 'absent' or null (all)
  const TodayAttendanceScreen({super.key, this.initialFilter});

  @override
  ConsumerState<TodayAttendanceScreen> createState() =>
      _TodayAttendanceScreenState();
}

class _TodayAttendanceScreenState
    extends ConsumerState<TodayAttendanceScreen> {
  late String? _statusFilter;
  String? _locationFilter;
  String? _supervisorFilter;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync =
        ref.watch(_todayAttendanceDetailProvider(_statusFilter));
    final today = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_statusFilter == 'present'
                ? 'Present Today'
                : _statusFilter == 'absent'
                    ? 'Absent Today'
                    : 'Today\'s Attendance'),
            Text(today,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.secondary400)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter bar
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _FilterChip(
                  label: 'All',
                  selected: _statusFilter == null,
                  onTap: () => setState(() => _statusFilter = null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Present',
                  selected: _statusFilter == 'present',
                  color: AppColors.success500,
                  onTap: () => setState(() => _statusFilter = 'present'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: 'Absent',
                  selected: _statusFilter == 'absent',
                  color: AppColors.error500,
                  onTap: () => setState(() => _statusFilter = 'absent'),
                ),
              ],
            ),
          ),
          Expanded(
            child: recordsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (records) {
                // Apply location/supervisor filters client-side
                final filtered = records.where((r) {
                  final att = r['attendance'] as Map? ?? {};
                  final loc = att['location_name'] as String? ?? '';
                  final sup = att['supervisors'] as Map? ?? {};
                  final supName = sup['name'] as String? ?? '';

                  if (_locationFilter != null &&
                      !loc
                          .toLowerCase()
                          .contains(_locationFilter!.toLowerCase()))
                    return false;
                  if (_supervisorFilter != null &&
                      !supName
                          .toLowerCase()
                          .contains(_supervisorFilter!.toLowerCase()))
                    return false;
                  return true;
                }).toList();

                // Build location and supervisor filter options
                final locations = records
                    .map((r) =>
                        (r['attendance'] as Map?)?['location_name']
                            as String? ??
                        '')
                    .where((l) => l.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();
                final supervisors = records
                    .map((r) {
                      final sup = ((r['attendance'] as Map?)?['supervisors']
                          as Map?);
                      return sup?['name'] as String? ?? '';
                    })
                    .where((s) => s.isNotEmpty)
                    .toSet()
                    .toList()
                  ..sort();

                if (records.isEmpty) {
                  return const Center(
                    child: w.EmptyState(
                      title: 'No attendance records today',
                      subtitle:
                          'No supervisors have submitted attendance yet today.',
                      icon: Icons.event_busy_rounded,
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref
                      .invalidate(_todayAttendanceDetailProvider(_statusFilter)),
                  child: Column(
                    children: [
                      // Location + Supervisor filter row
                      if (locations.length > 1 || supervisors.length > 1)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding:
                              const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Row(
                            children: [
                              if (locations.length > 1) ...[
                                const Icon(Icons.location_on_outlined,
                                    size: 14,
                                    color: AppColors.secondary500),
                                const SizedBox(width: 4),
                                DropdownButton<String?>(
                                  value: _locationFilter,
                                  hint: const Text('All Locations',
                                      style: TextStyle(fontSize: 12)),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondary700),
                                  underline: const SizedBox.shrink(),
                                  items: [
                                    const DropdownMenuItem(
                                        value: null,
                                        child: Text('All Locations')),
                                    ...locations.map((l) =>
                                        DropdownMenuItem(
                                            value: l, child: Text(l))),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _locationFilter = v),
                                ),
                                const SizedBox(width: 16),
                              ],
                              if (supervisors.length > 1) ...[
                                const Icon(Icons.person_outline_rounded,
                                    size: 14,
                                    color: AppColors.secondary500),
                                const SizedBox(width: 4),
                                DropdownButton<String?>(
                                  value: _supervisorFilter,
                                  hint: const Text('All Supervisors',
                                      style: TextStyle(fontSize: 12)),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.secondary700),
                                  underline: const SizedBox.shrink(),
                                  items: [
                                    const DropdownMenuItem(
                                        value: null,
                                        child: Text('All Supervisors')),
                                    ...supervisors.map((s) =>
                                        DropdownMenuItem(
                                            value: s, child: Text(s))),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _supervisorFilter = v),
                                ),
                              ],
                            ],
                          ),
                        ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Text('${filtered.length} record(s)',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.secondary500)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final r = filtered[i];
                            final emp = r['employees'] as Map? ?? {};
                            final att = r['attendance'] as Map? ?? {};
                            final sup =
                                att['supervisors'] as Map? ?? {};
                            final isPresent = r['status'] == 'present';

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: AppColors.secondary200),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: (isPresent
                                              ? AppColors.success500
                                              : AppColors.error500)
                                          .withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        isPresent ? 'P' : 'A',
                                        style: TextStyle(
                                          color: isPresent
                                              ? AppColors.success500
                                              : AppColors.error500,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          emp['name'] as String? ??
                                              'Unknown',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          '${emp['employee_code'] ?? ''}'
                                          '${emp['designation'] != null ? ' \u{2022} ${emp['designation']}' : ''}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                                  AppColors.secondary500),
                                        ),
                                        if (att['location_name'] != null ||
                                            sup['name'] != null)
                                          Text(
                                            '${att['location_name'] ?? ''}'
                                            '${sup['name'] != null ? ' \u{2022} ${sup['name']}' : ''}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppColors.secondary400),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (!att['is_approved'])
                                    const Icon(Icons.pending_outlined,
                                        size: 14,
                                        color: AppColors.accent500),
                                ],
                              ),
                            );
                          },
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

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary500;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? c : AppColors.secondary100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c : AppColors.secondary300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.secondary700,
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
