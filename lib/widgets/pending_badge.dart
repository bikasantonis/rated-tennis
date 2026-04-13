import 'package:flutter/material.dart';

/// Small pill chip showing a count — used inline inside tab labels.
/// Hidden when [count] == 0.
class CountChip extends StatelessWidget {
  const CountChip({required this.count, super.key});
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
      ),
    );
  }
}

/// A [Tab] with an optional count chip shown to the right of the [label].
/// Chip is hidden when [count] == 0.
class TabWithBadge extends StatelessWidget {
  const TabWithBadge({required this.label, required this.count, super.key});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            CountChip(count: count),
          ],
        ],
      ),
    );
  }
}
