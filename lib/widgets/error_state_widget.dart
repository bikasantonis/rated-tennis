import 'package:flutter/material.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/theme/app_colors.dart';

class ErrorStateWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const ErrorStateWidget({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              l.errorGeneric,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l.actionRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
