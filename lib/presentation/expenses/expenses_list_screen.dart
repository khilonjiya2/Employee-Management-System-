import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;

final expensesProvider = StateNotifierProvider.autoDispose<ExpensesNotifier, AsyncValue<List<ExpenseModel>>>((ref) {
  return ExpensesNotifier(ref.watch(expenseRepositoryProvider), ref.watch(supabaseProvider), ref.watch(currentProfileProvider).valueOrNull);
});

class ExpensesNotifier extends StateNotifier<AsyncValue<List<ExpenseModel>>> {
  final ExpenseRepository _repo;
  final dynamic _client;
  final ProfileModel? _profile;

  ExpensesNotifier(this._repo, this._client, this._profile) : super(const AsyncLoading()) {
    load();
  }

  Future<void> load({String? status, String? category}) async {
    try {
      String? supervisorId;
      if (_profile?.isSupervisor == true) {
        final sup = await _client.from('supervisors').select('id').eq('profile_id', _profile!.id).maybeSingle();
        supervisorId = sup?['id'] as String?;
      }
      final data = await _repo.getAll(supervisorId: supervisorId, status: status, category: category);
      state = AsyncData(data);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  void refresh() => load();
}

class ExpensesListScreen extends ConsumerStatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  ConsumerState<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends ConsumerState<ExpensesListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        final statuses = [null, 'pending', 'approved', 'rejected'];
        ref.read(expensesProvider.notifier).load(status: statuses[_tabController.index]);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref.watch(expensesProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          if (profile?.isSupervisor == true)
            IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => context.push('/expenses/new')),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: expenses.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) => list.isEmpty
            ? w.EmptyState(
                title: 'No expenses found',
                icon: Icons.receipt_long_outlined,
                actionLabel: profile?.isSupervisor == true ? 'Submit Expense' : null,
                onAction: profile?.isSupervisor == true ? () => context.push('/expenses/new') : null,
              )
            : RefreshIndicator(
                onRefresh: () async => ref.read(expensesProvider.notifier).refresh(),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ExpenseCard(
                    expense: list[i],
                    isAdmin: profile?.isAdmin == true,
                    onTap: () => context.push('/expenses/${list[i].id}'),
                  ),
                ),
              ),
      ),
      floatingActionButton: profile?.isSupervisor == true
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/expenses/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Expense'),
            )
          : null,
    );
  }
}

class _ExpenseCard extends ConsumerWidget {
  final ExpenseModel expense;
  final bool isAdmin;
  final VoidCallback onTap;

  const _ExpenseCard({required this.expense, required this.isAdmin, required this.onTap});

