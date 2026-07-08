import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart' as AppUtils;
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' show GenderAvatar;

// ── Providers ──────────────────────────────────────────────────────────────

final _advanceSupervisorsProvider =
    FutureProvider.autoDispose<List<SupervisorModel>>((ref) async {
  return ref.read(supervisorRepositoryProvider).getAll(isActive: true);
});

final _walletLedgerProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, supervisorId) async {
  return ref.read(walletRepositoryProvider).getWalletLedger(supervisorId);
});

// ── Advance Payment Screen (supervisor list → select → add amount) ─────────

class AdvancePaymentScreen extends ConsumerStatefulWidget {
  final String? supervisorId;
  const AdvancePaymentScreen({super.key, this.supervisorId});

  @override
  ConsumerState<AdvancePaymentScreen> createState() =>
      _AdvancePaymentScreenState();
}

class _AdvancePaymentScreenState
    extends ConsumerState<AdvancePaymentScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    // If supervisorId pre-selected, go straight to that supervisor's wallet
    if (widget.supervisorId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.push('/supervisors/${widget.supervisorId}/wallet');
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
    final supervisorsAsync = ref.watch(_advanceSupervisorsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Advance Payment')),
      body: Column(children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search supervisor...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      })
                  : null,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (v) => setState(() => _search = v),
          ),
        ),
        Expanded(
          child: supervisorsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (supervisors) {
              final filtered = _search.isEmpty
                  ? supervisors
                  : supervisors
                      .where((s) =>
                          s.name.toLowerCase().contains(
                              _search.toLowerCase()) ||
                          s.supervisorCode.toLowerCase().contains(
                              _search.toLowerCase()))
                      .toList();

              if (filtered.isEmpty) {
                return const Center(
                    child: Text('No supervisors found',
                        style: TextStyle(
                            color: AppColors.secondary400)));
              }

              return RefreshIndicator(
                onRefresh: () async =>
                    ref.invalidate(_advanceSupervisorsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (_, i) =>
                      _SupervisorWalletTile(supervisor: filtered[i]),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _SupervisorWalletTile extends ConsumerWidget {
  final SupervisorModel supervisor;
  const _SupervisorWalletTile({required this.supervisor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync =
        ref.watch(supervisorWalletProvider(supervisor.id));
    final balance = walletAsync.valueOrNull?.balance ?? 0.0;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => context.push(
        '/supervisors/${supervisor.id}/wallet',
        extra: supervisor.name,
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
          // Avatar
          GenderAvatar(
            radius: 24,
            photoUrl: supervisor.profilePhotoUrl,
            gender: supervisor.gender,
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(supervisor.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          fontFamily: 'Inter')),
                  const SizedBox(height: 2),
                  Text(supervisor.supervisorCode,
                      style: const TextStyle(
                          color: AppColors.primary500,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  if (supervisor.assignedArea != null) ...[
                    const SizedBox(height: 2),
                    Text(supervisor.assignedArea!,
                        style: const TextStyle(
                            color: AppColors.secondary400,
                            fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ]),
          ),
          const SizedBox(width: 8),
          // Balance
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: balance > 0
                    ? AppColors.success50
                    : AppColors.secondary100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                AppUtils.CurrencyUtils.format(balance),
                style: TextStyle(
                  color: balance > 0
                      ? AppColors.success600
                      : AppColors.secondary400,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Text('Balance',
                style: TextStyle(
                    fontSize: 10,
                    color: AppColors.secondary400)),
          ]),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.secondary300, size: 20),
        ]),
      ),
    );
  }
}

// ── Supervisor Wallet Detail Screen ───────────────────────────────────────

class SupervisorWalletScreen extends ConsumerStatefulWidget {
  final String supervisorId;
  final String? supervisorName;
  const SupervisorWalletScreen({
    super.key,
    required this.supervisorId,
    this.supervisorName,
  });

  @override
  ConsumerState<SupervisorWalletScreen> createState() =>
      _SupervisorWalletScreenState();
}

class _SupervisorWalletScreenState
    extends ConsumerState<SupervisorWalletScreen> {
  dynamic _realtimeSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscribeRealtime());
  }

  void _subscribeRealtime() {
    final client = ref.read(supabaseProvider);
    _realtimeSub = client
        .channel('wallet_${widget.supervisorId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'supervisor_wallet',
          callback: (_) {
            ref.invalidate(supervisorWalletProvider(widget.supervisorId));
            ref.invalidate(_walletLedgerProvider(widget.supervisorId));
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'expenses',
          callback: (_) {
            ref.invalidate(supervisorWalletProvider(widget.supervisorId));
            ref.invalidate(_walletLedgerProvider(widget.supervisorId));
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    ref.read(supabaseProvider).removeChannel(_realtimeSub);
    super.dispose();
  }

  void _showAddAdvance() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _AddAdvanceSheet(
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
        onSuccess: () {
          ref.invalidate(supervisorWalletProvider(widget.supervisorId));
          ref.invalidate(_walletLedgerProvider(widget.supervisorId));
          ref.invalidate(supervisorWalletsProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync =
        ref.watch(supervisorWalletProvider(widget.supervisorId));
    final ledgerAsync =
        ref.watch(_walletLedgerProvider(widget.supervisorId));
    final isAdmin = ref.read(currentUserRoleProvider) == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.supervisorName ?? 'Wallet',
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        actions: [
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Advance'),
                onPressed: _showAddAdvance,
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(supervisorWalletProvider(widget.supervisorId));
          ref.invalidate(_walletLedgerProvider(widget.supervisorId));
        },
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: walletAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
              error: (_, __) => const SizedBox.shrink(),
              data: (wallet) => _BalanceSummaryCard(wallet: wallet),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Transaction History',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
          ledgerAsync.when(
            loading: () => const SliverToBoxAdapter(
                child: Center(
                    child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator()))),
            error: (e, _) =>
                SliverToBoxAdapter(child: Center(child: Text('$e'))),
            data: (ledger) => ledger.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                            child: Text('No transactions yet',
                                style: TextStyle(
                                    color: AppColors.secondary400)))))
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _LedgerTile(entry: ledger[i]),
                      childCount: ledger.length,
                    ),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ]),
      ),
    );
  }
}

