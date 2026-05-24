import 'package:flutter/material.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rated/models/court_theme.dart';
import 'package:rated/models/profile.dart';
import 'package:rated/providers/auth_provider.dart';
import 'package:rated/providers/locale_provider.dart';
import 'package:rated/providers/location_provider.dart';
import 'package:rated/providers/organizer_request_provider.dart';
import 'package:rated/providers/profile_provider.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/utils/legal_urls.dart';
import 'package:rated/widgets/court_painter.dart';
import 'package:rated/widgets/error_state_widget.dart';

/// SCR-13 — Settings: language, organiser request, account management.
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
        error: (e, _) => const ErrorStateWidget(),
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

            // ── Appearance ──────────────────────────────────────────────
            _SectionHeader(title: l.settingsSectionAppearance),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CourtThemePicker(profile: profile, ref: ref),
            ),

            const Divider(),

            // ── Location ────────────────────────────────────────────────
            _SectionHeader(title: l.settingsSectionLocation),
            _LocationSection(playerId: profile?.id),

            const Divider(),

            // ── Organiser ───────────────────────────────────────────────
            _SectionHeader(title: l.settingsOrganizerSection),
            _OrganizerTile(profile: profile),

            const Divider(),

            // ── Legal ───────────────────────────────────────────────────
            _SectionHeader(title: l.settingsSectionLegal),
            ListTile(
              leading: const Icon(Icons.policy_outlined, color: AppColors.primary),
              title: const Text('Privacy Policy'),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () => LegalUrls.open(LegalUrls.privacyPolicy),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_outlined, color: AppColors.primary),
              title: Text(l.settingsTermsOfUse),
              trailing: const Icon(Icons.open_in_new, size: 16),
              onTap: () => LegalUrls.open(LegalUrls.termsOfUse),
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

// ── Organiser request tile ────────────────────────────────────────────────────

class _OrganizerTile extends ConsumerWidget {
  const _OrganizerTile({required this.profile});
  final Profile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final role = profile?.role;

    // Already an organiser or admin — nothing to request.
    if (role == UserRole.organizer || role == UserRole.admin) {
      return ListTile(
        leading:
            const Icon(Icons.verified_outlined, color: AppColors.eloGain),
        title: Text(l.settingsIsOrganizer),
        subtitle: Text(l.settingsIsOrganizerSub),
      );
    }

    final requestAsync = ref.watch(myOrganizerRequestProvider);

    return requestAsync.when(
      loading: () => const ListTile(
        leading: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('…'),
      ),
      error: (e, _) => ListTile(
        leading: const Icon(Icons.error_outline, color: AppColors.error),
        title: Text(l.errorGeneric),
      ),
      data: (request) {
        final status = request?['status'] as String?;

        if (status == 'pending') {
          return ListTile(
            leading: const Icon(Icons.hourglass_top_outlined,
                color: AppColors.primary),
            title: Text(l.settingsOrganizerRequestPending),
            subtitle: Text(l.settingsOrganizerRequestPendingSub),
          );
        }

        // Denied or no request yet — show the request button.
        return ListTile(
          leading:
              const Icon(Icons.manage_accounts_outlined, color: AppColors.primary),
          title: Text(l.settingsRequestOrganizer),
          subtitle: Text(status == 'denied'
              ? l.settingsOrganizerRequestDenied
              : l.settingsRequestOrganizerSub),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _confirmAndSubmit(context, ref, l),
        );
      },
    );
  }

  Future<void> _confirmAndSubmit(
      BuildContext context, WidgetRef ref, AppLocalizations l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsOrganizerRequestConfirmTitle),
        content: Text(l.settingsOrganizerRequestConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.settingsRequestOrganizer),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await ref
        .read(organizerRequestActionsProvider.notifier)
        .submitRequest();
    if (!context.mounted) return;

    final st = ref.read(organizerRequestActionsProvider);
    if (st is AsyncData) {
      ref.invalidate(myOrganizerRequestProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.settingsOrganizerRequestSuccess)),
      );
    } else if (st is AsyncError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(st.error.toString())),
      );
    }
  }
}

// ── Shared section header ─────────────────────────────────────────────────────

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

// ── Location section ──────────────────────────────────────────────────────────

class _LocationSection extends ConsumerWidget {
  const _LocationSection({required this.playerId});
  final String? playerId;

  static const _radii = [25, 50, 100, 150];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final prefsAsync = ref.watch(locationPrefsProvider);
    final actionState = ref.watch(locationActionsProvider);
    final isLoading = actionState is AsyncLoading;