  IconData get _categoryIcon {
    switch (expense.category) {
      case 'travel': return Icons.directions_car_outlined;
      case 'fuel': return Icons.local_gas_station_outlined;
      case 'food': return Icons.restaurant_outlined;
      case 'material': return Icons.inventory_outlined;
      case 'labour': return Icons.engineering_outlined;
      default: return Icons.receipt_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_categoryIcon, color: AppColors.primary500, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(expense.expenseName, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${StringUtils.capitalize(expense.category)} • ${DateFormat('dd/MM/yyyy').format(expense.expenseDate)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (expense.supervisorName != null)
                    Text(expense.supervisorName!, style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(CurrencyUtils.format(expense.amount), style: theme.textTheme.titleMedium?.copyWith(color: AppColors.primary600)),
                const SizedBox(height: 4),
                w.StatusBadge(status: expense.status),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ExpenseFormScreen extends ConsumerStatefulWidget {
  final String? expenseId;
  const ExpenseFormScreen({super.key, this.expenseId});

  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime _expenseDate = DateTime.now();
  String _category = 'travel';
  List<File> _attachments = [];
  File? _receipt;
  bool _isLoading = false;

  bool get isEditing => widget.expenseId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadExpense());
    }
  }

  Future<void> _loadExpense() async {
    final exp = await ref.read(expenseRepositoryProvider).getById(widget.expenseId!);
    if (exp == null || !mounted) return;
    _nameController.text = exp.expenseName;
    _descController.text = exp.description ?? '';
    _amountController.text = exp.amount.toString();
    _expenseDate = exp.expenseDate;
    _category = exp.category;
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickFiles({bool isReceipt = false}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      allowMultiple: !isReceipt,
    );
    if (result == null) return;

    if (isReceipt && result.files.isNotEmpty) {
      setState(() => _receipt = File(result.files.first.path!));
    } else {
      setState(() => _attachments.addAll(result.files.map((f) => File(f.path!)).toList()));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final client = ref.read(supabaseProvider);
      final profile = ref.read(currentProfileProvider).valueOrNull;

      final sup = await client.from('supervisors').select('id').eq('profile_id', profile!.id).maybeSingle();
      final supervisorId = sup?['id'] as String?;
      if (supervisorId == null) throw Exception('Supervisor not found');

      final data = {
        'supervisor_id': supervisorId,
        'expense_date': DateFormat('yyyy-MM-dd').format(_expenseDate),
        'category': _category,
        'expense_name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'amount': double.parse(_amountController.text),
        'status': 'pending',
      };

      final repo = ref.read(expenseRepositoryProvider);
      ExpenseModel expense;
      if (isEditing) {
        expense = await repo.update(widget.expenseId!, data);
      } else {
        expense = await repo.create(data);
      }

      if (_receipt != null) {
  final bytes = await _receipt!.readAsBytes();
  final ext = _receipt!.path.split('.').last.toLowerCase();

  String mimeType;

  if (ext == 'jpg' || ext == 'jpeg') {
    mimeType = 'image/jpeg';
  } else if (ext == 'png') {
    mimeType = 'image/png';
  } else if (ext == 'pdf') {
    mimeType = 'application/pdf';
  } else {
    mimeType = 'application/octet-stream';
  }

  await repo.uploadAttachment(
    expense.id,
    bytes,
    'receipt.$ext',
    mimeType,
    isReceipt: true,
  );
}

      for (final att in _attachments) {
        final bytes = await att.readAsBytes();
        final name = att.path.split('/').last;
        final mimeType = name.endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
        await repo.uploadAttachment(expense.id, bytes, name, mimeType);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEditing ? 'Expense updated' : 'Expense submitted'), backgroundColor: AppColors.success500),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error500),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Expense' : 'New Expense')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Expense Date *', prefixIcon: Icon(Icons.calendar_today_outlined)),
                  child: Text(DateFormat('dd MMMM yyyy').format(_expenseDate)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category *', prefixIcon: Icon(Icons.category_outlined)),
                items: AppConstants.expenseCategories.map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(StringUtils.capitalize(c)),
                )).toList(),
                onChanged: (v) => setState(() => _category = v ?? 'travel'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Expense Name *', prefixIcon: Icon(Icons.receipt_outlined)),
                validator: (v) => ValidationUtils.validateRequired(v, 'Expense name'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description_outlined)),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount (₹) *', prefixIcon: Icon(Icons.currency_rupee_rounded)),
                validator: ValidationUtils.validateAmount,
              ),
              const SizedBox(height: 24),
              Text('Receipt', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _buildAttachmentButton(
                label: _receipt != null ? 'Receipt: ${_receipt!.path.split('/').last}' : 'Upload Receipt',
                icon: Icons.attach_file_rounded,
                onTap: () => _pickFiles(isReceipt: true),
                attached: _receipt != null,
              ),
              const SizedBox(height: 16),
              Text('Additional Attachments', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ..._attachments.asMap().entries.map((e) => _buildAttachmentChip(e.value, e.key)),
              _buildAttachmentButton(
                label: 'Add Attachment',
                icon: Icons.attach_file_rounded,
                onTap: () => _pickFiles(),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEditing ? 'Update Expense' : 'Submit Expense'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentButton({required String label, required IconData icon, required VoidCallback onTap, bool attached = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: attached ? AppColors.success50 : AppColors.secondary50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: attached ? AppColors.success500 : AppColors.secondary200, style: BorderStyle.solid),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: attached ? AppColors.success600 : AppColors.secondary500),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(color: attached ? AppColors.success700 : AppColors.secondary600, fontSize: 14, fontFamily: 'Inter'))),
            if (attached) const Icon(Icons.check_circle_rounded, color: AppColors.success500, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentChip(File file, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary200),
      ),
      child: Row(
        children: [
          const Icon(Icons.attach_file_rounded, size: 14, color: AppColors.primary600),
          const SizedBox(width: 6),
          Expanded(child: Text(file.path.split('/').last, style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: AppColors.primary700), overflow: TextOverflow.ellipsis)),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.secondary500),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: () => setState(() => _attachments.removeAt(index)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _expenseDate = date);
  }
}

