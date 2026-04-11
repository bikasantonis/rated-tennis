import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rated/l10n/app_localizations.dart';

import 'package:rated/models/profile.dart';
import 'package:rated/providers/auth_provider.dart';
import 'package:rated/providers/profile_provider.dart';
import 'package:rated/router/app_router.dart';
import 'package:rated/theme/app_colors.dart';
import 'package:rated/widgets/tier_badge.dart';

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
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          Scaffold(body: Center(child: Text('Error: $e'))),
      data: (self) {
        final targetId = playerId ?? self?.id;
        if (targetId == null) {
          return Scaffold(
              body: Center(child: Text(l.errorNotLoggedIn)));
        }
        final isOwn = playerId == null || playerId == self?.id;
        return _ProfileView(
            targetId: targetId, isOwn: isOwn, selfId: self?.id);
      },
    );
  }
}

class _ProfileView extends ConsumerWidget {
  const _ProfileView(
      {required this.targetId,
      required this.isOwn,
      required this.selfId});

  final String targetId;
  final bool isOwn;
  final String? selfId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final profileAsync = ref.watch(playerProfileProvider(targetId));

    return Scaffold(
      appBar: AppBar(
        title: Text(isOwn ? l.profileMyProfile : l.profileTitle),
        actions: [
          if (isOwn)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => _showEditDialog(context, ref, targetId,
                  profileAsync.asData?.value?['display_name'] as String? ?? ''),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (profile) {
          if (profile == null) {
            return Center(child: Text(l.errorProfileNotFound));
          }
          return _ProfileBody(
              profile: profile, targetId: targetId, isOwn: isOwn);
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
    if (context.mounted) ref.invalidate(playerProfileProvider(playerId));
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody(
      {required this.profile,
      required this.targetId,
      required this.isOwn});

  final Map<String, dynamic> profile;
  final String targetId;
  final bool isOwn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final name = profile['display_name'] as String? ?? '—';
    final elo = (profile['elo_rating'] as num?)?.toDouble() ?? 5.0;
    final tierStr = profile['elo_tier'] as String? ?? 'beginner';
    final tier = EloTier.values.firstWhere(
      (t) => t.name == tierStr,
      orElse: () => EloTier.beginner,
    );
    final played = profile['matches_played'] as int? ?? 0;
    final won = profile['matches_won'] as int? ?? 0;
    final winPct = played == 0 ? '—' : '${(won / played * 100).round()}%';

    final historyAsync = ref.watch(eloHistoryProvider(targetId));
    final matchesAsync = ref.watch(playerMatchesProvider(targetId));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Header card ────────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor:
                      AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 12),
                Text(name,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                TierBadge(tier: tier),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _Stat(label: l.profileStatElo, value: elo.toStringAsFixed(1)),
                    _Stat(label: l.profileStatPlayed, value: '$played'),
                    _Stat(label: l.profileStatWon, value: '$won'),
                    _Stat(label: l.profileStatWinPct, value: winPct),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Questionnaire CTA ──────────────────────────────────────────
        // Visible on own profile only, until the first match is registered.
        if (isOwn &&
            (profile['questionnaire_done'] as bool? ?? false) == false &&
            (profile['matches_played'] as int? ?? 0) == 0)
          _QuestionnaireCta(onTap: () => context.push(AppRoutes.questionnaire)),

        // ── ELO sparkline ──────────────────────────────────────────────
        Text(l.profileEloHistory,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        historyAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(l.errorCouldNotLoadHistory,
              style: TextStyle(color: AppColors.error)),
          data: (history) => history.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l.profileNoEloHistory,
                      style: TextStyle(color: AppColors.outline)),
                )
              : _EloSparkline(history: history),
        ),
        const SizedBox(height: 20),

        // ── Match history ──────────────────────────────────────────────
        Text(l.profileMatchHistory,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        matchesAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text(l.errorCouldNotLoadMatches,
              style: TextStyle(color: AppColors.error)),
          data: (matches) => matches.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(l.profileNoMatches,
                      style: TextStyle(color: AppColors.outline)),
                )
              : Column(
                  children: matches
                      .map((m) => _MatchHistoryTile(
                          match: m, playerId: targetId, showDelta: isOwn))
                      .toList(),
                ),
        ),
      ],
    );
  }
}

// ── ELO sparkline (simple custom painter) ────────────────────────────────────

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
            painter: _SparklinePainter(
                points: points, color: AppColors.primary),
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
      final y = size.height -
          ((points[i] - min) / effectiveRange) * size.height;
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
        .map((s) { final m = s as Map; return '${m['winner']}–${m['loser']}'; })
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

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          won ? Icons.emoji_events_outlined : Icons.sports_tennis,
          color: won ? AppColors.eloGain : AppColors.eloLoss,
        ),
        title: Text(
            won ? l.homeMatchWonVs(opponent) : l.homeMatchLostVs(opponent)),
        subtitle: Text(_formatScore(match['score'])),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (delta != null)
              Text(
                '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}',
                style: TextStyle(
                  color: delta >= 0 ? AppColors.eloGain : AppColors.eloLoss,
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
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        color: AppColors.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.assignment_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete your profile',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
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
              FilledButton(
                onPressed: onTap,
                child: const Text('Start'),
              ),
            ],
          ),
        ),
      ),
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
