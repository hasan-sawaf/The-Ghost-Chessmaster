import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../core/utils/load_images.dart';
import 'opening_book_database.dart';

/// Normalized engine evaluation — always from White's perspective.
class NormalizedScore {
  final bool isMate;
  final int? mateIn;
  final double? cp;

  NormalizedScore({required this.isMate, this.mateIn, this.cp});

  factory NormalizedScore.fromRaw({
    required bool isMate,
    int? mateIn,
    double? cp,
    bool isWhiteTurn = true,
  }) {
    if (isMate) {
      final m = mateIn ?? 0;
      return NormalizedScore(
        isMate: true,
        mateIn: isWhiteTurn ? m : -m,
        cp: null,
      );
    } else {
      final cpVal = cp ?? 0.0;
      return NormalizedScore(
        isMate: false,
        mateIn: null,
        cp: isWhiteTurn ? cpVal : -cpVal,
      );
    }
  }

  String toDisplay() {
    if (isMate) {
      final m = mateIn ?? 0;
      return "#${m > 0 ? '+$m' : m}";
    }
    final cpVal = (cp ?? 0.0) / 100.0;
    return cpVal > 0
        ? "+${cpVal.toStringAsFixed(2)}"
        : cpVal.toStringAsFixed(2);
  }

  dynamic toReportValue() {
    if (isMate) {
      return "#${mateIn ?? 0}";
    }
    return double.parse(((cp ?? 0.0) / 100.0).toStringAsFixed(2));
  }
}

enum MoveClassification {
  brilliant,
  great,
  best,
  excellent,
  good,
  book,
  inaccuracy,
  mistake,
  blunder,
}

extension MoveClassificationX on MoveClassification {
  String get label {
    switch (this) {
      case MoveClassification.brilliant:
        return 'Brilliant';
      case MoveClassification.great:
        return 'Great';
      case MoveClassification.best:
        return 'Best';
      case MoveClassification.excellent:
        return 'Excellent';
      case MoveClassification.good:
        return 'Okay';
      case MoveClassification.book:
        return 'Book';
      case MoveClassification.inaccuracy:
        return 'Inaccuracy';
      case MoveClassification.mistake:
        return 'Mistake';
      case MoveClassification.blunder:
        return 'Blunder';
    }
  }

  /// Short move title key stored in Firebase (e.g. 'best', 'book', 'brilliant')
  String get iconKey => name;

  /// Full asset path resolved via AppImageHelper
  String get iconPath => AppImageHelper.getAssetPath(name);

  String get symbol {
    switch (this) {
      case MoveClassification.brilliant:
        return '!!';
      case MoveClassification.great:
        return '!';
      case MoveClassification.best:
        return '★';
      case MoveClassification.excellent:
        return '✓';
      case MoveClassification.good:
        return '✓';
      case MoveClassification.book:
        return '📖';
      case MoveClassification.inaccuracy:
        return '?!';
      case MoveClassification.mistake:
        return '?';
      case MoveClassification.blunder:
        return '??';
    }
  }

  Color get color {
    switch (this) {
      case MoveClassification.brilliant:
        return const Color(0xFF00E5FF);
      case MoveClassification.great:
        return const Color(0xFF3F51B5);
      case MoveClassification.best:
        return const Color(0xFF76FF03);
      case MoveClassification.excellent:
        return const Color(0xFF00E676);
      case MoveClassification.good:
        return const Color(0xFF81C784);
      case MoveClassification.book:
        return const Color(0xFFA1887F);
      case MoveClassification.inaccuracy:
        return const Color(0xFFFFD54F);
      case MoveClassification.mistake:
        return const Color(0xFFFF9800);
      case MoveClassification.blunder:
        return const Color(0xFFE53935);
    }
  }

  IconData get iconData {
    switch (this) {
      case MoveClassification.brilliant:
        return Icons.auto_awesome;
      case MoveClassification.great:
        return Icons.stars_rounded;
      case MoveClassification.best:
        return Icons.star_rounded;
      case MoveClassification.excellent:
        return Icons.thumb_up_rounded;
      case MoveClassification.good:
        return Icons.check_circle_rounded;
      case MoveClassification.book:
        return Icons.menu_book_rounded;
      case MoveClassification.inaccuracy:
        return Icons.warning_amber_rounded;
      case MoveClassification.mistake:
        return Icons.help_outline_rounded;
      case MoveClassification.blunder:
        return Icons.cancel_rounded;
    }
  }
}

class ChessEvaluator {
  /// Win Probability formula using standard logistic model:
  /// WinProb = 100.0 / (1.0 + e^(-0.00368208 * cp_pov))
  static double computeWinProbability(NormalizedScore score, bool sideIsWhite) {
    if (score.isMate) {
      final mate = score.mateIn ?? 0;
      final isFavorable =
          (mate > 0 && sideIsWhite) || (mate < 0 && !sideIsWhite);
      if (mate == 0) return 100.0;
      return isFavorable ? 100.0 : 0.0;
    }

    final cpPov = sideIsWhite ? (score.cp ?? 0.0) : -(score.cp ?? 0.0);
    try {
      return 100.0 / (1.0 + math.exp(-0.00368208 * cpPov));
    } catch (_) {
      return cpPov > 0 ? 100.0 : 0.0;
    }
  }

