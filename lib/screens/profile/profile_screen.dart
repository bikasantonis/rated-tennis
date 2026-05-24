import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rated/l10n/app_localizations.dart';

import 'package:rated/models/profile.dart';
import 'package:rated/providers/auth_provider.dart';
import 'package:rated/providers/profile_provider.dart';
import 'package:rated/router/app_router.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/utils/streak_utils.dart';
import 'package:rated/widgets/error_state_widget.dart';

/// SCR-06 — Player profile (own or another player's public profile).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.playerId});

  /// null = own profile; non-null = another player's public profile
  final String? playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final selfAsync = ref.watch(currentProfileProvider);

    return selfAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => const Scaffold(body: ErrorStateWidget()),
      data: (self) {
        final targetId = playerId ?? self?.id;
        if (targetId == null) {
          return Scaffold(body: Center(child: Text(l.errorNotLoggedIn)));
        }
        final isOwn = playerId == null || playerId == self?.id;
        return _ProfileView(
            targetId: targetId, isOwn: isOwn, selfId: self?.id);
      },
    );
  }
}

// ── Profile view ─────────────────────────────────────────────────────────────

class _ProfileView extends ConsumerStatefulWidget {
  const _ProfileView(
      {required this.targetId, required this.isOwn, required this.selfId});

  final String targetId;
  final bool isOwn;
  final String? selfId;

