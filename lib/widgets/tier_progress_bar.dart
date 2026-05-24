import 'package:flutter/material.dart';

import 'package:rated/models/profile.dart';
import 'package:rated/theme/app_theme.dart';
import 'package:rated/widgets/tier_badge.dart';

class TierProgressBar extends StatelessWidget {
  const TierProgressBar({
    required this.tier,
    required this.eloRating,
    required this.accentColor,
    super.key,
  });

  final EloTier tier;
  final double eloRating;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final next = tier.nextTier;

    if (next == null) {
      // Max tier — show full bar with "Elite" label
      return Row(
        children: [
          TierBadge(tier: tier, small: true),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusGlobal),
              child: LinearProgressIndicator(
                value: 1.0,
                color: accentColor,
                backgroundColor: accentColor.withValues(alpha: 0.12),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Elite',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
        ],
      );
    }

    final start = tier.threshold;
    final end = next.threshold;
    final progress = ((eloRating - start) / (end - start)).clamp(0.0, 1.0);

    return Row(
      children: [
        TierBadge(tier: tier, small: true),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusGlobal),
            child: LinearProgressIndicator(
              value: progress,
              color: accentColor,
              backgroundColor: accentColor.withValues(alpha: 0.12),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        TierBadge(tier: next, small: true),
      ],
    );
  }
}
