import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:rated/models/notification_item.dart';
import 'package:rated/providers/notification_panel_provider.dart';
import 'package:rated/theme/app_colors.dart';

/// Opens a compact notification panel anchored to the top-right corner,
/// just below the AppBar. Marks all visible notifications as read on open.
Future<void> showNotificationPanel(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'notifications',
    barrierColor: Colors.black.withValues(alpha: 0.15),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, a1, a2) => const _NotificationPanelDialog(),
    transitionBuilder: (ctx, anim, a2, child) {
      final curved =
          CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0.08, 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------------

class _NotificationPanelDialog extends ConsumerStatefulWidget {
  const _NotificationPanelDialog();

  @override
  ConsumerState<_NotificationPanelDialog> createState() =>
      _NotificationPanelDialogState();
}

class _NotificationPanelDialogState
    extends ConsumerState<_NotificationPanelDialog> {
  @override
  void initState() {
    super.initState();
    // Mark all read once the panel opens (after first frame so the provider
    // has already rendered the badge with the unread count).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationActionsProvider.notifier).markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifAsync = ref.watch(notificationsProvider);
    final mq = MediaQuery.of(context);
    // Position just below the status bar + AppBar (~56 dp typical height).
    final topOffset = mq.padding.top + kToolbarHeight;

    return Align(
      alignment: Alignment.topRight,
      child: Padding(
        padding: EdgeInsets.only(top: topOffset, right: 8),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.surface,
          child: SizedBox(
            width: 320,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: mq.size.height * 0.55,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PanelHeader(
                    onMarkAll: () => ref
                        .read(notificationActionsProvider.notifier)
                        .markAllRead(),
                  ),
                  const Divider(height: 1),
                  Flexible(
                    child: notifAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Could not load notifications.'),
                      ),
                      data: (items) => items.isEmpty
                          ? const _EmptyState()
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: items.length,
                              separatorBuilder: (_, i) =>
                                  const Divider(height: 1, indent: 56),
                              itemBuilder: (_, i) =>
                                  _NotificationTile(item: items[i]),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.onMarkAll});
  final VoidCallback onMarkAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Text(
            'Notifications',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          TextButton(
            onPressed: onMarkAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Mark all read',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item});
  final NotificationItem item;

  static final _dateFmt = DateFormat('d MMM, HH:mm');

  IconData _icon() => switch (item.type) {
        'match_submitted' => Icons.sports_tennis,
        'match_disputed' => Icons.warning_amber_outlined,
        'match_request_received' => Icons.calendar_today_outlined,
        'match_request_responded' => Icons.check_circle_outline,
        _ => Icons.notifications_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;

    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: unread
            ? AppColors.primaryContainer
            : AppColors.surfaceVariant,
        child: Icon(
          _icon(),
          size: 18,
          color: unread ? AppColors.primary : AppColors.outline,
        ),
      ),
      title: Text(
        item.title,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: unread ? FontWeight.w600 : FontWeight.normal,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item.body,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.outline),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _dateFmt.format(item.createdAt.toLocal()),
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: AppColors.outline),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    );
  }
}

// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const Icon(Icons.notifications_none, size: 40, color: AppColors.outline),
          const SizedBox(height: 8),
          Text(
            'No notifications yet.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.outline),
          ),
        ],
      ),
    );
  }
}
