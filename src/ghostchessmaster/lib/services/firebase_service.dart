import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import '../features/profile/data/board_connection_service.dart';
import '../firebase_options.dart';

class FirebaseService {
  /// The Firebase Service connects GhostchessMaster to the Python core
  
  static String _resolveBoardId([String? boardId]) {
    if (boardId != null && boardId.isNotEmpty && boardId != 'BOARD_8AA5C5') {
      return boardId;
    }
    return BoardConnectionService.instance.currentInfo?.boardId ?? boardId ?? 'BOARD_8AA5C5';
  }

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      // Ignore offline or duplicate app initialization errors gracefully
    }
  }

  /// Listens to the 'current_match' node in the Realtime Database for a specific board.
  /// Calls [onUpdate] whenever a new move is pushed by the Python core.
  static void listenToMatchUpdates(
    Function(Map<dynamic, dynamic>) onUpdate, {
    String? boardId,
  }) {
    final resolvedBoardId = _resolveBoardId(boardId);
    DatabaseReference matchRef = FirebaseDatabase.instance.ref('$resolvedBoardId/current_match');
    
    matchRef.onValue.listen((DatabaseEvent event) {
      if (event.snapshot.exists && event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        onUpdate(data);
      }
    });
  }

  /// Pushes a single move and current board state (FEN) to Firebase
  static Future<void> pushMove(
    String moveUci,
    String currentFen, {
    String? boardId,
    bool isWhite = true,
  }) async {
    try {
      final resolvedBoardId = _resolveBoardId(boardId);
      DatabaseReference matchRef = FirebaseDatabase.instance.ref('$resolvedBoardId/current_match');
      final Map<String, dynamic> updateData = {
        'last_move': moveUci,
        'current_fen': currentFen,
        'fen': currentFen,
        'timestamp': ServerValue.timestamp,
      };
      if (isWhite) {
        updateData['last_white_move'] = moveUci;
      } else {
        updateData['last_black_move'] = moveUci;
      }
      await matchRef.update(updateData).timeout(const Duration(milliseconds: 1000), onTimeout: () {});
    } catch (e) {
      // Ignore network errors gracefully if offline
    }
  }

  /// Sets the isGameEnded flag in Firebase RTDB under {boardId}/current_match
  static Future<void> setGameEnded(bool isEnded, {String? boardId}) async {
    try {
      final resolvedBoardId = _resolveBoardId(boardId);
      DatabaseReference matchRef = FirebaseDatabase.instance.ref('$resolvedBoardId/current_match');
      await matchRef.update({
        'isGameEnded': isEnded,
        'timestamp': ServerValue.timestamp,
      }).timeout(const Duration(milliseconds: 1000), onTimeout: () {});
    } catch (e) {
      // Ignore network errors gracefully
    }
  }

  /// Resets the current match state in Firebase (for starting a NEW physical mode game)
  /// Uses update to preserve session configurations (timer, inc_time, difficulty, elo, connected_user_id).
  static Future<void> resetMatch({String? boardId}) async {
    try {
      final resolvedBoardId = _resolveBoardId(boardId);
      DatabaseReference matchRef = FirebaseDatabase.instance.ref('$resolvedBoardId/current_match');
      await matchRef.update({
        'is_active': true,
        'isGameEnded': false,
        'last_move': '',
        'last_white_move': '',
        'last_black_move': '',
        'current_fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
        'status': 'ongoing',
        'timestamp': ServerValue.timestamp,
      }).timeout(const Duration(milliseconds: 1000), onTimeout: () {});
    } catch (e) {
      // Ignore network errors gracefully
    }
  }

  /// Clears game-related match data in RTDB when a match ends (checkmate, surrender, timeout, draw).
  /// Preserves game settings (timer, inc_time, difficulty, elo) but clears move/FEN/active state.
  static Future<void> clearMatchData({String? boardId}) async {
    try {
      final resolvedBoardId = _resolveBoardId(boardId);
      DatabaseReference matchRef = FirebaseDatabase.instance.ref('$resolvedBoardId/current_match');
      await matchRef.update({
        'is_active': false,
        'isGameEnded': true,
        'last_move': '',
        'last_white_move': '',
        'last_black_move': '',
        'current_fen': '',
        'fen': '',
        'status': 'completed',
        'timestamp': ServerValue.timestamp,
      }).timeout(const Duration(milliseconds: 1000), onTimeout: () {});
    } catch (e) {
      // Ignore network errors gracefully
    }
  }
}
