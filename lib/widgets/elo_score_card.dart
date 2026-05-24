import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:rated/models/court_theme.dart';
import 'package:rated/models/profile.dart';
import 'package:rated/providers/profile_provider.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/widgets/court_painter.dart';
import 'package:rated/widgets/elo_sparkline.dart';
import 'package:rated/widgets/tier_badge.dart';
import 'package:rated/widgets/tier_progress_bar.dart';
import 'package:rated/widgets/win_streak_badge.dart';

class EloScoreCard extends ConsumerWidget {
  const EloScoreCard({
    required this.profile,
    this.accentColor = AppColors.primary,
    this.winStreak = 0,
    this.courtTheme,
    super.key,
  });

  final Profile profile;
  final Color accentColor;
  final int winStreak;
  final CourtTheme? courtTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final historyAsync = ref.watch(eloHistoryProvider(profile.id));

    final sparklinePoints = historyAsync.maybeWhen(
      data: (rows) {
        final sorted = [...rows]
          ..sort((a, b) => (a['created_at'] as String)
              .compareTo(b['created_at'] as String));
        return sorted
            .map((r) => (r['elo_after'] as num).toDouble())
            .toList();
      },
      orElse: () => <double>[],
    );

    final onCourt = courtTheme != null;
    // When on a coloured court, all chrome flips to white for contrast.
    final effectiveAccent = onCourt ? Colors.white : accentColor;
    final textColor = onCourt ? Colors.white : null;
    final dividerColor = onCourt
        ? Colors.white.withValues(alpha: 0.30)
        : cs.outlineVariant;

    final content = Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  profile.eloRating.toStringAsFixed(1),
                  style: GoogleFonts.barlowCondensed(
                    fontSize: 72,
                    fontWeight: FontWeight.w700,
                    color: effectiveAccent,
                    height: 1,
                  ),
                ),
              ),
              if (winStreak >= 2)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: WinStreakBadge(streak: winStreak),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TierBadge(tier: profile.eloTier),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(
                label: 'Played',
                value: profile.matchesPlayed.toString(),
                textColor: textColor,
              ),
              _Stat(
                label: 'Won',
                value: profile.matchesWon.toString(),
                textColor: textColor,
              ),
              _Stat(
                label: 'Win %',
                value: profile.matchesPlayed == 0
                    ? '—'
                    : '${(profile.matchesWon / profile.matchesPlayed * 100).round()}%',
                textColor: textColor,
              ),
            ],
          ),
          if (sparklinePoints.length >= 2) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: dividerColor),
            const SizedBox(height: 12),
            EloSparkline(eloPoints: sparklinePoints, accentColor: effectiveAccent),
          ],
          const SizedBox(height: 12),
          TierProgressBar(
            tier: profile.eloTier,
            eloRating: profile.eloRating,
            accentColor: effectiveAccent,
          ),
        ],
      ),
    );

    if (!onCourt) {
      return Card(child: content);
    }

    // Court theme active: CustomPaint fills the card surface; content floats on top.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: CourtPainter(courtTheme!)),
          ),
          content,
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.textColor});

  final String label;
  final String value;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(value, style: tt.titleLarge?.copyWith(color: textColor)),
        Text(
          label,
          style: tt.bodySmall?.copyWith(
            color: textColor?.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}
