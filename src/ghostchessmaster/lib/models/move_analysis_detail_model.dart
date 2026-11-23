import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/load_images.dart';

/// Granular move-by-move evaluation model for the `move_analysis_detail` subcollection
/// under `matches_history/{matchId}/move_analysis_detail/{moveNumber}`.
///
/// Document ID inside subcollection: `{moveNumber}` (e.g. `'1'`, `'2'`, ... `'20'`).
class MoveAnalysisDetailModel {
  final String matchId; // FK → matches_history.id
  final int moveNumber; // PK (1, 2, 3, ...)
  final String analysisType; // 'live' | 'deep'
  final String uci; // UCI move (e.g., "e2e4")
  final String moveSan; // SAN move (e.g., "e4", "Nf3")
  final String fenBefore; // FEN before move
  final String fenAfter; // FEN after move
  final bool isWhite; // True if White moved
  final double evalScore; // Stockfish evaluation score
  final int cpDiff; // Centipawn loss (cpl)
  final double moveAcc; // Individual Move Accuracy Rating (0.0 to 100.0)
  final String? classification; // 'Brilliant', 'Best', 'Great', 'Book', 'Inaccuracy', 'Mistake', 'Blunder', or null/'none'
  final String commentary; // Textual commentary

  MoveAnalysisDetailModel({
    required this.matchId,
    required this.moveNumber,
    required this.analysisType,
    required this.uci,
    required this.moveSan,
    required this.fenBefore,
    required this.fenAfter,
    required this.isWhite,
    required this.evalScore,
    required this.cpDiff,
    required this.moveAcc,
    this.classification,
    required this.commentary,
  });

  /// Document ID for Firestore subcollection: `{moveNumber}`
  String get documentId => '$moveNumber';

  /// Serializes to Firestore-compatible map with exact fields required by schema.
  Map<String, dynamic> toMap() {
    return {
      'match_id': matchId,
      'move_number': moveNumber,
      'analysis_type': analysisType,
      'uci': uci,
      'move_san': moveSan,
      'fen_before': fenBefore,
      'fen_after': fenAfter,
      'is_white': isWhite,
      'eval_score': evalScore,
      'cp_diff': cpDiff,
      'move_acc': moveAcc,
      'classification': classification ?? 'none',
      'commentary': commentary,
    };
  }

  /// Alias for toMap() — Firestore format uses snake_case keys.
  Map<String, dynamic> toFirestoreMap() => toMap();

  /// Converts back to legacy embedded move log entry format (camelCase keys)
  /// for compatibility with `MatchRecordModel.liveMoveLog` / `deepMoveLog` arrays
  /// and interactive board rendering in [MatchReviewPage].
  Map<String, dynamic> toLegacyMoveLogEntry() {
    final iconPath = AppImageHelper.getClassificationIconPath(classification);
    return {
      'num': (moveNumber + 1) ~/ 2,
      'moveNumber': moveNumber,
      'move': moveSan.isNotEmpty ? moveSan : uci,
      'san': moveSan,
      'uci': uci,
      'fenBefore': fenBefore,
      'fenAfter': fenAfter,
      'isWhite': isWhite,
      'player': isWhite ? 'White' : 'Black',
      'eval': evalScore > 0 ? '+${evalScore.toStringAsFixed(2)}' : evalScore.toStringAsFixed(2),
      'evalScore': evalScore,
      'cpDiff': cpDiff,
      'cpl': cpDiff,
      'moveAcc': moveAcc,
      'accuracy': moveAcc.round(),
      'classification': (classification == null || classification == 'none' || classification == 'null') ? null : classification,
      'icon': iconPath, // Will be NULL for unanalyzed moves!
      'commentary': commentary,
      'isAnalyzing': classification == null || classification == 'none' || classification == 'null',
    };
  }

  factory MoveAnalysisDetailModel.fromMap(Map<String, dynamic> map, String docId) {
    final parsedMoveNum = (map['move_number'] as num?)?.toInt() ?? int.tryParse(docId) ?? 0;
    final rawClassif = map['classification']?.toString();
    final String? parsedClassif;
    if (rawClassif == null ||
        rawClassif.trim().isEmpty ||
        rawClassif.toLowerCase() == 'none' ||
        rawClassif.toLowerCase() == 'null' ||
        rawClassif == 'Not Analyzed' ||
        rawClassif == 'غير محللة') {
      parsedClassif = null;
    } else {
      parsedClassif = rawClassif;
    }

    final double rawEval = (map['eval_score'] as num?)?.toDouble() ??
        (map['evalScore'] as num?)?.toDouble() ??
        double.tryParse(map['eval']?.toString().replaceAll('+', '') ?? '') ??
        0.0;

    final int rawCp = (map['cp_diff'] as num?)?.toInt() ??
        (map['cpDiff'] as num?)?.toInt() ??
        (map['cpl'] as num?)?.toInt() ??
        0;

    final double rawAcc = (map['move_acc'] as num?)?.toDouble() ??
        (map['moveAcc'] as num?)?.toDouble() ??
        (map['accuracy'] as num?)?.toDouble() ??
        100.0;

    return MoveAnalysisDetailModel(
      matchId: map['match_id'] as String? ?? '',
      moveNumber: parsedMoveNum,
      analysisType: map['analysis_type'] as String? ?? 'live',
      uci: (map['uci'] ?? map['move'] ?? '').toString(),
      moveSan: (map['move_san'] ?? map['san'] ?? map['move'] ?? map['uci'] ?? '').toString(),
      fenBefore: (map['fen_before'] ?? map['fenBefore'] ?? '').toString(),
      fenAfter: (map['fen_after'] ?? map['fenAfter'] ?? '').toString(),
      isWhite: (map['is_white'] ?? map['isWhite'] ?? true) as bool,
      evalScore: rawEval,
      cpDiff: rawCp,
      moveAcc: rawAcc,
      classification: parsedClassif,
      commentary: (map['commentary'] ?? '').toString(),
    );
  }

