import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for the `live_session` Firestore collection & RTDB node.
/// Represents the real-time state of an active physical chess game session.
/// Primary Key / Document ID: `user_id` (connected user's Firebase Auth UID).
class LiveSessionModel {
  final String boardId; // FK → boards.id
  final String connectedUserId; // FK → users.id (Document ID)
  final bool isWhite; // True when player set the settings to play with White, False for Black
  final int timer; // Remaining clock time in seconds
  final int incTime; // Time increment per move in seconds
  final int difficulty; // Stockfish engine difficulty level
  final String lastMove; // Most recent UCI move
  final String currentFen; // Real-time FEN board state
  final DateTime? timestamp;

  LiveSessionModel({
    required this.boardId,
    required this.connectedUserId,
    this.isWhite = true,
    this.timer = 600,
    this.incTime = 0,
    this.difficulty = 5,
    this.lastMove = '',
    this.currentFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'board_id': boardId,
      'connected_user_id': connectedUserId,
      'user_id': connectedUserId,
      'is_white': isWhite,
      'timer': timer,
      'inc_time': incTime,
      'difficulty': difficulty,
      'last_move': lastMove,
      'current_fen': currentFen,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
    };
  }

  factory LiveSessionModel.fromMap(Map<String, dynamic> map, String docId) {
    final userId = map['connected_user_id'] as String? ?? (map['user_id'] as String? ?? docId);
    return LiveSessionModel(
      boardId: map['board_id'] as String? ?? '',
      connectedUserId: userId,
      isWhite: map['is_white'] as bool? ?? (map['isWhite'] as bool? ?? true),
      timer: (map['timer'] as num?)?.toInt() ?? 600,
      incTime: (map['inc_time'] as num?)?.toInt() ?? 0,
      difficulty: (map['difficulty'] as num?)?.toInt() ?? 5,
      lastMove: map['last_move'] as String? ?? '',
      currentFen: map['current_fen'] as String? ?? 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      timestamp: _parseTimestamp(map['timestamp']),
    );
  }

  factory LiveSessionModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return LiveSessionModel.fromMap(data, doc.id);
  }

  LiveSessionModel copyWith({
    String? boardId,
    String? connectedUserId,
    bool? isWhite,
    int? timer,
    int? incTime,
    int? difficulty,
    String? lastMove,
    String? currentFen,
    DateTime? timestamp,
  }) {
    return LiveSessionModel(
      boardId: boardId ?? this.boardId,
      connectedUserId: connectedUserId ?? this.connectedUserId,
      isWhite: isWhite ?? this.isWhite,
      timer: timer ?? this.timer,
      incTime: incTime ?? this.incTime,
      difficulty: difficulty ?? this.difficulty,
      lastMove: lastMove ?? this.lastMove,
      currentFen: currentFen ?? this.currentFen,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  static DateTime? _parseTimestamp(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    return null;
  }
}
