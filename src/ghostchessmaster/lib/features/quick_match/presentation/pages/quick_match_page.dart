import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/services/chess_sound_service.dart';
import '../../../../core/services/global_analysis_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../services/firebase_service.dart';
import '../../../engine/domain/deep_game_analyzer_service.dart';
import '../../../engine/services/stockfish_engine_service.dart';
import '../../../history/data/match_history_service.dart';
import '../../../history/domain/models/match_record_model.dart';
import '../../../profile/data/board_connection_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import '../../../training/presentation/widgets/live_game_analyzer_widget.dart';
import '../../../training/presentation/widgets/training_board_widget.dart';
import '../../../training/utils/chess_logic.dart';

/// Dedicated Quick Match Page with distinct UI, twin player/opponent clocks,
/// instant match launch (no pre-game popups), and Stockfish Depth-20 deep analysis.
class QuickMatchPage extends StatefulWidget {
  final String preferredColor; // 'W', 'B', 'R'
  final int stockfishLevel; // 0 to 20
  final int eloRating; // e.g. 1500
  final int timerMinutes; // 0 for unlimited, or 3, 5, 10, 15, 30
  final int incrementSeconds; // 0, 1, 2, 3

  const QuickMatchPage({
    super.key,
    required this.preferredColor,
    required this.stockfishLevel,
    required this.eloRating,
    required this.timerMinutes,
    required this.incrementSeconds,
  });

  @override
  State<QuickMatchPage> createState() => _QuickMatchPageState();
}

class _QuickMatchPageState extends State<QuickMatchPage> {
  // Match Identification & Lifecycle
  String _matchId = '';
  bool _isMatchActive = false;
  bool _isMatchFinished = false;
  late bool _isPlayerWhite;
  StreamSubscription<bool>? _boardOnlineSub;

  // Last Move Highlight Positions
  int? _lastMoveFromRow;
  int? _lastMoveFromCol;
  int? _lastMoveToRow;
  int? _lastMoveToCol;

  // Board Touch Selection
  int? _selectedRow;
  int? _selectedCol;
  List<List<int>> _legalDestinations = [];

  // Dynamic 8x8 Board Matrix
  List<List<String?>> _boardState = [
    ['BR', 'BN', 'BB', 'BQ', 'BK', 'BB', 'BN', 'BR'],
    ['BP', 'BP', 'BP', 'BP', 'BP', 'BP', 'BP', 'BP'],
    [null, null, null, null, null, null, null, null],
    [null, null, null, null, null, null, null, null],
    [null, null, null, null, null, null, null, null],
    [null, null, null, null, null, null, null, null],
    ['WP', 'WP', 'WP', 'WP', 'WP', 'WP', 'WP', 'WP'],
    ['WR', 'WN', 'WB', 'WQ', 'WK', 'WB', 'WN', 'WR'],
  ];

  // Independent Twin Clocks (Player vs Opponent)
  late final bool _hasTimer;
  late int _playerTimeSeconds;
  late int _opponentTimeSeconds;
  Timer? _gameTimer;

  // Move Log & Analysis State
  final List<Map<String, dynamic>> _moveLog = [];
  final double _evalBarValue = 0.5;
  bool _isWhiteTurn = true;
  int _accuracy = 100;

  // Deep Analysis State
  bool _hasRunDeepAnalysis = false;

  // Post-Match Interactive Review & Playback
  bool _hasStartedMatch = false;
  bool _isReviewingGame = false;
  int _reviewMoveIndex = 0;
  Timer? _playbackTimer;
  bool _isPlayingBack = false;
  DateTime _startedAt = DateTime.now();
  String? _reviewClassificationIcon;
  int? _reviewClassificationRow;
  int? _reviewClassificationCol;

  @override
  void initState() {
    super.initState();
    // Resolve player color preference
    if (widget.preferredColor == 'W') {
      _isPlayerWhite = true;
    } else if (widget.preferredColor == 'B') {
      _isPlayerWhite = false;
    } else {
      _isPlayerWhite = Random().nextBool();
    }

    _hasTimer = widget.timerMinutes > 0;
    _playerTimeSeconds = widget.timerMinutes * 60;
    _opponentTimeSeconds = widget.timerMinutes * 60;

    _resetBoardState();
  }

  @override
  void dispose() {
    _gameTimer?.cancel();
    _playbackTimer?.cancel();
    _boardOnlineSub?.cancel();
    StockfishEngineService.instance.stopEngine();
    BoardConnectionService.instance.toggleCamera(turnOn: false);
    if (_moveLog.length <= 4 && _matchId.isNotEmpty) {
      MatchHistoryService.instance.deleteMatchRecord(_matchId);
    }
    super.dispose();
  }

  // Match Initialization Guard
  bool _isInitializingMatch = false;
  String? _lastRemoteMoveUci;

  void _listenToRemotePhysicalBoardMoves() {
    final boardId = BoardConnectionService.instance.currentInfo?.boardId ?? 'BOARD_8AA5C5';
    FirebaseService.listenToMatchUpdates((data) {
      if (!mounted || !_isMatchActive) return;
      final moveUci = (data['last_move'] ?? data['last_white_move'] ?? data['last_black_move']) as String? ?? '';
      if (moveUci.isEmpty || moveUci == _lastRemoteMoveUci) return;

      _lastRemoteMoveUci = moveUci;

      if (moveUci.length < 4) return;
      const files = 'abcdefgh';
      const ranks = '87654321';

      final fromC = files.indexOf(moveUci[0]);
      final fromR = ranks.indexOf(moveUci[1]);
      final toC = files.indexOf(moveUci[2]);
      final toR = ranks.indexOf(moveUci[3]);

      if (fromC == -1 || fromR == -1 || toC == -1 || toR == -1) return;

      final piece = _boardState[fromR][fromC];
      if (piece == null) return;

      final fenBefore = _generateCurrentFen();
      final moveSan = ChessLogic.toSan(_boardState, moveUci);
      final capturedPiece = _boardState[toR][toC];
      final isCastle = piece.endsWith('K') && (fromC - toC).abs() == 2;
      final isCapture = capturedPiece != null || (piece.endsWith('P') && fromC != toC && capturedPiece == null);

      final isSound = context.read<SettingsBloc>().state.isSoundEnabled;
      if (isCastle) {
        ChessSoundService.instance.playCastle(isSound);
      } else if (isCapture) {
        ChessSoundService.instance.playCapture(isSound);
      } else {
        ChessSoundService.instance.playMoveSelf(isSound);
      }

      setState(() {
        _applyMoveIncrement();
        _applyMoveToBoardState(fromR, fromC, toR, toC, piece, moveUci);
        _selectedRow = null;
        _selectedCol = null;
        _legalDestinations.clear();
        _lastMoveFromRow = fromR;
        _lastMoveFromCol = fromC;
        _lastMoveToRow = toR;
        _lastMoveToCol = toC;
        _isWhiteTurn = !_isWhiteTurn;
      });

      final fenAfter = _generateCurrentFen();
      _recordMoveLog(
        moveUci: moveUci,
        moveSan: moveSan,
        fenBefore: fenBefore,
        fenAfter: fenAfter,
        isWhite: piece.startsWith('W'),
      );

      _checkGameEnd();
    }, boardId: boardId);
  }

