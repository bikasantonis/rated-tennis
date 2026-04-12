import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/providers/auth_provider.dart';
import 'package:rated/providers/biometric_provider.dart';
import 'package:rated/router/app_router.dart';
import 'package:rated/services/biometric_service.dart';

/// Shown on cold start when a Supabase session has been restored from storage.
/// Requires biometric or device-credential authentication before allowing access
/// to the rest of the app.
///
/// If the device has no biometric / credential enrolled, the screen auto-unlocks
/// so the user is not blocked.
class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() =>
      _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _isAuthenticating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Trigger on first frame so context / localizations are available.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryAuthenticate());
  }

  Future<void> _tryAuthenticate() async {
    final available = await BiometricService.instance.isAvailable();
    if (!mounted) return;

    if (!available) {
      // Device has no enrolled biometric — skip the lock transparently.
      ref.read(biometricUnlockedProvider.notifier).state = true;
      return;
    }

    await _authenticate();
  }

  Future<void> _authenticate() async {
    final l = AppLocalizations.of(context)!;
    setState(() {
      _isAuthenticating = true;
      _error = null;
    });

    final success =
        await BiometricService.instance.authenticate(l.biometricBody);

    if (!mounted) return;
    setState(() => _isAuthenticating = false);

    if (success) {
      ref.read(biometricUnlockedProvider.notifier).state = true;
      // Router will rebuild and redirect away from /lock automatically.
    } else {
      setState(() => _error = l.biometricError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fingerprint,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  l.biometricTitle,
                  style: tt.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l.biometricBody,
                  style: tt.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: tt.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 32),
                if (_isAuthenticating)
                  const CircularProgressIndicator()
                else
                  FilledButton.icon(
                    onPressed: _authenticate,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(l.biometricAuthenticate),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () async {
                    await ref.read(authActionsProvider.notifier).signOut();
                    if (mounted) {
                      // biometricUnlocked stays false; router redirects to onboarding.
                    }
                  },
                  child: Text(l.actionSignOut),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
