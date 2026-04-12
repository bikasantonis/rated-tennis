import 'package:flutter/material.dart';

import 'package:rated/models/profile.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/theme/app_theme.dart';

class TierBadge extends StatelessWidget {
  const TierBadge({required this.tier, super.key, this.small = false});

  final EloTier tier;
  final bool small;

  Color get _fill => switch (tier) {
        EloTier.beginner => AppColors.tierBeginner,
        EloTier.bronze => AppColors.tierBronze,
        EloTier.silver => AppColors.tierSilver,
        EloTier.gold => AppColors.tierGold,
        EloTier.platinum => AppColors.tierPlatinum,
        EloTier.elite => AppColors.tierElite,
      };

  Color get _textColor => tier == EloTier.beginner
      ? AppColors.tierBeginnerText
      : AppColors.tierBadgeText;

  @override
  Widget build(BuildContext context) {
    final fontSize = small ? 11.0 : 13.0;
    final padding = small
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 4);

    return Semantics(
      label: '${tier.label} tier',
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: _fill,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        child: Text(
          tier.label,
          style: TextStyle(
            color: _textColor,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