  Future<void> _initializeAndStartMatch(SettingsState settingsState) async {
    if (_isInitializingMatch || _hasStartedMatch) return;

    if (GlobalAnalysisService.instance.isAnalyzing) {
      AppSnackBar.showWarning(
        context,
        settingsState.isArabic
            ? 'التحليل العميق يعمل في الخلفية. يرجى الانتظار حتى اكتماله! 🧠'
            : 'Deep Analysis is running in background. Please wait until it completes! 🧠',
        iconAsset: 'assets/icons/1024x/inaccuracy_1024x.png',
      );
      return;
    }

    setState(() {
      _isInitializingMatch = true;
    });

    try {
      if (!settingsState.isPhysicalMode) {
        // 1. Show non-dismissible Engine Loading Dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) {
            final isAr = settingsState.isArabic;
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primaryGold),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isAr ? 'جاري تهيئة محرك الشطرنج ♟️' : 'Initializing Engine ♟️',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAr
                        ? 'يرجى الانتظار، جاري تحميل وتجهيز محرك Stockfish للمستوى ${widget.stockfishLevel} (${widget.eloRating} ELO)...'
                        : 'Please wait, loading and setting up Stockfish AI Engine Level ${widget.stockfishLevel} (${widget.eloRating} ELO)...',
                    style: const TextStyle(fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            );
          },
        );

        // 2. Ensure Stockfish is fully initialized and verified ready
        final isReady = await StockfishEngineService.instance.ensureEngineReady(
          level: widget.stockfishLevel,
          elo: widget.eloRating,
        );

        // 3. Dismiss loading dialog
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        if (!isReady || !mounted) {
          if (mounted) {
            setState(() {
              _hasStartedMatch = false;
            });
            AppSnackBar.showError(
              context,
              settingsState.isArabic
                  ? 'تعذر تهيئة محرك الشطرنج! يرجى المحاولة مرة أخرى.'
                  : 'Failed to initialize Stockfish engine! Please try again.',
              iconAsset: 'assets/icons/1024x/incorrect_1024x.png',
            );
          }
          return;
        }

