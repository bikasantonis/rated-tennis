import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rated/providers/match_provider.dart';
import 'package:rated/router/app_router.dart';

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

    final destinations = [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.leaderboard_outlined),
        selectedIcon: Icon(Icons.leaderboard),
        label: 'Leaderboard',
      ),
      NavigationDestination(
        icon: Badge(
          label: Text('$inboxCount'),
          isLabelVisible: inboxCount > 0,
          child: const Icon(Icons.inbox_outlined),
        ),
        selectedIcon: Badge(
          label: Text('$inboxCount'),
          isLabelVisible: inboxCount > 0,
          child: const Icon(Icons.inbox),
        ),
        label: 'Matches',
      ),
      const NavigationDestination(
        icon: Icon(Icons.emoji_events_outlined),
        selectedIcon: Icon(Icons.emoji_events),
        label: 'Tournaments',
      ),
    ];

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        destinations: destinations,
        onDestinationSelected: (i) => context.go(_routes[i]),
      ),
    );
  }
}