  /// Calculates Centipawn Loss (CPL) and mate swing detection
  static Map<String, dynamic> computeCpl(
    NormalizedScore best,
    NormalizedScore played,
    bool sideIsWhite,
  ) {
    final result = <String, dynamic>{
      'cpl': 0.0,
      'is_mate_swing': false,
      'mate_lost': false,
      'mate_allowed': false,
    };

    if (!best.isMate && !played.isMate) {
      final bestCp = best.cp ?? 0.0;
      final playedCp = played.cp ?? 0.0;
      if (sideIsWhite) {
        result['cpl'] = math.max(0.0, bestCp - playedCp);
      } else {
        result['cpl'] = math.max(0.0, playedCp - bestCp);
      }
      return result;
    }

    if (best.isMate && !played.isMate) {
      final bestM = best.mateIn ?? 0;
      final bestFavorable =
          (bestM > 0 && sideIsWhite) || (bestM < 0 && !sideIsWhite);
      if (bestFavorable) {
        result['is_mate_swing'] = true;
        result['mate_lost'] = true;
        result['cpl'] = 800.0;
      } else {
        result['cpl'] = 0.0;
      }
      return result;
    }

    if (!best.isMate && played.isMate) {
      final playedM = played.mateIn ?? 0;
      final playedUnfavorable =
          (playedM > 0 && !sideIsWhite) || (playedM < 0 && sideIsWhite);
      if (playedUnfavorable) {
        result['is_mate_swing'] = true;
        result['mate_allowed'] = true;
        result['cpl'] = 800.0;
      } else {
        result['cpl'] = 0.0;
      }
      return result;
    }

    if (best.isMate && played.isMate) {
      final bestM = best.mateIn ?? 0;
      final playedM = played.mateIn ?? 0;

      final bestWeMate =
          (bestM > 0 && sideIsWhite) || (bestM < 0 && !sideIsWhite);
      final playedWeMate =
          (playedM > 0 && sideIsWhite) || (playedM < 0 && !sideIsWhite);

      if (bestWeMate && playedWeMate) {
        final bestDist = bestM.abs();
        final playedDist = playedM.abs();
        final delay = playedDist - bestDist;
        result['cpl'] = delay >= 3 ? math.min(delay * 30.0, 200.0) : 0.0;
        return result;
      }

      if (!bestWeMate && !playedWeMate) {
        final bestDist = bestM.abs();
        final playedDist = playedM.abs();
        result['cpl'] = playedDist < bestDist
            ? math.min((bestDist - playedDist) * 50.0, 300.0)
            : 0.0;
        return result;
      }

      result['is_mate_swing'] = true;
      result['mate_lost'] = bestWeMate;
      result['mate_allowed'] = !bestWeMate;
      result['cpl'] = 1000.0;
      return result;
    }

    return result;
  }

  /// Smooth Exponential Move Accuracy calculation with CPL penalty cap safety
  static double computeMoveAccuracy({
    required NormalizedScore bestScore,
    required NormalizedScore playedScore,
    required bool sideIsWhite,
    required bool isBestMove,
    required bool isCheckmate,
  }) {
    // Checkmate or engine #1 move or favorable forced checkmate always gets 100% accuracy
    final playedM = playedScore.mateIn ?? 0;
    final isMoverFavorableMate = playedScore.isMate &&
        ((sideIsWhite && playedM > 0) || (!sideIsWhite && playedM < 0));

    if (isCheckmate || isBestMove || isMoverFavorableMate) return 100.0;

    final wpBest = computeWinProbability(bestScore, sideIsWhite);
    final wpPlayed = computeWinProbability(playedScore, sideIsWhite);
    final wpLoss = math.max(0.0, wpBest - wpPlayed);

    final accuracy = 103.1668 * math.exp(-0.04354 * wpLoss) - 3.1669;
    final clampedAccuracy = math.max(0.0, math.min(100.0, accuracy));

    // Calculate CPL for additional safety check on material blunders
    final cplRes = computeCpl(bestScore, playedScore, sideIsWhite);
    final double cpl = (cplRes['cpl'] as num).toDouble();

    // Direct CPL penalty caps to ensure blundered material is penalized even in winning positions:
    if (cpl >= 500) {
      return math.min(clampedAccuracy, 20.0);
    } else if (cpl >= 300) {
      return math.min(clampedAccuracy, 35.0);
    } else if (cpl >= 150) {
      return math.min(clampedAccuracy, 55.0);
    } else if (cpl >= 80) {
      return math.min(clampedAccuracy, 75.0);
    }

    return clampedAccuracy;
  }

