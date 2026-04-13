import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:rated/providers/auth_provider.dart';
import 'package:rated/screens/admin/dispute_resolution_screen.dart';
import 'package:rated/screens/auth/login_screen.dart';
import 'package:rated/screens/splash/splash_screen.dart';
import 'package:rated/screens/home/home_screen.dart';
import 'package:rated/screens/leaderboard/leaderboard_screen.dart';
import 'package:rated/screens/match/match_inbox_screen.dart';
import 'package:rated/screens/match/schedule_match_screen.dart';
import 'package:rated/screens/match/submit_match_screen.dart';
import 'package:rated/screens/onboarding/onboarding_screen.dart';
import 'package:rated/screens/organizer/organizer_dashboard_screen.dart';
import 'package:rated/screens/organizer/organizer_tournament_detail_screen.dart';
import 'package:rated/screens/profile/profile_screen.dart';
import 'package:rated/screens/questionnaire/questionnaire_screen.dart';
import 'package:rated/screens/settings/settings_screen.dart';
import 'package:rated/screens/tournament/tournament_detail_screen.dart';
import 'package:rated/screens/tournament/tournaments_list_screen.dart';
import 'package:rated/widgets/bottom_nav_shell.dart';

part 'app_router.g.dart';

// ---------------------------------------------------------------------------
// Route path constants
// ---------------------------------------------------------------------------

abstract final class AppRoutes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const questionnaire = '/questionnaire';
  static const home = '/home';
  static const leaderboard = '/leaderboard';
  static const matchInbox = '/matches';
  static const tournaments = '/tournaments';
  static const tournamentDetail = '/tournaments/:id';
  static const submitMatch = '/matches/submit';
  static const scheduleMatch = '/matches/schedule';
  static const profile = '/profile';
  static const playerProfile = '/profile/:id';
  static const settings = '/settings';
  static const organizerDashboard = '/organizer';
  static const organizerTournamentDetail = '/organizer/tournaments/:id';
  static const adminDisputes = '/admin/disputes';
}

// ---------------------------------------------------------------------------
// Router provider
// ---------------------------------------------------------------------------

@riverpod
GoRouter appRouter(Ref ref) {
  final notifier = ref.watch(authProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    refreshListenable: notifier,
    redirect: (context, state) {
      final status = notifier.status;
      final splashReady = notifier.splashReady;
      final path = state.matchedLocation;

      // While splash is still showing, stay on it
      if (!splashReady) {
        return path == AppRoutes.splash ? null : AppRoutes.splash;
      }

      // Authenticated — redirect away from splash / auth screens
      if (status == AuthStatus.authenticated) {
        if (path == AppRoutes.splash ||
            path == AppRoutes.onboarding ||
            path == AppRoutes.login) {
          return AppRoutes.home;
        }
        return null;
      }

      // Unauthenticated — allow only public screens
      if (path == AppRoutes.onboarding || path == AppRoutes.login) {
        return null;
      }
      return AppRoutes.onboarding;
    },
    routes: [
      // ── Splash screen ─────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _fade(state, const SplashScreen()),
      ),

      // ── Public screens ────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) => _fade(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _fade(state, const LoginScreen()),
      ),

      // ── Post-registration ─────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.questionnaire,
        pageBuilder: (context, state) =>
            _fade(state, const QuestionnaireScreen()),
      ),

      // ── Authenticated shell (bottom nav) ──────────────────────────────────
      ShellRoute(
        builder: (context, state, child) => BottomNavShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.home,
            pageBuilder: (context, state) =>
                _slide(state, const HomeScreen()),
          ),
          GoRoute(
            path: AppRoutes.leaderboard,
            pageBuilder: (context, state) =>
                _slide(state, const LeaderboardScreen()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) => _slide(
                  state,
                  ProfileScreen(playerId: state.pathParameters['id']!),
                ),
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.matchInbox,
            pageBuilder: (context, state) =>
                _slide(state, const MatchInboxScreen()),
          ),
          GoRoute(
            path: AppRoutes.tournaments,
            pageBuilder: (context, state) =>
                _slide(state, const TournamentsListScreen()),
            routes: [
              GoRoute(
                path: ':id',
                pageBuilder: (context, state) => _slide(
                  state,
                  TournamentDetailScreen(
                    tournamentId: state.pathParameters['id']!,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),

      // ── Floating screens (no bottom nav) ──────────────────────────────────
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) =>
            _slide(state, const ProfileScreen()),
      ),
      GoRoute(
        path: AppRoutes.submitMatch,
        pageBuilder: (context, state) =>
            _slide(state, const SubmitMatchScreen()),
      ),
      GoRoute(
        path: AppRoutes.scheduleMatch,
        pageBuilder: (context, state) =>
            _slide(state, const ScheduleMatchScreen()),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) =>
            _slide(state, const SettingsScreen()),
      ),

      // ── Role-gated screens ────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.organizerDashboard,
        pageBuilder: (context, state) =>
            _slide(state, const OrganizerDashboardScreen()),
      ),
      GoRoute(
        path: AppRoutes.organizerTournamentDetail,
        pageBuilder: (context, state) => _slide(
          state,
          OrganizerTournamentDetailScreen(
            tournamentId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.adminDisputes,
        pageBuilder: (context, state) =>
            _slide(state, const DisputeResolutionScreen()),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Page transition helpers (MD3 motion tokens)
// ---------------------------------------------------------------------------

CustomTransitionPage<void> _slide(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeInOut));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
