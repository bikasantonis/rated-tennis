import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rated/l10n/app_localizations.dart';
import 'package:rated/models/profile.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/utils/tier_path_calculator.dart';
import 'package:rated/widgets/tier_badge.dart';

/// A small ⓘ icon placed next to the tier badge on the ELO score card.
///
/// - Desktop / web: the suggestion popup appears on **hover**.
/// - Phone / mobile web: the popup appears on **tap** and dismisses when the
///   user taps anywhere outside it.
class TierInfoButton extends StatefulWidget {
  const TierInfoButton({
    required this.currentElo,
    required this.currentTier,
    required this.iconColor,
    super.key,
  });

  final double currentElo;
  final EloTier currentTier;

  /// Colour of the info icon — caller sets this to match the card surface.
  final Color iconColor;

  @override
  State<TierInfoButton> createState() => _TierInfoButtonState();
}

class _TierInfoButtonState extends State<TierInfoButton> {
  OverlayEntry? _entry;
  final _layerLink = LayerLink();
  bool _isHovering = false;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  void _showOverlay() {
    if (_entry != null) return;
    final path =
        computeNextTierPath(widget.currentElo, widget.currentTier);
    if (path == null) return;

    _entry = OverlayEntry(
      builder: (_) => _TierPathOverlay(
        layerLink: _layerLink,
        path: path,
        onDismiss: _removeOverlay,
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        cursor: SystemMouseCursors.help,
        onEnter: (_) {
          _isHovering = true;
          _showOverlay();
        },
        onExit: (_) {
          _isHovering = false;
          _removeOverlay();
        },
        child: GestureDetector(
          onTap: () {
            // On desktop the hover already controls visibility; ignore extra taps.
            if (_isHovering) return;
            if (_entry != null) {
              _removeOverlay();
            } else {
              _showOverlay();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: widget.iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Overlay shell ─────────────────────────────────────────────────────────────

class _TierPathOverlay extends StatelessWidget {
  const _TierPathOverlay({
    required this.layerLink,
    required this.path,
    required this.onDismiss,
  });

  final LayerLink layerLink;
  final TierPath path;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full-screen transparent barrier captures taps outside the card.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: onDismiss,
          ),
        ),
        CompositedTransformFollower(
          link: layerLink,
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(-4, 6),
          child: Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 10,
              shadowColor: Colors.black38,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: _TierPathCard(path: path),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Popup card ────────────────────────────────────────────────────────────────

class _TierPathCard extends StatelessWidget {
  const _TierPathCard({required this.path});

  final TierPath path;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context)!;

    return Container(
      constraints: const BoxConstraints(maxWidth: 252),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      color: cs.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Path to ',
                style: GoogleFonts.barlowCondensed(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              TierBadge(tier: path.targetTier, small: true),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            l.tierPathEloNeeded(path.eloNeeded.toStringAsFixed(2)),
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: cs.outlineVariant),
          const SizedBox(height: 10),
          // ── Suggested path ────────────────────────────────────────────────
          Text(
            l.tierPathSuggested,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 7),
          ...path.steps.map((s) => _StepRow(step: s, cs: cs)),
          const SizedBox(height: 8),
          // ── Disclaimer ────────────────────────────────────────────────────
          Text(
            l.tierPathDisclaimer,
            style: TextStyle(
              fontSize: 10,
              fontStyle: FontStyle.italic,
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.cs});

  final TierPathStep step;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.tierColor(step.opponentTier),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            '${step.wins}× ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          Text(
            'Tier ',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
          TierBadge(tier: step.opponentTier, small: true),
          Text(
            ' players',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
