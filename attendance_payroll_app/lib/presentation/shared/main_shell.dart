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

  int _calculateIndex(
    String location,
    bool isAdmin,
  ) {
    final items = isAdmin
        ? [
            '/dashboard',
            '/employees',
            '/supervisors',
            '/attendance',
            '/expenses',
          ]
        : [
            '/dashboard',
            '/attendance',
            '/expenses',
            '/reports',
          ];

    for (int i = 0; i < items.length; i++) {
      if (location.startsWith(items[i])) {
        return i;
      }
    }

    return 0;
  }

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final profile =
        ref.watch(currentProfileProvider).valueOrNull;

    final isAdmin = profile?.isAdmin ?? false;

    final adminItems = [
      const _NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard_rounded,
        label: 'Dashboard',
        path: '/dashboard',
      ),
      const _NavItem(
        icon: Icons.people_outline_rounded,
        activeIcon: Icons.people_rounded,
        label: 'Employees',
        path: '/employees',
      ),
      const _NavItem(
        icon: Icons.supervisor_account_outlined,
        activeIcon: Icons.supervisor_account_rounded,
        label: 'Supervisors',
        path: '/supervisors',
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

    final items =
        isAdmin ? adminItems : supervisorItems;

    final location =
        GoRouterState.of(context).matchedLocation;

    final selectedIndex =
        _calculateIndex(location, isAdmin);

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
        backgroundColor:
            Theme.of(context).colorScheme.surface,
        indicatorColor: AppColors.primary100,
        labelBehavior:
            NavigationDestinationLabelBehavior
                .alwaysShow,
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