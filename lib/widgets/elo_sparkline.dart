import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class EloSparkline extends StatelessWidget {
  const EloSparkline({
    required this.eloPoints,
    required this.accentColor,
    this.height = 48,
    super.key,
  });

  final List<double> eloPoints;
  final Color accentColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (eloPoints.length < 2) return const SizedBox.shrink();

    final spots = eloPoints
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          minX: 0,
          maxX: (eloPoints.length - 1).toDouble(),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: accentColor,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: accentColor.withValues(alpha: 0.08),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
