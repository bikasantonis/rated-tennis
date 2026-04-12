import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rated/models/profile.dart';
import 'package:rated/providers/auth_provider.dart';
import 'package:rated/providers/notification_panel_provider.dart';
import 'package:rated/router/app_router.dart';
import 'package:rated/widgets/notification_panel.dart';

/// Profile icon + notification bell shown in the top-right of every shell
/// screen's AppBar.
class AppBarActions extends ConsumerWidget {
  const AppBarActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadCountProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final isAdmin = profileAsync.whenOrNull(
          data: (p) => p?.role == UserRole.admin,
        ) ??
        false;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Organiser dashboard (organiser + admin) ────────────────────
        if (isAdmin ||
            profileAsync.whenOrNull(data: (p) => p?.role == UserRole.organizer) == true)
          IconButton(
            icon: const Icon(Icons.emoji_events_outlined),
            tooltip: 'My tournaments',
            onPressed: () => context.push(AppRoutes.organizerDashboard),
          ),

        // ── Admin panel (admins only) ──────────────────────────────────
        if (isAdmin)
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: 'Admin panel',
            onPressed: () => context.push(AppRoutes.adminDisputes),
          ),
        // ── Notification bell ──────────────────────────────────────────
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Notifications',
              onPressed: () => showNotificationPanel(context),
            ),
            if (unread > 0)
              Positioned(
                top: 6,
                right: 6,
                child: IgnorePointer(
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),

        // ── Profile ────────────────────────────────────────────────────
        IconButton(
          icon: const Icon(Icons.person_outlined),
          tooltip: 'My profile',
          onPressed: () => context.push(AppRoutes.profile),
        ),

        // ── Settings ───────────────────────────────────────────────────
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () => context.push(AppRoutes.settings),
        ),

        const SizedBox(width: 4),
      ],
    );
  }
}