    return prefsAsync.when(
      loading: () => const ListTile(
        leading: SizedBox(
            width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
        title: Text('…'),
      ),
      error: (e, _) => ListTile(
        leading: const Icon(Icons.error_outline, color: AppColors.error),
        title: Text(l.errorGeneric),
      ),
      data: (prefs) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Master consent toggle
          SwitchListTile(
            secondary: Icon(
              Icons.location_on_outlined,
              color: prefs.locationConsent ? AppColors.primary : AppColors.outline,
            ),
            title: Text(l.settingsLocationEnable),
            subtitle: Text(prefs.locationConsent
                ? (prefs.homeCity ?? l.settingsLocationUnknownArea)
                : l.settingsLocationEnableSub),
            value: prefs.locationConsent,
            onChanged: isLoading || playerId == null
                ? null
                : (on) => on
                    ? _showConsentSheet(context, ref, l)
                    : _confirmRevoke(context, ref, l),
          ),

          // Sub-options visible only when consent is active
          if (prefs.locationConsent) ...[
            // Nearby-tournament notifications toggle
            SwitchListTile(
              secondary: const Icon(Icons.notifications_outlined,
                  color: AppColors.primary),
              title: Text(l.settingsLocationNotifyNearby),
              subtitle: Text(l.settingsLocationNotifyNearbySub),
              value: prefs.notifyNearbyTournaments,
              onChanged: isLoading
                  ? null
                  : (v) => ref
                      .read(locationActionsProvider.notifier)
                      .setNotifyNearby(v),
            ),

            // Radius picker
            ListTile(
              leading: const Icon(Icons.radar, color: AppColors.primary),
              title: Text(l.settingsLocationRadius),
              trailing: DropdownButton<int>(
                value: prefs.nearbyRadiusKm,
                underline: const SizedBox.shrink(),
                items: _radii
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(l.settingsLocationRadiusKm(r)),
                        ))
                    .toList(),
                onChanged: isLoading
                    ? null
                    : (v) {
                        if (v != null) {
                          ref
                              .read(locationActionsProvider.notifier)
                              .setRadius(v);
                        }
                      },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showConsentSheet(
      BuildContext context, WidgetRef ref, AppLocalizations l) async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LocationConsentSheet(),
    );
    if (accepted != true || !context.mounted) return;

    await ref.read(locationActionsProvider.notifier).grantConsent();
    if (!context.mounted) return;

    final st = ref.read(locationActionsProvider);
    if (st is AsyncError) {
      final msg = _locationErrorMessage(st.error, l);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _confirmRevoke(
      BuildContext context, WidgetRef ref, AppLocalizations l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.settingsLocationRevokeTitle),
        content: Text(l.settingsLocationRevokeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(l.settingsLocationRevokeConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(locationActionsProvider.notifier).revokeConsent();
  }

  String _locationErrorMessage(Object error, AppLocalizations l) {
    final s = error.toString().toLowerCase();
    if (s.contains('service') || s.contains('disabled')) {
      return l.locationServiceDisabled;
    }
    if (s.contains('denied') || s.contains('permission')) {
      return l.locationPermissionDenied;
    }
    return l.errorGeneric;
  }
}

// ── Location consent bottom sheet ─────────────────────────────────────────────

class _LocationConsentSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sheet handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.outline.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              Text(l.settingsLocationConsentTitle,
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          Text(l.settingsLocationConsentBody,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          // GDPR data-minimisation note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              l.settingsLocationConsentPrivacyNote,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.primary),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(l.actionDecline),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(l.settingsLocationConsentAccept),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Court theme picker ────────────────────────────────────────────────────────

class _CourtThemePicker extends StatelessWidget {
  const _CourtThemePicker({required this.profile, required this.ref});
  final Profile? profile;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final currentKey = profile?.courtTheme ?? 'roland_garros';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l.settingsCourtTheme,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: CourtTheme.all.length,
            separatorBuilder: (context, i) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final theme = CourtTheme.all[i];
              final selected = theme.dbKey == currentKey;
              return GestureDetector(
                onTap: profile == null
                    ? null
                    : () async {
                        await ref
                            .read(profileEditActionsProvider.notifier)
                            .updateCourtTheme(profile!.id, theme.dbKey);
                        ref.invalidate(currentProfileProvider);
                      },
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 60,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5.5),
                        child: CustomPaint(
                          painter: CourtPainter(theme),
                          size: const Size(80, 60),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 80,
                      child: Text(
                        theme.displayName,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: selected ? AppColors.primary : null,
                              fontWeight:
                                  selected ? FontWeight.w600 : null,
                            ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Language tile ─────────────────────────────────────────────────────────────

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
                ref
                    .read(localeProvider.notifier)
                    .setLocale(Locale(picked));
                await ref
                    .read(profileEditActionsProvider.notifier)
                    .updateLanguage(playerId!, picked);
                ref.invalidate(currentProfileProvider);
              }
            },
    );
  }
}
