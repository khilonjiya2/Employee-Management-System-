import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;

final _employeeOwnRecordProvider =
    FutureProvider.autoDispose<EmployeeModel?>((ref) async {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile == null) return null;
  return ref.read(employeeRepositoryProvider).getByProfileId(profile.id);
});

final _employeeOwnAttendanceProvider = FutureProvider.autoDispose
    .family<List<AttendanceDetailModel>, String>((ref, employeeId) async {
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  return ref.read(employeeRepositoryProvider).getOwnAttendance(
        employeeId,
        fromDate: monthStart,
        toDate: now,
      );
});

final _employeeOwnPayrollProvider = FutureProvider.autoDispose
    .family<List<PayrollModel>, String>((ref, employeeId) async {
  return ref.read(payrollRepositoryProvider).getOwnPayrollHistory(employeeId, limit: 6);
});

final _employeeUnreadNotificationsProvider =
    FutureProvider.autoDispose<int>((ref) async {
  return ref.read(notificationRepositoryProvider).getUnreadCount();
});

class EmployeeDashboardScreen extends ConsumerWidget {
  const EmployeeDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final employeeAsync = ref.watch(_employeeOwnRecordProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('My Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppColors.secondary700),
                onPressed: () async {
                  await context.push('/notifications');
                  ref.invalidate(_employeeUnreadNotificationsProvider);
                },
              ),
              ref.watch(_employeeUnreadNotificationsProvider).maybeWhen(
                    data: (count) => count > 0
                        ? Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                              decoration: BoxDecoration(
                                color: AppColors.error500,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: Text(
                                count > 9 ? '9+' : '$count',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'Inter',
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: employeeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (employee) {
          if (employee == null) {
            return const w.EmptyState(
              title: 'No employee record linked',
              subtitle: 'Contact your administrator to link your login to your employee record',
              icon: Icons.person_off_outlined,
            );
          }
          return _EmployeeDashboardBody(employee: employee, profile: profile);
        },
      ),
    );
  }
}

class _EmployeeDashboardBody extends ConsumerStatefulWidget {
  final EmployeeModel employee;
  final ProfileModel? profile;
  const _EmployeeDashboardBody({required this.employee, this.profile});

  @override
  ConsumerState<_EmployeeDashboardBody> createState() => _EmployeeDashboardBodyState();
}

class _EmployeeDashboardBodyState extends ConsumerState<_EmployeeDashboardBody> {
  Future<void> _refresh() async {
    ref.invalidate(_employeeOwnAttendanceProvider(widget.employee.id));
    ref.invalidate(_employeeOwnPayrollProvider(widget.employee.id));
    ref.invalidate(_employeeUnreadNotificationsProvider);
    await Future.wait([
      ref.read(_employeeOwnAttendanceProvider(widget.employee.id).future),
      ref.read(_employeeOwnPayrollProvider(widget.employee.id).future),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final attendance = ref.watch(_employeeOwnAttendanceProvider(widget.employee.id));
    final payroll = ref.watch(_employeeOwnPayrollProvider(widget.employee.id));
    final monthLabel = DateFormat('MMMM yyyy').format(DateTime.now());

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary700, AppColors.primary400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary500.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  w.GenderAvatar(
                    radius: 28,
                    photoUrl: widget.employee.employeePhotoUrl,
                    gender: widget.employee.gender,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back,',
                          style: TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                        ),
                        Text(
                          widget.employee.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.employee.employeeCode} \u{B7} ${widget.employee.designation ?? "Employee"}',
                          style: const TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontFamily: 'Inter',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Attendance \u{B7} $monthLabel',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            attendance.when(
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $e', style: const TextStyle(color: AppColors.error500)),
              ),
              data: (list) {
                final present = list.where((d) => d.status == 'present').length;
                final absent = list.where((d) => d.status == 'absent').length;
                return Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Present Days',
                        value: '$present',
                        icon: Icons.check_circle_rounded,
                        iconColor: AppColors.success500,
                        iconBg: const Color(0xFFE8F5E9),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        title: 'Absent Days',
                        value: '$absent',
                        icon: Icons.cancel_rounded,
                        iconColor: AppColors.error500,
                        iconBg: const Color(0xFFFFEBEE),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: const Text('View Full Attendance History'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary600,
                  side: const BorderSide(color: AppColors.primary400),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => context.push('/my-attendance-history', extra: widget.employee.id),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('View Full Payroll History'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary600,
                  side: const BorderSide(color: AppColors.primary400),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => context.push('/my-payroll-history', extra: widget.employee.id),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.account_balance_outlined, size: 18),
                label: const Text('My Bank Details'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary600,
                  side: const BorderSide(color: AppColors.primary400),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => context.push('/my-bank-details'),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Salary History',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            payroll.when(
              loading: () => const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Error: $e', style: const TextStyle(color: AppColors.error500)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const w.EmptyState(
                    title: 'No payroll history yet',
                    icon: Icons.payments_outlined,
                  );
                }
                return Column(
                  children: list.map((p) {
                    final monthName = DateFormat('MMMM yyyy')
                        .format(DateTime(p.payrollYear, p.payrollMonth));
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.secondary200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(monthName, style: Theme.of(context).textTheme.titleSmall),
                                Text(
                                  '${p.effectiveDays.toStringAsFixed(1)} days worked',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                CurrencyUtils.format(p.netWage),
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: AppColors.primary600,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              w.StatusBadge(status: p.isPaid ? 'paid' : p.status),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'My Details',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter',
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.secondary200),
              ),
              child: Column(
                children: [
                  _DetailRow(label: 'Daily Wage', value: CurrencyUtils.format(widget.employee.dailyWageRate)),
                  if (widget.employee.mobile != null)
                    _DetailRow(label: 'Mobile', value: widget.employee.mobile!),
                  _DetailRow(
                    label: 'Joining Date',
                    value: DateFormat('dd MMM yyyy').format(widget.employee.joiningDate),
                  ),
                  _DetailRow(
                    label: 'Status',
                    value: widget.employee.isActive ? 'Active' : 'Inactive',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFamily: 'Inter',
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'Inter',
              color: Color(0xFF8A8FA3),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}