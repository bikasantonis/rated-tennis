import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'organizer_request_provider.g.dart';

SupabaseClient get _db => Supabase.instance.client;
String? get _uid => _db.auth.currentUser?.id;

/// The current user's most recent organiser request (any status).
/// Returns null if the user has never submitted one.
@riverpod
Future<Map<String, dynamic>?> myOrganizerRequest(Ref ref) async {
  final uid = _uid;
  if (uid == null) return null;
  final result = await _db
      .from('organizer_requests')
      .select('id, status, created_at, decided_at')
      .eq('player_id', uid)
      .order('created_at', ascending: false)
      .limit(1)
      .maybeSingle();
  return result;
}

/// All pending organiser requests — admin only (RLS enforces this).
@riverpod
Future<List<Map<String, dynamic>>> pendingOrganizerRequests(Ref ref) async {
  final results = await _db
      .from('organizer_requests')
      .select(
        'id, player_id, status, created_at, '
        'player:profiles!player_id(display_name, elo_rating, elo_tier)',
      )
      .eq('status', 'pending')
      .order('created_at', ascending: true);
  return List<Map<String, dynamic>>.from(results as List);
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

@riverpod
class OrganizerRequestActions extends _$OrganizerRequestActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  /// Player submits a request.  The DB trigger notifies all admins.
  Future<void> submitRequest() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db.from('organizer_requests').insert({'player_id': _uid!});
    });
  }

  /// Admin approves or denies a request.
  /// The DB trigger updates profiles.role (if approved) and notifies the player.
  Future<void> decideRequest(String requestId, {required bool approve}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _db.from('organizer_requests').update({
        'status': approve ? 'approved' : 'denied',
        'decided_by': _uid!,
        'decided_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);
    });
  }
}
