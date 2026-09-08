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
import 'package:rated/widgets/tier_info_button.dart';
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

  // Court geometry — must mirror CourtPainter constants exactly.
  static const _lx  = 0.05;
  static const _lsx = 0.26;
  static const _cx  = 0.50;
  static const _rsx = 0.74;
  static const _tyD = 0.2826;
  static const _tyS = 0.3348;
  static const _csy = 0.5348;
  static const _byS = 0.7348;
  static const _byD = 0.7870;

  // Aspect ratio derived from real doubles-court proportions (23.77 m × 10.97 m = 2.167:1).
  // CourtPainter inner rect: width=(rx−lx)=0.90·cardW, height=(byD−tyD)=0.5044·cardH
  // → 0.90·cardW / (0.5044·cardH) = 2.167  →  cardW/cardH ≈ 1.214
  static const _aspect  = 1.214;
  static const _maxCardH = 360.0;

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

    // ── Standard (no court) layout ─────────────────────────────────────────
    if (courtTheme == null) {
      return Card(
        child: Padding(
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
                        color: accentColor,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TierBadge(tier: profile.eloTier),
                  if (profile.eloTier.nextTier != null) ...[
                    const SizedBox(width: 6),
                    TierInfoButton(
                      currentElo: profile.eloRating,
                      currentTier: profile.eloTier,
                      iconColor: accentColor.withValues(alpha: 0.65),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Stat(label: 'Played', value: profile.matchesPlayed.toString()),
                  _Stat(label: 'Won', value: profile.matchesWon.toString()),
                  _Stat(
                    label: 'Win %',
                    value: profile.matchesPlayed == 0
                        ? '—'
                        : '${(profile.matchesWon / profile.matchesPlayed * 100).round()}%',
                  ),
                ],
              ),
              if (sparklinePoints.length >= 2) ...[
                const SizedBox(height: 16),
                Divider(height: 1, color: cs.outlineVariant),
                const SizedBox(height: 12),
                EloSparkline(eloPoints: sparklinePoints, accentColor: accentColor),
              ],
              const SizedBox(height: 12),
              TierProgressBar(
                tier: profile.eloTier,
                eloRating: profile.eloRating,
                accentColor: accentColor,
              ),
            ],
          ),
        ),
      );
    }

    // ── Court-theme layout ─────────────────────────────────────────────────
    // Card dimensions are derived from available width so the inner court
    // rectangle matches real tennis-court proportions at every screen size.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardH = (constraints.maxWidth / _aspect).clamp(0.0, _maxCardH);
        final cardW = cardH * _aspect;

        // Outer bands: areas outside the court lines — no lines cross here.
        final topBandH    = _tyD * cardH;        // 0 → tyD·h
        final bottomBandH = (1 - _byD) * cardH;  // byD·h → h
        final hPad        = _lx * cardW;

        final eloFontSize = (topBandH * 0.55).clamp(28.0, 64.0);

        // Show sparkline only when the bottom band has enough vertical space.
        final sparklineH = (bottomBandH - 36).clamp(12.0, 36.0);
        final showSparkline = sparklinePoints.length >= 2 && bottomBandH >= 48;

        final winRatio = profile.matchesPlayed == 0
            ? '—'
            : '${(profile.matchesWon / profile.matchesPlayed * 100).round()}%';

        return Center(
          child: SizedBox(
            width: cardW,
            height: cardH,
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Court background
                  CustomPaint(painter: CourtPainter(courtTheme!)),

                  // ── Top outer band: ELO rating + tier + win streak ──────
                  Positioned(
                    left: hPad,
                    right: hPad,
                    top: topBandH * 0.08,
                    height: topBandH * 0.92,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                profile.eloRating.toStringAsFixed(1),
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: eloFontSize,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TierBadge(tier: profile.eloTier, small: true),
                                  if (profile.eloTier.nextTier != null) ...[
                                    const SizedBox(width: 4),
                                    TierInfoButton(
                                      currentElo: profile.eloRating,
                                      currentTier: profile.eloTier,
                                      iconColor: Colors.white.withValues(alpha: 0.65),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (winStreak >= 2)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: WinStreakBadge(streak: winStreak),
                          ),
                      ],
                    ),
                  ),

                  // ── Left deuce service box: Played ──────────────────────
                  // Bounded by left service line, net, singles sideline, centre service line.
                  Positioned(
                    left: _lsx * cardW,
                    top: _tyS * cardH,
                    width: (_cx - _lsx) * cardW,
                    height: (_csy - _tyS) * cardH,
                    child: Center(
                      child: _Stat(
                        label: 'Played',
                        value: profile.matchesPlayed.toString(),
                        textColor: Colors.white,
                      ),
                    ),
                  ),

                  // ── Right deuce service box: Won ────────────────────────
                  Positioned(
                    left: _cx * cardW,
                    top: _tyS * cardH,
                    width: (_rsx - _cx) * cardW,
                    height: (_csy - _tyS) * cardH,
                    child: Center(
                      child: _Stat(
                        label: 'Won',
                        value: profile.matchesWon.toString(),
                        textColor: Colors.white,
                      ),
                    ),
                  ),

                  // ── Right ad service box: Win % ─────────────────────────
                  Positioned(
                    left: _cx * cardW,
                    top: _csy * cardH,
                    width: (_rsx - _cx) * cardW,
                    height: (_byS - _csy) * cardH,
                    child: Center(
                      child: _Stat(
                        label: 'Win %',
                        value: winRatio,
                        textColor: Colors.white,
                      ),
                    ),
                  ),

                  // ── Bottom outer band: sparkline + progress bar ─────────
                  if (showSparkline)
                    Positioned(
                      left: hPad,
                      right: hPad,
                      top: _byD * cardH + 4,
                      height: sparklineH,
                      child: EloSparkline(
                        eloPoints: sparklinePoints,
                        accentColor: Colors.white,
                        height: sparklineH,
                      ),
                    ),
                  Positioned(
                    left: hPad,
                    right: hPad,
                    bottom: 6,
                    height: 22,
                    child: TierProgressBar(
                      tier: profile.eloTier,
                      eloRating: profile.eloRating,
                      accentColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
      mainAxisSize: MainAxisSize.min,
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