// ── Add Advance Bottom Sheet ───────────────────────────────────────────────

class _AddAdvanceSheet extends ConsumerStatefulWidget {
  final String supervisorId;
  final String? supervisorName;
  final VoidCallback onSuccess;
  const _AddAdvanceSheet({
    required this.supervisorId,
    this.supervisorName,
    required this.onSuccess,
  });

  @override
  ConsumerState<_AddAdvanceSheet> createState() => _AddAdvanceSheetState();
}

class _AddAdvanceSheetState extends ConsumerState<_AddAdvanceSheet> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    setState(() => _loading = true);
    try {
      final profile = ref.read(currentProfileProvider).valueOrNull;
      await ref.read(walletRepositoryProvider).giveAdvance(
        supervisorId: widget.supervisorId,
        amount: amount,
        note: _noteController.text.trim().isEmpty
            ? 'Advance Payment'
            : _noteController.text.trim(),
        createdBy: profile!.id,
      );
      widget.onSuccess();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Advance of ${AppUtils.CurrencyUtils.format(amount)} given to ${widget.supervisorName ?? "supervisor"}'),
          backgroundColor: AppColors.success500,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error500));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.secondary300,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Text('Add Advance - ${widget.supervisorName ?? ""}',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFamily: 'Inter')),
        const SizedBox(height: 20),
        TextField(
          controller: _amountController,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Amount *',
            prefixIcon: const Icon(Icons.currency_rupee_rounded),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          decoration: InputDecoration(
            labelText: 'Note (optional)',
            prefixIcon: const Icon(Icons.note_outlined),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Give Advance'),
          ),
        ),
      ]),
    );
  }
}

