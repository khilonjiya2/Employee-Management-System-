import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/utils/app_utils.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';

// ── Advance amount page (select supervisor + enter amount) ─────────────────

class AdvancePaymentScreen extends ConsumerStatefulWidget {
  /// If provided, pre-selects a supervisor (from supervisor detail screen)
  final String? supervisorId;
  const AdvancePaymentScreen({super.key, this.supervisorId});

  @override
  ConsumerState<AdvancePaymentScreen> createState() => _AdvancePaymentScreenState();
}

class _AdvancePaymentScreenState extends ConsumerState<AdvancePaymentScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _selectedSupervisorId;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _selectedSupervisorId = widget.supervisorId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedSupervisorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a supervisor')));
      return;
    }
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
        supervisorId: _selectedSupervisorId!,
        amount: amount,
        note: _noteController.text.trim().isEmpty ? 'Advance Payment' : _noteController.text.trim(),
        createdBy: profile!.id,
      );
      ref.invalidate(supervisorWalletProvider(_selectedSupervisorId!));
      ref.invalidate(supervisorWalletsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Advance of ${CurrencyUtils.format(amount)} given successfully'),
            backgroundColor: AppColors.success500,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error500));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final supervisorsAsync = ref.watch(supervisorWalletsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Advance Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Supervisor selector (or fixed if pre-selected)
          supervisorsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (wallets) {
              if (widget.supervisorId != null) {
                final w = wallets.firstWhere(
                  (w) => w.supervisorId == widget.supervisorId,
                  orElse: () => wallets.first,
                );
                return _WalletInfoCard(wallet: w);
              }
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Select Supervisor',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                ...wallets.map((w) => RadioListTile<String>(
                  value: w.supervisorId,
                  groupValue: _selectedSupervisorId,
                  title: Text(w.supervisorName ?? ''),
                  subtitle: Text('${w.supervisorCode} · Balance: ${CurrencyUtils.format(w.balance)}'),
                  onChanged: (v) => setState(() => _selectedSupervisorId = v),
                  contentPadding: EdgeInsets.zero,
                )),
              ]);
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Amount *',
              prefixIcon: Icon(Icons.currency_rupee_rounded),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              prefixIcon: Icon(Icons.note_outlined),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Give Advance'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _WalletInfoCard extends StatelessWidget {
  final SupervisorWalletModel wallet;
  const _WalletInfoCard({required this.wallet});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary200),
      ),
      child: Row(children: [
        const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary500),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(wallet.supervisorName ?? '', style: const TextStyle(
              fontWeight: FontWeight.w700, fontFamily: 'Inter')),
          Text(wallet.supervisorCode ?? '', style: const TextStyle(
              color: AppColors.secondary500, fontSize: 12)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          const Text('Balance', style: TextStyle(fontSize: 11, color: AppColors.secondary500)),
          Text(CurrencyUtils.format(wallet.balance),
              style: const TextStyle(fontWeight: FontWeight.w700,
                  color: AppColors.success600, fontSize: 16, fontFamily: 'Inter')),
        ]),
      ]),
    );
  }
}

// ── Supervisor Wallet Detail Screen ────────────────────────────────────────

class SupervisorWalletScreen extends ConsumerWidget {
  final String supervisorId;
  final String? supervisorName;
  const SupervisorWalletScreen({
    super.key,
    required this.supervisorId,
    this.supervisorName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(supervisorWalletProvider(supervisorId));
    final ledgerAsync = ref.watch(_walletLedgerProvider(supervisorId));
    final isAdmin = ref.read(currentUserRoleProvider) == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(supervisorName != null ? '$supervisorName · Wallet' : 'Wallet'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Give Advance',
              onPressed: () => context.push('/advance-payment/$supervisorId'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(supervisorWalletProvider(supervisorId));
          ref.invalidate(_walletLedgerProvider(supervisorId));
        },
        child: CustomScrollView(slivers: [
          // Balance card
          SliverToBoxAdapter(
            child: walletAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => const SizedBox.shrink(),
              data: (wallet) => _BalanceSummaryCard(wallet: wallet),
            ),
          ),
          // Ledger
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text('Transaction History',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700)),
            ),
          ),
          ledgerAsync.when(
            loading: () => const SliverToBoxAdapter(
                child: Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator()))),
            error: (e, _) => SliverToBoxAdapter(child: Center(child: Text('$e'))),
            data: (ledger) => ledger.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No transactions yet',
                          style: TextStyle(color: AppColors.secondary400))),
                    ))
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

