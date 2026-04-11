import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rated/models/notification_item.dart';

// ---------------------------------------------------------------------------
// Fetch notifications for the current user (newest first, last 30)
// ---------------------------------------------------------------------------

final notificationsProvider =
    FutureProvider<List<NotificationItem>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  final rows = await Supabase.instance.client
      .from('notifications')
      .select()
      .eq('recipient_id', user.id)
      .order('created_at', ascending: false)
      .limit(30);

  return (rows as List)
      .map((r) => NotificationItem.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ---------------------------------------------------------------------------
// Unread count (derived from the list above)
// ---------------------------------------------------------------------------

final unreadCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsProvider).asData?.value ?? [];
  return notifs.where((n) => !n.isRead).length;
});

// ---------------------------------------------------------------------------
// Mark all notifications read
// ---------------------------------------------------------------------------

final notificationActionsProvider =
    NotifierProvider<NotificationActions, void>(NotificationActions.new);

class NotificationActions extends Notifier<void> {
  @override
  void build() {}

  SupabaseClient get _db => Supabase.instance.client;

  Future<void> markAllRead() async {
    final user = _db.auth.currentUser;
    if (user == null) return;

    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', user.id)
        .eq('is_read', false);

    ref.invalidate(notificationsProvider);
  }

  Future<void> markRead(String notificationId) async {
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);

    ref.invalidate(notificationsProvider);
  }
}
