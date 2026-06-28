import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;

final employeesProvider = StateNotifierProvider.autoDispose<EmployeesNotifier,
    AsyncValue<List<EmployeeModel>>>((ref) {
  return EmployeesNotifier(ref.watch(employeeRepositoryProvider));
});

class EmployeesNotifier
    extends StateNotifier<AsyncValue<List<EmployeeModel>>> {
  final EmployeeRepository _repo;
  String _search = '';
  String? _status;
  int _page = 0;
  bool _hasMore = true;
  final List<EmployeeModel> _items = [];

  EmployeesNotifier(this._repo) : super(const AsyncLoading()) {
    load();
  }

  Future<void> load({bool reset = false}) async {
    if (reset) {
      _page = 0;
      _hasMore = true;
      _items.clear();
    }
    if (!_hasMore) return;

    try {
      final data = await _repo.getAll(
          search: _search, status: _status, page: _page);
      _items.addAll(data);
      _hasMore = data.length == 20;
      _page++;
      state = AsyncData(List.from(_items));
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void search(String query) {
    _search = query;
    load(reset: true);
  }

  void filterStatus(String? status) {
    _status = status;
    load(reset: true);
  }

  void refresh() => load(reset: true);
}

class EmployeesListScreen extends ConsumerStatefulWidget {
  final String? initialStatus;
  const EmployeesListScreen({super.key, this.initialStatus});

  @override
  ConsumerState<EmployeesListScreen> createState() =>
      _EmployeesListScreenState();
}

class _EmployeesListScreenState extends ConsumerState<EmployeesListScreen> {
  final _searchController = TextEditingController();
  String? _selectedStatus;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialStatus != null) {
      _selectedStatus = widget.initialStatus;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(employeesProvider.notifier).filterStatus(widget.initialStatus);
      });
    }
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        ref.read(employeesProvider.notifier).load();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(employeesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        actions: [
          PopupMenuButton<String?>(
            icon: Icon(
              Icons.filter_list_rounded,
              color: _selectedStatus != null ? AppColors.primary500 : null,
            ),
            tooltip: 'Filter by status',
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              setState(() => _selectedStatus = value);
              ref.read(employeesProvider.notifier).filterStatus(value);
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem<String?>(value: null, checked: _selectedStatus == null, child: const Text('All')),
              CheckedPopupMenuItem<String?>(value: 'active', checked: _selectedStatus == 'active', child: const Text('Active')),
              CheckedPopupMenuItem<String?>(value: 'inactive', checked: _selectedStatus == 'inactive', child: const Text('Inactive')),
            ],
          ),
          TextButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Employee'),
            onPressed: () => context.push('/employees/new'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: w.SearchBar(
              controller: _searchController,
              hint: 'Search employees...',
              onChanged: (v) =>
                  ref.read(employeesProvider.notifier).search(v),
              onClear: () {
                _searchController.clear();
                ref.read(employeesProvider.notifier).search('');
              },
            ),
          ),
          if (_selectedStatus != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  FilterChip(
                    label: Text(
                      'Status: $_selectedStatus',
                      style: const TextStyle(
                        color: AppColors.primary700,
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    backgroundColor: AppColors.primary50,
                    selectedColor: AppColors.primary100,
                    selected: true,
                    deleteIconColor: AppColors.primary600,
                    onDeleted: () {
                      setState(() => _selectedStatus = null);
                      ref
                          .read(employeesProvider.notifier)
                          .filterStatus(null);
                    },
                    onSelected: (_) {},
                  ),
                ],
              ),
            ),
          Expanded(
            child: employees.when(
              loading: () => _buildShimmer(),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (list) => list.isEmpty
                  ? w.EmptyState(
                      title: 'No employees found',
                      subtitle: 'Add employees to get started',
                      icon: Icons.people_outline_rounded,
                      actionLabel: 'Add Employee',
                      onAction: () => context.push('/employees/new'),
                    )
                  : RefreshIndicator(
                      onRefresh: () async =>
                          ref.read(employeesProvider.notifier).refresh(),
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) => _EmployeeCard(
                          employee: list[i],
                          onTap: () =>
                              context.push('/employees/${list[i].id}'),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter Employees',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Status', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['active', 'inactive'].map((s) {
                final isSelected = _selectedStatus == s;
                return FilterChip(
                  label: Text(
                    s,
                    style: TextStyle(
                      color: isSelected
                          ? AppColors.primary700
                          : AppColors.secondary600,
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary100,
                  backgroundColor: AppColors.secondary100,
                  checkmarkColor: AppColors.primary600,
                  onSelected: (v) {
                    Navigator.pop(context);
                    setState(() => _selectedStatus = v ? s : null);
                    ref
                        .read(employeesProvider.notifier)
                        .filterStatus(v ? s : null);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (_selectedStatus != null)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _selectedStatus = null);
                  ref
                      .read(employeesProvider.notifier)
                      .filterStatus(null);
                },
                child: const Text('Clear Filter',
                    style: TextStyle(color: AppColors.error500)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 8,
      itemBuilder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        height: 80,
        decoration: BoxDecoration(
          color: AppColors.secondary100,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  final EmployeeModel employee;
  final VoidCallback onTap;
  const _EmployeeCard({required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.secondary200),
        ),
        child: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(employee.name,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(employee.employeeCode,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.primary500)),
                  if (employee.designation != null) ...[
                    const SizedBox(height: 2),
                    Text(employee.designation!,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                w.StatusBadge(status: employee.status),
                const SizedBox(height: 4),
                Text('\u{20B9}${employee.dailyWageRate.toStringAsFixed(0)}/day',
                    style: theme.textTheme.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (employee.employeePhotoUrl != null) {
      return CircleAvatar(
          radius: 24,
          backgroundImage: NetworkImage(employee.employeePhotoUrl!));
    }
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.primary100,
      child: Text(
        employee.name.isNotEmpty ? employee.name[0].toUpperCase() : '?',
        style: const TextStyle(
            color: AppColors.primary600,
            fontWeight: FontWeight.w700,
            fontFamily: 'Inter'),
      ),
    );
  }
}