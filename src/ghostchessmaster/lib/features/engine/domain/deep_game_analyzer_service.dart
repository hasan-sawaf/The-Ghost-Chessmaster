import 'package:flutter/foundation.dart';
import '../services/stockfish_engine_service.dart';
import 'chess_evaluator.dart';
import 'game_analyzer_logic.dart';

/// Progress callback reported during deep post-game analysis.
typedef DeepAnalysisProgressCallback = void Function(
  int currentMove,
  int totalMoves,
  double progressPercentage,
);

/// Service responsible for performing deep post-game analysis on a full chess match at depth 20.
class DeepGameAnalyzerService {
  static final DeepGameAnalyzerService _instance =
      DeepGameAnalyzerService._internal();
  static DeepGameAnalyzerService get instance => _instance;
  DeepGameAnalyzerService._internal();

  /// Generates standard Portable Game Notation (PGN) SAN text from move history log.
  /// Example: "1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4 4. Nxe5 Qg5 5. Nxf7 Qxg2 6. Rf1 Qxe4+ 7. Be2 Nf3#"
  static String formatFullGamePgn(List<Map<String, dynamic>> moveLog) {
    final pgnBuffer = StringBuffer();
    for (int i = 0; i < moveLog.length; i++) {
      final move = moveLog[i];
      final String san = move['move'] as String? ?? move['san'] as String? ?? '';
      final String player = move['player'] as String? ?? (i % 2 == 0 ? 'White' : 'Black');

      if (player == 'White' || i % 2 == 0) {
        final moveNum = (i ~/ 2) + 1;
        if (i > 0) pgnBuffer.write(' ');
        pgnBuffer.write('$moveNum. $san');
      } else {
        pgnBuffer.write(' $san');
      }
    }
    return pgnBuffer.toString();
  }

  /// Deeply analyzes an entire match at depth 20, move by move.
  ///
  /// Updates each move entry with exact evaluation, centipawn loss, move classification,
  /// icon asset path (`assets/icons/1024x/<type>_1024x.png`), and accuracy percentage.
  Future<Map<String, dynamic>> analyzeFullGameDeeply({
    required List<Map<String, dynamic>> rawMoveLog,
    required bool isPlayerWhite,
    DeepAnalysisProgressCallback? onProgress,
  }) async {
    final updatedLog = <Map<String, dynamic>>[];
    final totalMoves = rawMoveLog.length;

    if (totalMoves == 0) {
      return {
        'moveLog': <Map<String, dynamic>>[],
        'overallAccuracy': 100,
        'pgn': '',
      };
    }

    // Ensure Stockfish engine hash is fully reset from 0 and configured at max depth 20 power
    await StockfishEngineService.instance.ensureEngineReady(elo: null);

    for (int i = 0; i < totalMoves; i++) {
      final rawMove = rawMoveLog[i];
      final String moveUci = rawMove['uci'] as String;
      final String moveSan = rawMove['move'] as String? ?? rawMove['san'] as String? ?? '';
      final String fenBefore = rawMove['fenBefore'] as String;
      final String fenAfter = rawMove['fenAfter'] as String;
      final bool isWhite = rawMove['isWhite'] as bool? ?? (i % 2 == 0);

      try {
        final result = await GameAnalyzerLogic.evaluateAndAnalyzeMove(
          moveUci: moveUci,
          moveSan: moveSan,
          fenBefore: fenBefore,
          fenAfter: fenAfter,
          isWhite: isWhite,
          currentMoveLog: updatedLog,
          isPlayerWhite: isPlayerWhite,
          depth: 20,
          moveTime: null,
        );

        final moveEntry = Map<String, dynamic>.from(result.moveEntry);
        // Ensure fenBefore and fenAfter are preserved for step-by-step playback
        moveEntry['fenBefore'] = fenBefore;
        moveEntry['fenAfter'] = fenAfter;
        moveEntry['isWhite'] = isWhite;

        updatedLog.add(moveEntry);
      } catch (e) {
        debugPrint('[DEEP_ANALYZER] Error evaluating move ${i + 1}: $e');
        // Fallback for move if evaluation fails
        final fallbackEntry = Map<String, dynamic>.from(rawMove);
        fallbackEntry['eval'] = '0.00';
        fallbackEntry['cpl'] = 0;
        fallbackEntry['classification'] = MoveClassification.good.label;
        fallbackEntry['icon'] = MoveClassification.good.name;
        fallbackEntry['accuracy'] = 100;
        updatedLog.add(fallbackEntry);
      }

      // Report progress callback AFTER move evaluation completes to prevent UI freeze illusion
      if (onProgress != null) {
        onProgress(i + 1, totalMoves, (i + 1) / totalMoves);
      }
      await Future.delayed(const Duration(milliseconds: 20));
    }

    final int overallAccuracy = ChessEvaluator.computeOverallGameAccuracy(
      updatedLog,
      isPlayerWhite,
    ).round();

    final String pgnText = formatFullGamePgn(updatedLog);

    return {
      'moveLog': updatedLog,
      'overallAccuracy': overallAccuracy,
      'pgn': pgnText,
    };
  }
}
