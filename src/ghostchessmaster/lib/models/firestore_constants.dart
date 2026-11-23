/// Central Firestore collection and field name constants.
/// All services MUST reference these constants instead of hardcoded strings.
class FirestoreConstants {
  FirestoreConstants._();

  // ─── Root Collections ───────────────────────────────────────────────
  static const String usersCollection = 'users';
  static const String userIslandCollection = 'user_island';
  static const String islandsCollection = 'islands';
  static const String matchesHistoryCollection = 'matches_history';
  static const String liveSessionCollection = 'live_session';
  static const String boardsCollection = 'boards';

  // ─── Subcollections ─────────────────────────────────────────────────
  /// Subcollection under `user_island/{userId}/`
  static const String userIslandSubcollection = 'islands';

  /// Subcollection under `matches_history/{matchId}/`
  static const String moveAnalysisDetailSubcollection = 'move_analysis_detail';

  // ─── Analysis Type Discriminator Values ─────────────────────────────
  static const String analysisTypeLive = 'live';
  static const String analysisTypeDeep = 'deep';

  // ─── Match Type Values ──────────────────────────────────────────────
  static const String matchTypeTraining = 'training';
  static const String matchTypeQuickMatch = 'quick_match';

  // ─── Analyzer Mode Values ───────────────────────────────────────────
  static const String analyzerModeLive = 'live_game_analysis';
  static const String analyzerModeDeep = 'deep_game_analysis';
  static const String analyzerModeNone = 'none';

  // ─── Match Status Values ────────────────────────────────────────────
  static const String statusInProgress = 'in_progress';
  static const String statusCompleted = 'completed';
  static const String statusSurrendered = 'surrendered';
  static const String statusDraw = 'draw';

  // ─── Match Result Values ────────────────────────────────────────────
  static const String resultVictory = 'victory';
  static const String resultDefeat = 'defeat';
  static const String resultDraw = 'draw';
  static const String resultOngoing = 'ongoing';

  // ─── Total Islands & Rounds ─────────────────────────────────────────
  static const int totalIslands = 20;
  static const int roundsPerIsland = 4;
}