        // 4. Show Readiness Success Snackbar & Play Game Start Sound
        ChessSoundService.instance.playGameStart(settingsState.isSoundEnabled);
        AppSnackBar.showSuccess(
          context,
          settingsState.isArabic
              ? 'محرك الشطرنج (Stockfish ELO ${widget.eloRating}) جاهز للمباراة! 🚀'
              : 'Stockfish Chess Engine (ELO ${widget.eloRating}) is ready for match! 🚀',
          iconAsset: 'assets/icons/1024x/best_1024x.png',
        );
      }

      _matchId = 'match_${DateTime.now().millisecondsSinceEpoch}';
      _startedAt = DateTime.now();

      if (mounted) {
        setState(() {
          _hasStartedMatch = true;
          _isMatchActive = true;
        });
        _startClocks();
        if (settingsState.isPhysicalMode) {
          _listenToRemotePhysicalBoardMoves();
        }

        // Monitor board online status during physical mode game
        if (settingsState.isPhysicalMode) {
          _boardOnlineSub = BoardConnectionService.instance.boardOnlineStream.listen((isOnline) {
            if (!isOnline && mounted && _isMatchActive) {
              final isAr = context.read<SettingsBloc>().state.isArabic;
              BoardConnectionService.instance.showMidGameOfflineDialog(context, isAr: isAr);
            }
          });
        }

        if (settingsState.isPhysicalMode) {
          FirebaseService.resetMatch();
          BoardConnectionService.instance.updateLiveSessionState(
            isWhite: _isPlayerWhite,
            timer: widget.timerMinutes * 60,
            incTime: widget.incrementSeconds,
            difficulty: widget.stockfishLevel,
            elo: widget.eloRating,
            playStyle: 'Balanced',
          );
          BoardConnectionService.instance.sendAppAction('START_MATCH', {
            'is_white': _isPlayerWhite,
            'timer': widget.timerMinutes * 60,
            'inc_time': widget.incrementSeconds,
            'difficulty': widget.stockfishLevel,
            'elo': widget.eloRating,
            'play_style': 'Balanced',
          });
        }

        // If player is Black, Stockfish AI plays White's first move instantly (Only in Digital mode)
        if (!_isPlayerWhite && !settingsState.isPhysicalMode) {
          await _executeStockfishAiMove();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializingMatch = false;
        });
      }
    }
  }

  void _resetBoardState() {
    _boardState = [
      ['BR', 'BN', 'BB', 'BQ', 'BK', 'BB', 'BN', 'BR'],
      ['BP', 'BP', 'BP', 'BP', 'BP', 'BP', 'BP', 'BP'],
      [null, null, null, null, null, null, null, null],
      [null, null, null, null, null, null, null, null],
      [null, null, null, null, null, null, null, null],
      [null, null, null, null, null, null, null, null],
      ['WP', 'WP', 'WP', 'WP', 'WP', 'WP', 'WP', 'WP'],
      ['WR', 'WN', 'WB', 'WQ', 'WK', 'WB', 'WN', 'WR'],
    ];
    _selectedRow = null;
    _selectedCol = null;
    _legalDestinations.clear();
    _lastMoveFromRow = null;
    _lastMoveFromCol = null;
    _lastMoveToRow = null;
    _lastMoveToCol = null;
    _isWhiteTurn = true;
    _reviewClassificationIcon = null;
    _reviewClassificationRow = null;
    _reviewClassificationCol = null;
  }

  void _startClocks() {
    if (!_hasTimer) return;
    _gameTimer?.cancel();
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_isMatchActive) {
        t.cancel();
        return;
      }

      final isPlayersTurn = (_isWhiteTurn == _isPlayerWhite);
      setState(() {
        if (isPlayersTurn) {
          if (_playerTimeSeconds > 0) {
            _playerTimeSeconds--;
            if (_playerTimeSeconds == 10) {
              final isSound = context.read<SettingsBloc>().state.isSoundEnabled;
              ChessSoundService.instance.playTenSeconds(isSound);
            }
          } else {
            t.cancel();
            _onTimeOut(isPlayerTimeout: true);
          }
        } else {
          if (_opponentTimeSeconds > 0) {
            _opponentTimeSeconds--;
            if (_opponentTimeSeconds == 10) {
              final isSound = context.read<SettingsBloc>().state.isSoundEnabled;
              ChessSoundService.instance.playTenSeconds(isSound);
            }
          } else {
            t.cancel();
            _onTimeOut(isPlayerTimeout: false);
          }
        }
      });
    });
  }

  void _applyMoveIncrement() {
    if (!_hasTimer || widget.incrementSeconds <= 0) return;
    final isPlayersTurn = (_isWhiteTurn == _isPlayerWhite);
    setState(() {
      if (isPlayersTurn) {
        _playerTimeSeconds += widget.incrementSeconds;
      } else {
        _opponentTimeSeconds += widget.incrementSeconds;
      }
    });
  }

  void _onTimeOut({required bool isPlayerTimeout}) {
    setState(() {
      _isMatchActive = false;
      _isMatchFinished = true;
    });
    _gameTimer?.cancel();
    FirebaseService.clearMatchData();
    if (context.read<SettingsBloc>().state.isPhysicalMode) {
      FirebaseService.setGameEnded(true);
      BoardConnectionService.instance.sendAppAction('STOP_MATCH');
    }

    final pgn = DeepGameAnalyzerService.formatFullGamePgn(_moveLog);
    final theme = context.read<SettingsBloc>().state.pieceTheme;
    MatchHistoryService.instance.completeMatchRecord(
      matchId: _matchId,
      matchType: 'quick_match',
      playerColor: _isPlayerWhite ? 'white' : 'black',
      opponentName: 'Stockfish Lvl ${widget.stockfishLevel} (${widget.eloRating} ELO)',
      stockfishLevel: widget.stockfishLevel,
      pieceTheme: theme,
      startedAt: _startedAt,
      status: 'completed',
      result: isPlayerTimeout ? 'defeat' : 'victory',
      resultReason: 'timeout',
      accuracy: 0,
      isDeepAnalyzed: false,
      pgn: pgn,
      finalMoveLog: _moveLog,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          final isAr = settingsState.isArabic;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.only(left: 24, top: 12, right: 8),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    isPlayerTimeout
                        ? (isAr ? 'انتهى الوقت! (خسارة) ⏱️' : 'Time Out! (Defeat) ⏱️')
                        : (isAr ? 'انتهى وقت الخصم! (فوز) 🏆' : 'Opponent Time Out! (Victory) 🏆'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isPlayerTimeout ? AppColors.error : AppColors.success,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: Text(
              isPlayerTimeout
                  ? (isAr ? 'نفد وقتك المخصص للمباراة.' : 'Your match time has expired.')
                  : (isAr ? 'نفد وقت الذكاء الاصطناعي!' : 'Stockfish ran out of time!'),
            ),
          );
        },
      ),
    );
  }

  void _onSurrenderButtonPressed(SettingsState settingsState) {
    _showExitOrSurrenderDialog(settingsState);
  }

  Future<void> _showExitOrSurrenderDialog(SettingsState settingsState) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Image.asset(
                  'assets/icons/1024x/resign_white_1024x.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  settingsState.translate('exit_match_dialog_title'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            settingsState.translate('exit_match_dialog_desc'),
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: Text(settingsState.translate('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(
                settingsState.translate('exit_match_confirm'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (result == true && mounted) {
      _surrenderMatch();
    }
  }

  void _surrenderMatch() {
    final isSound = context.read<SettingsBloc>().state.isSoundEnabled;
    ChessSoundService.instance.playGameEnd(isSound);
    setState(() {
      _isMatchActive = false;
      _isMatchFinished = true;
    });
    _gameTimer?.cancel();
    _playbackTimer?.cancel();
    FirebaseService.clearMatchData();
    if (context.read<SettingsBloc>().state.isPhysicalMode) {
      FirebaseService.setGameEnded(true);
      BoardConnectionService.instance.sendAppAction('STOP_MATCH');
    }

    final pgn = DeepGameAnalyzerService.formatFullGamePgn(_moveLog);
    final theme = context.read<SettingsBloc>().state.pieceTheme;
    MatchHistoryService.instance.completeMatchRecord(
      matchId: _matchId,
      matchType: 'quick_match',
      playerColor: _isPlayerWhite ? 'white' : 'black',
      opponentName: 'Stockfish Lvl ${widget.stockfishLevel} (${widget.eloRating} ELO)',
      stockfishLevel: widget.stockfishLevel,
      pieceTheme: theme,
      startedAt: _startedAt,
      status: 'completed',
      result: 'defeat',
      resultReason: 'surrendered',
      accuracy: _accuracy,
      pgn: pgn,
      finalMoveLog: _moveLog,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          final isAr = settingsState.isArabic;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.only(left: 24, top: 12, right: 8),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    isAr ? 'خسارة بالاستسلام 🏳️' : 'Resigned Match 🏳️',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.error),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            content: Text(
              isAr
                  ? 'لقد استسلمت في المباراة. تم تسجيلها كخسارة بسبب الاستسلام.'
                  : 'You surrendered the match. It has been recorded as a defeat (Resigned).',
            ),
          );
        },
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    if (!_hasTimer) return '∞';
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _onSquareTapped(int row, int col, SettingsState settingsState) {
    if (_isReviewingGame) return;

    if (!_hasStartedMatch) {
      AppSnackBar.showWarning(
        context,
        settingsState.isArabic
            ? 'اضغط على زر "بدء المباراة ⚔️" للبدء باللعب!'
            : 'Click "Start Match ⚔️" to begin playing!',
        iconAsset: 'assets/icons/1024x/inaccuracy_1024x.png',
      );
      return;
    }

    if (!_isMatchActive) return;

    if (settingsState.isPhysicalMode) {
      AppSnackBar.showInfo(
        context,
        settingsState.isArabic
            ? 'الوضع الفيزيائي مفعل: يرجى تنفيذ النقلات على الرقعة الحقيقية!'
            : 'Physical Mode Active: Execute moves on your physical chessboard!',
        iconAsset: 'assets/icons/1024x/book_1024x.png',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    final isDestination = _legalDestinations.any(
      (d) => d[0] == row && d[1] == col,
    );

    if (isDestination && _selectedRow != null && _selectedCol != null) {
      _executeLocalMove(_selectedRow!, _selectedCol!, row, col, settingsState);
      return;
    }

    final piece = _boardState[row][col];
    if (piece != null &&
        (piece.startsWith('W') == _isWhiteTurn) &&
        (_isWhiteTurn == _isPlayerWhite)) {
      if (_selectedRow == row && _selectedCol == col) {
        setState(() {
          _selectedRow = null;
          _selectedCol = null;
          _legalDestinations.clear();
        });
        return;
      }

      setState(() {
        _selectedRow = row;
        _selectedCol = col;
        _legalDestinations = ChessLogic.getLegalMoves(
          _boardState,
          row,
          col,
          _isWhiteTurn,
        );
      });
    } else {
      if (_selectedRow != null && _selectedCol != null) {
        ChessSoundService.instance.playIllegal(settingsState.isSoundEnabled);
      }
      setState(() {
        _selectedRow = null;
        _selectedCol = null;
        _legalDestinations.clear();
      });
    }
  }

  void _checkGameEnd() {
    bool hasLegalMoves = false;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = _boardState[r][c];
        if (p != null &&
            (_isWhiteTurn ? p.startsWith('W') : p.startsWith('B'))) {
          final moves = ChessLogic.getLegalMovesForColor(
            _boardState,
            r,
            c,
            isWhite: _isWhiteTurn,
          );
          if (moves.isNotEmpty) {
            hasLegalMoves = true;
            break;
          }
        }
      }
      if (hasLegalMoves) break;
    }

    if (!hasLegalMoves || !_isMatchActive) {
      final isSound = context.read<SettingsBloc>().state.isSoundEnabled;
      ChessSoundService.instance.playGameEnd(isSound);
      final inCheck = ChessLogic.isKingInCheck(_boardState, _isWhiteTurn);
      setState(() {
        _isMatchActive = false;
        _isMatchFinished = true;
      });
      _gameTimer?.cancel();
      _playbackTimer?.cancel();
      FirebaseService.clearMatchData();
      if (context.read<SettingsBloc>().state.isPhysicalMode) {
        FirebaseService.setGameEnded(true);
        BoardConnectionService.instance.sendAppAction('STOP_MATCH');
      }

      final pgn = DeepGameAnalyzerService.formatFullGamePgn(_moveLog);
      final isVictory = inCheck ? (_isWhiteTurn != _isPlayerWhite) : false;
      final reason = !hasLegalMoves
          ? (inCheck ? 'checkmate' : 'stalemate')
          : (_playerTimeSeconds <= 0 || _opponentTimeSeconds <= 0 ? 'timeout' : 'surrendered');
      final resultStr = !hasLegalMoves
          ? (!inCheck ? 'draw' : (isVictory ? 'victory' : 'defeat'))
          : 'defeat';

      final theme = context.read<SettingsBloc>().state.pieceTheme;
      MatchHistoryService.instance.completeMatchRecord(
        matchId: _matchId,
        matchType: 'quick_match',
        playerColor: _isPlayerWhite ? 'white' : 'black',
        opponentName: 'Stockfish Lvl ${widget.stockfishLevel} (${widget.eloRating} ELO)',
        stockfishLevel: widget.stockfishLevel,
        pieceTheme: theme,
        startedAt: _startedAt,
        status: 'completed',
        result: resultStr,
        resultReason: reason,
        accuracy: 0,
        isDeepAnalyzed: false,
        pgn: pgn,
        finalMoveLog: _moveLog,
      );

      String title = inCheck
          ? (_isWhiteTurn == _isPlayerWhite ? 'You Lose!' : 'You Win!')
          : 'Stalemate!';
      String desc = inCheck
          ? (_isWhiteTurn == _isPlayerWhite
                ? 'You have been checkmated.'
                : 'You delivered checkmate!')
          : 'The game is a draw.';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.only(left: 24, top: 12, right: 8),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: inCheck && _isWhiteTurn == _isPlayerWhite
                            ? AppColors.error
                            : AppColors.success,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: Text(desc),
            );
          },
        ),
      );
    }
  }

  void _applyMoveToBoardState(int fromR, int fromC, int toR, int toC, String piece, String moveUci) {
    // 1. En Passant Pawn Captures
    if (piece.endsWith('P') && fromC != toC && _boardState[toR][toC] == null) {
      final captureRow = piece.startsWith('W') ? toR + 1 : toR - 1;
      if (captureRow >= 0 && captureRow < 8) {
        _boardState[captureRow][toC] = null;
      }
    }

    // 2. Move Primary Piece
    _boardState[toR][toC] = piece;
    _boardState[fromR][fromC] = null;

    // 3. Castling Rook Transfers (White & Black, Kingside & Queenside)
    if (piece.endsWith('K') && (fromC - toC).abs() == 2) {
      if (toC == 6) {
        // Kingside Castling (col 4 -> col 6): Move Rook from col 7 to col 5
        _boardState[fromR][5] = _boardState[fromR][7];
        _boardState[fromR][7] = null;
      } else if (toC == 2) {
        // Queenside Castling (col 4 -> col 2): Move Rook from col 0 to col 3
        _boardState[fromR][3] = _boardState[fromR][0];
        _boardState[fromR][0] = null;
      }
    }

    // 4. Pawn Promotions (UCI notation or auto-Queen at rank 0/7)
    if (moveUci.length == 5) {
      final promo = moveUci[4].toUpperCase();
      final color = piece.startsWith('W') ? 'W' : 'B';
      _boardState[toR][toC] = '$color$promo';
    } else if (piece == 'WP' && toR == 0) {
      _boardState[toR][toC] = 'WQ';
    } else if (piece == 'BP' && toR == 7) {
      _boardState[toR][toC] = 'BQ';
    }
  }

  Future<String?> _showPromotionDialog(bool isWhite, SettingsState settingsState) {
    final isAr = settingsState.isArabic;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isAr ? 'ترقية البيدق ♛' : 'Pawn Promotion ♛',
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: ['Q', 'R', 'B', 'N'].map((type) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, type),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: settingsState.isDarkMode
                          ? const Color(0xFF2A2A32)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.5)),
                    ),
                    child: Image.asset(
                      settingsState.getPieceAssetPath('${isWhite ? "W" : "B"}$type'),
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _executeLocalMove(
    int fromR,
    int fromC,
    int toR,
    int toC,
    SettingsState settingsState,
  ) async {
    final fenBefore = _generateCurrentFen();
    final piece = _boardState[fromR][fromC];
    if (piece == null) return;

    String promoChar = '';
    if (piece.endsWith('P') && (toR == 0 || toR == 7)) {
      final choice = await _showPromotionDialog(piece.startsWith('W'), settingsState);
      if (choice != null) promoChar = choice;
    }

    const files = 'abcdefgh';
    const ranks = '87654321';
    final moveUci = '${files[fromC]}${ranks[fromR]}${files[toC]}${ranks[toR]}${promoChar.toLowerCase()}';
    _lastRemoteMoveUci = moveUci;
    final moveSan = ChessLogic.toSan(_boardState, moveUci);

    final capturedPiece = _boardState[toR][toC];
    final isCastle = piece.endsWith('K') && (fromC - toC).abs() == 2;
    final isCapture = capturedPiece != null || (piece.endsWith('P') && fromC != toC && capturedPiece == null);

    if (isCastle) {
      ChessSoundService.instance.playCastle(settingsState.isSoundEnabled);
    } else if (isCapture) {
      ChessSoundService.instance.playCapture(settingsState.isSoundEnabled);
    } else {
      ChessSoundService.instance.playMoveSelf(settingsState.isSoundEnabled);
    }

    setState(() {
      _applyMoveIncrement();
      _applyMoveToBoardState(fromR, fromC, toR, toC, piece, moveUci);
      _selectedRow = null;
      _selectedCol = null;
      _legalDestinations.clear();
      _lastMoveFromRow = fromR;
      _lastMoveFromCol = fromC;
      _lastMoveToRow = toR;
      _lastMoveToCol = toC;
      _isWhiteTurn = !_isWhiteTurn;
    });

    final fenAfter = _generateCurrentFen();
    if (settingsState.isPhysicalMode) {
      FirebaseService.pushMove(moveUci, fenAfter);
    }
    _recordMoveLog(moveUci: moveUci, moveSan: moveSan, fenBefore: fenBefore, fenAfter: fenAfter, isWhite: _isPlayerWhite);

    _checkGameEnd();

    if (_isMatchActive && _isWhiteTurn != _isPlayerWhite && !settingsState.isPhysicalMode) {
      await _executeStockfishAiMove();
    }
  }

  int _calculateStockfishThinkingDelaySeconds() {
    final rand = Random().nextInt(100);
    if (rand < 10) {
      // 10% probability for 1s or 2s
      return Random().nextBool() ? 1 : 2;
    } else if (rand < 85) {
      // 75% probability for 3s, 4s, 5s, 6s (usual range)
      return 3 + Random().nextInt(4);
    } else {
      // 15% probability for 7s, 8s, 9s, 10s (rare range)
      return 7 + Random().nextInt(4);
    }
  }

  Future<void> _executeStockfishAiMove() async {
    if (!_isMatchActive) return;

    final fenBefore = _generateCurrentFen();
    final evalDepth = (widget.stockfishLevel / 2).round().clamp(1, 10);
    Map<String, dynamic> eval;
    try {
      eval = await StockfishEngineService.instance
          .evaluatePosition(
            [],
            fen: fenBefore,
            depth: evalDepth,
          )
          .timeout(const Duration(milliseconds: 2500));
    } catch (_) {
      eval = {};
    }

    // Weighted random human-like thinking delay (3-6s usual, 1-2s or 7-10s rare)
    final delaySeconds = _calculateStockfishThinkingDelaySeconds();
    await Future.delayed(Duration(seconds: delaySeconds));
    if (!_isMatchActive || !mounted) return;

    String bestMoveUci = eval['best_move'] as String? ?? '';
    if (bestMoveUci.isEmpty || bestMoveUci.length < 4) {
      final aiIsWhite = !_isPlayerWhite;
      final aiPrefix = aiIsWhite ? 'W' : 'B';
      final legalMoves = <List<int>>[];
      for (int r = 0; r < 8; r++) {
        for (int c = 0; c < 8; c++) {
          final p = _boardState[r][c];
          if (p != null && p.startsWith(aiPrefix)) {
            final dests = ChessLogic.getLegalMovesForColor(_boardState, r, c, isWhite: aiIsWhite);
            for (final d in dests) {
              legalMoves.add([r, c, d[0], d[1]]);
            }
          }
        }
      }
      if (legalMoves.isNotEmpty) {
        legalMoves.shuffle();
        final m = legalMoves.first;
        const files = 'abcdefgh';
        const ranks = '87654321';
        bestMoveUci = '${files[m[1]]}${ranks[m[0]]}${files[m[3]]}${ranks[m[2]]}';
      } else {
        _checkGameEnd();
        return;
      }
    }

    const files = 'abcdefgh';
    const ranks = '87654321';

    final fromC = files.indexOf(bestMoveUci[0]);
    final fromR = ranks.indexOf(bestMoveUci[1]);
    final toC = files.indexOf(bestMoveUci[2]);
    final toR = ranks.indexOf(bestMoveUci[3]);

    if (fromC != -1 && fromR != -1 && toC != -1 && toR != -1) {
      final moveSan = ChessLogic.toSan(_boardState, bestMoveUci);
      final piece = _boardState[fromR][fromC];

      if (piece != null && mounted) {
        final capturedPiece = _boardState[toR][toC];
        final isCastle = piece.endsWith('K') && (fromC - toC).abs() == 2;
        final isCapture = capturedPiece != null || (piece.endsWith('P') && fromC != toC && capturedPiece == null);

        final isSound = context.read<SettingsBloc>().state.isSoundEnabled;
        if (isCastle) {
          ChessSoundService.instance.playCastle(isSound);
        } else if (isCapture) {
          ChessSoundService.instance.playCapture(isSound);
        } else {
          ChessSoundService.instance.playMoveOpponent(isSound);
        }

        setState(() {
          _applyMoveIncrement();
          _applyMoveToBoardState(fromR, fromC, toR, toC, piece, bestMoveUci);
          _lastMoveFromRow = fromR;
          _lastMoveFromCol = fromC;
          _lastMoveToRow = toR;
          _lastMoveToCol = toC;
          _isWhiteTurn = !_isWhiteTurn;
        });

        final fenAfter = _generateCurrentFen();
        if (mounted && context.read<SettingsBloc>().state.isPhysicalMode) {
          FirebaseService.pushMove(bestMoveUci, fenAfter);
        }
        _recordMoveLog(moveUci: bestMoveUci, moveSan: moveSan, fenBefore: fenBefore, fenAfter: fenAfter, isWhite: !_isPlayerWhite);
        _checkGameEnd();
      }
    }
  }

  void _recordMoveLog({
    required String moveUci,
    required String moveSan,
    required String fenBefore,
    required String fenAfter,
    required bool isWhite,
  }) {
    final rawEntry = {
      'num': (_moveLog.length ~/ 2) + 1,
      'player': isWhite ? 'White' : 'Black',
      'move': moveSan,
      'uci': moveUci,
      'fenBefore': fenBefore,
      'fenAfter': fenAfter,
      'isWhite': isWhite,
    };
    _moveLog.add(rawEntry);

    final pgn = DeepGameAnalyzerService.formatFullGamePgn(_moveLog);
    final theme = context.read<SettingsBloc>().state.pieceTheme;
    MatchHistoryService.instance.updateLiveMatchData(
      matchId: _matchId,
      matchType: 'quick_match',
      playerColor: _isPlayerWhite ? 'white' : 'black',
      opponentName: 'Stockfish Lvl ${widget.stockfishLevel} (${widget.eloRating} ELO)',
      stockfishLevel: widget.stockfishLevel,
      pieceTheme: theme,
      startedAt: _startedAt,
      moveLog: _moveLog,
      accuracy: 0,
      pgn: pgn,
      fen: fenAfter,
    );
  }

  Future<void> _runDeepGameAnalysis(SettingsState settingsState) async {
    if (_moveLog.isEmpty) return;

    final dummyRecord = MatchRecordModel(
      id: _matchId,
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'guest_user',
      matchType: 'quick_match',
      analyzerMode: 'deep_game_analysis',
      playerColor: _isPlayerWhite ? 'white' : 'black',
      opponentName: 'Stockfish Lvl ${widget.stockfishLevel} (${widget.eloRating} ELO)',
      stockfishLevel: widget.stockfishLevel,
      status: 'completed',
      result: 'completed',
      accuracy: _accuracy,
      moveCount: _moveLog.length,
      pgn: '',
      fen: _generateCurrentFen(),
      moveLog: _moveLog,
      pieceTheme: settingsState.pieceTheme,
      startedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // 1. Immediately transition UI to review mode & unlock navigation
    _startMatchReview();

    // 2. Launch deep analysis asynchronously in background
    GlobalAnalysisService.instance.startDeepAnalysis(
      context: context,
      matchRecord: dummyRecord,
      rawMoveLog: List<Map<String, dynamic>>.from(_moveLog),
      settingsState: settingsState,
    ).then((success) async {
      if (success && mounted) {
        final updatedRecord = await MatchHistoryService.instance.getMatchRecordById(_matchId);
        if (updatedRecord != null && mounted) {
          setState(() {
            _moveLog.clear();
            _moveLog.addAll(updatedRecord.moveLog);
            _accuracy = updatedRecord.accuracy;
            _hasRunDeepAnalysis = true;
          });
        }
      }
    });
  }

  void _startMatchReview() {
    setState(() {
      _isReviewingGame = true;
      _reviewMoveIndex = _moveLog.length;
    });
    _updateBoardStateForReviewIndex(_reviewMoveIndex);
  }

  void _toggleAutoPlayback() {
    if (!_hasRunDeepAnalysis || _moveLog.isEmpty) return;
    if (_isPlayingBack) {
      _playbackTimer?.cancel();
      setState(() => _isPlayingBack = false);
    } else {
      setState(() => _isPlayingBack = true);
      if (_reviewMoveIndex >= _moveLog.length) {
        _updateBoardStateForReviewIndex(0);
      }
      _playbackTimer = Timer.periodic(const Duration(milliseconds: 1200), (t) {
        if (_reviewMoveIndex < _moveLog.length) {
          _updateBoardStateForReviewIndex(_reviewMoveIndex + 1);
        } else {
          t.cancel();
          setState(() => _isPlayingBack = false);
        }
      });
    }
  }

  void _stepToFirstMove() {
    if (!_hasRunDeepAnalysis) return;
    _playbackTimer?.cancel();
    setState(() => _isPlayingBack = false);
    _updateBoardStateForReviewIndex(0);
  }

  void _stepPreviousMove() {
    if (!_hasRunDeepAnalysis) return;
    _playbackTimer?.cancel();
    setState(() => _isPlayingBack = false);
    _updateBoardStateForReviewIndex(_reviewMoveIndex - 1);
  }

  void _stepNextMove() {
    if (!_hasRunDeepAnalysis) return;
    _playbackTimer?.cancel();
    setState(() => _isPlayingBack = false);
    _updateBoardStateForReviewIndex(_reviewMoveIndex + 1);
  }

  void _stepToLastMove() {
    if (!_hasRunDeepAnalysis) return;
    _playbackTimer?.cancel();
    setState(() => _isPlayingBack = false);
    _updateBoardStateForReviewIndex(_moveLog.length);
  }

  void _updateBoardStateForReviewIndex(int index) {
    if (index <= 0) {
      setState(() {
        _reviewMoveIndex = 0;
        _resetBoardState();
        _reviewClassificationIcon = null;
        _reviewClassificationRow = null;
        _reviewClassificationCol = null;
        _lastMoveFromRow = null;
        _lastMoveFromCol = null;
        _lastMoveToRow = null;
        _lastMoveToCol = null;
      });
      return;
    }

    final targetIndex = index.clamp(1, _moveLog.length);
    final move = _moveLog[targetIndex - 1];
    final fenAfter = move['fenAfter'] as String? ?? '';
    final moveUci = move['uci'] as String? ?? '';
    final iconPath = move['icon'] as String?;

    const files = 'abcdefgh';
    const ranks = '87654321';

    int? fromR, fromC, toR, toC;
    if (moveUci.length >= 4) {
      fromC = files.indexOf(moveUci[0]);
      fromR = ranks.indexOf(moveUci[1]);
      toC = files.indexOf(moveUci[2]);
      toR = ranks.indexOf(moveUci[3]);
    }

    setState(() {
      _reviewMoveIndex = targetIndex;
      if (fenAfter.isNotEmpty) {
        _boardState = _parseFenToBoardState(fenAfter);
      }
      _lastMoveFromRow = (fromR != null && fromR != -1) ? fromR : null;
      _lastMoveFromCol = (fromC != null && fromC != -1) ? fromC : null;
      _lastMoveToRow = (toR != null && toR != -1) ? toR : null;
      _lastMoveToCol = (toC != null && toC != -1) ? toC : null;
      _reviewClassificationIcon = iconPath;
      _reviewClassificationRow = (toR != null && toR != -1) ? toR : null;
      _reviewClassificationCol = (toC != null && toC != -1) ? toC : null;
    });
  }

  List<List<String?>> _parseFenToBoardState(String fen) {
    final board = List.generate(8, (_) => List<String?>.filled(8, null));
    final parts = fen.split(' ');
    if (parts.isEmpty) return board;

    final rows = parts[0].split('/');
    for (int r = 0; r < 8 && r < rows.length; r++) {
      int c = 0;
      for (int i = 0; i < rows[r].length && c < 8; i++) {
        final char = rows[r][i];
        if (RegExp(r'\d').hasMatch(char)) {
          c += int.parse(char);
        } else {
          final isWhite = char == char.toUpperCase();
          final pieceChar = char.toUpperCase();
          board[r][c] = '${isWhite ? 'W' : 'B'}$pieceChar';
          c++;
        }
      }
    }
    return board;
  }

  String _generateCurrentFen() {
    final rows = <String>[];
    for (int r = 0; r < 8; r++) {
      int emptyCount = 0;
      String rowFen = '';
      for (int c = 0; c < 8; c++) {
        final p = _boardState[r][c];
        if (p == null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            rowFen += emptyCount.toString();
            emptyCount = 0;
          }
          final isWhite = p.startsWith('W');
          final char = p.substring(1).toLowerCase();
          rowFen += isWhite ? char.toUpperCase() : char;
        }
      }
      if (emptyCount > 0) {
        rowFen += emptyCount.toString();
      }
      rows.add(rowFen);
    }

    final activeColor = _isWhiteTurn ? 'w' : 'b';
    final castling = _generateCastlingRights();
    return '${rows.join('/')} $activeColor $castling - 0 1';
  }

  String _generateCastlingRights() {
    final buffer = StringBuffer();
    if (_boardState[7][4] == 'WK' && _boardState[7][7] == 'WR') {
      buffer.write('K');
    }
    if (_boardState[7][4] == 'WK' && _boardState[7][0] == 'WR') {
      buffer.write('Q');
    }
    if (_boardState[0][4] == 'BK' && _boardState[0][7] == 'BR') {
      buffer.write('k');
    }
    if (_boardState[0][4] == 'BK' && _boardState[0][0] == 'BR') {
      buffer.write('q');
    }
    return buffer.isEmpty ? '-' : buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
        final isDark = settingsState.isDarkMode;
        final isAr = settingsState.isArabic;

        return PopScope(
          canPop: !_isMatchActive,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (_isMatchActive) {
              await _showExitOrSurrenderDialog(settingsState);
            }
          },
          child: DefaultTabController(
            length: 3,
            child: Scaffold(
              appBar: AppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    if (_isMatchActive) {
                      _showExitOrSurrenderDialog(settingsState);
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAr ? 'مباراة سريعة ⚡' : 'Quick Match ⚡',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Stockfish Lvl ${widget.stockfishLevel} (${widget.eloRating} ELO)',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                actions: [
                  if (_isMatchActive)
                    IconButton(
                      icon: const Icon(Icons.flag_rounded, color: AppColors.error),
                      tooltip: isAr ? 'استسلام' : 'Surrender',
                      onPressed: () => _onSurrenderButtonPressed(settingsState),
                    ),
                ],
                elevation: 0,
                backgroundColor: Colors.transparent,
                bottom: TabBar(
                  indicatorColor: AppColors.primaryGold,
                  indicatorWeight: 3,
                  labelColor: AppColors.primaryGold,
                  unselectedLabelColor: Colors.grey.shade600,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.sports_esports_rounded),
                      text: isAr ? 'رقعة اللعب' : 'Game Board',
                    ),
                    Tab(
                      icon: const Icon(Icons.psychology_rounded),
                      text: isAr ? 'التحليل العميق' : 'Deep Analysis',
                    ),
                    Tab(
                      icon: const Icon(Icons.description_rounded),
                      text: isAr ? 'تدوين PGN' : 'Game PGN',
                    ),
                  ],
                ),
              ),
              body: SafeArea(
                child: TabBarView(
                  children: [
                    // --- TAB 1: GAME BOARD & TWIN CLOCKS ---
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Top Opponent Clock Card
                                  _buildOpponentClockCard(settingsState),
                                  const SizedBox(height: 10),

                                  // Training Board Widget
                                  TrainingBoardWidget(
                                    boardState: _boardState,
                                    settingsState: settingsState,
                                    isBoardFlipped: !_isPlayerWhite,
                                    selectedRow: _selectedRow,
                                    selectedCol: _selectedCol,
                                    legalDestinations: _legalDestinations,
                                    lastMoveFromRow: _lastMoveFromRow,
                                    lastMoveFromCol: _lastMoveFromCol,
                                    lastMoveToRow: _lastMoveToRow,
                                    lastMoveToCol: _lastMoveToCol,
                                    hintFromRow: null,
                                    hintFromCol: null,
                                    hintToRow: null,
                                    hintToCol: null,
                                    classificationIconPath: _reviewClassificationIcon,
                                    classificationRow: _reviewClassificationRow,
                                    classificationCol: _reviewClassificationCol,
                                    isKingInCheck: (isWhite) => ChessLogic.isKingInCheck(
                                      _boardState,
                                      isWhite,
                                    ),
                                    onSquareTapped: (r, c) => _onSquareTapped(r, c, settingsState),
                                  ),
                                  const SizedBox(height: 10),

                                  // Bottom Player Clock Card
                                  _buildPlayerClockCard(settingsState),
                                  if (!_hasStartedMatch) ...[
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.primaryGold,
                                          foregroundColor: Colors.black,
                                          minimumSize: const Size(0, 54),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          elevation: 4,
                                        ),
                                        icon: const Icon(Icons.play_arrow_rounded, size: 30),
                                        label: Text(
                                          isAr ? 'بدء المباراة ⚔️' : 'Start Match ⚔️',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        onPressed: (_isInitializingMatch || _hasStartedMatch)
                                            ? null
                                            : () => _initializeAndStartMatch(settingsState),
                                      ),
                                    ),
                                  ],
                                  if (_isMatchFinished) ...[
                                    const SizedBox(height: 10),
                                    _buildPlaybackControlBar(settingsState),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // --- TAB 2: GAME ANALYSIS & DEEP ENGINE ---
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMatchHeaderCard(settingsState),
                          const SizedBox(height: 14),
                          if (_isMatchActive) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.primaryGold.withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.lock_clock_rounded, color: AppColors.primaryGold, size: 28),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          isAr ? 'التحليل العميق سيتوفر عند نهاية المباراة 🧠' : 'Deep Analysis unlocks after match end 🧠',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    isAr
                                        ? 'المباراة مفعّلة حالياً. يمكنك إجراء التحليل العميق محرك Stockfish Depth-20 بعد انتهاء اللقاء أو الاستسلام.'
                                        : 'Match is currently live. Stockfish Depth-20 deep analysis will unlock once the match ends or upon surrender.',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ] else if (!_hasRunDeepAnalysis) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.primaryGold),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.psychology_rounded, color: AppColors.primaryGold, size: 28),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          isAr ? 'التحليل العميق للمباراة 🧠' : 'Deep Game Analysis 🧠',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isAr
                                        ? 'تشغيل محرك Stockfish Depth-20 لتحليل جميع النقلات وحساب الدقة وتصنيف الأخطاء!'
                                        : 'Run Stockfish Depth-20 engine to analyze all moves, calculate accuracy and classify errors!',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 12),
                                  Builder(
                                    builder: (context) {
                                      final isAnalyzing = GlobalAnalysisService.instance.isAnalyzing;
                                      return SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isAnalyzing ? Colors.grey.shade400 : AppColors.primaryGold,
                                            foregroundColor: isAnalyzing ? Colors.grey.shade700 : Colors.black,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                          ),
                                          icon: isAnalyzing
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                                )
                                              : const Icon(Icons.play_circle_fill_rounded),
                                          label: Text(
                                            isAnalyzing
                                                ? (isAr ? 'التحليل العميق جارٍ الآن... ⏳' : 'Deep Analysis in Progress... ⏳')
                                                : (isAr ? 'بدء التحليل العميق الآن' : 'Start Deep Analysis Now'),
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: isAnalyzing ? null : () => _runDeepGameAnalysis(settingsState),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          if (_hasRunDeepAnalysis)
                            LiveGameAnalyzerWidget(
                              moveLog: _moveLog,
                              settingsState: settingsState,
                              evalBarValue: _evalBarValue,
                              overallAccuracy: _accuracy,
                            ),
                        ],
                      ),
                    ),

                    // --- TAB 3: GAME PGN ---
                    _buildGamePgnTab(settingsState),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Clock Card Widgets ---
  Widget _buildOpponentClockCard(SettingsState settingsState) {
    final isDark = settingsState.isDarkMode;
    final isOpponentTurn = (_isWhiteTurn != _isPlayerWhite) && _isMatchActive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOpponentTurn ? AppColors.primaryGold : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isOpponentTurn ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isOpponentTurn ? AppColors.primaryGold : Colors.grey.shade400,
                child: Icon(
                  Icons.smart_toy_rounded,
                  color: isOpponentTurn ? Colors.black : Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Stockfish Lvl ${widget.stockfishLevel}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    '${widget.eloRating} ELO • ${_isPlayerWhite ? 'Black' : 'White'}',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isOpponentTurn ? AppColors.primaryGold : (isDark ? const Color(0xFF1E1E24) : Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_rounded,
                  size: 16,
                  color: isOpponentTurn ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTime(_opponentTimeSeconds),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isOpponentTurn ? Colors.black : (isDark ? Colors.white : Colors.black87),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerClockCard(SettingsState settingsState) {
    final isDark = settingsState.isDarkMode;
    final isPlayerTurn = (_isWhiteTurn == _isPlayerWhite) && _isMatchActive;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPlayerTurn ? AppColors.primaryGold : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: isPlayerTurn ? 2 : 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isPlayerTurn ? AppColors.primaryGold : Colors.grey.shade400,
                child: Icon(
                  Icons.person_rounded,
                  color: isPlayerTurn ? Colors.black : Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settingsState.isArabic ? 'أنت (اللاعب)' : 'You (Player)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  Text(
                    _isPlayerWhite ? 'White' : 'Black',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isPlayerTurn ? AppColors.primaryGold : (isDark ? const Color(0xFF1E1E24) : Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_rounded,
                  size: 16,
                  color: isPlayerTurn ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTime(_playerTimeSeconds),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isPlayerTurn ? Colors.black : (isDark ? Colors.white : Colors.black87),
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchHeaderCard(SettingsState settingsState) {
    final isDark = settingsState.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stockfish Lvl ${widget.stockfishLevel} (${widget.eloRating} ELO)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_moveLog.length} moves • Accuracy: $_accuracy%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryGold),
            ),
            child: Text(
              _isMatchActive ? 'LIVE' : 'FINISHED',
              style: const TextStyle(
                color: AppColors.primaryGold,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamePgnTab(SettingsState settingsState) {
    final pgnText = DeepGameAnalyzerService.formatFullGamePgn(_moveLog);
    final isDark = settingsState.isDarkMode;
    final isAr = settingsState.isArabic;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMatchHeaderCard(settingsState),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? AppColors.primaryGold.withValues(alpha: 0.3)
                    : AppColors.primaryMahogany.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.description_rounded, size: 22, color: AppColors.primaryGold),
                        const SizedBox(width: 8),
                        Text(
                          isAr ? 'تدوين المباراة (PGN)' : 'Game PGN Notation',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: pgnText.isNotEmpty
                          ? () {
                              Clipboard.setData(ClipboardData(text: pgnText));
                              AppSnackBar.showSuccess(
                                context,
                                isAr ? 'تم نسخ PGN بنجاح!' : 'PGN copied to clipboard!',
                                iconAsset: 'assets/icons/1024x/correct_1024x.png',
                              );
                            }
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: pgnText.isNotEmpty ? AppColors.primaryGold : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.copy_rounded, size: 16, color: Colors.black),
                            const SizedBox(width: 4),
                            Text(
                              isAr ? 'نسخ PGN' : 'Copy PGN',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 180),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141418) : const Color(0xFFF5F5F8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                  ),
                  child: pgnText.isEmpty
                      ? Center(
                          child: Text(
                            isAr ? 'لا يوجد تدوين PGN لهذا اللقاء.' : 'No PGN recorded for this match.',
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        )
                      : SelectableText(
                          pgnText,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            height: 1.6,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControlBar(SettingsState settingsState) {
    final isDark = settingsState.isDarkMode;
    final isAr = settingsState.isArabic;
    final isEnabled = _hasRunDeepAnalysis;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEnabled
              ? AppColors.primaryGold.withValues(alpha: 0.6)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
      ),
      child: Column(
        children: [
          if (!isEnabled) ...[
            Text(
              isAr
                  ? '🔒 قم بإجراء التحليل العميق في التبويب 2 لتفعيل مراجعة النقلات على الرقعة'
                  : '🔒 Run Deep Game Analysis in Tab 2 to unlock interactive board playback',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
          ] else ...[
            Text(
              isAr
                  ? 'مراجعة النقلات: النقلة $_reviewMoveIndex من ${_moveLog.length}'
                  : 'Move Review: Move $_reviewMoveIndex of ${_moveLog.length}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // First Move ⏮
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 28),
                color: isEnabled ? AppColors.primaryGold : Colors.grey.shade600,
                onPressed: isEnabled ? _stepToFirstMove : null,
                tooltip: isAr ? 'البداية' : 'First Move',
              ),

              // Step Back ◀
              IconButton(
                icon: const Icon(Icons.navigate_before_rounded, size: 32),
                color: isEnabled ? AppColors.primaryGold : Colors.grey.shade600,
                onPressed: isEnabled ? _stepPreviousMove : null,
                tooltip: isAr ? 'النقلة السابقة' : 'Previous Move',
              ),

              // Play / Pause ▶ / ⏸
              IconButton(
                icon: Icon(
                  _isPlayingBack ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  size: 38,
                ),
                color: isEnabled ? AppColors.primaryGold : Colors.grey.shade600,
                onPressed: isEnabled ? _toggleAutoPlayback : null,
                tooltip: isAr ? 'تشغيل تلقائي' : 'Auto Playback',
              ),

              // Step Forward ▶
              IconButton(
                icon: const Icon(Icons.navigate_next_rounded, size: 32),
                color: isEnabled ? AppColors.primaryGold : Colors.grey.shade600,
                onPressed: isEnabled ? _stepNextMove : null,
                tooltip: isAr ? 'النقلة التالية' : 'Next Move',
              ),

              // Last Move ⏭
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 28),
                color: isEnabled ? AppColors.primaryGold : Colors.grey.shade600,
                onPressed: isEnabled ? _stepToLastMove : null,
                tooltip: isAr ? 'النهاية' : 'Last Move',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
