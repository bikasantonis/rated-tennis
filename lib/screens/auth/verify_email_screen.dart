import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/providers/auth_provider.dart';

/// Shown when the authenticated user's email has not yet been confirmed.
/// Prompts the user to check their inbox and offers a resend button.
class VerifyEmailScreen extends ConsumerWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final tt = Theme.of(context).textTheme;
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.mark_email_unread_outlined,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  l.verifyEmailTitle,
                  style: tt.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l.verifyEmailBody(email),
                  style: tt.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: email.isEmpty
                      ? null
                      : () async {
                          try {
                            await Supabase.instance.client.auth.resend(
                              type: OtpType.signup,
                              email: email,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(l.verifyEmailResendSuccess),
                                ),
                              );
                            }
                          } catch (_) {}
                        },
                  child: Text(l.verifyEmailResend),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () =>
                      ref.read(authActionsProvider.notifier).signOut(),
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
