import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;

final _supervisorEmployeesProvider = FutureProvider.autoDispose
    .family<List<EmployeeModel>, String>((ref, supervisorId) async {
  final client = ref.read(supabaseProvider);
  final rows = await client
      .from('supervisor_employees')
      .select('employee_id')
      .eq('supervisor_id', supervisorId);

  final ids = (rows as List).map((r) => r['employee_id'] as String).toList();
  if (ids.isEmpty) return [];

  final data = await client
      .from('employees')
      .select('*, departments(name), locations(name)')
      .inFilter('id', ids)
      .order('name');

  return (data as List).map((e) => EmployeeModel.fromJson(e)).toList();
});

class SupervisorEmployeesScreen extends ConsumerWidget {
  final String supervisorId;
  const SupervisorEmployeesScreen({super.key, required this.supervisorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeesAsync = ref.watch(_supervisorEmployeesProvider(supervisorId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Employees'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: employeesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (employees) {
          if (employees.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline_rounded,
                      size: 56, color: AppColors.secondary300),
                  SizedBox(height: 12),
                  Text('No employees assigned yet',
                      style: TextStyle(color: AppColors.secondary500)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () =>
                ref.refresh(_supervisorEmployeesProvider(supervisorId).future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: employees.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final emp = employees[i];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.secondary200),
                  ),
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: w.GenderAvatar(
                      radius: 22,
                      photoUrl: emp.employeePhotoUrl,
                      gender: emp.gender,
                    ),
                    title: Text(
                      emp.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${emp.employeeCode}'
                      '${emp.designation != null ? ' · ${emp.designation}' : ''}'
                      '${emp.departmentName != null ? '\n${emp.departmentName}' : ''}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.secondary500),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: emp.status == 'active'
                            ? AppColors.success50
                            : AppColors.secondary100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        emp.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: emp.status == 'active'
                              ? AppColors.success600
                              : AppColors.secondary500,
                        ),
                      ),
                    ),
                    onTap: () => context.push('/employees/${emp.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
