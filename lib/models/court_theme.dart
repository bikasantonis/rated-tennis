import 'package:flutter/material.dart';

/// Describes a court surface personalisation option for the EloScoreCard.
///
/// Each theme has:
/// - [surfaceColor] — the inner playing surface (between the baselines/sidelines)
/// - [outerColor]  — the surrounding area (visible at top/bottom of the card)
/// - Wimbledon additionally uses 16 alternating grass stripes via [grassStripeColor]
class CourtTheme {
  const CourtTheme({
    required this.dbKey,
    required this.displayName,
    required this.surfaceColor,
    required this.outerColor,
    this.hasGrassStripes = false,
    this.grassStripeColor,
  });

  final String dbKey;
  final String displayName;
  final Color surfaceColor;
  final Color outerColor;
  final bool hasGrassStripes;
  final Color? grassStripeColor;

  static const all = [
    australianOpen,
    rolandGarros,
    wimbledon,
    usOpen,
    clubClassic,
  ];

  static CourtTheme fromDbKey(String key) =>
      all.firstWhere((c) => c.dbKey == key, orElse: () => rolandGarros);

  static const australianOpen = CourtTheme(
    dbKey: 'australian_open',
    displayName: 'Australian Open',
    surfaceColor: Color(0xFF006EA7), // aoBlue
    outerColor: Color(0xFF005D8E),   // slightly darker blue
  );

  static const rolandGarros = CourtTheme(
    dbKey: 'roland_garros',
    displayName: 'Roland Garros',
    surfaceColor: Color(0xFFC8440F), // rgClay — uniform surface
    outerColor: Color(0xFFC8440F),
  );

  static const wimbledon = CourtTheme(
    dbKey: 'wimbledon',
    displayName: 'Wimbledon',
    surfaceColor: Color(0xFF006B3C),   // wGreen — uniform surface
    outerColor: Color(0xFF006B3C),
    hasGrassStripes: true,
    grassStripeColor: Color(0xFF4DB379), // lighter grass stripe
  );

  static const usOpen = CourtTheme(
    dbKey: 'us_open',
    displayName: 'US Open',
    surfaceColor: Color(0xFF002D72), // usoNavy
    outerColor: Color(0xFF1A5C30),   // court green surrounds
  );

  static const clubClassic = CourtTheme(
    dbKey: 'club_classic',
    displayName: 'Club Classic',
    surfaceColor: Color(0xFF5B2D8E), // wPurple — Indian Wells-style hard court
    outerColor: Color(0xFF2E5E1E),   // club green
  );
}
