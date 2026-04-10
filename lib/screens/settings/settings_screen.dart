import 'package:flutter/material.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rated/providers/auth_provider.dart';
import 'package:rated/providers/locale_provider.dart';
import 'package:rated/providers/profile_provider.dart';
import 'package:rated/theme/app_colors.dart';

/// SCR-13 — Settings: language, notifications, account management.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) => ListView(
          children: [
            // ── Language ────────────────────────────────────────────────
            _SectionHeader(title: l.settingsSectionLanguage),
            _LanguageTile(
              current: profile?.preferredLanguage ?? 'en',
              playerId: profile?.id,
              ref: ref,
            ),

            const Divider(),

            // ── Account ─────────────────────────────────────────────────
            _SectionHeader(title: l.settingsSectionAccount),
            ListTile(
              leading: const Icon(Icons.lock_outline, color: AppColors.primary),
              title: Text(l.settingsChangePassword),
              onTap: () => _changePassword(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.primary),
              title: Text(l.actionSignOut),
              onTap: () => _signOut(context, ref),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: Text(l.settingsDeleteAccount,
                  style: const TextStyle(color: AppColors.error)),
              subtitle: Text(l.settingsDeleteAccountSubtitle),
              onTap: () => _confirmDelete(context, ref, profile?.id),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context)!;
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? errorText;

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.settingsChangePasswordDialogTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l.settingsChangePasswordNew,
                ),
                onChanged: (_) => setState(() => errorText = null),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l.settingsChangePasswordConfirm,
                  errorText: errorText,
                ),
                onChanged: (_) => setState(() => errorText = null),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.actionCancel),
            ),
            FilledButton(
              onPressed: () {
                final pw = newCtrl.text.trim();
                final confirm = confirmCtrl.text.trim();
                if (pw.length < 8) {
                  setState(() => errorText = l.settingsChangePasswordTooShort);
                  return;
                }
                if (pw != confirm) {
                  setState(() => errorText = l.settingsChangePasswordMismatch);
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(l.actionSave),
            ),
          ],
        ),
      ),
    );

    if (submitted != true || !context.mounted) return;

    try {
      await ref
          .read(authActionsProvider.notifier)
          .changePassword(newCtrl.text.trim());
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.settingsChangePasswordSuccess)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      newCtrl.dispose();
      confirmCtrl.dispose();
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    await ref.read(authActionsProvider.notifier).signOut();
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, String? playerId) async {
    if (playerId == null) return;
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsDeleteAccountTitle),
        content: Text(l.settingsDeleteAccountBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.actionCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l.actionDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(authActionsProvider.notifier).anonymiseAccount();
    if (context.mounted) {
      await ref.read(authActionsProvider.notifier).signOut();
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile(
      {required this.current, required this.playerId, required this.ref});
  final String current;
  final String? playerId;
  final WidgetRef ref;

  static const _langs = [
    (code: 'en', label: 'English'),
    (code: 'el', label: 'Ελληνικά'),
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final label =
        _langs.firstWhere((lang) => lang.code == current, orElse: () => _langs[0]).label;

    return ListTile(
      leading: const Icon(Icons.language, color: AppColors.primary),
      title: Text(l.settingsLanguageLabel),
      trailing: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.primary)),
      onTap: playerId == null
          ? null
          : () async {
              final picked = await showDialog<String>(
                context: context,
                builder: (ctx) {
                  final dl = AppLocalizations.of(ctx)!;
                  return SimpleDialog(
                    title: Text(dl.settingsChooseLanguage),
                    children: _langs
                        .map((lang) => SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, lang.code),
                              child: Text(lang.label),
                            ))
                        .toList(),
                  );
                },
              );
              if (picked != null && picked != current) {
                // Update locale in app immediately
                ref
                    .read(localeProvider.notifier)
                    .setLocale(Locale(picked));
                // Persist to profile
                await ref
                    .read(profileEditActionsProvider.notifier)
                    .updateLanguage(playerId!, picked);
                ref.invalidate(currentProfileProvider);
              }
            },
    );
  }
}
