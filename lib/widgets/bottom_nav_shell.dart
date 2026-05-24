import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rated/providers/match_provider.dart';
import 'package:rated/router/app_router.dart';
import 'package:rated/theme/app_colors.dart';

class BottomNavShell extends ConsumerWidget {
  const BottomNavShell({required this.child, super.key});

  final Widget child;

  static const _routes = [
    AppRoutes.home,
    AppRoutes.leaderboard,
    AppRoutes.matchInbox,
    AppRoutes.tournaments,
  ];

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (var i = 0; i < _routes.length; i++) {
      if (location.startsWith(_routes[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsCount =
        ref.watch(pendingResultsProvider).asData?.value.length ?? 0;
    final requestsCount =
        ref.watch(pendingRequestsProvider).asData?.value.length ?? 0;
    final inboxCount = resultsCount + requestsCount;

    final selectedIdx = _selectedIndex(context);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: child,
      bottomNavigationBar: _CustomNavBar(
        selectedIndex: selectedIdx,
        inboxCount: inboxCount,
        onTap: (i) => context.go(_routes[i]),
        surfaceColor: cs.surface,
        outlineColor: cs.outlineVariant,
      ),
    );
  }
}

// ── Custom nav bar ────────────────────────────────────────────────────────────

class _CustomNavBar extends StatelessWidget {
  const _CustomNavBar({
    required this.selectedIndex,
    required this.inboxCount,
    required this.onTap,
    required this.surfaceColor,
    required this.outlineColor,
  });

  final int selectedIndex;
  final int inboxCount;
  final ValueChanged<int> onTap;
  final Color surfaceColor;
  final Color outlineColor;

  static const _items = [
    _NavItemData(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _NavItemData(
      label: 'Leaderboard',
      icon: Icons.leaderboard_outlined,
      selectedIcon: Icons.leaderboard,
    ),
    _NavItemData(
      label: 'Matches',
      icon: Icons.inbox_outlined,
      selectedIcon: Icons.inbox,
    ),
    _NavItemData(
      label: 'Tournaments',
      icon: Icons.emoji_events_outlined,
      selectedIcon: Icons.emoji_events,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          top: BorderSide(color: outlineColor, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              return Expanded(
                child: _NavItem(
                  data: item,
                  isSelected: i == selectedIndex,
                  accent: AppColors.slamAccent(i),
                  secondary: AppColors.slamForeground(i),
                  badge: i == 2 ? inboxCount : 0,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.isSelected,
    required this.accent,
    required this.secondary,
    required this.onTap,
    this.badge = 0,
  });

  final _NavItemData data;
  final bool isSelected;
  final Color accent;
  final Color secondary; // used only where contrast passes — see slamForeground
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final unselectedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            badge > 0
                ? Badge(
                    label: Text('$badge'),
                    child: Icon(
                      isSelected ? data.selectedIcon : data.icon,
                      size: 24,
                      color: isSelected ? secondary : unselectedColor,
                    ),
                  )
                : Icon(
                    isSelected ? data.selectedIcon : data.icon,
                    size: 24,
                    color: isSelected ? secondary : unselectedColor,
                  ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              style: TextStyle(
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? secondary : unselectedColor,
              ),
              child: Text(data.label),
            ),
          ],
        ),
      ),
    );
  }
}
