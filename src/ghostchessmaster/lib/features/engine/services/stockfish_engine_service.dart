import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:stockfish_flutter_plus/stockfish_flutter_plus.dart';
import '../../../core/services/global_analysis_service.dart';

/// Manages the local Stockfish engine process to perform deep game and live match analyses.
class StockfishEngineService {
  static final StockfishEngineService instance = StockfishEngineService._internal();

  StockfishEngineService._internal();

  Stockfish? _stockfish;
  final StreamController<String> _outputController = StreamController<String>.broadcast();
  Future<bool>? _initFuture;

  /// Serial mutex lock to guarantee that all engine evaluations execute one at a time.
  /// Prevents concurrent command collisions, stream listener crosstalk, and stdout corruption.
  Future<void> _lock = Future.value();

  static const int minStockfishElo = 1320;
  static const int maxStockfishElo = 3190;

  /// Number of CPU threads for engine evaluation (enables full CPU speed)
  static int get _cpuThreads => math.max(2, Platform.numberOfProcessors);

  /// Synchronizes engine actions sequentially so only one evaluation or command sequence runs at any moment.
  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _lock = _lock.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    }).catchError((_) {
      // Prevents unhandled queue rejection from blocking future actions
    });
    return completer.future;
  }

  /// Initializes the engine if it hasn't been initialized yet.
  Future<bool> initEngine() {
    if (_stockfish != null && _stockfish!.state.value == StockfishState.ready) {
      return Future.value(true);
    }

    if (_initFuture != null) {
      return _initFuture!;
    }

    _initFuture = _doInitEngine().whenComplete(() {
      _initFuture = null;
    });

    return _initFuture!;
  }

  Future<bool> _doInitEngine() async {
    try {
      if (_stockfish == null) {
        debugPrint('[STOCKFISH_SERVICE] Starting Stockfish FFI engine...');
        _stockfish = Stockfish();
        
        final completer = Completer<void>();

        void listener() {
          if (_stockfish == null) return;
          if (_stockfish!.state.value == StockfishState.ready) {
            _stockfish!.state.removeListener(listener);
            if (!completer.isCompleted) completer.complete();
          } else if (_stockfish!.state.value == StockfishState.error) {
            _stockfish!.state.removeListener(listener);
            if (!completer.isCompleted) completer.completeError('Stockfish error state');
          }
        }
        
        if (_stockfish != null) {
          _stockfish!.state.addListener(listener);
        }
        
        if (_stockfish != null && _stockfish!.state.value == StockfishState.ready) {
          _stockfish!.state.removeListener(listener);
          if (!completer.isCompleted) completer.complete();
        }

        await completer.future.timeout(const Duration(seconds: 10));
        
        // Setup stdout listener for output
        _stockfish!.stdout.listen((line) {
          _outputController.add(line);
        });

        // Send initial UCI initialization commands
        sendCommand('uci');
        sendCommand('isready');
        debugPrint('[STOCKFISH_SERVICE] Stockfish is ready.');
        return true;
      }
      return _stockfish != null && _stockfish!.state.value == StockfishState.ready;
    } catch (e) {
      debugPrint('[STOCKFISH_SERVICE] Initialization failed: $e');
      return _stockfish != null && _stockfish!.state.value == StockfishState.ready;
    }
  }

  /// Sends a raw UCI command to the Stockfish engine process.
  void sendCommand(String command) {
    if (_stockfish == null) {
      debugPrint('[STOCKFISH_WARNING] Cannot send command "$command". Engine is not running.');
      return;
    }
    if (_stockfish!.state.value != StockfishState.ready) {
      debugPrint('[STOCKFISH_WARNING] Cannot send command "$command". Engine is not ready (State: ${_stockfish!.state.value}).');
      return;
    }
    debugPrint('[STOCKFISH_SEND] >> $command');
    _stockfish!.stdin = command;
  }

  /// Stops any active search and resets Stockfish memory from 0 for a clean new game.
  void stopEngine() {
    try {
      if (_stockfish != null && _stockfish!.state.value == StockfishState.ready) {
        debugPrint('[STOCKFISH_SERVICE] Stopping active search and resetting Stockfish from 0...');
        sendCommand('stop');
        sendCommand('ucinewgame');
        sendCommand('isready');
      }
    } catch (e) {
      debugPrint('[STOCKFISH_SERVICE] Error in stopEngine: $e');
    }
  }

  /// Sends ucinewgame to reset engine state (hash tables, etc.) for a fresh game.
  Future<void> newGame() async {
    await initEngine();
    await _synchronized(() async {
      stopEngine();
    });
  }

  /// Sets the Stockfish engine difficulty level.
  /// Ensures the engine is fully initialized, reset from 0 with ucinewgame, configured with requested strength/ELO, and verified ready.
  Future<bool> ensureEngineReady({int? level, int? elo}) async {
    final initOk = await initEngine();
    if (!initOk || _stockfish == null) return false;

    return _synchronized(() async {
      try {
        // 1. Stop any ongoing search
        sendCommand('stop');
        // 2. Reset engine hash & evaluation state from scratch (ucinewgame)
        sendCommand('ucinewgame');
        
        int targetElo = elo ?? 1500;
        if (level != null && elo == null) {
          targetElo = 800 + (level.clamp(0, 10) * 200);
        }
        _configureEngineStrength(targetElo);

        final completer = Completer<bool>();
        StreamSubscription<String>? sub;

        sub = _outputController.stream.listen((line) {
          if (line.trim().contains('readyok')) {
            sub?.cancel();
            if (!completer.isCompleted) completer.complete(true);
          }
        });

        sendCommand('isready');

        final result = await completer.future.timeout(
          const Duration(seconds: 4),
          onTimeout: () {
            sub?.cancel();
            return _stockfish?.state.value == StockfishState.ready;
          },
        );
        debugPrint('[STOCKFISH_SERVICE] Engine readiness verified from 0: $result (ELO: $targetElo)');
        return result;
      } catch (e) {
        debugPrint('[STOCKFISH_SERVICE] ensureEngineReady error: $e');
        return _stockfish?.state.value == StockfishState.ready;
      }
    });
  }

  /// Sets the Stockfish engine difficulty level.
  Future<void> setDifficulty(int level) async {
    await initEngine();
    final targetElo = 800 + (level.clamp(0, 10) * 200);
    await _synchronized(() async {
      _configureEngineStrength(targetElo);
    });
  }

  /// Configures engine strength options prior to evaluation.
  void _configureEngineStrength(int? elo) {
    if (elo != null) {
      sendCommand('setoption name UCI_LimitStrength value true');
      final stockfishUciElo = elo.clamp(minStockfishElo, maxStockfishElo);
      sendCommand('setoption name UCI_Elo value $stockfishUciElo');

      int skillLevel;
      if (elo <= 800) {
        skillLevel = 0;
      } else if (elo <= 1000) {
        skillLevel = 2;
      } else if (elo <= 1200) {
        skillLevel = 4;
      } else if (elo <= 1400) {
        skillLevel = 6;
      } else if (elo <= 1600) {
        skillLevel = 8;
      } else if (elo <= 1800) {
        skillLevel = 10;
      } else if (elo <= 2000) {
        skillLevel = 12;
      } else if (elo <= 2200) {
        skillLevel = 14;
      } else if (elo <= 2400) {
        skillLevel = 16;
      } else if (elo <= 2600) {
        skillLevel = 18;
      } else {
        skillLevel = 20;
      }
      sendCommand('setoption name Skill Level value $skillLevel');
      debugPrint('[STOCKFISH_SERVICE] Configured Engine Strength: Elo=$elo, UCI_Elo=$stockfishUciElo, SkillLevel=$skillLevel');
    } else {
      // Full power mode for deep game analysis (Maximum depth & full CPU speed)
      sendCommand('setoption name UCI_LimitStrength value false');
      sendCommand('setoption name Skill Level value 20');
      sendCommand('setoption name Threads value $_cpuThreads');
      sendCommand('setoption name Hash value 64');
      sendCommand('setoption name UCI_AnalyseMode value true');
      debugPrint('[STOCKFISH_SERVICE] Full Power Analysis Mode: Threads=$_cpuThreads, Hash=64MB, SkillLevel=20');
    }
    sendCommand('isready');
  }

  /// Evaluates a given position based on FEN or move history with high-precision deep search.
  /// All evaluations pass through `_synchronized` mutex lock to guarantee zero concurrency race conditions.
  Future<Map<String, dynamic>> evaluatePosition(
    List<String> moves, {
    int depth = 16,
    int? moveTime,
    String? fen,
    int? elo,
  }) async {
    await initEngine();
    if (_stockfish == null) {
      return {'cp': 0.0, 'best_move': '', 'is_mate': false, 'mate_in': 0};
    }

    return _synchronized(() async {
      try {
        // 1. Stop any previous evaluation activity cleanly
        sendCommand('stop');

        // 2. Configure engine strength / analysis options
        _configureEngineStrength(elo);

        final innerCompleter = Completer<Map<String, dynamic>>();
        double currentCp = 0.0;
        bool isMate = false;
        int mateIn = 0;
        String bestMove = '';
        int maxDepthParsed = 0;

        // 3. Attach fresh isolated listener to output controller
        StreamSubscription<String>? subscription;
        subscription = _outputController.stream.listen((line) {
          final trimmedLine = line.trim();
          if (trimmedLine.startsWith('info ') && trimmedLine.contains(' score ')) {
            final parts = trimmedLine.split(RegExp(r'\s+'));

            // Check multipv: ONLY parse multipv 1 (or missing multipv)
            final multipvIdx = parts.indexOf('multipv');
            if (multipvIdx != -1 && multipvIdx + 1 < parts.length) {
              final multipv = int.tryParse(parts[multipvIdx + 1]) ?? 1;
              if (multipv > 1) return; // Skip non-primary variations
            }

            // Check for lowerbound / upperbound lines — skip bound cutoffs if not exact
            final isLowerBound = parts.contains('lowerbound');
            final isUpperBound = parts.contains('upperbound');

            int lineDepth = 0;
            final depthIdx = parts.indexOf('depth');
            if (depthIdx != -1 && depthIdx + 1 < parts.length) {
              lineDepth = int.tryParse(parts[depthIdx + 1]) ?? 0;
            }

            // Update scores if depth is advancing or equal (and not an intermediate bound line)
            if (lineDepth >= maxDepthParsed && !isLowerBound && !isUpperBound) {
              maxDepthParsed = lineDepth;

              if (parts.contains('cp')) {
                final scoreIndex = parts.indexOf('cp');
                if (scoreIndex != -1 && scoreIndex + 1 < parts.length) {
                  final cpVal = int.tryParse(parts[scoreIndex + 1]);
                  if (cpVal != null) {
                    currentCp = cpVal.toDouble();
                    isMate = false;
                    mateIn = 0;
                  }
                }
              } else if (parts.contains('mate')) {
                final mateIndex = parts.indexOf('mate');
                if (mateIndex != -1 && mateIndex + 1 < parts.length) {
                  final mateVal = int.tryParse(parts[mateIndex + 1]);
                  if (mateVal != null) {
                    isMate = true;
                    mateIn = mateVal;
                  }
                }
              }
            }
          }

          if (trimmedLine.startsWith('bestmove ')) {
            final parts = trimmedLine.split(RegExp(r'\s+'));
            if (parts.length > 1) {
              bestMove = parts[1];
            }
            subscription?.cancel();
            if (!innerCompleter.isCompleted) {
              innerCompleter.complete({
                'cp': currentCp,
                'is_mate': isMate,
                'mate_in': mateIn,
                'best_move': bestMove,
              });
            }
          }
        });

        // 4. Send position & search commands
        if (fen != null && fen.isNotEmpty) {
          final cleanFen = sanitizeFen(fen);
          if (moves.isNotEmpty) {
            sendCommand('position fen $cleanFen moves ${moves.join(' ')}');
          } else {
            sendCommand('position fen $cleanFen');
          }
        } else {
          if (moves.isEmpty) {
            sendCommand('position startpos');
          } else {
            sendCommand('position startpos moves ${moves.join(' ')}');
          }
        }

        if (moveTime != null) {
          sendCommand('go depth $depth movetime $moveTime');
        } else {
          sendCommand('go depth $depth');
        }

        // 5. Await bestmove result with safety timeout
        final result = await innerCompleter.future.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            sendCommand('stop');
            subscription?.cancel();
            debugPrint('[STOCKFISH_SERVICE] Evaluation timed out at depth $depth, returning latest parsed score cp=$currentCp, is_mate=$isMate');
            return {
              'cp': currentCp,
              'is_mate': isMate,
              'mate_in': mateIn,
              'best_move': bestMove.isNotEmpty ? bestMove : '',
            };
          },
        );
        return result;
      } catch (e) {
        sendCommand('stop');
        rethrow;
      }
    });
  }

  /// Validates and sanitizes FEN castling rights to prevent C++ Stockfish engine assertion aborts.
  static String sanitizeFen(String rawFen) {
    try {
      final parts = rawFen.trim().split(RegExp(r'\s+'));
      if (parts.length < 3) return rawFen;

      final piecePlacement = parts[0];
      final castlingRights = parts[2];

      if (castlingRights == '-') return rawFen;

      final ranks = piecePlacement.split('/');
      if (ranks.length != 8) return rawFen;

      final board = List.generate(8, (_) => List<String?>.filled(8, null));
      for (int r = 0; r < 8; r++) {
        int c = 0;
        for (int i = 0; i < ranks[r].length && c < 8; i++) {
          final char = ranks[r][i];
          if (RegExp(r'\d').hasMatch(char)) {
            c += int.parse(char);
          } else {
            board[r][c] = char;
            c++;
          }
        }
      }

      final validCastling = StringBuffer();

      // White Kingside 'K': King at (7,4) 'K' and Rook at (7,7) 'R'
      if (castlingRights.contains('K')) {
        if (board[7][4] == 'K' && board[7][7] == 'R') {
          validCastling.write('K');
        }
      }
      // White Queenside 'Q': King at (7,4) 'K' and Rook at (7,0) 'R'
      if (castlingRights.contains('Q')) {
        if (board[7][4] == 'K' && board[7][0] == 'R') {
          validCastling.write('Q');
        }
      }
      // Black Kingside 'k': King at (0,4) 'k' and Rook at (0,7) 'r'
      if (castlingRights.contains('k')) {
        if (board[0][4] == 'k' && board[0][7] == 'r') {
          validCastling.write('k');
        }
      }
      // Black Queenside 'q': King at (0,4) 'q' and Rook at (0,0) 'r'
      if (castlingRights.contains('q')) {
        if (board[0][4] == 'k' && board[0][0] == 'r') {
          validCastling.write('q');
        }
      }

      parts[2] = validCastling.isEmpty ? '-' : validCastling.toString();
      return parts.join(' ');
    } catch (e) {
      debugPrint('[STOCKFISH_SERVICE] Error sanitizing FEN: $e');
      return rawFen;
    }
  }

  /// Closes and cleans up the Stockfish process.
  void disposeEngine({bool force = false}) {
    try {
      if (!force && GlobalAnalysisService.instance.isAnalyzing) {
        debugPrint('[STOCKFISH_SERVICE] Skipping engine stop: Background Deep Analysis is active.');
        return;
      }
      stopEngine();
    } catch (e) {
      debugPrint('[STOCKFISH_SERVICE] Error disposing Stockfish: $e');
    }
  }
}
