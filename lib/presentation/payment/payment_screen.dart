import 'package:flutter/material.dart';

import '../supervisors/supervisor_wallet_screen.dart' show SupervisorPaymentTabBody;
import '../employees/employee_payment_list_screen.dart' show EmployeePaymentTabBody;

/// Replaces the old standalone "Advance" dashboard destination
/// (AdvancePaymentScreen) as the single "Payment" entry point, with two
/// tabs:
///   - Supervisors: exactly the same search+list+Add/Edit Advance flow as
///     before, unchanged — just relocated under a tab.
///   - Employees: the new employee payment picker, leading to
///     EmployeePaymentScreen's month/year-scoped payment history.
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payment'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Supervisors'),
              Tab(text: 'Employees'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SupervisorPaymentTabBody(),
            EmployeePaymentTabBody(),
          ],
        ),
      ),
    );
  }
}