  @override
  ConsumerState<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends ConsumerState<_ProfileView> {
  bool _avatarUploading = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(playerProfileProvider(widget.targetId));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isOwn ? l.profileMyProfile : l.profileTitle),
        actions: [
          if (widget.isOwn)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => _showEditDialog(
                context,
                ref,
                widget.targetId,
                profileAsync.asData?.value?['display_name'] as String? ?? '',
              ),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const ErrorStateWidget(),
        data: (profile) {
          if (profile == null) {
            return Center(child: Text(l.errorProfileNotFound));
          }
          return _ProfileBody(
            profile: profile,
            targetId: widget.targetId,
            isOwn: widget.isOwn,
            avatarUploading: _avatarUploading,
            onAvatarTap: widget.isOwn
                ? () => _pickAndUploadAvatar(
                      context,
                      ref,
                      widget.targetId,
                      profile['avatar_url'] as String?,
                    )
                : null,
          );
        },
      ),
    );
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref,
      String playerId, String current) async {
    final l = AppLocalizations.of(context)!;
    final ctrl = TextEditingController(text: current);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.profileEditDisplayName),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: l.profileDisplayNameLabel),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l.actionCancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.actionSave)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref
        .read(profileEditActionsProvider.notifier)
        .updateDisplayName(playerId, ctrl.text.trim());
    if (context.mounted) {
      ref.invalidate(playerProfileProvider(playerId));
      ref.invalidate(currentProfileProvider);
    }
  }

  Future<void> _pickAndUploadAvatar(
      BuildContext context, WidgetRef ref, String playerId,
      String? currentAvatarUrl) async {
    // Determine the extension stored for the current avatar (for removal).
    final currentExt = currentAvatarUrl != null &&
            currentAvatarUrl.contains('.')
        ? currentAvatarUrl.split('.').last.split('?').first
        : 'jpg';

    // On web, ImagePicker uses a file input — source is ignored for web.
    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      builder: (ctx) {
        final lCtx = AppLocalizations.of(ctx)!;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(lCtx.profileChooseFromGallery),
                onTap: () => Navigator.pop(ctx, _AvatarAction.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(lCtx.profileTakePhoto),
                onTap: () => Navigator.pop(ctx, _AvatarAction.camera),
              ),
              if (currentAvatarUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: Text(lCtx.profileRemovePhoto,
                      style: const TextStyle(color: Colors.red)),
                  onTap: () => Navigator.pop(ctx, _AvatarAction.remove),
                ),
            ],
          ),
        );
      },
    );
    if (action == null || !context.mounted) return;

    if (action == _AvatarAction.remove) {
      setState(() => _avatarUploading = true);
      try {
        await ref
            .read(profileEditActionsProvider.notifier)
            .removeAvatar(playerId, currentExt);
        if (context.mounted) {
          ref.invalidate(playerProfileProvider(playerId));
          ref.invalidate(currentProfileProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture removed')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Remove failed: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _avatarUploading = false);
      }
      return;
    }

    final source = action == _AvatarAction.gallery
        ? ImageSource.gallery
        : ImageSource.camera;

    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (xfile == null || !context.mounted) return;

    final bytes = await xfile.readAsBytes();
    final name = xfile.name.toLowerCase();
    final ext = name.contains('.') ? name.split('.').last : 'jpg';

    setState(() => _avatarUploading = true);
    try {
      await ref
          .read(profileEditActionsProvider.notifier)
          .updateAvatar(playerId, bytes, ext);
      if (context.mounted) {
        ref.invalidate(playerProfileProvider(playerId));
        ref.invalidate(currentProfileProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }
}

// ── Profile body ─────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({
    required this.profile,
    required this.targetId,
    required this.isOwn,
    required this.avatarUploading,
    this.onAvatarTap,
  });

  final Map<String, dynamic> profile;
  final String targetId;
  final bool isOwn;
  final bool avatarUploading;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;

    final name = profile['display_name'] as String? ?? '—';
    final elo = (profile['elo_rating'] as num?)?.toDouble() ?? 5.0;
    final tierStr = profile['elo_tier'] as String? ?? '5.0';
    final tier = EloTier.fromString(tierStr);
    final played = profile['matches_played'] as int? ?? 0;
    final won = profile['matches_won'] as int? ?? 0;
    final lost = played - won;
    final winPct =
        played == 0 ? '—' : '${(won / played * 100).round()}%';
    final peakElo = (profile['peak_elo'] as num?)?.toDouble();
    final avatarUrl = profile['avatar_url'] as String?;
    final roleStr = profile['role'] as String? ?? 'player';
    final role = UserRole.values.firstWhere(
      (r) => r.name == roleStr,
      orElse: () => UserRole.player,
    );
    final homeCity = profile['home_city'] as String?;
    final locationConsent = profile['location_consent'] as bool? ?? false;
    final createdAt = DateTime.tryParse(
        (profile['created_at'] ?? '').toString());
    final questionnaireDone =
        profile['questionnaire_done'] as bool? ?? false;

    final historyAsync = ref.watch(eloHistoryProvider(targetId));
    final matchesAsync = ref.watch(playerMatchesProvider(targetId));
    final questionnaireAsync =
        ref.watch(playerQuestionnaireProvider(targetId));
    final tournamentsAsync =
        ref.watch(playerTournamentHistoryProvider(targetId));
    final rankAsync = ref.watch(playerGlobalRankProvider(targetId));

    return matchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (matches) {
        final streak = computeWinStreak(matches, targetId);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Header card ─────────────────────────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Avatar with optional upload button
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        _buildAvatar(
                            avatarUrl, name, avatarUploading),
                        if (onAvatarTap != null)
                          Positioned(
                            bottom: 0,
                            right: -4,
                            child: GestureDetector(
                              onTap:
                                  avatarUploading ? null : onAvatarTap,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surface,
                                      width: 2),
                                ),
                                child: const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 14,
                                    color: AppColors.onPrimary),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Name
                    Text(name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall),
                    const SizedBox(height: 4),
                    // Meta row: city · member since
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (locationConsent && homeCity != null) ...[
                          const Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: AppColors.outline),
                          const SizedBox(width: 2),
                          Text(homeCity,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: AppColors.outline)),
                          const SizedBox(width: 8),
                        ],
                        if (createdAt != null) ...[
                          const Icon(Icons.calendar_today_outlined,
                              size: 12, color: AppColors.outline),
                          const SizedBox(width: 2),
                          Text(
                            'Since ${_monthYear(createdAt)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.outline),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Badges row — role badges only; tier shown separately below
                    if (role == UserRole.organizer || role == UserRole.admin)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        alignment: WrapAlignment.center,
                        children: [
                          if (role == UserRole.organizer)
                            _RoleBadge(label: 'Organiser'),
                          if (role == UserRole.admin)
                            _RoleBadge(label: 'Admin'),
                        ],
                      ),
                    const SizedBox(height: 16),
                    // Stats row 1 — ELO, Played, Won, Win%
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Stat(
                            label: l.profileStatElo,
                            value: elo.toStringAsFixed(1)),
                        _Stat(
                            label: l.profileStatPlayed,
                            value: '$played'),
                        _Stat(label: l.profileStatWon, value: '$won'),
                        _Stat(
                            label: l.profileStatWinPct,
                            value: winPct),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Tier number + progress bar (hidden for RATED players)
                    _TierProgressBar(tier: tier, eloRating: elo),
                    const Divider(height: 24),
                    // Stats row 2: Rank · Peak ELO · Streak · Lost
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _Stat(
                          label: l.profileStatRank,
                          value: rankAsync.when(
                            data: (r) => r != null ? '#$r' : '—',
                            loading: () => '…',
                            error: (e, _) => '—',
                          ),
                        ),
                        _Stat(
                          label: l.profileStatPeak,
                          value: peakElo != null
                              ? peakElo.toStringAsFixed(1)
                              : elo.toStringAsFixed(1),
                        ),
                        _Stat(
                            label: l.profileStatLost, value: '$lost'),
                        _Stat(
                          label: l.profileStatStreak,
                          value: streak == 0
                              ? '—'
                              : streak > 0
                                  ? '+$streak W'
                                  : '${streak.abs()} L',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Questionnaire CTA ────────────────────────────────────────────
            if (isOwn && !questionnaireDone && played == 0)
              _QuestionnaireCta(
                  onTap: () => context.push(AppRoutes.questionnaire)),

            // ── Playing profile ──────────────────────────────────────────────
            questionnaireAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (q) => q == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _PlayingProfileSection(questionnaire: q),
                    ),
            ),

            // ── ELO sparkline ────────────────────────────────────────────────
            Text(l.profileEloHistory,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            historyAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text(l.errorCouldNotLoadHistory,
                  style:
                      const TextStyle(color: AppColors.error)),
              data: (history) => history.isEmpty
                  ? Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      child: Text(l.profileNoEloHistory,
                          style: const TextStyle(
                              color: AppColors.outline)),
                    )
                  : _EloSparkline(history: history),
            ),
            const SizedBox(height: 20),

            // ── Tournament history ───────────────────────────────────────────
            Text(l.profileSectionTournaments,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            tournamentsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => const SizedBox.shrink(),
              data: (tournaments) => tournaments.isEmpty
                  ? Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                      child: Text(l.profileNoTournaments,
                          style: const TextStyle(
                              color: AppColors.outline)),
                    )
                  : Column(
                      children: tournaments
                          .map((t) => _TournamentHistoryTile(entry: t))
                          .toList(),
                    ),
            ),
            const SizedBox(height: 20),

            // ── Match history ────────────────────────────────────────────────
            Text(l.profileMatchHistory,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            matches.isEmpty
                ? Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 12),
                    child: Text(l.profileNoMatches,
                        style: const TextStyle(
                            color: AppColors.outline)),
                  )
                : Column(
                    children: matches
                        .map((m) => _MatchHistoryTile(
                              match: m,
                              playerId: targetId,
                              showDelta: isOwn,
                            ))
                        .toList(),
                  ),
          ],
        );
      },
    );
  }

  Widget _buildAvatar(
      String? avatarUrl, String name, bool uploading) {
    const radius = 40.0;
    if (uploading) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorWidget: (ctx, err, _) => _initialsAvatar(name, radius),
        ),
      );
    }
    return _initialsAvatar(name, radius);
  }

  Widget _initialsAvatar(String name, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.primary),
      ),
    );
  }

  String _monthYear(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }
}

