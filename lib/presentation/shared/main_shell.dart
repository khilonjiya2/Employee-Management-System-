import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/auth_repository.dart';

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({
    super.key,
    required this.child,
  });

  int _calculateIndex(String location, String role) {
    final items = _itemPaths(role);

    for (int i = 0; i < items.length; i++) {
      if (location.startsWith(items[i])) {
        return i;
      }
    }

    return role == 'admin' ? 1 : 0;
  }

  List<String> _itemPaths(String role) {
    if (role == 'admin') {
      return ['/employees', '/dashboard', '/supervisors'];
    }
    if (role == 'employee') {
      return ['/dashboard', '/notifications', '/settings'];
    }
    // supervisor (default)
    return ['/dashboard', '/attendance', '/expenses', '/reports'];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.valueOrNull;

    // Previously this defaulted to `?? 'supervisor'` whenever the profile
    // was still loading, so EVERY login — including admins and
    // employees — visibly flashed the supervisor nav bar
    // (Dashboard/Attendance/Expenses/Reports) for a moment before
    // swapping to the correct one once the real role arrived. Show a
    // plain loading scaffold with no nav bar at all instead, so nothing
    // incorrect is ever shown even briefly — the nav only renders once
    // the role is actually confirmed.
    if (profile == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final role = profile.role;

    final adminItems = [
      const _NavItem(
        icon: Icons.people_outline_rounded,
        activeIcon: Icons.people_rounded,
        label: 'Employees',
        path: '/employees',
      ),
      const _NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Dashboard',
        path: '/dashboard',
      ),
      const _NavItem(
        icon: Icons.supervisor_account_outlined,
        activeIcon: Icons.supervisor_account_rounded,
        label: 'Supervisors',
        path: '/supervisors',
      ),
    ];

    final supervisorItems = [
      const _NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Dashboard',
        path: '/dashboard',
      ),
      const _NavItem(
        icon: Icons.calendar_today_outlined,
        activeIcon: Icons.calendar_today_rounded,
        label: 'Attendance',
        path: '/attendance',
      ),
      const _NavItem(
        icon: Icons.receipt_long_outlined,
        activeIcon: Icons.receipt_long_rounded,
        label: 'Expenses',
        path: '/expenses',
      ),
      const _NavItem(
        icon: Icons.bar_chart_rounded,
        activeIcon: Icons.bar_chart_rounded,
        label: 'Reports',
        path: '/reports',
      ),
    ];

    // Employee gets a minimal, self-contained nav: their dashboard already
    // shows attendance + payroll history inline, so they only need
    // Dashboard, Notifications, and Settings \u{2014} not the supervisor-only
    // screens (Attendance/Expenses/Reports), which query by supervisor_id
    // and would break or show nothing meaningful for an employee profile.
    final employeeItems = [
      const _NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Dashboard',
        path: '/dashboard',
      ),
      const _NavItem(
        icon: Icons.notifications_outlined,
        activeIcon: Icons.notifications_rounded,
        label: 'Notifications',
        path: '/notifications',
      ),
      const _NavItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: 'Settings',
        path: '/settings',
      ),
    ];

    final items = role == 'admin'
        ? adminItems
        : role == 'employee'
            ? employeeItems
            : supervisorItems;

    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _calculateIndex(location, role);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          context.go(items[index].path);
        },
        destinations: items
            .map(
              (item) => NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.activeIcon),
                label: item.label,
              ),
            )
            .toList(),
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: AppColors.primary100,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}