final _walletLedgerProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, supervisorId) async {
  return ref.read(walletRepositoryProvider).getWalletLedger(supervisorId);
});

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
        gradient: LinearGradient(
          colors: [AppColors.primary500, AppColors.primary600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Available Balance',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
        const SizedBox(height: 4),
        Text(CurrencyUtils.format(balance),
            style: const TextStyle(color: Colors.white, fontSize: 28,
                fontWeight: FontWeight.w800, fontFamily: 'Inter')),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _MiniStat(
            label: 'Total Given',
            value: CurrencyUtils.format(advanced),
            color: Colors.greenAccent,
          )),
          Expanded(child: _MiniStat(
            label: 'Total Used',
            value: CurrencyUtils.format(deducted),
            color: Colors.orangeAccent,
          )),
        ]),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(color: Colors.white60, fontSize: 11)),
      Text(value, style: TextStyle(color: color,
          fontWeight: FontWeight.w700, fontSize: 14, fontFamily: 'Inter')),
    ],
  );
}

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
    IconData icon;
    String sign;
    if (isAdvance) {
      statusColor = AppColors.success500;
      icon = Icons.arrow_downward_rounded;
      sign = '+';
    } else if (status == 'approved') {
      statusColor = AppColors.error500;
      icon = Icons.arrow_upward_rounded;
      sign = '-';
    } else if (status == 'rejected') {
      statusColor = AppColors.secondary400;
      icon = Icons.undo_rounded;
      sign = '+';
    } else {
      statusColor = const Color(0xFFF59E0B);
      icon = Icons.hourglass_empty_rounded;
      sign = '~';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.secondary200),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: statusColor),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(note, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Text(
            '${isAdvance ? 'Advance' : 'Expense'} · ${DateUtils.formatDate(date)} · ${status.toUpperCase()}',
            style: const TextStyle(fontSize: 11, color: AppColors.secondary400),
          ),
        ])),
        Text(
          '$sign${CurrencyUtils.format(amount)}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: statusColor,
            fontSize: 14,
            fontFamily: 'Inter',
          ),
        ),
      ]),
    );
  }
}

// ── All Supervisors Wallet List (Admin view) ────────────────────────────────

class SupervisorWalletsListScreen extends ConsumerWidget {
  const SupervisorWalletsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletsAsync = ref.watch(supervisorWalletsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advance Payments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Give Advance',
            onPressed: () => context.push('/advance-payment'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(supervisorWalletsProvider),
        child: walletsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (wallets) => wallets.isEmpty
              ? const Center(child: Text('No wallet records yet',
                  style: TextStyle(color: AppColors.secondary400)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: wallets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final w = wallets[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.push(
                          '/supervisors/${w.supervisorId}/wallet',
                          extra: w.supervisorName),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.secondary200),
                        ),
                        child: Row(children: [
                          CircleAvatar(
                            backgroundColor: AppColors.primary100,
                            child: Text(
                              (w.supervisorName ?? '?')[0].toUpperCase(),
                              style: const TextStyle(color: AppColors.primary600,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(w.supervisorName ?? '',
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(w.supervisorCode ?? '',
                                  style: const TextStyle(fontSize: 12,
                                      color: AppColors.secondary400)),
                            ],
                          )),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(CurrencyUtils.format(w.balance),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success600,
                                    fontSize: 16, fontFamily: 'Inter')),
                            const Text('Balance',
                                style: TextStyle(fontSize: 11,
                                    color: AppColors.secondary400)),
                          ]),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline_rounded,
                                color: AppColors.primary500),
                            onPressed: () => context.push(
                                '/advance-payment/${w.supervisorId}'),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
