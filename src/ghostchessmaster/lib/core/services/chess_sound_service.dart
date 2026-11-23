import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service for playing chess match sound effects (moves, captures, castling, game start/end, illegal moves).
class ChessSoundService {
  static final ChessSoundService instance = ChessSoundService._internal();
  ChessSoundService._internal();

  final AudioPlayer _player = AudioPlayer();

  Future<void> _playSound(String assetFileName, bool isSoundEnabled) async {
    if (!isSoundEnabled) return;
    try {
      // AudioPlayer AssetSource handles relative assets inside 'assets/'
      await _player.stop();
      await _player.play(AssetSource('sound effect/$assetFileName'));
    } catch (e) {
      debugPrint('[CHESS_SOUND] Error playing sound $assetFileName: $e');
    }
  }

  /// Played when match starts
  Future<void> playGameStart(bool isSoundEnabled) async {
    await _playSound('game-start.mp3', isSoundEnabled);
  }

  /// Played when match ends
  Future<void> playGameEnd(bool isSoundEnabled) async {
    await _playSound('game-end.mp3', isSoundEnabled);
  }

  /// Played on player's standard move
  Future<void> playMoveSelf(bool isSoundEnabled) async {
    await _playSound('move-self.mp3', isSoundEnabled);
  }

  /// Played on opponent's standard move
  Future<void> playMoveOpponent(bool isSoundEnabled) async {
    await _playSound('move-opponent.mp3', isSoundEnabled);
  }

  /// Played on piece capture
  Future<void> playCapture(bool isSoundEnabled) async {
    await _playSound('capture.mp3', isSoundEnabled);
  }

  /// Played on castling
  Future<void> playCastle(bool isSoundEnabled) async {
    await _playSound('castle.mp3', isSoundEnabled);
  }

  /// Played on illegal move or illegal drag-and-drop attempt
  Future<void> playIllegal(bool isSoundEnabled) async {
    await _playSound('illegal.mp3', isSoundEnabled);
  }

  /// Played when timer reaches 10 seconds remaining
  Future<void> playTenSeconds(bool isSoundEnabled) async {
    await _playSound('tenseconds.mp3', isSoundEnabled);
  }

  void dispose() {
    _player.dispose();
  }
}