class ExpenseDetailScreen extends ConsumerWidget {
  final String id;
  const ExpenseDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<ExpenseModel?>(
      future: ref.read(expenseRepositoryProvider).getById(id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        final exp = snapshot.data;
        if (exp == null) return const Scaffold(body: Center(child: Text('Not found')));

        final profile = ref.watch(currentProfileProvider).valueOrNull;
        final isAdmin = profile?.isAdmin == true;
        final isSupervisorOwner = exp.supervisorId == ref.watch(currentProfileProvider).valueOrNull?.id;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Expense Details'),
            actions: [
              if (exp.isPending && !isAdmin)
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/expenses/$id/edit')),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, exp),
                const SizedBox(height: 16),
                _buildInfoSection(context, exp),
                if (exp.attachments?.isNotEmpty == true) ...[
                  const SizedBox(height: 16),
                  _buildAttachments(context, exp),
                ],
                if (exp.adminRemarks != null) ...[
                  const SizedBox(height: 16),
                  _buildAdminRemarks(context, exp),
                ],
                if (isAdmin && exp.isPending) ...[
                  const SizedBox(height: 24),
                  _buildAdminActions(context, ref, exp),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, ExpenseModel exp) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exp.expenseName, style: theme.textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(StringUtils.capitalize(exp.category), style: theme.textTheme.bodySmall),
                if (exp.supervisorName != null) Text('By: ${exp.supervisorName}', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(CurrencyUtils.format(exp.amount), style: theme.textTheme.headlineLarge?.copyWith(color: AppColors.primary600)),
              const SizedBox(height: 4),
              w.StatusBadge(status: exp.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(BuildContext context, ExpenseModel exp) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Details', style: theme.textTheme.titleMedium),
          const Divider(),
          _Row(label: 'Date', value: DateFormat('dd MMMM yyyy').format(exp.expenseDate)),
          _Row(label: 'Category', value: StringUtils.capitalize(exp.category)),
          if (exp.description != null) _Row(label: 'Description', value: exp.description!),
          _Row(label: 'Submitted', value: DateFormat('dd/MM/yyyy HH:mm').format(exp.createdAt)),
          if (exp.reviewedAt != null) _Row(label: 'Reviewed', value: DateFormat('dd/MM/yyyy HH:mm').format(exp.reviewedAt!)),
        ],
      ),
    );
  }

  Widget _buildAttachments(BuildContext context, ExpenseModel exp) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attachments', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...exp.attachments!.map((att) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.secondary200),
          ),
          child: Row(
            children: [
              Icon(att.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_outlined, color: AppColors.primary500, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(att.fileName ?? 'Attachment', style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis)),
              if (att.isReceipt) Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.success100, borderRadius: BorderRadius.circular(4)),
                child: const Text('Receipt', style: TextStyle(color: AppColors.success700, fontSize: 10, fontFamily: 'Inter')),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildAdminRemarks(BuildContext context, ExpenseModel exp) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: exp.isRejected ? AppColors.error50 : AppColors.success50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
  color: exp.isRejected
      ? AppColors.error100
      : AppColors.success100,
),
),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Admin Remarks', style: theme.textTheme.labelMedium?.copyWith(color: exp.isRejected ? AppColors.error600 : AppColors.success600)),
          const SizedBox(height: 4),
          Text(exp.adminRemarks!, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildAdminActions(BuildContext context, WidgetRef ref, ExpenseModel exp) {
    final _remarksController = TextEditingController();

    Future<void> _handleAction(bool approve) async {
      String? remarks;
      if (!approve) {
        final result = await showDialog<String>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Rejection Reason'),
            content: TextField(
              controller: _remarksController,
              decoration: const InputDecoration(hintText: 'Enter reason for rejection...'),
              maxLines: 3,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.pop(context, _remarksController.text.trim()),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error500),
                child: const Text('Reject'),
              ),
            ],
          ),
        );
        if (result == null || result.isEmpty) return;
        remarks = result;
      }

      final profile = ref.read(currentProfileProvider).valueOrNull;
      if (profile == null) return;

      try {
        if (approve) {
          await ref.read(expenseRepositoryProvider).approve(exp.id, profile.id, remarks: remarks);
        } else {
          await ref.read(expenseRepositoryProvider).reject(exp.id, profile.id, remarks: remarks!);
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(approve ? 'Expense approved' : 'Expense rejected'),
              backgroundColor: approve ? AppColors.success500 : AppColors.error500,
            ),
          );
          context.pop();
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error500),
          );
        }
      }
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error500),
            label: const Text('Reject', style: TextStyle(color: AppColors.error500)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.error500)),
            onPressed: () => _handleAction(false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success500),
            onPressed: () => _handleAction(true),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: Theme.of(context).textTheme.labelMedium)),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
