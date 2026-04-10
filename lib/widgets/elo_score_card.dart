import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/profile.dart';
import 'tier_badge.dart';

class EloScoreCard extends StatelessWidget {
  const EloScoreCard({required this.profile, super.key});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              profile.eloRating.toStringAsFixed(1),
              style: GoogleFonts.barlowCondensed(
                fontSize: 72,
                fontWeight: FontWeight.w700,
                color: cs.primary,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            TierBadge(tier: profile.eloTier),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Stat(
                  label: 'Played',
                  value: profile.matchesPlayed.toString(),
                ),
                _Stat(
                  label: 'Won',
                  value: profile.matchesWon.toString(),
                ),
                _Stat(
                  label: 'Win %',
                  value: profile.matchesPlayed == 0
                      ? '—'
                      : '${(profile.matchesWon / profile.matchesPlayed * 100).round()}%',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(value, style: tt.titleLarge),
        Text(label, style: tt.bodySmall),
      ],
    );
  }
}
