import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;

final attendanceListProvider = StateNotifierProvider.autoDispose<AttendanceListNotifier, AsyncValue<List<AttendanceModel>>>((ref) {
  return AttendanceListNotifier(ref.watch(attendanceRepositoryProvider), ref.watch(supabaseProvider), ref.watch(currentProfileProvider).valueOrNull);
});

class AttendanceListNotifier extends StateNotifier<AsyncValue<List<AttendanceModel>>> {
  final AttendanceRepository _repo;
  final dynamic _client;
  final ProfileModel? _profile;

  AttendanceListNotifier(this._repo, this._client, this._profile) : super(const AsyncLoading()) {
    load();
  }

  Future<void> load({DateTime? from, DateTime? to}) async {
    try {
      String? supervisorId;
      if (_profile?.isSupervisor == true) {
        final sup = await _client.from('supervisors').select('id').eq('profile_id', _profile!.id).maybeSingle();
        supervisorId = sup?['id'] as String?;
      }
      final data = await _repo.getAll(supervisorId: supervisorId, fromDate: from, toDate: to);
      state = AsyncData(data);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void refresh() => load();
}

class AttendanceListScreen extends ConsumerWidget {
  const AttendanceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendance = ref.watch(attendanceListProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(icon: const Icon(Icons.filter_alt_outlined), onPressed: () {}),
          if (profile?.isSupervisor == true)
            IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => context.push('/attendance/new')),
        ],
      ),
      body: attendance.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? w.EmptyState(
                title: 'No attendance records',
                subtitle: profile?.isSupervisor == true ? 'Submit attendance for your team' : 'No attendance submitted yet',
                icon: Icons.calendar_today_outlined,
                actionLabel: profile?.isSupervisor == true ? 'Submit Attendance' : null,
                onAction: profile?.isSupervisor == true ? () => context.push('/attendance/new') : null,
              )
            : RefreshIndicator(
                onRefresh: () async => ref.read(attendanceListProvider.notifier).refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _AttendanceCard(
                    attendance: list[i],
                    isAdmin: profile?.isAdmin == true,
                  ),
                ),
              ),
      ),
      floatingActionButton: profile?.isSupervisor == true
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/attendance/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Mark Attendance'),
            )
          : null,
    );
  }
}

class _AttendanceCard extends ConsumerWidget {
  final AttendanceModel attendance;
  final bool isAdmin;

  const _AttendanceCard({required this.attendance, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final details = attendance.details ?? [];
    final present = details.where((d) => d.status == 'present').length;
    final absent = details.where((d) => d.status == 'absent').length;
    final halfDay = details.where((d) => d.status == 'half_day').length;
    final leave = details.where((d) => d.status == 'leave').length;

    return Container(
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
                    color: attendance.isApproved ? AppColors.success50 : AppColors.accent50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('dd').format(attendance.attendanceDate),
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, fontFamily: 'Inter', color: attendance.isApproved ? AppColors.success700 : AppColors.accent700),
                      ),
                      Text(
                        DateFormat('MMM').format(attendance.attendanceDate),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, fontFamily: 'Inter', color: attendance.isApproved ? AppColors.success600 : AppColors.accent600),
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
                        attendance.locationName ?? attendance.workSiteName ?? 'Location not set',
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (attendance.supervisorName != null)
                        Text(attendance.supervisorName!, style: theme.textTheme.bodySmall),
                      if (attendance.workDescription != null)
                        Text(attendance.workDescription!, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                w.StatusBadge(status: attendance.isApproved ? 'approved' : 'pending'),
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
                  _AttendanceStat(label: 'Present', value: present, color: AppColors.success500),
                  _AttendanceStat(label: 'Absent', value: absent, color: AppColors.error500),
                  _AttendanceStat(label: 'Half Day', value: halfDay, color: AppColors.accent500),
                  _AttendanceStat(label: 'Leave', value: leave, color: AppColors.primary500),
                ],
              ),
            ),
          ],
          if (isAdmin && !attendance.isApproved && details.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  if (attendance.latitude != null)
                    TextButton.icon(
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('View Location'),
                      onPressed: () => context.push('/attendance/${attendance.id}/map'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => _approve(context, ref, attendance.id),
                    child: const Text('Approve'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.success600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance approved'), backgroundColor: AppColors.success500),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error500),
        );
      }
    }
  }
}

class _AttendanceStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _AttendanceStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'Inter', color: color)),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
