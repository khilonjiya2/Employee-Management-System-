import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;

final attendanceListProvider =
    StateNotifierProvider.autoDispose<AttendanceListNotifier,
        AsyncValue<List<AttendanceModel>>>((ref) {
  return AttendanceListNotifier(
    ref.watch(attendanceRepositoryProvider),
    ref.watch(supabaseProvider),
    ref.watch(currentProfileProvider).valueOrNull,
  );
});

class AttendanceListNotifier
    extends StateNotifier<AsyncValue<List<AttendanceModel>>> {
  final AttendanceRepository _repo;
  final dynamic _client;
  final ProfileModel? _profile;

  AttendanceListNotifier(this._repo, this._client, this._profile)
      : super(const AsyncLoading()) {
    load();
  }

  Future<void> load({DateTime? from, DateTime? to}) async {
    try {
      String? supervisorId;
      if (_profile?.isSupervisor == true) {
        final sup = await _client
            .from('supervisors')
            .select('id')
            .eq('profile_id', _profile!.id)
            .maybeSingle();
        supervisorId = sup?['id'] as String?;
      }
      final data = await _repo.getAll(
          supervisorId: supervisorId, fromDate: from, toDate: to);
      state = AsyncData(data);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void refresh() => load();
}

class AttendanceListScreen extends ConsumerStatefulWidget {
  const AttendanceListScreen({super.key});

  @override
  ConsumerState<AttendanceListScreen> createState() =>
      _AttendanceListScreenState();
}

class _AttendanceListScreenState extends ConsumerState<AttendanceListScreen> {
  DateTime? _filterFrom;
  DateTime? _filterTo;

  void _showFilterSheet() {
    DateTime tempFrom = _filterFrom ?? DateTime.now().subtract(const Duration(days: 30));
    DateTime tempTo = _filterTo ?? DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Filter by Date',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: tempFrom,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setModalState(() => tempFrom = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'From Date', isDense: true),
                        child: Text(DateFormat('dd/MM/yyyy').format(tempFrom),
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
                          initialDate: tempTo,
                          firstDate: tempFrom,
                          lastDate: DateTime.now(),
                        );
                        if (d != null) setModalState(() => tempTo = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'To Date', isDense: true),
                        child: Text(DateFormat('dd/MM/yyyy').format(tempTo),
                            style: const TextStyle(
                                fontSize: 13, fontFamily: 'Inter')),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _filterFrom = null;
                          _filterTo = null;
                        });
                        ref
                            .read(attendanceListProvider.notifier)
                            .load();
                        Navigator.pop(ctx);
                      },
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterFrom = tempFrom;
                          _filterTo = tempTo;
                        });
                        ref
                            .read(attendanceListProvider.notifier)
                            .load(from: tempFrom, to: tempTo);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendance = ref.watch(attendanceListProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final isFiltered = _filterFrom != null || _filterTo != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(profile?.role == 'supervisor' ? 'Overview' : 'Attendance'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.calendar_month_outlined),
                onPressed: _showFilterSheet,
              ),
              if (isFiltered)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.error500,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          if (profile?.isSupervisor == true)
            IconButton(
                icon: const Icon(Icons.event_available_rounded),
                tooltip: 'Mark Attendance',
                onPressed: () => context.push('/attendance/new')),
        ],
      ),
      body: Column(
        children: [
          if (isFiltered)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Chip(
                    label: Text(
                      '${DateFormat('dd/MM').format(_filterFrom!)} - ${DateFormat('dd/MM').format(_filterTo!)}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary700,
                          fontFamily: 'Inter'),
                    ),
                    backgroundColor: AppColors.primary50,
                    deleteIconColor: AppColors.primary500,
                    onDeleted: () {
                      setState(() {
                        _filterFrom = null;
                        _filterTo = null;
                      });
                      ref.read(attendanceListProvider.notifier).load();
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: attendance.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => list.isEmpty
                  ? w.EmptyState(
                      title: 'No attendance records',
                      subtitle: profile?.isSupervisor == true
                          ? 'Submit attendance for your team'
                          : 'No attendance submitted yet',
                      icon: Icons.calendar_today_outlined,
                      actionLabel:
                          profile?.isSupervisor == true ? 'Submit Attendance' : null,
                      onAction: profile?.isSupervisor == true
                          ? () => context.push('/attendance/new')
                          : null,
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.read(attendanceListProvider.notifier).refresh(),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (_, i) => _AttendanceCard(
                          attendance: list[i],
                          isAdmin: profile?.isAdmin == true,
                          isSupervisor: profile?.isSupervisor == true,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: null,
    );
  }
}

class _AttendanceCard extends ConsumerWidget {
  final AttendanceModel attendance;
  final bool isAdmin;
  final bool isSupervisor;

  const _AttendanceCard({
    required this.attendance,
    required this.isAdmin,
    required this.isSupervisor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final details = attendance.details ?? [];
    final present = details.where((d) => d.status == 'present').length;
    final absent = details.where((d) => d.status == 'absent').length;

    return InkWell(
      onTap: () => context.push('/attendance/${attendance.id}/detail'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondary200),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: attendance.isApproved
                          ? AppColors.success50
                          : AppColors.accent50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('dd').format(attendance.attendanceDate),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                            color: attendance.isApproved
                                ? AppColors.success700
                                : AppColors.accent600,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(attendance.attendanceDate),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Inter',
                            color: attendance.isApproved
                                ? AppColors.success600
                                : AppColors.accent600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attendance.locationName ??
                              attendance.workSiteName ??
                              'Location not set',
                          style: theme.textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (attendance.supervisorName != null)
                          Text(attendance.supervisorName!,
                              style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  w.StatusBadge(
                      status: attendance.isApproved ? 'approved' : 'pending'),
                ],
              ),
            ),
            if (details.isNotEmpty) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _AttendanceStat('Present', present, AppColors.success500),
                    _AttendanceStat('Absent', absent, AppColors.error500),
                    _AttendanceStat('Total', details.length, AppColors.primary500),
                  ],
                ),
              ),
            ],
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_rounded,
                      size: 14, color: AppColors.secondary400),
                  const SizedBox(width: 4),
                  Text('Tap to view full report',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: AppColors.secondary400)),
                  const Spacer(),
                  if (attendance.latitude != null &&
                      attendance.longitude != null)
                    TextButton.icon(
                      icon: const Icon(Icons.location_on_outlined, size: 14),
                      label: const Text('View Location'),
                      onPressed: () => _viewLocation(
                          context, attendance.latitude!, attendance.longitude!),
                    ),
                  if (isSupervisor)
                    TextButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 14),
                      label: const Text('Edit'),
                      onPressed: () => context
                          .push('/attendance/${attendance.id}/edit'),
                    ),
                  if (isAdmin && !attendance.isApproved && details.isNotEmpty)
                    TextButton(
                      onPressed: () => _approve(context, ref, attendance.id),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.success600),
                      child: const Text('Approve'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewLocation(
      BuildContext context, double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open maps app'),
            backgroundColor: AppColors.error500));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not open maps app'),
            backgroundColor: AppColors.error500));
      }
    }
  }

  Future<void> _approve(BuildContext context, WidgetRef ref, String id) async {
    final confirm = await w.ConfirmDialog.show(
      context,
      title: 'Approve Attendance?',
      message: 'Approve this attendance record?',
      confirmLabel: 'Approve',
      confirmColor: AppColors.success500,
    );
    if (confirm != true || !context.mounted) return;

    final client = ref.read(supabaseProvider);
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await ref.read(attendanceRepositoryProvider).approve(id, userId);
      ref.read(attendanceListProvider.notifier).refresh();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Attendance approved'),
            backgroundColor: AppColors.success500));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error500));
      }
    }
  }
}

class _AttendanceStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _AttendanceStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                color: color)),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
