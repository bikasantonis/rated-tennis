import 'package:flutter/material.dart';

import 'package:rated/theme/app_theme.dart';

const _streakOrange = Color(0xFFFF6B00);

class WinStreakBadge extends StatelessWidget {
  const WinStreakBadge({required this.streak, super.key});

  final int streak;

  @override
  Widget build(BuildContext context) {
    if (streak < 2) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _streakOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: _streakOrange.withValues(alpha: 0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            '$streak',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _streakOrange,
            ),
          ),
        ],
      ),
    );
  }
}
