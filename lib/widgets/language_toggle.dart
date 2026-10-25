import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/providers/locale_provider.dart';

/// Compact `EN | ΕΛ` switch for the pre-auth screens (onboarding, login), where
/// Settings is out of reach and the app may have guessed the wrong language
/// right at the moment it asks for an email, a password and GDPR consent.
///
/// A segmented control rather than a menu: with two languages both fit, the
/// current one stays visible and switching costs a single tap.
class LanguageToggle extends ConsumerWidget {
  const LanguageToggle({super.key});

  static const _options = [
    (code: 'en', short: 'EN', name: 'English'),
    (code: 'el', short: 'ΕΛ', name: 'Ελληνικά'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider).languageCode;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: AppLocalizations.of(context)!.settingsChooseLanguage,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in _options)
              _Segment(
                label: option.short,
                tooltip: option.name,
                selected: option.code == current,
                onTap: option.code == current
                    ? null
                    : () => ref
                        .read(localeProvider.notifier)
                        .setLocale(Locale(option.code)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minWidth: 40, minHeight: 30),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.5,
                ),
          ),
        ),
      ),
    );
  }
}
