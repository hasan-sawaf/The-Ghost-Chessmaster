import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../training/domain/training_theme_helper.dart';
import '../../../../models/firestore_constants.dart';

/// Data model representing a saved chess match in Firebase Firestore & local device cache.
/// Stored in root collection `matches_history` (PK: `id`).
///
/// Move analysis data is stored separately in the `move_analysis_detail` subcollection
/// under `matches_history/{matchId}/move_analysis_detail/`.
/// However, for local device cache (SharedPreferences), move arrays remain embedded
/// inside this model for offline support.
class MatchRecordModel {
  final String id;
  final String userId; // FK → users.id
  final String? boardId; // FK → boards.id (nullable for digital/quick matches)
  final String? islandId; // FK → user_island.island_id (nullable for non-training matches)
  final String matchType; // 'training' or 'quick_match'
  final String analyzerMode; // 'live_game_analysis' or 'deep_game_analysis' or 'none'
  final bool deepAnalyzed;
  final String playerColor; // 'white' or 'black'
  final String opponentName;
  final int? roundIndex;
  final String? islandTitle;
  final int stockfishLevel;
  final String status; // 'in_progress', 'completed', 'surrendered', 'draw'
  final String result; // 'victory', 'defeat', 'draw', 'ongoing'
  final String? resultReason; // 'surrendered', 'checkmate', 'timeout', 'stalemate'
  final int accuracy; // Current primary accuracy score
  final int liveAccuracy; // Dedicated Live Game Analysis accuracy
  final int? deepAccuracy; // Dedicated Deep Game Analysis accuracy
  final int moveCount;
  final String pgn;
  final String fen;
  final List<Map<String, dynamic>> moveLog; // Primary move log (defaults to Live) — LOCAL CACHE ONLY
  final List<Map<String, dynamic>> liveMoveLog; // Dedicated Live Game Analysis move log — LOCAL CACHE ONLY
  final List<Map<String, dynamic>>? deepMoveLog; // Dedicated Deep Game Analysis move log — LOCAL CACHE ONLY
  final String pieceTheme;
  final DateTime startedAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  MatchRecordModel({
    required this.id,
    required this.userId,
    this.boardId,
    this.islandId,
    required this.matchType,
    required this.analyzerMode,
    this.deepAnalyzed = false,
    required this.playerColor,
    required this.opponentName,
    this.roundIndex,
    this.islandTitle,
    required this.stockfishLevel,
    required this.status,
    required this.result,
    this.resultReason,
    required this.accuracy,
    int? liveAccuracy,
    this.deepAccuracy,
    required this.moveCount,
    required this.pgn,
    required this.fen,
    required this.moveLog,
    List<Map<String, dynamic>>? liveMoveLog,
    this.deepMoveLog,
    this.pieceTheme = 'Standered',
    required this.startedAt,
    required this.updatedAt,
    this.completedAt,
  })  : liveAccuracy = liveAccuracy ?? accuracy,
        liveMoveLog = liveMoveLog ?? moveLog;

  bool get isDeepAnalyzed => deepAnalyzed || analyzerMode == FirestoreConstants.analyzerModeDeep || (deepMoveLog != null && deepMoveLog!.isNotEmpty);

  /// Returns true if the game has any real analysis data (live or deep).
  /// Games played in Deep Analyzer mode without running analysis should return false.
  bool get hasRealAnalysis {
    if (isDeepAnalyzed) return true;
    // Check if live analysis was performed (moves have real classification data)
    if (analyzerMode == FirestoreConstants.analyzerModeLive && liveMoveLog.isNotEmpty) {
      return liveMoveLog.any((m) =>
          (m.containsKey('classification') && m['classification'] != null && m['classification'].toString().isNotEmpty) ||
          (m.containsKey('isAnalyzing') && m['isAnalyzing'] == false));
    }
    return false;
  }