// ── Playing profile section ───────────────────────────────────────────────────

class _PlayingProfileSection extends StatelessWidget {
  const _PlayingProfileSection({required this.questionnaire});
  final Map<String, dynamic> questionnaire;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    final years = questionnaire['years_playing'];
    if (years != null) {
      chips.add(_InfoChip(
        icon: Icons.history_outlined,
        label: '${years == 0 ? '<1' : years} ${years == 1 ? 'year' : 'years'}',
      ));
    }

    final freq = questionnaire['playing_frequency'] as String?;
    if (freq != null) {
      chips.add(_InfoChip(
        icon: Icons.schedule_outlined,
        label: _freqLabel(freq),
      ));
    }

    final surface = questionnaire['preferred_surface'] as String?;
    if (surface != null) {
      chips.add(_InfoChip(
        icon: Icons.sports_tennis_outlined,
        label: _capitalise(surface),
      ));
    }

    final level = questionnaire['self_assessed_level'] as String?;
    if (level != null) {
      chips.add(_InfoChip(
        icon: Icons.bar_chart_outlined,
        label: _capitalise(level),
      ));
    }

    final competed = questionnaire['has_competed'] as bool?;
    if (competed != null) {
      chips.add(_InfoChip(
        icon: Icons.emoji_events_outlined,
        label: competed ? 'Tournament player' : 'Recreational',
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context)!.profileSectionPlayingProfile,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: chips),
          ],
        ),
      ),
    );
  }

  String _freqLabel(String v) => switch (v) {
        'daily' => 'Daily',
        'several_times_week' => 'Several times/week',
        'weekly' => 'Weekly',
        'biweekly' => 'Every 2 weeks',
        'monthly' => 'Monthly',
        _ => _capitalise(v),
      };

  String _capitalise(String v) =>
      v.isEmpty ? v : '${v[0].toUpperCase()}${v.substring(1)}';
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurface,
                ),
          ),
        ],
      ),
    );
  }
}

