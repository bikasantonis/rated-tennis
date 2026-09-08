import 'dart:math';

import 'package:rated/models/profile.dart';

// ELO formula constants — must match apply_elo_changes() in the DB:
//   K = 0.15, d = 1.67, delta clamped to [0.01, 0.20]
const double _k = 0.15;
const double _d = 1.67;

class TierPathStep {
  const TierPathStep({required this.opponentTier, required this.wins});

  final EloTier opponentTier;
  final int wins;
}

class TierPath {
  const TierPath({
    required this.targetTier,
    required this.eloNeeded,
    required this.steps,
  });

  final EloTier targetTier;

  /// How many ELO points remain until the next tier boundary.
  final double eloNeeded;

  final List<TierPathStep> steps;
}

/// Estimated ELO gain for beating an opponent whose ELO is [opponentElo].
double _eloGain(double myElo, double opponentElo) {
  final e = 1.0 / (1.0 + pow(10.0, (opponentElo - myElo) / _d));
  return (_k * (1.0 - e)).clamp(0.01, 0.20);
}

/// Computes a randomised-but-reproducible path to the next tier.
///
/// The suggestion mixes 1–2 opponent-tier groups so the output is realistic
/// rather than a simple "beat N players all at the same tier". Returns null
/// when [currentTier] is already the maximum (10.0).
TierPath? computeNextTierPath(double currentElo, EloTier currentTier) {
  final next = currentTier.nextTier;
  if (next == null) return null;

  final needed = next.threshold - currentElo;
  if (needed <= 0.005) return null;

  // Seed the RNG from the current ELO so the suggestion changes naturally
  // as the player improves but stays stable within the same fractional rating.
  final rng = Random((currentElo * 100).floor());

  // Collect candidate opponent tiers: current tier up to current + 1.5
  // (the maximum gap before a match is voided for ELO purposes).
  // We focus on the upper half of that range so wins actually move the needle.
  final candidates = <EloTier>[];
  EloTier t = currentTier;
  for (var i = 0; i < 5; i++) {
    final diff = t.threshold - currentTier.threshold;
    if (diff > 1.5 + 0.001) break;
    candidates.add(t);
    final n = t.nextTier;
    if (n == null) break;
    t = n;
  }

  // Use mid-tier rating (+0.25) as a representative opponent ELO.
  double gainFor(EloTier tier) =>
      _eloGain(currentElo, tier.threshold + 0.25);

  // Shuffle and pick up to 2 distinct tiers for a mixed suggestion.
  candidates.shuffle(rng);
  final tierA = candidates[0];
  final tierB = candidates.length > 1 ? candidates[1] : null;

  if (tierB == null || tierB == tierA) {
    final gain = gainFor(tierA);
    final wins = max(1, (needed / gain).ceil());
    return TierPath(
      targetTier: next,
      eloNeeded: needed,
      steps: [TierPathStep(opponentTier: tierA, wins: wins)],
    );
  }

  // Two-tier split: randomly skew 40–60 % of the needed gain toward tierA.
  final ratio = 0.4 + rng.nextDouble() * 0.2;
  final gainA = gainFor(tierA);
  final gainB = gainFor(tierB);
  final winsA = max(1, (needed * ratio / gainA).round());
  final remaining = needed - winsA * gainA;
  final winsB = remaining > 0 ? max(1, (remaining / gainB).ceil()) : 1;

  final steps = [
    TierPathStep(opponentTier: tierA, wins: winsA),
    TierPathStep(opponentTier: tierB, wins: winsB),
  ]..sort(
    (a, b) => b.opponentTier.threshold.compareTo(a.opponentTier.threshold),
  );

  return TierPath(targetTier: next, eloNeeded: needed, steps: steps);
}
