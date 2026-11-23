import '../../training/utils/chess_logic.dart';
import '../services/stockfish_engine_service.dart';
import 'chess_evaluator.dart';

/// Result object returned after analyzing a chess move.
class MoveAnalysisResult {
  final double evaluationScore;
  final double evalBarValue;
  final Map<String, dynamic> moveEntry;
  final int overallAccuracy;

  MoveAnalysisResult({
    required this.evaluationScore,
    required this.evalBarValue,
    required this.moveEntry,
    required this.overallAccuracy,
  });
}

/// Core Game Analyzer Logic for position evaluation and move accuracy classification.
/// ALWAYS evaluates at maximum engine strength (Depth 20) regardless of AI player level.
class GameAnalyzerLogic {
  /// Deep analysis depth — strict Depth 20 evaluation
  static const int analysisDepth = 20;

  /// Piece values for sacrifice detection
  static const Map<String, int> _pieceValues = {
    'P': 100,
    'N': 320,
    'B': 330,
    'R': 500,
    'Q': 900,
    'K': 0,
  };

  /// Returns true if [fenAfter] is a checkmate position (king in check + zero legal moves)
  static bool isFenCheckmate(String fenAfter) {
    if (fenAfter.isEmpty) return false;
    try {
      final parts = fenAfter.split(' ');
      if (parts.length < 2) return false;
      final isWhiteTurn = parts[1] == 'w';

      final board = List.generate(8, (_) => List<String?>.filled(8, null));
      final rows = parts[0].split('/');
      for (int r = 0; r < 8 && r < rows.length; r++) {
        int c = 0;
        for (int i = 0; i < rows[r].length && c < 8; i++) {
          final char = rows[r][i];
          if (RegExp(r'\d').hasMatch(char)) {
            c += int.parse(char);
          } else {
            final isWhitePiece = char == char.toUpperCase();
            final pieceChar = char.toUpperCase();
            board[r][c] = '${isWhitePiece ? 'W' : 'B'}$pieceChar';
            c++;
          }
        }
      }

      if (!ChessLogic.isKingInCheck(board, isWhiteTurn)) return false;

      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          final piece = board[r][c];
          if (piece != null && (isWhiteTurn ? piece.startsWith('W') : piece.startsWith('B'))) {
            final moves = ChessLogic.getLegalMoves(board, r, c, isWhiteTurn);
            if (moves.isNotEmpty) return false;
          }
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Detect if a move is a material sacrifice.
  /// A sacrifice = the mover's material drops after the move, while the
  /// resulting position is still good (best/equal or better).
  static bool _isSacrifice({
    required String fenBefore,
    required String fenAfter,
    required bool moverIsWhite,
  }) {
    final materialBefore = _countMaterial(fenBefore, moverIsWhite);
    final materialAfter = _countMaterial(fenAfter, moverIsWhite);
    final opponentBefore = _countMaterial(fenBefore, !moverIsWhite);
    final opponentAfter = _countMaterial(fenAfter, !moverIsWhite);

    // Did we lose more material than our opponent?
    final moverLoss = materialBefore - materialAfter;
    final opponentLoss = opponentBefore - opponentAfter;

    // A sacrifice is when we give up material voluntarily (net material loss ≥ 100cp / 1 pawn)
    return (moverLoss - opponentLoss) >= 100;
  }

  /// Count total material value for one side from a FEN string.
  static int _countMaterial(String fen, bool forWhite) {
    final boardPart = fen.split(' ').first;
    int total = 0;
    for (final ch in boardPart.runes) {
      final c = String.fromCharCode(ch);
      if (c == '/' || c == ' ') continue;
      if (int.tryParse(c) != null) continue; // digit = empty squares

      final isWhitePiece = c == c.toUpperCase();
      if (isWhitePiece == forWhite) {
        total += _pieceValues[c.toUpperCase()] ?? 0;
      }
    }
    return total;
  }

  static Future<MoveAnalysisResult> evaluateAndAnalyzeMove({
    required String moveUci,
    required String moveSan,
    required String fenBefore,
    required String fenAfter,
    required bool isWhite,
    required List<Map<String, dynamic>> currentMoveLog,
    required bool isPlayerWhite,
    int depth = 16,
    int? moveTime = 800,
  }) async {
    // Build clean UCI history without duplicate current move
    final playedUciHistory = <String>[];
    for (final m in currentMoveLog) {
      final uci = m['uci'] as String?;
      if (uci != null && uci.isNotEmpty) {
        if (playedUciHistory.isEmpty || playedUciHistory.last != uci) {
          playedUciHistory.add(uci);
        }
      }
    }
    if (playedUciHistory.isEmpty || playedUciHistory.last != moveUci) {
      playedUciHistory.add(moveUci);
    }

    // Check if ALL previous moves in currentMoveLog were book moves.
    // Opening book moves MUST form an unbroken sequence starting from Move 1.
    // The moment a non-book move occurs, no subsequent move can ever be a book move.
    bool isBookChainIntact = true;
    for (final m in currentMoveLog) {
      final uci = m['uci'] as String?;
      if (uci == moveUci) continue; // Skip current move being evaluated
      final isAnalyzing = m['isAnalyzing'] == true;
      if (isAnalyzing) continue; // Skip unanalyzed draft entries

      final classLabel = m['classification']?.toString();
      final iconKey = m['icon']?.toString();
      final isPreviousBook = (classLabel == MoveClassification.book.label ||
          classLabel == 'Book' ||
          iconKey == MoveClassification.book.name ||
          iconKey == 'book');
      if (!isPreviousBook) {
        isBookChainIntact = false;
        break;
      }
    }

    // 0. Book Move Short-Circuit (Only during opening phase with unbroken book sequence)
    if (isBookChainIntact && ChessEvaluator.isBookMove(playedUciHistory)) {
      final double dummyEval = isWhite ? 0.35 : -0.35;
      double evalBarValue = (dummyEval + 10.0) / 20.0;
      evalBarValue = evalBarValue.clamp(0.05, 0.95);

      final moveEntry = {
        'num': (currentMoveLog.length ~/ 2) + 1,
        'player': isWhite ? 'White' : 'Black',
        'move': moveSan,
        'uci': moveUci,
        'eval': dummyEval > 0
            ? '+${dummyEval.toStringAsFixed(2)}'
            : dummyEval.toStringAsFixed(2),
        'evalScore': dummyEval,
        'cpDiff': 0,
        'cpl': 0,
        'accuracy': 100,
        'moveAcc': 100.0,
        'classification': MoveClassification.book.label,
        'icon': MoveClassification.book.name,
      };

      final updatedLog = List<Map<String, dynamic>>.from(currentMoveLog);
      final existingIdx = updatedLog.indexWhere((m) => m['uci'] == moveUci && m['fenAfter'] == fenAfter);
      if (existingIdx != -1) {
        updatedLog[existingIdx] = moveEntry;
      } else {
        updatedLog.add(moveEntry);
      }

      final overallAccuracy = ChessEvaluator.computeOverallGameAccuracy(
        updatedLog,
        isPlayerWhite,
      ).round();

      return MoveAnalysisResult(
        evaluationScore: dummyEval,
        evalBarValue: evalBarValue,
        moveEntry: moveEntry,
        overallAccuracy: overallAccuracy,
      );
    }

    // ──────────────────────────────────────────────────────
    // 1. Evaluate the BEFORE position
    // ──────────────────────────────────────────────────────
    final beforeEval = await StockfishEngineService.instance.evaluatePosition(
      [],
      fen: fenBefore,
      depth: depth,
      moveTime: moveTime,
      elo: null,
    );
    final double beforeCpRaw = (beforeEval['cp'] as num).toDouble();
    final bool beforeIsMate = beforeEval['is_mate'] as bool? ?? false;
    final int beforeMateInRaw = beforeEval['mate_in'] as int? ?? 0;
    final String bestMoveUci = beforeEval['best_move'] as String? ?? '';

    // ──────────────────────────────────────────────────────
    // 2. Evaluate the AFTER position
    // ──────────────────────────────────────────────────────
    final bool afterCheckmate = isFenCheckmate(fenAfter) ||
        moveSan.contains('#') ||
        moveSan.endsWith('#');

    Map<String, dynamic> afterEval;
    if (afterCheckmate) {
      afterEval = {
        'cp': 0.0,
        'is_mate': true,
        'mate_in': 0,
        'best_move': '',
      };
    } else {
      afterEval = await StockfishEngineService.instance.evaluatePosition(
        [],
        fen: fenAfter,
        depth: depth,
        moveTime: moveTime,
        elo: null,
      );
    }
    final double afterCpRaw = (afterEval['cp'] as num).toDouble();
    final bool afterIsMate = afterEval['is_mate'] as bool? ?? false;
    final int afterMateInRaw = afterEval['mate_in'] as int? ?? 0;

    // ──────────────────────────────────────────────────────
    // 3. Normalize ALL scores to White's perspective.
    //    Stockfish reports from the side-to-move's viewpoint.
    //
    //    BEFORE: side-to-move = isWhite
    //      - If isWhite=true  → cp already from White's PoV → keep as is
    //      - If isWhite=false → cp from Black's PoV → negate to get White's PoV
    //
    //    AFTER: side-to-move = !isWhite (the opponent)
    //      - If isWhite=true  → after move, it's Black to move → cp from Black's PoV → negate
    //      - If isWhite=false → after move, it's White to move → cp from White's PoV → keep as is
    // ──────────────────────────────────────────────────────
    final double bestCpWhite = isWhite ? beforeCpRaw : -beforeCpRaw;
    final int bestMateInWhite = isWhite ? beforeMateInRaw : -beforeMateInRaw;

    final double playedCpWhite = isWhite ? -afterCpRaw : afterCpRaw;
    final int playedMateInWhite = isWhite ? -afterMateInRaw : afterMateInRaw;

    final bestScore = NormalizedScore(
      isMate: beforeIsMate,
      cp: bestCpWhite,
      mateIn: bestMateInWhite,
    );
    final playedScore = NormalizedScore(
      isMate: afterIsMate,
      cp: playedCpWhite,
      mateIn: playedMateInWhite,
    );

    // ──────────────────────────────────────────────────────
    // 4. Determine move properties
    // ──────────────────────────────────────────────────────
    final bool isCheckmate = moveSan.contains('#') ||
        moveSan.endsWith('#') ||
        (afterIsMate && afterMateInRaw == 0) ||
        isFenCheckmate(fenAfter);

    final isBestMove = (moveUci == bestMoveUci) || isCheckmate;

    // Detect material sacrifice for brilliant move classification
    final bool isSacrifice = _isSacrifice(
      fenBefore: fenBefore,
      fenAfter: fenAfter,
      moverIsWhite: isWhite,
    );

    // ──────────────────────────────────────────────────────
    // 5. Compute CPL and mate swing
    // ──────────────────────────────────────────────────────
    double cpl = 0.0;
    bool isMateSwing = false;

    if (isCheckmate || isBestMove) {
      cpl = 0.0;
    } else {
      final cplRes = ChessEvaluator.computeCpl(bestScore, playedScore, isWhite);
      cpl = (cplRes['cpl'] as num).toDouble();
      isMateSwing = cplRes['is_mate_swing'] as bool? ?? false;
    }

    // Detect Great Move (Great Find): Finding the best move in a critical or tense position
    bool isGreatMove = false;
    if (isBestMove && !isSacrifice && !isCheckmate) {
      final double moverBestPawns = (isWhite ? bestCpWhite : -bestCpWhite) / 100.0;
      if (moverBestPawns >= -2.0 && moverBestPawns <= 1.5) {
        isGreatMove = true;
      }
    }

    // ──────────────────────────────────────────────────────
    // 6. Compute move accuracy using Win Probability model & CPL caps
    // ──────────────────────────────────────────────────────
    final accuracy = ChessEvaluator.computeMoveAccuracy(
      bestScore: bestScore,
      playedScore: playedScore,
      sideIsWhite: isWhite,
      isBestMove: isBestMove,
      isCheckmate: isCheckmate,
    );

    // ──────────────────────────────────────────────────────
    // 7. Classify the move with strict accuracy and CPL synchronization
    // ──────────────────────────────────────────────────────
    final classification = ChessEvaluator.classifyMove(
      bestScore: bestScore,
      playedScore: playedScore,
      sideIsWhite: isWhite,
      isBestMove: isBestMove,
      isCheckmate: isCheckmate,
      isSacrifice: isSacrifice,
      isBookMove: false,
      isMateSwing: isMateSwing,
      isGreatMove: isGreatMove,
      accuracy: accuracy,
      cpl: cpl,
    );

    // ──────────────────────────────────────────────────────
    // 8. Build evaluation display score (always from White's perspective)
    // ──────────────────────────────────────────────────────
    double evaluationScore;
    double evalBarValue;
    String evalString;

    if (isCheckmate) {
      evaluationScore = isWhite ? 10.0 : -10.0;
      evalBarValue = isWhite ? 0.95 : 0.05;
      evalString = '#0';
    } else if (playedScore.isMate) {
      final m = playedMateInWhite;
      if (m > 0) {
        evaluationScore = 10.0;
      } else if (m < 0) {
        evaluationScore = -10.0;
      } else {
        evaluationScore = isWhite ? 10.0 : -10.0;
      }
      evalBarValue = (evaluationScore + 10.0) / 20.0;
      evalBarValue = evalBarValue.clamp(0.05, 0.95);
      evalString = '#${playedScore.mateIn ?? 0}';
    } else {
      evaluationScore = playedCpWhite / 100.0;
      evalBarValue = (evaluationScore + 10.0) / 20.0;
      evalBarValue = evalBarValue.clamp(0.05, 0.95);
      evalString = evaluationScore > 0
          ? '+${evaluationScore.toStringAsFixed(2)}'
          : evaluationScore.toStringAsFixed(2);
    }

    final moveEntry = {
      'num': (currentMoveLog.length ~/ 2) + 1,
      'player': isWhite ? 'White' : 'Black',
      'move': moveSan,
      'uci': moveUci,
      'eval': evalString,
      'evalScore': evaluationScore,
      'cpDiff': cpl.toInt(),
      'cpl': cpl.toInt(),
      'accuracy': accuracy.round(),
      'moveAcc': accuracy.toDouble(),
      'classification': classification.label,
      'icon': classification.name,
      'isAnalyzing': false,
    };

    final updatedLog = List<Map<String, dynamic>>.from(currentMoveLog);
    final existingIdx = updatedLog.indexWhere((m) =>
        m['uci'] == moveUci && (m['fenAfter'] == fenAfter || m['fenBefore'] == fenBefore));
    if (existingIdx != -1) {
      updatedLog[existingIdx] = moveEntry;
    } else {
      updatedLog.add(moveEntry);
    }

    final overallAccuracy = ChessEvaluator.computeOverallGameAccuracy(
      updatedLog,
      isPlayerWhite,
    ).round();

    return MoveAnalysisResult(
      evaluationScore: evaluationScore,
      evalBarValue: evalBarValue,
      moveEntry: moveEntry,
      overallAccuracy: overallAccuracy,
    );
  }
}
