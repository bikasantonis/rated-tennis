import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rated/providers/auth_provider.dart';
import 'package:rated/providers/match_provider.dart';

part 'realtime_sync_provider.g.dart';

/// Live cross-device updates via Supabase Realtime (Postgres Changes).
///
/// One channel per signed-in user. Every event is treated as a "something
/// changed" signal: the payload is ignored and the affected providers are
/// invalidated, so data is always refetched through RLS-checked PostgREST —
/// the same path as a manual refresh. The tables must be in the
/// `supabase_realtime` publication (migration 029).
///
/// Watched from `RatedApp` so it lives for the whole session. It rebuilds on
/// sign-in / sign-out through [authStateProvider]; `onDispose` removes the
/// previous user's channel so subscriptions never leak between sessions.
@Riverpod(keepAlive: true)
void realtimeSync(Ref ref) {
  final uid = ref.watch(authStateProvider).asData?.value?.user.id;
  if (uid == null) return;

  final client = Supabase.instance.client;

  // One confirmation fires several events (the match_results UPDATE, then two
  // profiles UPDATEs — the 028 counter trigger and apply_elo_changes), so a
  // burst is coalesced into a single refetch.
  Timer? debounce;
  var dirtyMatches = false;
  var dirtyRating = false;
  var dirtyRequests = false;

  void flush() {
    if (!ref.mounted) return;
    if (dirtyMatches || dirtyRating) {
      invalidateMatchViews(ref, includeRating: dirtyRating);
    }
    if (dirtyRequests) ref.invalidate(pendingRequestsProvider);
    dirtyMatches = dirtyRating = dirtyRequests = false;
  }

  void schedule({
    bool matches = false,
    bool rating = false,
    bool requests = false,
  }) {
    if (!ref.mounted) return;
    dirtyMatches |= matches;
    dirtyRating |= rating;
    dirtyRequests |= requests;
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), flush);
  }

  PostgresChangeFilter mine(String column) => PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: column,
        value: uid,
      );

  var subscribedOnce = false;

  final channel = client
      .channel('user-sync:$uid')
      // Own profile: Played / Won (028 trigger), ELO and tier
      // (apply_elo_changes), admin overrides, the 48 h auto-confirm cron.
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'profiles',
        filter: mine('id'),
        callback: (_) => schedule(matches: true, rating: true),
      )
      // Matches I play in. Postgres Changes filters cannot OR, hence one
      // binding per side.
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'match_results',
        filter: mine('winner_id'),
        callback: (_) => schedule(matches: true),
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'match_results',
        filter: mine('loser_id'),
        callback: (_) => schedule(matches: true),
      )
      // Challenges sent to me. DELETEs (a withdrawn challenge) do not match
      // this filter under the default replica identity — see migration 029.
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'match_requests',
        filter: mine('recipient_id'),
        callback: (_) => schedule(requests: true),
      )
      .subscribe((status, _) {
        if (status != RealtimeSubscribeStatus.subscribed) return;
        // Events are not replayed after a disconnect (app backgrounded, tab
        // asleep, network drop), so every re-subscribe refetches everything.
        if (subscribedOnce) schedule(matches: true, rating: true, requests: true);
        subscribedOnce = true;
      });

  ref.onDispose(() {
    debounce?.cancel();
    client.removeChannel(channel);
  });
}