// ── Balance Summary Card ──────────────────────────────────────────────────

class _BalanceSummaryCard extends StatelessWidget {
  final SupervisorWalletModel? wallet;
  const _BalanceSummaryCard({this.wallet});

  @override
  Widget build(BuildContext context) {
    final balance = wallet?.balance ?? 0;
    final advanced = wallet?.totalAdvanced ?? 0;
    final deducted = wallet?.totalDeducted ?? 0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1E40AF).withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Available Balance',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 4),
        Text(AppUtils.CurrencyUtils.format(balance),
            style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                fontFamily: 'Inter')),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: _MiniStat(
                  label: 'Total Given',
                  value: AppUtils.CurrencyUtils.format(advanced),
                  color: Colors.greenAccent)),
          Expanded(
              child: _MiniStat(
                  label: 'Total Used',
                  value: AppUtils.CurrencyUtils.format(deducted),
                  color: Colors.orangeAccent)),
        ]),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  const TextStyle(color: Colors.white60, fontSize: 11)),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  fontFamily: 'Inter')),
        ],
      );
}

// ── Ledger Tile ───────────────────────────────────────────────────────────

class _LedgerTile extends StatelessWidget {
  final Map<String, dynamic> entry;
  const _LedgerTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isAdvance = entry['type'] == 'advance';
    final status = entry['status'] as String;
    final amount = (entry['amount'] as num).toDouble();
    final date = entry['date'] as DateTime;
    final note = entry['note'] as String? ?? '';

    Color statusColor;
    Color bgColor;
    IconData icon;
    String sign;

    if (isAdvance) {
      statusColor = AppColors.success600;
      bgColor = AppColors.success50;
      icon = Icons.arrow_downward_rounded;
      sign = '+';
    } else if (status == 'approved') {
      statusColor = AppColors.error500;
      bgColor = const Color(0xFFFFF1F1);
      icon = Icons.check_rounded;
      sign = '-';
    } else if (status == 'rejected') {
      statusColor = AppColors.secondary500;
      bgColor = AppColors.secondary100;
      icon = Icons.undo_rounded;
      sign = '+';
    } else {
      // pending
      statusColor = const Color(0xFFF59E0B);
      bgColor = const Color(0xFFFFFBEB);
      icon = Icons.hourglass_empty_rounded;
      sign = '-';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.secondary200),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: bgColor, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: statusColor),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(note,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                '${isAdvance ? "Advance" : "Expense"} - ${AppUtils.DateUtils.formatDate(date)} - ${status.toUpperCase()}',
                style: const TextStyle(
                    fontSize: 11, color: AppColors.secondary400),
              ),
            ])),
        Text(
          '$sign${AppUtils.CurrencyUtils.format(amount)}',
          style: TextStyle(
              fontWeight: FontWeight.w700,
              color: statusColor,
              fontSize: 14,
              fontFamily: 'Inter'),
        ),
      ]),
    );
  }
}

// ── Supervisor Dashboard Wallet Card ─────────────────────────────────────

class SupervisorDashboardWalletCard extends ConsumerWidget {
  final String? supervisorId;
  const SupervisorDashboardWalletCard({super.key, this.supervisorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (supervisorId == null) return const SizedBox.shrink();
    final walletAsync = ref.watch(supervisorWalletProvider(supervisorId!));

    return walletAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (wallet) {
        final balance = wallet?.balance ?? 0;
        return GestureDetector(
          onTap: () => context.push('/supervisors/$supervisorId/wallet'),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A5F), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('Advance Balance',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 12)),
                    Text(AppUtils.CurrencyUtils.format(balance),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                            fontFamily: 'Inter')),
                  ])),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: const Text('View',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        );
      },
    );
  }
}
