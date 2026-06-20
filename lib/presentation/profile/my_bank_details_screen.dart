import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../data/repositories/auth_repository.dart';

/// Item 22: lets a logged-in employee or supervisor edit their OWN
/// UPI / bank details, instead of needing an admin to do it for them.
class MyBankDetailsScreen extends ConsumerStatefulWidget {
  const MyBankDetailsScreen({super.key});

  @override
  ConsumerState<MyBankDetailsScreen> createState() => _MyBankDetailsScreenState();
}

class _MyBankDetailsScreenState extends ConsumerState<MyBankDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _upiController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankIfscController = TextEditingController();
  final _bankNameController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _table; // 'employees' or 'supervisors'
  String? _recordId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _upiController.dispose();
    _bankAccountController.dispose();
    _bankIfscController.dispose();
    _bankNameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null) return;
    final client = ref.read(supabaseProvider);

    try {
      if (profile.role == 'supervisor') {
        final row = await client
            .from('supervisors')
            .select('id, upi_id, bank_account_number, bank_ifsc, bank_name')
            .eq('profile_id', profile.id)
            .maybeSingle();
        if (row != null) {
          _table = 'supervisors';
          _recordId = row['id'] as String;
          _upiController.text = row['upi_id'] as String? ?? '';
          _bankAccountController.text = row['bank_account_number'] as String? ?? '';
          _bankIfscController.text = row['bank_ifsc'] as String? ?? '';
          _bankNameController.text = row['bank_name'] as String? ?? '';
        }
      } else {
        final row = await client
            .from('employees')
            .select('id, upi_id, bank_account_number, bank_ifsc, bank_name')
            .eq('profile_id', profile.id)
            .maybeSingle();
        if (row != null) {
          _table = 'employees';
          _recordId = row['id'] as String;
          _upiController.text = row['upi_id'] as String? ?? '';
          _bankAccountController.text = row['bank_account_number'] as String? ?? '';
          _bankIfscController.text = row['bank_ifsc'] as String? ?? '';
          _bankNameController.text = row['bank_name'] as String? ?? '';
        }
      }
    } catch (_) {}

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _table == null || _recordId == null) return;
    setState(() => _isSaving = true);
    try {
      final client = ref.read(supabaseProvider);
      await client.from(_table!).update({
        'upi_id': _upiController.text.trim().isEmpty ? null : _upiController.text.trim(),
        'bank_account_number': _bankAccountController.text.trim().isEmpty ? null : _bankAccountController.text.trim(),
        'bank_ifsc': _bankIfscController.text.trim().isEmpty ? null : _bankIfscController.text.trim().toUpperCase(),
        'bank_name': _bankNameController.text.trim().isEmpty ? null : _bankNameController.text.trim(),
      }).eq('id', _recordId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bank details updated'), backgroundColor: AppColors.success500),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ErrorUtils.friendly(e)), backgroundColor: AppColors.error500),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Bank Details')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _recordId == null
              ? const Center(child: Text('Could not find your record. Contact your admin.'))
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'This information is used to pay your salary/expenses directly via UPI or bank transfer.',
                        style: TextStyle(color: AppColors.secondary500, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _upiController,
                        decoration: const InputDecoration(
                            labelText: 'UPI ID',
                            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                            hintText: 'yourname@bank'),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bankAccountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Bank Account Number',
                            prefixIcon: Icon(Icons.account_balance_outlined)),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bankIfscController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                            labelText: 'IFSC Code',
                            prefixIcon: Icon(Icons.numbers_outlined)),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bankNameController,
                        decoration: const InputDecoration(
                            labelText: 'Bank Name',
                            prefixIcon: Icon(Icons.business_outlined)),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _save,
                          child: _isSaving
                              ? const SizedBox(
                                  height: 20, width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}