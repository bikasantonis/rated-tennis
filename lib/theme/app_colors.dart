import 'package:flutter/material.dart';

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

  // ── Dark theme overrides ─────────────────────────────────────────────────
  /// Clay tertiary override for dark mode (PRD §7.2.2)
  static const tertiaryDark = Color(0xFFE8845C);

  // ── Tier badge colours (PRD §7.2.3) ─────────────────────────────────────
  static const tierBeginner = Color(0xFFE0E0E0);
  static const tierBeginnerText = Color(0xFF4D4D4D);
  static const tierBronze = Color(0xFFCD7F32);
  static const tierSilver = Color(0xFFA8A9AD);
  static const tierGold = Color(0xFFB7860B);
  static const tierPlatinum = Color(0xFF5B8DB8);
  static const tierElite = Color(0xFF1B4F8A);
  static const tierBadgeText = Color(0xFFFFFFFF);

  // ── Semantic colours ──────────────────────────────────────────────────────
  static const eloGain = secondary;
  static const eloLoss = tertiary;
  static const matchConfirmed = secondaryContainer;
  static const matchDisputed = tertiaryContainer;
}
