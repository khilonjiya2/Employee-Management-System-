import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart' as AppUtils;
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' show GenderAvatar;

/// The direct employee-side counterpart to AdvancePaymentScreen — reached
/// from the same "Payment" quick action on the admin dashboard, sitting
/// right beside "Advance". Lists every active employee so the admin can
/// pick who to pay; tapping one opens EmployeePaymentScreen for them.
final paymentEmployeesProvider =
    FutureProvider.autoDispose<List<EmployeeModel>>((ref) async {
  // getAll() is paginated with a default limit of 20 — without an
  // explicit higher limit here, any company with more than 20 employees
  // would silently only see the first 20 in this picker.
  return ref.read(employeeRepositoryProvider).getAll(status: 'active', limit: 1000);
});

/// This screen itself is now just a thin Scaffold+AppBar wrapper around
/// EmployeePaymentTabBody below — kept around unchanged for any existing
/// direct link, and so its behavior is identical to before. The actual
/// search+list content lives in EmployeePaymentTabBody so PaymentScreen's
/// "Employees" tab can reuse the exact same widget.
class EmployeePaymentListScreen extends StatelessWidget {
  final String? employeeId;
  const EmployeePaymentListScreen({super.key, this.employeeId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Employee Payment')),
      body: EmployeePaymentTabBody(employeeId: employeeId),
    );
  }
}

/// The search+list body for paying employees — no Scaffold or AppBar of
/// its own, so it can be embedded either standalone (via
/// EmployeePaymentListScreen above) or as one tab of PaymentScreen.
class EmployeePaymentTabBody extends ConsumerStatefulWidget {
  final String? employeeId;
  const EmployeePaymentTabBody({super.key, this.employeeId});

  @override
  ConsumerState<EmployeePaymentTabBody> createState() =>
      _EmployeePaymentTabBodyState();
}

class _EmployeePaymentTabBodyState
    extends ConsumerState<EmployeePaymentTabBody> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    // If an employeeId was pre-selected (e.g. arrived here from an
    // employee's own detail screen), go straight to their payment screen
    // instead of showing the picker list — mirrors AdvancePaymentScreen's
    // same shortcut for supervisors.
    if (widget.employeeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.push('/employees/${widget.employeeId}/payments');
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employeesAsync = ref.watch(paymentEmployeesProvider);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search employee...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _search = '');
                    })
                : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
      ),
      Expanded(
        child: employeesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (employees) {
            final filtered = _search.isEmpty
                ? employees
                : employees
                    .where((e) =>
                        e.name.toLowerCase().contains(_search.toLowerCase()) ||
                        e.employeeCode.toLowerCase().contains(_search.toLowerCase()))
                    .toList();

            if (filtered.isEmpty) {
                return const Center(
                    child: Text('No employees found',
                        style: TextStyle(color: AppColors.secondary400)));
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(paymentEmployeesProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _EmployeePaymentTile(employee: filtered[i]),
                ),
              );
            },
          ),
        ),
      ]);
  }
}

class _EmployeePaymentTile extends ConsumerWidget {
  final EmployeeModel employee;
  const _EmployeePaymentTile({required this.employee});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final monthTotalAsync = ref.watch(
        employeeMonthPaymentsProvider((employeeId: employee.id, month: now.month, year: now.year)));
    final monthTotal = monthTotalAsync.valueOrNull?.total ?? 0.0;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push(
        '/employees/${employee.id}/payments',
        extra: {
          'name': employee.name,
          'gender': employee.gender,
          'photoUrl': employee.employeePhotoUrl,
        },
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.secondary200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(children: [
          GenderAvatar(
            radius: 24,
            photoUrl: employee.employeePhotoUrl,
            gender: employee.gender,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(employee.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15, fontFamily: 'Inter')),
                  const SizedBox(height: 2),
                  Text(employee.employeeCode,
                      style: const TextStyle(
                          color: AppColors.primary500, fontSize: 12, fontWeight: FontWeight.w600)),
                  if (employee.departmentName != null) ...[
                    const SizedBox(height: 2),
                    Text(employee.departmentName!,
                        style: const TextStyle(color: AppColors.secondary400, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('This Month',
                style: TextStyle(color: AppColors.secondary400, fontSize: 10)),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: monthTotal > 0 ? AppColors.success50 : AppColors.secondary100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                AppUtils.CurrencyUtils.format(monthTotal),
                style: TextStyle(
                  color: monthTotal > 0 ? AppColors.success600 : AppColors.secondary400,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}
