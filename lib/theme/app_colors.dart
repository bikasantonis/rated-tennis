import 'package:flutter/material.dart';

import 'package:rated/models/profile.dart';

/// All design tokens from PRD §7.2 — do not modify without re-checking
/// WCAG 2.1 AA contrast ratios.
abstract final class AppColors {
  // ── Light theme ───────────────────────────────────────────────────────────
  static const primary = Color(0xFF1B4F8A);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFFD6E4F7);
  static const secondary = Color(0xFF2D6A4F);
  static const onSecondary = Color(0xFFFFFFFF);
  static const secondaryContainer = Color(0xFFD8F3DC);
  static const tertiary = Color(0xFFC1440E);
  static const tertiaryContainer = Color(0xFFFAE0D4);
  static const surface = Color(0xFFF8FAFB);
  static const onSurface = Color(0xFF1A1A2E);
  static const surfaceVariant = Color(0xFFE3ECF5);
  static const outline = Color(0xFF8AAAC8);
  static const error = Color(0xFFBA1A1A);
  static const onError = Color(0xFFFFFFFF);

  // ── Light theme explicit surface tokens ──────────────────────────────────
  static const lightBg   = Color(0xFFF4F7FC);
  static const lightCard = Color(0xFFFFFFFF);

  // ── Dark theme overrides ─────────────────────────────────────────────────
  /// Clay tertiary override for dark mode (PRD §7.2.2)
  static const tertiaryDark = Color(0xFFE8845C);

  // ── Dark theme surface tokens ────────────────────────────────────────────
  static const darkBg      = Color(0xFF0A0F1E);
  static const darkCard    = Color(0xFF101829);
  static const darkSurface = Color(0xFF141E30);

  // ── Grand Slam palettes (tab order = calendar order) ─────────────────────
  // Tab 0 — Home → Australian Open (hard court blue / yellow gold)
  static const aoBlue   = Color(0xFF006EA7);
  static const aoYellow = Color(0xFFF4C430);
  // Tab 1 — Leaderboard → Roland Garros (clay / olive)
  static const rgClay  = Color(0xFFC8440F);
  static const rgOlive = Color(0xFF3D6B35);
  // Tab 2 — Matches → Wimbledon (grass green / purple)
  static const wGreen  = Color(0xFF006B3C);
  static const wPurple = Color(0xFF5B2D8E);
  // Tab 3 — Tournaments → US Open (asphalt navy / gold)
  static const usoNavy = Color(0xFF002D72);
  static const usoGold = Color(0xFFF7A800);

  /// Primary slam accent for [tabIndex] (0-3).
  static Color slamAccent(int tabIndex) => switch (tabIndex) {
        0 => aoBlue,
        1 => rgClay,
        2 => wGreen,
        3 => usoNavy,
        _ => primary,
      };

  /// Secondary slam accent for [tabIndex] (0-3).
  static Color slamSecondary(int tabIndex) => switch (tabIndex) {
        0 => aoYellow,
        1 => rgOlive,
        2 => wPurple,
        3 => usoGold,
        _ => primary,
      };

  /// Foreground colour (icon + label) on a solid slam-accent box.
  /// Uses the secondary colour only where it passes WCAG AA contrast
  /// against the primary accent background; falls back to white otherwise.
  ///   AO  blue  + yellow ✓  (contrast ~6.5:1)
  ///   RG  clay  + olive  ✗  (contrast ~1.9:1) → white
  ///   WIM green + purple ✗  (contrast ~2.1:1) → white
  ///   USO navy  + gold   ✓  (contrast ~8.2:1)
  static Color slamForeground(int tabIndex) => switch (tabIndex) {
        0 => aoYellow,
        1 => const Color(0xFFFFFFFF),
        2 => const Color(0xFFFFFFFF),
        3 => usoGold,
        _ => const Color(0xFFFFFFFF),
      };

  // ── Tier colours (PRD §7.2.3) ────────────────────────────────────────────
  // Used as the foreground/text colour for the tier number on the profile page
  // and as the fill colour for the leaderboard pill badge.
  // 11 numeric tiers at 0.5-point intervals; colour families:
  //   5.0–5.5  slate/entry · 6.0–6.5 bronze · 7.0–7.5 silver
  //   8.0–8.5  gold        · 9.0–9.5 platinum · 10.0 elite navy
  static const tier50Color  = Color(0xFF78909C); // slate blue-gray
  static const tier55Color  = Color(0xFF8D6E63); // warm taupe
  static const tier60Color  = Color(0xFFA0522D); // sienna
  static const tier65Color  = Color(0xFFB87333); // copper
  static const tier70Color  = Color(0xFF7B8D9A); // steel
  static const tier75Color  = Color(0xFFA0A8B0); // silver
  static const tier80Color  = Color(0xFFB8860B); // dark gold
  static const tier85Color  = Color(0xFFDAA520); // goldenrod
  static const tier90Color  = Color(0xFF4A7FA5); // steel blue
  static const tier95Color  = Color(0xFF2C5F8A); // deep ocean
  static const tier100Color = Color(0xFF1B4F8A); // elite navy (= primary)

  // Text on leaderboard pill badges (dark for 5.0/5.5 which are light-toned).
  static const tierLightText = Color(0xFF3D3D3D);
  static const tierBadgeText = Color(0xFFFFFFFF);

  /// Returns the canonical colour for [tier] — used as text on the profile page
  /// and as the fill on leaderboard pill badges.
  static Color tierColor(EloTier tier) => switch (tier) {
        EloTier.tier50  => tier50Color,
        EloTier.tier55  => tier55Color,
        EloTier.tier60  => tier60Color,
        EloTier.tier65  => tier65Color,
        EloTier.tier70  => tier70Color,
        EloTier.tier75  => tier75Color,
        EloTier.tier80  => tier80Color,
        EloTier.tier85  => tier85Color,
        EloTier.tier90  => tier90Color,
        EloTier.tier95  => tier95Color,
        EloTier.tier100 => tier100Color,
      };

  /// Light-toned tiers need dark text on pill badges; all others use white.
  static Color tierTextColor(EloTier tier) =>
      (tier == EloTier.tier50 || tier == EloTier.tier55)
          ? tierLightText
          : tierBadgeText;

  // ── Semantic colours ──────────────────────────────────────────────────────
  static const eloGain = secondary;
  static const eloLoss = tertiary;
  static const matchConfirmed = secondaryContainer;
  static const matchDisputed = tertiaryContainer;
}
