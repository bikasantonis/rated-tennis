import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rated/providers/auth_provider.dart';
import 'package:rated/providers/locale_provider.dart';

part 'locale_sync_provider.g.dart';

/// Keeps the app language and `profiles.preferred_language` in agreement, so a
/// player's choice follows them to a new phone or browser instead of being
/// stranded in that device's SharedPreferences.
///
/// This device wins when the player has picked a language here — including from
/// the toggle on the onboarding / login screen, before a profile is in hand —
/// and that pick is pushed up to the profile. With no local pick the profile's
/// stored language is adopted, which is what makes the preference cross-device.
///
/// Watched from `RatedApp` so it runs for the whole session.
@Riverpod(keepAlive: true)
void localeSync(Ref ref) {
  ref.listen(
    currentProfileProvider,
    (_, next) {
      final profile = next.asData?.value;
      if (profile == null) return;
      _reconcile(ref, profile.id, profile.preferredLanguage);
    },
    fireImmediately: true,
  );
}

Future<void> _reconcile(Ref ref, String playerId, String remote) async {
  final explicit = await hasExplicitLocaleChoice();
  if (!ref.mounted) return;

  if (!explicit) {
    ref.read(localeProvider.notifier).adoptProfileLocale(remote);
    return;
  }

  final local = ref.read(localeProvider).languageCode;
  if (local == remote) return;

  try {
    await Supabase.instance.client
        .from('profiles')
        .update({'preferred_language': local})
        .eq('id', playerId);
  } catch (error) {
    // Best effort — the app language is already correct on this device, and the
    // next profile load re-attempts the push.
    assert(() {
      debugPrint('[locale sync] failed to push preferred_language: $error');
      return true;
    }());
  }
}
