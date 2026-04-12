import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rated/models/notification_item.dart';
import 'package:rated/providers/auth_provider.dart';

// ---------------------------------------------------------------------------
// Fetch notifications for the current user (newest first, last 30)
// Real-time: Supabase .stream() pushes updates whenever a row is
// inserted or updated for this recipient.
// Scoped to auth state: stream is recreated on sign-in and disposed on
// sign-out to prevent subscription leaks between sessions.
// ---------------------------------------------------------------------------

final notificationsProvider =
    StreamProvider<List<NotificationItem>>((ref) {
  // Watch the session so this provider re-builds on sign-in / sign-out.
  final session = ref.watch(authStateProvider).asData?.value;
  final userId = session?.user.id;
  if (userId == null) return Stream.value([]);

  return Supabase.instance.client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('recipient_id', userId)
      .order('created_at', ascending: false)
      .limit(30)
      .map(
        (rows) => rows
            .map((r) => NotificationItem.fromJson(r))
            .toList(),
      );
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
    // Stream auto-updates via Supabase realtime — no invalidate needed.
  }

  Future<void> markRead(String notificationId) async {
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
    // Stream auto-updates via Supabase realtime — no invalidate needed.
  }
}