  /// Serializes to Firestore-compatible map for the `matches_history` root document.
  /// Serializes to Firestore-compatible map for the `matches_history` root document.
  /// **EXCLUDES** embedded move arrays completely — all move data is stored exclusively in `move_analysis_detail` subcollection.
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'user_id': userId,
      'board_id': boardId,
      'island_id': islandId,
      'match_type': matchType,
      'analyzer_mode': isDeepAnalyzed
          ? FirestoreConstants.analyzerModeDeep
          : (hasRealAnalysis ? FirestoreConstants.analyzerModeLive : (analyzerMode == FirestoreConstants.analyzerModeNone ? FirestoreConstants.analyzerModeNone : analyzerMode)),
      'deep_analyzed': isDeepAnalyzed,
      'player_color': playerColor,
      'opponent_name': opponentName,
      'round_index': roundIndex,
      'island_title': islandTitle,
      'stockfish_level': stockfishLevel,
      'status': status,
      'result': result,
      'result_reason': resultReason,
      'accuracy': accuracy,
      'live_accuracy': liveAccuracy,
      'deep_accuracy': deepAccuracy,
      'move_count': moveCount,
      'pgn': pgn,
      'fen': fen,
      'piece_theme': pieceTheme,
      'started_at': Timestamp.fromDate(startedAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'completed_at': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };
  }

  /// Serializes to local cache map (SharedPreferences).
  /// **INCLUDES** embedded move arrays for offline support.
  /// Uses camelCase keys for backward compatibility with existing local cache.
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> map = {
      'id': id,
      'userId': userId,
      'boardId': boardId,
      'islandId': islandId,
      'matchType': matchType,
      'analyzerMode': isDeepAnalyzed
          ? FirestoreConstants.analyzerModeDeep
          : (hasRealAnalysis ? FirestoreConstants.analyzerModeLive : (analyzerMode == FirestoreConstants.analyzerModeNone ? FirestoreConstants.analyzerModeNone : analyzerMode)),
      'deep_analyzed': isDeepAnalyzed,
      'playerColor': playerColor,
      'opponentName': opponentName,
      'roundIndex': roundIndex,
      'islandTitle': islandTitle,
      'stockfishLevel': stockfishLevel,
      'status': status,
      'result': result,
      'resultReason': resultReason,
      'accuracy': accuracy,
      'liveAccuracy': liveAccuracy,
      'deepAccuracy': deepAccuracy,
      'moveCount': moveCount,
      'pgn': pgn,
      'fen': fen,
      'moveLog': liveMoveLog, // Preserve live analysis move log
      'liveMoveLog': liveMoveLog,
      'pieceTheme': pieceTheme,
      'startedAt': Timestamp.fromDate(startedAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
    };

    if (deepMoveLog != null && deepMoveLog!.isNotEmpty) {
      map['deepMoveLog'] = deepMoveLog;
      map['deep_analysis'] = deepMoveLog;
    }

    return map;
  }

  factory MatchRecordModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    int parseIslandIndex(String? title) {
      if (title == null) return 1;
      final match = RegExp(r'\d+').firstMatch(title);
      if (match != null) {
        return int.tryParse(match.group(0)!) ?? 1;
      }
      return 1;
    }

    // Support both snake_case (Firestore) and camelCase (local cache) keys
    final roundIndex = (map['roundIndex'] ?? map['round_index']) as int?;
    final islandTitle = (map['islandTitle'] ?? map['island_title']) as String?;
    String matchType = (map['matchType'] ?? map['match_type']) as String? ?? '';
    if (matchType.isEmpty) {
      if (roundIndex != null || islandTitle != null) {
        matchType = FirestoreConstants.matchTypeTraining;
      } else {
        matchType = FirestoreConstants.matchTypeQuickMatch;
      }
    }

    String defaultTheme = 'Standered';
    if (matchType == FirestoreConstants.matchTypeTraining && roundIndex != null) {
      final islandIdx = parseIslandIndex(islandTitle);
      defaultTheme = TrainingThemeHelper.getTrainingPieceTheme(islandIdx, roundIndex);
    }

    final rawMoveLog = ((map['moveLog'] ?? map['move_log'] ?? map['liveMoveLog'] ?? map['live_move_log']) as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [];

    final rawLiveMoveLog = ((map['liveMoveLog'] ?? map['live_move_log'] ?? map['moveLog'] ?? map['move_log']) as List<dynamic>?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        rawMoveLog;

    final rawDeepMoveLog = ((map['deepMoveLog'] ?? map['deep_move_log'] ?? map['deep_analysis']) as List<dynamic>?)
        ?.map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final isDeep = (map['deep_analyzed'] as bool?) ??
        ((map['analyzerMode'] ?? map['analyzer_mode']) == FirestoreConstants.analyzerModeDeep) ||
        (rawDeepMoveLog != null && rawDeepMoveLog.isNotEmpty);

    final bool hasLiveEval = rawLiveMoveLog.any((m) =>
        (m.containsKey('classification') && m['classification'] != null && m['classification'].toString().isNotEmpty) ||
        (m.containsKey('isAnalyzing') && m['isAnalyzing'] == false));

    final String rawAnalyzerMode = (map['analyzerMode'] ?? map['analyzer_mode']) as String? ?? FirestoreConstants.analyzerModeNone;
    final String resolvedAnalyzerMode = isDeep
        ? FirestoreConstants.analyzerModeDeep
        : (hasLiveEval ? FirestoreConstants.analyzerModeLive : (rawAnalyzerMode == FirestoreConstants.analyzerModeLive && !hasLiveEval ? FirestoreConstants.analyzerModeNone : rawAnalyzerMode));

    final rawAccuracy = (map['accuracy'] as num?)?.toInt() ?? 0;
    final liveAcc = ((map['liveAccuracy'] ?? map['live_accuracy']) as num?)?.toInt() ?? rawAccuracy;
    final deepAcc = ((map['deepAccuracy'] ?? map['deep_accuracy']) as num?)?.toInt();

    return MatchRecordModel(
      id: map['id'] as String? ?? docId,
      userId: (map['userId'] ?? map['user_id']) as String? ?? '',
      boardId: (map['boardId'] ?? map['board_id']) as String?,
      islandId: (map['islandId'] ?? map['island_id']) as String?,
      matchType: matchType,
      analyzerMode: resolvedAnalyzerMode,
      deepAnalyzed: isDeep,
      playerColor: (map['playerColor'] ?? map['player_color']) as String? ?? 'white',
      opponentName: (map['opponentName'] ?? map['opponent_name']) as String? ?? 'Stockfish AI',
      roundIndex: roundIndex,
      islandTitle: islandTitle,
      stockfishLevel: (map['stockfishLevel'] ?? map['stockfish_level']) as int? ?? 5,
      status: map['status'] as String? ?? FirestoreConstants.statusCompleted,
      result: map['result'] as String? ?? FirestoreConstants.resultVictory,
      resultReason: (map['resultReason'] ?? map['result_reason']) as String?,
      accuracy: rawAccuracy,
      liveAccuracy: liveAcc,
      deepAccuracy: deepAcc,
      moveCount: ((map['moveCount'] ?? map['move_count']) as num?)?.toInt() ?? rawLiveMoveLog.length,
      pgn: map['pgn'] as String? ?? '',
      fen: map['fen'] as String? ?? '',
      moveLog: rawLiveMoveLog,
      liveMoveLog: rawLiveMoveLog,
      deepMoveLog: rawDeepMoveLog,
      pieceTheme: (map['pieceTheme'] ?? map['piece_theme']) as String? ?? defaultTheme,
      startedAt: parseDate(map['startedAt'] ?? map['started_at']),
      updatedAt: parseDate(map['updatedAt'] ?? map['updated_at']),
      completedAt: (map['completedAt'] ?? map['completed_at']) != null ? parseDate(map['completedAt'] ?? map['completed_at']) : null,
    );
  }

  factory MatchRecordModel.fromFirestoreDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MatchRecordModel.fromMap(data, doc.id);
  }

  MatchRecordModel copyWith({
    String? id,
    String? userId,
    String? boardId,
    String? islandId,
    String? matchType,
    String? analyzerMode,
    bool? deepAnalyzed,
    String? playerColor,
    String? opponentName,
    int? roundIndex,
    String? islandTitle,
    int? stockfishLevel,
    String? status,
    String? result,
    String? resultReason,
    int? accuracy,
    int? liveAccuracy,
    int? deepAccuracy,
    int? moveCount,
    String? pgn,
    String? fen,
    List<Map<String, dynamic>>? moveLog,
    List<Map<String, dynamic>>? liveMoveLog,
    List<Map<String, dynamic>>? deepMoveLog,
    String? pieceTheme,
    DateTime? startedAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return MatchRecordModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      boardId: boardId ?? this.boardId,
      islandId: islandId ?? this.islandId,
      matchType: matchType ?? this.matchType,
      analyzerMode: analyzerMode ?? this.analyzerMode,
      deepAnalyzed: deepAnalyzed ?? this.deepAnalyzed,
      playerColor: playerColor ?? this.playerColor,
      opponentName: opponentName ?? this.opponentName,
      roundIndex: roundIndex ?? this.roundIndex,
      islandTitle: islandTitle ?? this.islandTitle,
      stockfishLevel: stockfishLevel ?? this.stockfishLevel,
      status: status ?? this.status,
      result: result ?? this.result,
      resultReason: resultReason ?? this.resultReason,
      accuracy: accuracy ?? this.accuracy,
      liveAccuracy: liveAccuracy ?? this.liveAccuracy,
      deepAccuracy: deepAccuracy ?? this.deepAccuracy,
      moveCount: moveCount ?? this.moveCount,
      pgn: pgn ?? this.pgn,
      fen: fen ?? this.fen,
      moveLog: moveLog ?? this.moveLog,
      liveMoveLog: liveMoveLog ?? this.liveMoveLog,
      deepMoveLog: deepMoveLog ?? this.deepMoveLog,
      pieceTheme: pieceTheme ?? this.pieceTheme,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