// ── Tournament history tile ───────────────────────────────────────────────────

class _TournamentHistoryTile extends StatelessWidget {
  const _TournamentHistoryTile({required this.entry});
  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final tournament = entry['tournament'] as Map<String, dynamic>?;
    if (tournament == null) return const SizedBox.shrink();

    final tName = tournament['name'] as String? ?? '—';
    final tStatus = tournament['status'] as String? ?? '';
    final startsAt =
        DateTime.tryParse((tournament['starts_at'] ?? '').toString());
    final endsAt =
        DateTime.tryParse((tournament['ends_at'] ?? '').toString());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.emoji_events_outlined,
            color: AppColors.primary),
        title: Text(tName),
        subtitle: startsAt != null
            ? Text(_dateRange(startsAt, endsAt),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.outline))
            : null,
        trailing: _TournamentStatusChip(status: tStatus),
      ),
    );
  }

  String _dateRange(DateTime start, DateTime? end) {
    final s = '${start.day}/${start.month}/${start.year}';
    if (end == null) return s;
    return '$s – ${end.day}/${end.month}/${end.year}';
  }
}

class _TournamentStatusChip extends StatelessWidget {
  const _TournamentStatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, bg) = switch (status) {
      'completed' => ('Done', AppColors.eloGain),
      'in_progress' => ('Live', AppColors.primary),
      'registration_open' => ('Open', AppColors.secondary),
      'cancelled' => ('Cancelled', AppColors.error),
      _ => ('Draft', AppColors.outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bg.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: bg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── Role badge ────────────────────────────────────────────────────────────────

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified_outlined,
              size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

// ── ELO sparkline (custom painter) ───────────────────────────────────────────

class _EloSparkline extends StatelessWidget {
  const _EloSparkline({required this.history});
  final List<Map<String, dynamic>> history;

  @override
  Widget build(BuildContext context) {
    final points = history.reversed
        .map((h) => (h['elo_after'] as num?)?.toDouble() ?? 5.0)
        .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 80,
          child: CustomPaint(
            painter:
                _SparklinePainter(points: points, color: AppColors.primary),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.points, required this.color});
  final List<double> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final min = points.reduce((a, b) => a < b ? a : b);
    final max = points.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs();
    final effectiveRange = range < 0.01 ? 1.0 : range;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i / (points.length - 1) * size.width;
      final y =
          size.height - ((points[i] - min) / effectiveRange) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.points != points;
}

// ── Match history tile ────────────────────────────────────────────────────────

class _MatchHistoryTile extends StatelessWidget {
  const _MatchHistoryTile({
    required this.match,
    required this.playerId,
    this.showDelta = false,
  });
  final Map<String, dynamic> match;
  final String playerId;
  final bool showDelta;

  String _formatScore(dynamic score) {
    if (score is! List) return '—';
    return score
        .map((s) {
          final m = s as Map;
          return '${m['winner']}–${m['loser']}';
        })
        .join(', ');
  }

  String _formatDate(dynamic date) {
    if (date == null) return '—';
    final d = DateTime.tryParse(date.toString());
    if (d == null) return date.toString();
    return '${d.day}/${d.month}/${d.year}';
  }

  double? get _eloDelta {
    if (!showDelta) return null;
    final history = match['elo_history'] as List?;
    if (history == null || history.isEmpty) return null;
    return (history.first as Map?)?['delta'] as double?;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final won = match['winner_id'] == playerId;
    final winnerName =
        (match['winner'] as Map?)?['display_name'] as String? ?? 'Winner';
    final loserName =
        (match['loser'] as Map?)?['display_name'] as String? ?? 'Loser';
    final opponent = won ? loserName : winnerName;
    final delta = _eloDelta;
    final matchType = match['match_type'] as String? ?? '';
    final tournamentName =
        (match['tournament'] as Map?)?['name'] as String?;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          won ? Icons.emoji_events_outlined : Icons.sports_tennis,
          color: won ? AppColors.eloGain : AppColors.eloLoss,
        ),
        title: Text(
            won ? l.homeMatchWonVs(opponent) : l.homeMatchLostVs(opponent)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatScore(match['score'])),
            if (matchType == 'tournament' && tournamentName != null)
              Text(
                tournamentName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primary,
                    ),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (match['elo_excluded'] == true)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.outline.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Not rated',
                  style: TextStyle(
                    color: AppColors.outline,
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                  ),
                ),
              )
            else if (delta != null)
              Text(
                '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                style: TextStyle(
                  color:
                      delta >= 0 ? AppColors.eloGain : AppColors.eloLoss,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            Text(
              _formatDate(match['played_at']),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.outline),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Questionnaire CTA card ────────────────────────────────────────────────────

class _QuestionnaireCta extends StatelessWidget {
  const _QuestionnaireCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: AppColors.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.assignment_outlined,
                  color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete your profile',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Answer a few questions to get a personalised starting rating.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: FilledButton(
                  onPressed: onTap,
                  style:
                      FilledButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text(AppLocalizations.of(context)!.profileStartQuestionnaire),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tier number + progress bar ────────────────────────────────────────────────
// Shows the current tier label in its tier colour, then a LinearProgressIndicator
// with the remaining points to the next tier shown as "#.## points to next tier".
// Hidden entirely for RATED (tier100 / 10.0) players.

class _TierProgressBar extends StatelessWidget {
  const _TierProgressBar({required this.tier, required this.eloRating});

  final EloTier tier;
  final double eloRating;

  @override
  Widget build(BuildContext context) {
    final next = tier.nextTier;
    if (next == null) return const SizedBox.shrink(); // RATED — no next tier

    final progress = ((eloRating - tier.threshold) / 0.5).clamp(0.0, 1.0);
    final remaining = (tier.threshold + 0.5) - eloRating;
    final tierColor = AppColors.tierColor(tier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tier ${tier.label}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: tierColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            Text(
              '${remaining.toStringAsFixed(2)} points to next tier',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.outline,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: tierColor.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(tierColor),
          ),
        ),
      ],
    );
  }
}

// ── Shared stat widget ────────────────────────────────────────────────────────

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

enum _AvatarAction { gallery, camera, remove }
