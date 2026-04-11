import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:rated/router/app_router.dart';

class BottomNavShell extends StatelessWidget {
  const BottomNavShell({required this.child, super.key});

  final Widget child;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.leaderboard_outlined),
      selectedIcon: Icon(Icons.leaderboard),
      label: 'Leaderboard',
    ),
    NavigationDestination(
      icon: Icon(Icons.inbox_outlined),
      selectedIcon: Icon(Icons.inbox),
      label: 'Matches',
    ),
    NavigationDestination(
      icon: Icon(Icons.emoji_events_outlined),
      selectedIcon: Icon(Icons.emoji_events),
      label: 'Tournaments',
    ),
  ];

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
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex(context),
        destinations: _destinations,
        onDestinationSelected: (i) => context.go(_routes[i]),
      ),
    );
  }
}
