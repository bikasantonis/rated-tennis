/// A single match slot in a tournament bracket.
///
/// Row in `tournament_bracket_matches`.  Player fields are nullable because
/// later-round slots are created empty and filled as winners advance.
class BracketMatch {
  const BracketMatch({
    required this.id,
    required this.tournamentId,
    required this.roundNumber,
    required this.matchNumber,
    this.player1Id,
    this.player2Id,
    this.winnerId,
    this.isBye = false,
    this.player1Name,
    this.player2Name,
    this.winnerName,
  });

  final String id;
  final String tournamentId;
  final int roundNumber;
  final int matchNumber;
  final String? player1Id;
  final String? player2Id;
  final String? winnerId;
  final bool isBye;

  /// Denormalised display names fetched via a join.
  final String? player1Name;
  final String? player2Name;
  final String? winnerName;

  factory BracketMatch.fromMap(Map<String, dynamic> m) {
    final p1 = m['p1'] as Map?;
    final p2 = m['p2'] as Map?;
    final w  = m['w']  as Map?;
    return BracketMatch(
      id:           m['id'] as String,
      tournamentId: m['tournament_id'] as String,
      roundNumber:  m['round_number'] as int,
      matchNumber:  m['match_number'] as int,
      player1Id:    m['player1_id'] as String?,
      player2Id:    m['player2_id'] as String?,
      winnerId:     m['winner_id'] as String?,
      isBye:        (m['is_bye'] as bool?) ?? false,
      player1Name:  p1?['display_name'] as String?,
      player2Name:  p2?['display_name'] as String?,
      winnerName:   w?['display_name']  as String?,
    );
  }

  bool get hasResult => winnerId != null;

  /// True when both slots are filled (or it is a bye) and no result yet.
  bool get isReady =>
      !hasResult && (isBye || (player1Id != null && player2Id != null));
}