  /// Classifies move based on Win Probability Loss (WPL), Centipawn Loss (CPL), and Move Accuracy.
  /// Strictly synchronizes classification with accuracy so a low-accuracy move (e.g. 20%) can NEVER be classified as Excellent.
  static MoveClassification classifyMove({
    required NormalizedScore bestScore,
    required NormalizedScore playedScore,
    required bool sideIsWhite,
    required bool isBestMove,
    required bool isCheckmate,
    required bool isSacrifice,
    required bool isBookMove,
    required bool isMateSwing,
    bool isGreatMove = false,
    double? accuracy,
    double? cpl,
  }) {
    if (isBookMove) return MoveClassification.book;

    // Check if the played move gives checkmate or is the top engine move
    if (isCheckmate || isBestMove) {
      if (isSacrifice) return MoveClassification.brilliant;
      if (isGreatMove) return MoveClassification.great;
      return MoveClassification.best;
    }

    // Check if the played move maintains a forced checkmate for our side
    final playedM = playedScore.mateIn ?? 0;
    final isMoverFavorableMate = playedScore.isMate &&
        ((sideIsWhite && playedM > 0) || (!sideIsWhite && playedM < 0));

    if (isMoverFavorableMate) {
      if (isSacrifice) return MoveClassification.brilliant;
      return MoveClassification.best;
    }

    final wpBest = computeWinProbability(bestScore, sideIsWhite);
    final wpPlayed = computeWinProbability(playedScore, sideIsWhite);
    final wpLoss = math.max(0.0, wpBest - wpPlayed);

    final double effectiveCpl = cpl ??
        ((computeCpl(bestScore, playedScore, sideIsWhite)['cpl'] as num?)?.toDouble() ?? 0.0);

    final double effectiveAcc = accuracy ??
        computeMoveAccuracy(
          bestScore: bestScore,
          playedScore: playedScore,
          sideIsWhite: sideIsWhite,
          isBestMove: isBestMove,
          isCheckmate: isCheckmate,
        );

    // Brilliant move: A genuine sacrifice that maintains winning advantage or equal/strong position
    if (isSacrifice && (effectiveAcc >= 90.0 || wpLoss <= 2.0) && effectiveCpl <= 50.0) {
      return MoveClassification.brilliant;
    }

    // 1. Blunder conditions (mate swing, catastrophic material loss, or accuracy < 30%)
    if (isMateSwing || effectiveCpl >= 300.0 || effectiveAcc < 30.0 || wpLoss >= 20.0) {
      return MoveClassification.blunder;
    }

    // 2. Mistake conditions (moderate material loss, positional breakdown, or accuracy < 55%)
    if (effectiveCpl >= 150.0 || effectiveAcc < 55.0 || wpLoss >= 10.0) {
      return MoveClassification.mistake;
    }

    // 3. Inaccuracy conditions (minor material loss, sub-optimal maneuver, or accuracy < 75%)
    if (effectiveCpl >= 60.0 || effectiveAcc < 75.0 || wpLoss >= 5.0) {
      return MoveClassification.inaccuracy;
    }

    // 4. Good / Okay conditions (acceptable move, accuracy < 90% or slight CPL loss)
    if (effectiveCpl > 25.0 || effectiveAcc < 90.0 || wpLoss > 2.0) {
      return MoveClassification.good;
    }

    // 5. Excellent move: Near-best move with high accuracy (>= 90%), minimal CPL (<= 25), and minimal WPL (<= 2.0)
    return MoveClassification.excellent;
  }

  /// Reference to the complete OpeningBookDatabase lines
  static List<List<String>> get bookLines => OpeningBookDatabase.bookLines;

  /// Checks whether a sequence of moves matches any known opening book move
  static bool isBookMove(List<String> playedUciHistory) {
    if (playedUciHistory.isEmpty) return false;
    for (final line in bookLines) {
      if (playedUciHistory.length <= line.length) {
        bool matches = true;
        for (int i = 0; i < playedUciHistory.length; i++) {
          if (playedUciHistory[i] != line[i]) {
            matches = false;
            break;
          }
        }
        if (matches) return true;
      }
    }
    return false;
  }

  /// Gets the official opening name for the played moves, if available
  static String? getOpeningName(List<String> playedUciHistory) {
    return OpeningBookDatabase.getOpeningName(playedUciHistory);
  }

  static double computeOverallGameAccuracy(
    List<Map<String, dynamic>> moves,
    bool forWhite,
  ) {
    double weightedSum = 0.0;
    double weightTotal = 0.0;

    for (final m in moves) {
      if (m['isAnalyzing'] == true) continue;
      final player = m['player'] as String?;
      final isWhiteMove = player == 'White' || (m['isWhite'] == true);
      if (isWhiteMove != forWhite) continue;

      final acc = (m['accuracy'] as num?)?.toDouble() ?? (m['moveAcc'] as num?)?.toDouble();
      if (acc == null) continue;

      final classification = (m['classification'] as String? ?? 'Best').toLowerCase();

      double w = 1.0;
      if (classification == 'blunder') {
        w = 4.0;
      } else if (classification == 'mistake') {
        w = 2.5;
      } else if (classification == 'inaccuracy') {
        w = 1.5;
      }

      weightedSum += acc * w;
      weightTotal += w;
    }

    return weightTotal > 0 ? (weightedSum / weightTotal) : 100.0;
  }
}
