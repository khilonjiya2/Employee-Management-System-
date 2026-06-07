import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/app_models.dart';
import '../../data/repositories/auth_repository.dart';
import '../shared/widgets.dart' as w;

final notificationsProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  final client = ref.watch(supabaseProvider);
  final user = client.auth.currentUser;

  if (user == null) return [];

  final data = await client
      .from('notifications')
      .select()
      .eq('user_id', user.id)
      .order('created_at', ascending: false)
      .limit(50);

  return (data as List)
      .map((n) => NotificationModel.fromJson(n as Map<String, dynamic>))
      .toList();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final client = ref.watch(supabaseProvider);
  final user = client.auth.currentUser;

  if (user == null) return 0;

  final res = await client
      .from('notifications')
      .select('id')
      .eq('user_id', user.id)
      .eq('is_read', false);

  return (res as List).length;
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              final client = ref.read(supabaseProvider);
              final user = client.auth.currentUser;

              if (user == null) return;

              await client
                  .from('notifications')
                  .update({'is_read': true})
                  .eq('user_id', user.id);

              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: notifications.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (e, _) => Center(
          child: Text('Error: $e'),
        ),
        data: (list) => list.isEmpty
            ? const w.EmptyState(
                title: 'No notifications',
                subtitle: 'You\'re all caught up!',
                icon: Icons.notifications_none_rounded,
              )
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final n = list[i];

                  return ListTile(
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: n.isRead
                            ? AppColors.secondary100
                            : AppColors.primary100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIcon(n.type),
                        color: n.isRead
                            ? AppColors.secondary400
                            : AppColors.primary500,
                        size: 22,
                      ),
                    ),
                    title: Text(
                      n.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight:
                            n.isRead ? FontWeight.w400 : FontWeight.w600,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.body,
                          style: theme.textTheme.bodySmall,
                        ),
                        Text(
                          _formatTime(n.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.secondary400,
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    tileColor: n.isRead
                        ? null
                        : AppColors.primary50.withOpacity(0.5),
                    onTap: () async {
                      if (!n.isRead) {
                        await ref
                            .read(supabaseProvider)
                            .from('notifications')
                            .update({'is_read': true})
                            .eq('id', n.id);

                        ref.invalidate(notificationsProvider);
                        ref.invalidate(unreadCountProvider);
                      }
                    },
                  );
                },
              ),
      ),
    );
  }

  IconData _getIcon(String? type) {
    switch (type) {
      case 'expense_approved':
        return Icons.check_circle_rounded;
      case 'expense_rejected':
        return Icons.cancel_rounded;
      case 'attendance':
        return Icons.calendar_today_rounded;
      case 'expense':
        return Icons.receipt_long_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }

    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }

    if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    }

    return '${dt.day}/${dt.month}/${dt.year}';
  }
}