  factory MoveAnalysisDetailModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MoveAnalysisDetailModel.fromMap(data, doc.id);
  }

  factory MoveAnalysisDetailModel.fromFirestoreDoc(DocumentSnapshot doc) {
    return MoveAnalysisDetailModel.fromSnapshot(doc);
  }

  MoveAnalysisDetailModel copyWith({
    String? matchId,
    int? moveNumber,
    String? analysisType,
    String? uci,
    String? moveSan,
    String? fenBefore,
    String? fenAfter,
    bool? isWhite,
    double? evalScore,
    int? cpDiff,
    double? moveAcc,
    String? classification,
    String? commentary,
  }) {
    return MoveAnalysisDetailModel(
      matchId: matchId ?? this.matchId,
      moveNumber: moveNumber ?? this.moveNumber,
      analysisType: analysisType ?? this.analysisType,
      uci: uci ?? this.uci,
      moveSan: moveSan ?? this.moveSan,
      fenBefore: fenBefore ?? this.fenBefore,
      fenAfter: fenAfter ?? this.fenAfter,
      isWhite: isWhite ?? this.isWhite,
      evalScore: evalScore ?? this.evalScore,
      cpDiff: cpDiff ?? this.cpDiff,
      moveAcc: moveAcc ?? this.moveAcc,
      classification: classification ?? this.classification,
      commentary: commentary ?? this.commentary,
    );
  }

  /// Converts a raw move log entry (Map) safely into a [MoveAnalysisDetailModel].
  /// Correctly parses evalScore, cpDiff, moveAcc, and sets classification to null if unanalyzed.
  factory MoveAnalysisDetailModel.fromLegacyMoveLogEntry({
    required String matchId,
    required int moveNumber,
    required String analysisType,
    Map<String, dynamic>? entry,
    Map<String, dynamic>? moveLogEntry,
  }) {
    final e = entry ?? moveLogEntry ?? {};
    final rawUci = (e['uci'] ?? e['move'] ?? '').toString();
    final rawSan = (e['san'] ?? e['move'] ?? rawUci).toString();
    final fenB = (e['fenBefore'] ?? e['fen_before'] ?? '').toString();
    final fenA = (e['fenAfter'] ?? e['fen_after'] ?? '').toString();

    bool white = true;
    if (e.containsKey('isWhite') && e['isWhite'] is bool) {
      white = e['isWhite'] as bool;
    } else if (e.containsKey('is_white') && e['is_white'] is bool) {
      white = e['is_white'] as bool;
    } else if (e.containsKey('player')) {
      white = e['player'].toString().toLowerCase() == 'white';
    } else {
      white = (moveNumber % 2 != 0);
    }

    double evalVal = 0.0;
    if (e['evalScore'] is num) {
      evalVal = (e['evalScore'] as num).toDouble();
    } else if (e['eval_score'] is num) {
      evalVal = (e['eval_score'] as num).toDouble();
    } else if (e['eval'] is num) {
      evalVal = (e['eval'] as num).toDouble();
    } else if (e['eval'] != null) {
      evalVal = double.tryParse(e['eval'].toString().replaceAll('+', '')) ?? 0.0;
    }

    int cpVal = 0;
    if (e['cpDiff'] is num) {
      cpVal = (e['cpDiff'] as num).toInt();
    } else if (e['cp_diff'] is num) {
      cpVal = (e['cp_diff'] as num).toInt();
    } else if (e['cpl'] is num) {
      cpVal = (e['cpl'] as num).toInt();
    }

    double accVal = 100.0;
    if (e['moveAcc'] is num) {
      accVal = (e['moveAcc'] as num).toDouble();
    } else if (e['move_acc'] is num) {
      accVal = (e['move_acc'] as num).toDouble();
    } else if (e['accuracy'] is num) {
      accVal = (e['accuracy'] as num).toDouble();
    }

    final bool isUnanalyzed = (e['isAnalyzing'] == true) ||
        !e.containsKey('classification') ||
        e['classification'] == null ||
        e['classification'].toString().trim().isEmpty ||
        e['classification'].toString().toLowerCase() == 'none' ||
        e['classification'].toString().toLowerCase() == 'null' ||
        e['classification'].toString() == 'Not Analyzed' ||
        e['classification'].toString() == 'غير محللة';

    final String? classif = isUnanalyzed ? null : e['classification'].toString();
    final comment = (e['commentary'] ?? '').toString();

    return MoveAnalysisDetailModel(
      matchId: matchId,
      moveNumber: moveNumber,
      analysisType: analysisType,
      uci: rawUci,
      moveSan: rawSan,
      fenBefore: fenB,
      fenAfter: fenA,
      isWhite: white,
      evalScore: evalVal,
      cpDiff: cpVal,
      moveAcc: accVal,
      classification: classif,
      commentary: comment,
    );
  }
}
