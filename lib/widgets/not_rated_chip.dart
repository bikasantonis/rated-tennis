import 'package:flutter/material.dart';
import 'package:rated/theme/app_colors.dart';

/// Grey pill shown on a match tile in place of the ELO delta when the match was
/// ELO-excluded (`match_results.elo_excluded`).
///
/// A friendly match between players more than 1.5 tiers apart is voided by
/// `apply_elo_changes` (migration 019 §9): it still counts as Played, but no
/// rating moves and no `elo_history` row is written — so without this chip the
/// tile shows nothing at all where a delta would be.
///
/// Long-pressing reveals the reason.
class NotRatedChip extends StatelessWidget {
  const NotRatedChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'This match did not affect ratings — the gap between '
          'players exceeds 1.5 tiers.',
      triggerMode: TooltipTriggerMode.longPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.outline.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'Not rated',
          style: TextStyle(
            color: AppColors.outline,
            fontWeight: FontWeight.w500,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
