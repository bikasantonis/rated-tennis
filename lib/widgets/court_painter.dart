import 'package:flutter/material.dart';
import 'package:rated/models/court_theme.dart';

/// Paints a top-down landscape tennis court as the background of the EloScoreCard.
///
/// Geometry is expressed as proportions of the canvas so it scales to any card size.
/// Proportions derived from the SVG reference (200 × 230 dp):
///
///   x: left-baseline=5%  left-service=26%  net=50%  right-service=74%  right-baseline=95%
///   y: top-doubles=28.3% top-singles=33.5% centre=53.5% bottom-singles=73.5% bottom-doubles=78.7%
class CourtPainter extends CustomPainter {
  const CourtPainter(this.theme);

  final CourtTheme theme;

  // x proportions
  static const _lx  = 0.05;   // left baseline
  static const _lsx = 0.26;   // left service line
  static const _cx  = 0.50;   // net
  static const _rsx = 0.74;   // right service line
  static const _rx  = 0.95;   // right baseline

  // y proportions
  static const _tyD = 0.2826; // top doubles sideline
  static const _tyS = 0.3348; // top singles sideline
  static const _csy = 0.5348; // centre service line
  static const _byS = 0.7348; // bottom singles sideline
  static const _byD = 0.7870; // bottom doubles sideline

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1 ── Outer band (full canvas background)
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = theme.outerColor,
    );

    // 2 ── Inner playing surface (between baselines and doubles sidelines)
    final innerRect = Rect.fromLTRB(_lx * w, _tyD * h, _rx * w, _byD * h);
    canvas.drawRect(innerRect, Paint()..color = theme.surfaceColor);

    // 3 ── Wimbledon grass stripes (16 alternating, odd indices = light)
    if (theme.hasGrassStripes && theme.grassStripeColor != null) {
      final stripeH = (_byD - _tyD) * h / 16;
      final lightPaint = Paint()..color = theme.grassStripeColor!;
      for (var i = 0; i < 16; i++) {
        if (i.isOdd) {
          canvas.drawRect(
            Rect.fromLTWH(_lx * w, _tyD * h + i * stripeH, (_rx - _lx) * w, stripeH),
            lightPaint,
          );
        }
      }
    }

    // 4 ── Court lines (white, fully opaque)
    final thick = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final thin = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final net = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // baselines (left / right — inset from card edges)
    canvas.drawLine(Offset(_lx * w, _tyD * h), Offset(_lx * w, _byD * h), thick);
    canvas.drawLine(Offset(_rx * w, _tyD * h), Offset(_rx * w, _byD * h), thick);

    // doubles sidelines (top / bottom)
    canvas.drawLine(Offset(_lx * w, _tyD * h), Offset(_rx * w, _tyD * h), thick);
    canvas.drawLine(Offset(_lx * w, _byD * h), Offset(_rx * w, _byD * h), thick);

    // singles sidelines (top / bottom)
    canvas.drawLine(Offset(_lx * w, _tyS * h), Offset(_rx * w, _tyS * h), thin);
    canvas.drawLine(Offset(_lx * w, _byS * h), Offset(_rx * w, _byS * h), thin);

    // net
    canvas.drawLine(Offset(_cx * w, _tyD * h), Offset(_cx * w, _byD * h), net);

    // service lines (vertical)
    canvas.drawLine(Offset(_lsx * w, _tyS * h), Offset(_lsx * w, _byS * h), thin);
    canvas.drawLine(Offset(_rsx * w, _tyS * h), Offset(_rsx * w, _byS * h), thin);

    // centre service line (horizontal T-bisector)
    canvas.drawLine(Offset(_lsx * w, _csy * h), Offset(_rsx * w, _csy * h), thin);
  }

  @override
  bool shouldRepaint(CourtPainter old) => old.theme.dbKey != theme.dbKey;
}
