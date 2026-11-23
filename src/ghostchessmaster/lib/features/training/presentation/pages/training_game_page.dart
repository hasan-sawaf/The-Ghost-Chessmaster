import 'package:firebase_auth/firebase_auth.dart';
import 'package:ghostchessmaster/features/training/presentation/widgets/training_board_widget.dart';
import 'package:ghostchessmaster/features/training/presentation/widgets/live_game_analyzer_widget.dart';
import 'dart:math';
import 'dart:async';
import 'package:ghostchessmaster/features/training/utils/chess_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/training_theme_helper.dart';
import '../../../../core/services/chess_sound_service.dart';
import '../../../../core/services/global_analysis_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/load_images.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../../../services/firebase_service.dart';
import '../../../engine/domain/game_analyzer_logic.dart';
import '../../../engine/domain/deep_game_analyzer_service.dart';
import '../../../engine/domain/chess_evaluator.dart';
import '../../../engine/services/stockfish_engine_service.dart';
import '../../../history/data/match_history_service.dart';
import '../../../history/domain/models/match_record_model.dart';
import '../../../../models/island_model.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import '../../data/training_campaign_service.dart';
import '../../../profile/data/board_connection_service.dart';

class TrainingGamePage extends StatefulWidget {
  final int islandIndex; // 1 to 20
  final int roundIndex; // 1 to 5
  final String islandTitle;
  final int stockfishLevel;
  final int eloRating;
  final String matchType; // 'training' or 'quick_match'
  final int timerMinutes;
  final int incrementSeconds;
  final bool isDeepAnalyzerMode;

  const TrainingGamePage({
    super.key,
    required this.islandIndex,
    required this.roundIndex,
    required this.islandTitle,
    required this.stockfishLevel,
    required this.eloRating,
    this.matchType = 'training',
    this.timerMinutes = 10,
    this.incrementSeconds = 2,
    this.isDeepAnalyzerMode = true,
  });

  @override
  State<TrainingGamePage> createState() => _TrainingGamePageState();
}

class _TrainingGamePageState extends State<TrainingGamePage> {
  String _matchId = '';
  bool _isMatchActive = false;
  bool _isEngineThinking = false;
  StreamSubscription<bool>? _boardOnlineSub;


  // Rules: Islands 1..10 get 3 hints max & no timer. Islands 11..20 get no hints & timer.
  late final bool _hintsAllowed;
  late final bool _hasTimer;
  int _hintsRemaining = 3;
  bool _hintUsedThisTurn = false;
  String? _activeHintText;

  // Active Hint Positions
  int? _hintFromRow;
  int? _hintFromCol;
  int? _hintToRow;
  int? _hintToCol;

  // Last Move Positions
  int? _lastMoveFromRow;
  int? _lastMoveFromCol;
  int? _lastMoveToRow;
  int? _lastMoveToCol;

  // Selected Square & Legal Destinations
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

  // Timer State
  int _remainingSeconds = 600;
  int _resolvedTimerMinutes = 10;
  int _resolvedIncrementSeconds = 2;
  Timer? _timer;

  // Move Log & Analysis State
  final List<Map<String, dynamic>> _moveLog = [];
  double _evalBarValue = 0.5;
  bool _isWhiteTurn = true;
  bool _isPlayerWhite = true;
  int _accuracy = 100;

  // Analyzer Mode Selection (Live vs Deep)
  bool _isDeepAnalyzerMode = true;
  bool _hasRunDeepAnalysis = false;

  // Post-Match Interactive Review & Playback
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
    // Round 1 & 3: White pieces | Round 2 & 4: Black pieces
    _isPlayerWhite = widget.roundIndex % 2 != 0;
    _isDeepAnalyzerMode = widget.isDeepAnalyzerMode;

    if (widget.matchType == 'quick_match') {
      _hintsAllowed = false;
      _hintsRemaining = 0;
      _resolvedTimerMinutes = widget.timerMinutes;
      _resolvedIncrementSeconds = widget.incrementSeconds;
      _hasTimer = _resolvedTimerMinutes > 0;
      _remainingSeconds = _resolvedTimerMinutes * 60;
    } else {
      _hintsRemaining = IslandModel.getHintNumForIsland(widget.islandIndex);
      _hintsAllowed = _hintsRemaining > 0;
      _resolvedTimerMinutes = IslandModel.getTimeForIsland(widget.islandIndex);
      _resolvedIncrementSeconds = IslandModel.getIncTimeForIsland(widget.islandIndex);
      _hasTimer = _resolvedTimerMinutes > 0;
      _remainingSeconds = _resolvedTimerMinutes * 60;
    }
    _resetBoardState();
    _initializeEngine();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final settingsState = context.read<SettingsBloc>().state;
        if (settingsState.isPhysicalMode) {
          _startMatchDirectly(settingsState);
        }
      }
    });
  }

  Future<void> _initializeEngine() async {
    await StockfishEngineService.instance.initEngine();
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

  @override
  void dispose() {
    _timer?.cancel();
    _playbackTimer?.cancel();
    _boardOnlineSub?.cancel();
    StockfishEngineService.instance.stopEngine();
    BoardConnectionService.instance.toggleCamera(turnOn: false);
    if (_moveLog.length <= 4 && _matchId.isNotEmpty) {
      MatchHistoryService.instance.deleteMatchRecord(_matchId);
    }
    super.dispose();
  }

  void _startTimer() {
    if (!_hasTimer) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
        if (_remainingSeconds == 10) {
          final isSound = context.read<SettingsBloc>().state.isSoundEnabled;
          ChessSoundService.instance.playTenSeconds(isSound);
        }
      } else {
        _timer?.cancel();
        _onTimeOut();
      }
    });
  }

  void _onTimeOut() {
    final isSound = context.read<SettingsBloc>().state.isSoundEnabled;
    ChessSoundService.instance.playGameEnd(isSound);
    AppSnackBar.showError(
      context,
      'Time Out! Match ended.',
      iconAsset: 'assets/icons/1024x/unnamed_clock_black_1024x.png',
    );
    _isMatchActive = false;
    FirebaseService.clearMatchData();
    if (context.read<SettingsBloc>().state.isPhysicalMode) {
      FirebaseService.setGameEnded(true);
      BoardConnectionService.instance.sendAppAction('STOP_MATCH');
    }
    _checkGameEnd();
  }

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
        _boardState[toR][toC] = piece;
        _boardState[fromR][fromC] = null;

        if (piece.endsWith('K') && (fromC - toC).abs() == 2) {
          if (toC == 6) {
            _boardState[fromR][5] = _boardState[fromR][7];
            _boardState[fromR][7] = null;
          } else if (toC == 2) {
            _boardState[fromR][3] = _boardState[fromR][0];
            _boardState[fromR][0] = null;
          }
        }

        _lastMoveFromRow = fromR;
        _lastMoveFromCol = fromC;
        _lastMoveToRow = toR;
        _lastMoveToCol = toC;

        _selectedRow = null;
        _selectedCol = null;
        _legalDestinations.clear();
        _hintFromRow = null;
        _hintFromCol = null;
        _hintToRow = null;
        _hintToCol = null;
        _hintUsedThisTurn = false;
        _activeHintText = null;
        _isWhiteTurn = !_isWhiteTurn;
      });

      final fenAfter = _generateCurrentFen();

      // 1. ALWAYS record the move into _moveLog FIRST so the checkmate move is saved!
      _recordMoveForDeepAnalysis(
        moveUci: moveUci,
        moveSan: moveSan,
        fenBefore: fenBefore,
        fenAfter: fenAfter,
        isWhite: piece.startsWith('W'),
      );

      // 2. Perform live move evaluation if not in deep analyzer mode
      if (!_isDeepAnalyzerMode) {
        _evaluateAndRecordMove(
          moveUci,
          moveSan,
          fenBefore,
          fenAfter,
          isWhite: piece.startsWith('W'),
        );
      }

      if (_hasTimer && _resolvedIncrementSeconds > 0) {
        setState(() {
          _remainingSeconds += _resolvedIncrementSeconds;
        });
      }

      // 3. Check for checkmate / game end SECOND (now _moveLog contains the move!)
      _checkGameEnd();
    }, boardId: boardId);
  }

  Future<void> _startMatchDirectly(SettingsState settingsState) async {
    if (_isMatchActive) return;

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

    // 5. Activate match state & start game
    _matchId = 'match_${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _isMatchActive = true;
      _isReviewingGame = false;
      _hasRunDeepAnalysis = false;
      _evalBarValue = 0.5;
      _accuracy = 0;
      _moveLog.clear();
      _hintUsedThisTurn = false;
      _activeHintText = null;
      _resetBoardState();
    });
    if (settingsState.isPhysicalMode) {
      FirebaseService.resetMatch();
      BoardConnectionService.instance.updateLiveSessionState(
        isWhite: _isPlayerWhite,
        timer: _resolvedTimerMinutes * 60,
        incTime: _resolvedIncrementSeconds,
        difficulty: widget.stockfishLevel,
        elo: widget.eloRating,
        playStyle: 'Balanced',
      );
      BoardConnectionService.instance.sendAppAction('START_MATCH', {
        'is_white': _isPlayerWhite,
        'timer': _resolvedTimerMinutes * 60,
        'inc_time': _resolvedIncrementSeconds,
        'difficulty': widget.stockfishLevel,
        'elo': widget.eloRating,
        'play_style': 'Balanced',
      });
    }
    _startTimer();
    if (settingsState.isPhysicalMode) {
      _listenToRemotePhysicalBoardMoves();
    }
    
    if (settingsState.isPhysicalMode) {
      _boardOnlineSub = BoardConnectionService.instance.boardOnlineStream.listen((isOnline) {
        if (!isOnline && mounted && _isMatchActive) {
          final isAr = context.read<SettingsBloc>().state.isArabic;
          BoardConnectionService.instance.showMidGameOfflineDialog(context, isAr: isAr);
        }
      });
    }

    _startedAt = DateTime.now();

    final opponentName = widget.matchType == 'quick_match'
        ? 'Stockfish Lvl ${widget.stockfishLevel}'
        : '${widget.islandTitle} - Round ${widget.roundIndex}';

    final newMatchRecord = MatchRecordModel(
      id: _matchId,
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'guest_user',
      islandId: widget.matchType == 'training' ? '${widget.islandIndex}' : null,
      matchType: widget.matchType,
      analyzerMode: _isDeepAnalyzerMode ? 'none' : 'live_game_analysis',
      deepAnalyzed: false,
      playerColor: _isPlayerWhite ? 'white' : 'black',
      opponentName: opponentName,
      roundIndex: widget.roundIndex,
      islandTitle: widget.islandTitle,
      stockfishLevel: widget.stockfishLevel,
      status: 'in_progress',
      result: 'ongoing',
      accuracy: 0,
      moveCount: 0,
      pgn: '',
      fen: _generateCurrentFen(),
      moveLog: [],
      pieceTheme: TrainingThemeHelper.getTrainingPieceTheme(widget.islandIndex, widget.roundIndex),
      startedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    MatchHistoryService.instance.createMatchRecord(newMatchRecord);

    if (!_isPlayerWhite && !settingsState.isPhysicalMode) {
      setState(() => _isEngineThinking = true);
      _executeStockfishAiMove().then((_) {
        if (mounted) setState(() => _isEngineThinking = false);
      });
    }
  }





  Future<void> _useHint(SettingsState settingsState) async {
    if (!_hintsAllowed) {
      AppSnackBar.showWarning(
        context,
        settingsState.translate('no_hints_allowed'),
        iconAsset: 'assets/icons/1024x/inaccuracy_1024x.png',
      );
      return;
    }

    if (_hintsRemaining <= 0) {
      AppSnackBar.showError(
        context,
        'No hints remaining!',
        iconAsset: 'assets/icons/1024x/incorrect_1024x.png',
      );
      return;
    }

    if (_hintUsedThisTurn) {
      AppSnackBar.showWarning(
        context,
        'Hint already used for this turn! Make your move first.',
        iconAsset: 'assets/icons/1024x/inaccuracy_1024x.png',
      );
      return;
    }

    if (_isWhiteTurn != _isPlayerWhite) {
    }

    setState(() {
      _isEngineThinking = true;
    });

    final fen = _generateCurrentFen();
    final eval = await StockfishEngineService.instance.evaluatePosition(
      [],
      fen: fen,
      depth: 12,
    );
    final String bestMoveUci = eval['best_move'] as String? ?? '';

    if (bestMoveUci.isEmpty || bestMoveUci.length < 4) {
      if (mounted) {
        setState(() => _isEngineThinking = false);
      }
      return;
    }

    const files = 'abcdefgh';
    const ranks = '87654321';

    final fromC = files.indexOf(bestMoveUci[0]);
    final fromR = ranks.indexOf(bestMoveUci[1]);
    final toC = files.indexOf(bestMoveUci[2]);
    final toR = ranks.indexOf(bestMoveUci[3]);

    if (fromC == -1 || fromR == -1 || toC == -1 || toR == -1) {
      if (mounted) setState(() => _isEngineThinking = false);
      return;
    }

    final fromSquare = '${files[fromC]}${ranks[fromR]}';
    final toSquare = '${files[toC]}${ranks[toR]}';

    if (mounted) {
      setState(() {
        _isEngineThinking = false;
        _hintsRemaining--;
        _hintUsedThisTurn = true;
        _hintFromRow = fromR;
        _hintFromCol = fromC;
        _hintToRow = toR;
        _hintToCol = toC;

        _activeHintText = settingsState.isArabic
            ? 'تلميح: انقل من $fromSquare إلى $toSquare ($_hintsRemaining تلميحات متبقية)'
            : 'Hint: Move from $fromSquare to $toSquare ($_hintsRemaining hints left)';
      });

      AppSnackBar.showInfo(
        context,
        _activeHintText!,
        iconAsset: 'assets/icons/1024x/best_1024x.png',
        duration: const Duration(seconds: 5),
      );
    }
  }

  void _onSurrenderButtonPressed(SettingsState settingsState) {
    _showExitOrSurrenderDialog(settingsState);
  }

  Future<void> _showExitOrSurrenderDialog(SettingsState settingsState) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Image.asset(
                  'assets/icons/1024x/resign_white_1024x.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  settingsState.translate('exit_match_dialog_title'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
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
    _isMatchActive = false;
    _timer?.cancel();
    _playbackTimer?.cancel();
    FirebaseService.clearMatchData();
    if (context.read<SettingsBloc>().state.isPhysicalMode) {
      FirebaseService.setGameEnded(true);
      BoardConnectionService.instance.sendAppAction('STOP_MATCH');
    }

    final isSound = context.read<SettingsBloc>().state.isSoundEnabled;
    ChessSoundService.instance.playGameEnd(isSound);

    final pgn = DeepGameAnalyzerService.formatFullGamePgn(_moveLog);
    final opponentName = widget.matchType == 'quick_match'
        ? 'Stockfish Lvl ${widget.stockfishLevel}'
        : '${widget.islandTitle} - Round ${widget.roundIndex}';

    MatchHistoryService.instance.completeMatchRecord(
      matchId: _matchId,
      matchType: widget.matchType,
      playerColor: _isPlayerWhite ? 'white' : 'black',
      opponentName: opponentName,
      stockfishLevel: widget.stockfishLevel,
      roundIndex: widget.roundIndex,
      islandTitle: widget.islandTitle,
      islandId: widget.matchType == 'training' ? '${widget.islandIndex}' : null,
      pieceTheme: TrainingThemeHelper.getTrainingPieceTheme(widget.islandIndex, widget.roundIndex),
      startedAt: _startedAt,
      status: 'completed',
      result: 'defeat',
      resultReason: 'surrendered',
      accuracy: _accuracy,
      isLiveAnalyzed: !_isDeepAnalyzerMode,
      pgn: pgn,
      finalMoveLog: _moveLog,
    );

    TrainingCampaignService.instance.recordPlayedRoundGame(
      islandIndex: widget.islandIndex,
      roundIndex: widget.roundIndex,
      matchId: _matchId,
      isWin: false,
    );

    // 1. Immediately activate match review controls on the board
    _startMatchReview();

    // 2. Show surrender dialog with button to open Full Match Review Page
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, settingsState) {
          final isAr = settingsState.isArabic;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.only(left: 24, top: 16, right: 8),
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
                  ? 'لقد استسلمت في المباراة. تم حفظ كافة النقلات، يمكنك مراجعة النقلات الآن!'
                  : 'You surrendered the match. All moves are saved. You can now review your moves!',
            ),
          );
        },
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _onSquareTapped(int row, int col, SettingsState settingsState) {
    if (_isReviewingGame) return;

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

    if (_isEngineThinking) return;

    if (!_isMatchActive) {
      AppSnackBar.showWarning(
        context,
        settingsState.isArabic
            ? 'اضغط على "بدء الجولة" للبدء باللعب!'
            : 'Click "Start Round" to begin playing!',
        iconAsset: 'assets/icons/1024x/inaccuracy_1024x.png',
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
      _isMatchActive = false;
      _timer?.cancel();
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
          : (_remainingSeconds <= 0 ? 'timeout' : 'surrendered');
      final resultStr = !hasLegalMoves
          ? (!inCheck ? 'draw' : (isVictory ? 'victory' : 'defeat'))
          : 'defeat';

      final opponentName = widget.matchType == 'quick_match'
          ? 'Stockfish Lvl ${widget.stockfishLevel}'
          : '${widget.islandTitle} - Round ${widget.roundIndex}';

      MatchHistoryService.instance.completeMatchRecord(
        matchId: _matchId,
        matchType: widget.matchType,
        playerColor: _isPlayerWhite ? 'white' : 'black',
        opponentName: opponentName,
        stockfishLevel: widget.stockfishLevel,
        roundIndex: widget.roundIndex,
        islandTitle: widget.islandTitle,
        islandId: widget.matchType == 'training' ? '${widget.islandIndex}' : null,
        pieceTheme: TrainingThemeHelper.getTrainingPieceTheme(widget.islandIndex, widget.roundIndex),
        startedAt: _startedAt,
        status: 'completed',
        result: resultStr,
        resultReason: reason,
        accuracy: _accuracy,
        isDeepAnalyzed: false,
        isLiveAnalyzed: !_isDeepAnalyzerMode,
        pgn: pgn,
        finalMoveLog: _moveLog,
      );

      TrainingCampaignService.instance.recordPlayedRoundGame(
        islandIndex: widget.islandIndex,
        roundIndex: widget.roundIndex,
        matchId: _matchId,
        isWin: isVictory,
      );

      // 1. Immediately activate match review controls on the board
      _startMatchReview();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settingsState) {
            final isAr = settingsState.isArabic;
            final translatedTitle = inCheck
                ? (_isWhiteTurn == _isPlayerWhite
                    ? (isAr ? 'خسارة! ❌' : 'You Lose!')
                    : (isAr ? 'فوز! 🏆' : 'You Win!'))
                : (isAr ? 'تعادل (مأزق)! 🤝' : 'Stalemate!');
            final translatedDesc = inCheck
                ? (_isWhiteTurn == _isPlayerWhite
                    ? (isAr ? 'تمت هزيمتك بكش مات.' : 'You have been checkmated.')
                    : (isAr ? 'لقد حققت كش مات وفزت بالمباراة!' : 'You delivered checkmate!'))
                : (isAr ? 'انتهت المباراة بالتعادل.' : 'The game is a draw.');

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.only(left: 24, top: 16, right: 8),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      translatedTitle,
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
              content: Text(translatedDesc, style: const TextStyle(fontSize: 14)),
            );
          },
        ),
      );
    }
  }

  Future<void> _runDeepGameAnalysis(SettingsState settingsState) async {
    if (_moveLog.isEmpty) return;

    final dummyRecord = MatchRecordModel(
      id: _matchId,
      userId: FirebaseAuth.instance.currentUser?.uid ?? 'guest_user',
      matchType: widget.matchType,
      analyzerMode: 'deep_game_analysis',
      playerColor: _isPlayerWhite ? 'white' : 'black',
      opponentName: widget.matchType == 'quick_match'
          ? 'Stockfish Lvl ${widget.stockfishLevel}'
          : '${widget.islandTitle} - Round ${widget.roundIndex}',
      roundIndex: widget.roundIndex,
      islandTitle: widget.islandTitle,
      stockfishLevel: widget.stockfishLevel,
      status: 'completed',
      result: 'completed',
      accuracy: _accuracy,
      moveCount: _moveLog.length,
      pgn: '',
      fen: _generateCurrentFen(),
      moveLog: _moveLog,
      pieceTheme: TrainingThemeHelper.getTrainingPieceTheme(widget.islandIndex, widget.roundIndex),
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

  void _updateBoardStateForReviewIndex(int index) {
    if (index <= 0) {
      setState(() {
        _reviewMoveIndex = 0;
        _resetBoardState();
        _reviewClassificationIcon = null;
        _reviewClassificationRow = null;
        _reviewClassificationCol = null;
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

  void _togglePlaybackTimer() {
    if (_isPlayingBack) {
      _stopPlayback();
    } else {
      if (_moveLog.isEmpty) return;
      if (_reviewMoveIndex >= _moveLog.length) {
        _updateBoardStateForReviewIndex(0);
      }
      setState(() {
        _isPlayingBack = true;
      });
      _playbackTimer?.cancel();
      _playbackTimer = Timer.periodic(const Duration(seconds: 2), (t) {
        if (_reviewMoveIndex < _moveLog.length) {
          _updateBoardStateForReviewIndex(_reviewMoveIndex + 1);
        } else {
          _stopPlayback();
        }
      });
    }
  }

  void _stopPlayback() {
    _playbackTimer?.cancel();
    if (mounted) {
      setState(() {
        _isPlayingBack = false;
      });
    }
  }

  Future<void> _executeLocalMove(
    int fromR,
    int fromC,
    int toR,
    int toC,
    SettingsState settingsState,
  ) async {
    final piece = _boardState[fromR][fromC];
    if (piece == null) return;

    String promoChar = '';
    if (piece.endsWith('P') && (toR == 0 || toR == 7)) {
      final choice = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            settingsState.translate('pawn_promotion_title'),
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
                        AppImageHelper.getPieceAssetPath(
                          TrainingThemeHelper.getTrainingPieceTheme(widget.islandIndex, widget.roundIndex),
                          '${piece.startsWith('W') ? 'W' : 'B'}$type',
                        ),
                        width: 36,
                        height: 36,
                        fit: BoxFit.contain,
                        errorBuilder: (ctx, err, stack) => Text(
                          type,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      );
      if (choice != null) promoChar = choice;
    }

    const files = 'abcdefgh';
    const ranks = '87654321';
    final moveUci =
        '${files[fromC]}${ranks[fromR]}${files[toC]}${ranks[toR]}${promoChar.toLowerCase()}';
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

    final fenBefore = _generateCurrentFen();

    setState(() {
      _boardState[toR][toC] = promoChar.isNotEmpty
          ? '${piece[0]}$promoChar'
          : piece;
      _boardState[fromR][fromC] = null;

      if (piece.endsWith('K') && (fromC - toC).abs() == 2) {
        if (toC == 6) {
          _boardState[fromR][5] = _boardState[fromR][7];
          _boardState[fromR][7] = null;
        } else if (toC == 2) {
          _boardState[fromR][3] = _boardState[fromR][0];
          _boardState[fromR][0] = null;
        }
      }

      _lastMoveFromRow = fromR;
      _lastMoveFromCol = fromC;
      _lastMoveToRow = toR;
      _lastMoveToCol = toC;

      _selectedRow = null;
      _selectedCol = null;
      _legalDestinations.clear();
      _hintFromRow = null;
      _hintFromCol = null;
      _hintToRow = null;
      _hintToCol = null;
      _isWhiteTurn = !_isWhiteTurn;
    });

    final fenAfter = _generateCurrentFen();

    // 1. ALWAYS record the move into _moveLog FIRST so the checkmate move is saved!
    _recordMoveForDeepAnalysis(
      moveUci: moveUci,
      moveSan: moveSan,
      fenBefore: fenBefore,
      fenAfter: fenAfter,
      isWhite: _isPlayerWhite,
    );
    if (mounted && context.read<SettingsBloc>().state.isPhysicalMode) {
      FirebaseService.pushMove(moveUci, fenAfter);
    }

    if (!_isDeepAnalyzerMode) {
      await _evaluateAndRecordMove(
        moveUci,
        moveSan,
        fenBefore,
        fenAfter,
        isWhite: _isPlayerWhite,
      );
    }

    if (_hasTimer && _resolvedIncrementSeconds > 0) {
      setState(() {
        _remainingSeconds += _resolvedIncrementSeconds;
      });
    }

    // 2. Check for checkmate / game end SECOND (now _moveLog contains the move!)
    _checkGameEnd();

    // 3. Trigger AI move AFTER Live Game Analysis has finished analyzing (Only in Digital mode)
    if (mounted && _isMatchActive && !settingsState.isPhysicalMode) {
      setState(() {
        _isEngineThinking = true;
      });
      try {
        await _executeStockfishAiMove();
      } finally {
        if (mounted) setState(() => _isEngineThinking = false);
      }
    }
  }

  int _calculateStockfishThinkingDelaySeconds() {
    if (!_isDeepAnalyzerMode) {
      // In Live Game Analysis mode: random delay between 1 to 3 seconds only
      return 1 + Random().nextInt(3);
    }
    final rand = Random().nextInt(100);
    if (rand < 20) {
      return 1 + Random().nextInt(2);
    } else {
      return 3 + Random().nextInt(3);
    }
  }

  Future<void> _executeStockfishAiMove() async {
    if (!_isMatchActive || !mounted) return;

    final fenBefore = _generateCurrentFen();
    final random = Random();

    final int level = widget.stockfishLevel.clamp(0, 10);

    late final int targetElo;
    late final int aiDepth;
    int? aiMoveTimeMs;

    switch (level) {
      case 0:
        targetElo = 800;
        aiDepth = 1;
        if (random.nextDouble() < 0.35) {
          await Future.delayed(Duration(milliseconds: 800 + Random().nextInt(800)));
          _executeRandomAiMove();
          return;
        }
        break;
      case 1:
        targetElo = 1000;
        aiDepth = 1;
        if (random.nextDouble() < 0.20) {
          await Future.delayed(Duration(milliseconds: 800 + Random().nextInt(800)));
          _executeRandomAiMove();
          return;
        }
        break;
      case 2:
        targetElo = 1200;
        aiDepth = 2;
        if (random.nextDouble() < 0.10) {
          await Future.delayed(Duration(milliseconds: 800 + Random().nextInt(800)));
          _executeRandomAiMove();
          return;
        }
        break;
      case 3:
        targetElo = 1400;
        aiDepth = 3;
        break;
      case 4:
        targetElo = 1600;
        aiDepth = 4;
        break;
      case 5:
        targetElo = 1800;
        aiDepth = 5;
        break;
      case 6:
        targetElo = 2000;
        aiDepth = 6;
        aiMoveTimeMs = 150;
        break;
      case 7:
        targetElo = 2200;
        aiDepth = 8;
        aiMoveTimeMs = 200;
        break;
      case 8:
        targetElo = 2400;
        aiDepth = 10;
        aiMoveTimeMs = 250;
        break;
      case 9:
        targetElo = 2600;
        aiDepth = 12;
        aiMoveTimeMs = 300;
        break;
      case 10:
      default:
        targetElo = 2800;
        aiDepth = 12;
        aiMoveTimeMs = 400;
        break;
    }

    final eval = await StockfishEngineService.instance.evaluatePosition(
      [],
      fen: fenBefore,
      depth: aiDepth,
      moveTime: aiMoveTimeMs,
      elo: targetElo,
    );

    // Weighted random human-like thinking delay (3-6s usual, 1-2s or 7-10s rare)
    final delaySeconds = _calculateStockfishThinkingDelaySeconds();
    await Future.delayed(Duration(seconds: delaySeconds));

    if (!mounted || !_isMatchActive) return;

    final String bestMoveUci = eval['best_move'] as String? ?? '';

    if (bestMoveUci.length < 4 || bestMoveUci == '(none)') {
      _executeRandomAiMove();
      return;
    }

    const files = 'abcdefgh';
    const ranks = '87654321';

    final fromC = files.indexOf(bestMoveUci[0]);
    final fromR = ranks.indexOf(bestMoveUci[1]);
    final toC = files.indexOf(bestMoveUci[2]);
    final toR = ranks.indexOf(bestMoveUci[3]);

    if (fromC == -1 || fromR == -1 || toC == -1 || toR == -1) {
      _executeRandomAiMove();
      return;
    }

    final piece = _boardState[fromR][fromC];
    if (piece == null) {
      _executeRandomAiMove();
      return;
    }

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

    final moveSan = ChessLogic.toSan(_boardState, bestMoveUci);

    setState(() {
      if (piece.endsWith('P') &&
          fromC != toC &&
          _boardState[toR][toC] == null) {
        final captureRow = piece.startsWith('W') ? toR + 1 : toR - 1;
        if (captureRow >= 0 && captureRow < 8) {
          _boardState[captureRow][toC] = null;
        }
      }

      _boardState[toR][toC] = piece;
      _boardState[fromR][fromC] = null;

      if (piece.endsWith('K') && (fromC - toC).abs() == 2) {
        if (toC == 6) {
          _boardState[fromR][5] = _boardState[fromR][7];
          _boardState[fromR][7] = null;
        } else if (toC == 2) {
          _boardState[fromR][3] = _boardState[fromR][0];
          _boardState[fromR][0] = null;
        }
      }

      if (bestMoveUci.length == 5) {
        final promo = bestMoveUci[4].toUpperCase();
        final color = piece.startsWith('W') ? 'W' : 'B';
        _boardState[toR][toC] = '$color$promo';
      }

      _lastMoveFromRow = fromR;
      _lastMoveFromCol = fromC;
      _lastMoveToRow = toR;
      _lastMoveToCol = toC;

      _isWhiteTurn = !_isWhiteTurn;
      _hintUsedThisTurn = false;
    });

    final fenAfter = _generateCurrentFen();

    _recordMoveForDeepAnalysis(
      moveUci: bestMoveUci,
      moveSan: moveSan,
      fenBefore: fenBefore,
      fenAfter: fenAfter,
      isWhite: !_isPlayerWhite,
    );
    if (mounted && context.read<SettingsBloc>().state.isPhysicalMode) {
      FirebaseService.pushMove(bestMoveUci, fenAfter);
    }

    if (!_isDeepAnalyzerMode) {
      await _evaluateAndRecordMove(
        bestMoveUci,
        moveSan,
        fenBefore,
        fenAfter,
        isWhite: !_isPlayerWhite,
      );
    }

    _checkGameEnd();
  }

  Future<void> _executeRandomAiMove() async {
    if (!_isMatchActive || !mounted) return;

    final aiIsWhite = !_isPlayerWhite;
    final aiPrefix = aiIsWhite ? 'W' : 'B';
    final aiMoves = <Map<String, dynamic>>[];
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final piece = _boardState[r][c];
        if (piece != null && piece.startsWith(aiPrefix)) {
          final dests = ChessLogic.getLegalMovesForColor(
            _boardState,
            r,
            c,
            isWhite: aiIsWhite,
          );
          for (final d in dests) {
            aiMoves.add({
              'from': [r, c],
              'to': d,
              'piece': piece,
            });
          }
        }
      }
    }

    if (aiMoves.isNotEmpty) {
      final aiMove = (aiMoves..shuffle()).first;
      final fromR = aiMove['from'][0] as int;
      final fromC = aiMove['from'][1] as int;
      final toR = aiMove['to'][0] as int;
      final toC = aiMove['to'][1] as int;
      final piece = aiMove['piece'] as String;

      const files = 'abcdefgh';
      const ranks = '87654321';
      final moveUci =
          '${files[fromC]}${ranks[fromR]}${files[toC]}${ranks[toR]}';

      final fenBefore = _generateCurrentFen();
      final moveSan = ChessLogic.toSan(_boardState, moveUci);

      setState(() {
        _boardState[toR][toC] = piece;
        _boardState[fromR][fromC] = null;

        if (piece.endsWith('K') && (fromC - toC).abs() == 2) {
          if (toC == 6) {
            _boardState[fromR][5] = _boardState[fromR][7];
            _boardState[fromR][7] = null;
          } else if (toC == 2) {
            _boardState[fromR][3] = _boardState[fromR][0];
            _boardState[fromR][0] = null;
          }
        }

        _lastMoveFromRow = fromR;
        _lastMoveFromCol = fromC;
        _lastMoveToRow = toR;
        _lastMoveToCol = toC;

        _isWhiteTurn = !_isWhiteTurn;
        _hintUsedThisTurn = false;
      });

      final fenAfter = _generateCurrentFen();

      _recordMoveForDeepAnalysis(
        moveUci: moveUci,
        moveSan: moveSan,
        fenBefore: fenBefore,
        fenAfter: fenAfter,
        isWhite: !_isPlayerWhite,
      );
      if (mounted && context.read<SettingsBloc>().state.isPhysicalMode) {
        FirebaseService.pushMove(moveUci, fenAfter);
      }

      if (!_isDeepAnalyzerMode) {
        await _evaluateAndRecordMove(
          moveUci,
          moveSan,
          fenBefore,
          fenAfter,
          isWhite: !_isPlayerWhite,
        );
      }

      _checkGameEnd();
    }
  }

  void _recordMoveForDeepAnalysis({
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
      'isAnalyzing': true,
    };
    _moveLog.add(rawEntry);

    final pgn = DeepGameAnalyzerService.formatFullGamePgn(_moveLog);
    final opponentName = widget.matchType == 'quick_match'
        ? 'Stockfish Lvl ${widget.stockfishLevel}'
        : '${widget.islandTitle} - Round ${widget.roundIndex}';

    MatchHistoryService.instance.updateLiveMatchData(
      matchId: _matchId,
      matchType: widget.matchType,
      playerColor: _isPlayerWhite ? 'white' : 'black',
      opponentName: opponentName,
      stockfishLevel: widget.stockfishLevel,
      roundIndex: widget.roundIndex,
      islandTitle: widget.islandTitle,
      islandId: widget.matchType == 'training' ? '${widget.islandIndex}' : null,
      pieceTheme: TrainingThemeHelper.getTrainingPieceTheme(widget.islandIndex, widget.roundIndex),
      startedAt: _startedAt,
      moveLog: _moveLog,
      accuracy: 0,
      pgn: pgn,
      fen: fenAfter,
    );
  }

  Future<void> _evaluateAndRecordMove(
    String moveUci,
    String moveSan,
    String fenBefore,
    String fenAfter, {
    required bool isWhite,
  }) async {
    final result = await GameAnalyzerLogic.evaluateAndAnalyzeMove(
      moveUci: moveUci,
      moveSan: moveSan,
      fenBefore: fenBefore,
      fenAfter: fenAfter,
      isWhite: isWhite,
      currentMoveLog: _moveLog,
      isPlayerWhite: _isPlayerWhite,
    );

    if (mounted) {
      setState(() {
        _evalBarValue = result.evalBarValue;
        final moveEntry = Map<String, dynamic>.from(result.moveEntry);
        moveEntry['fenBefore'] = fenBefore;
        moveEntry['fenAfter'] = fenAfter;
        moveEntry['isWhite'] = isWhite;
        moveEntry['isAnalyzing'] = false;

        final existingIndex = _moveLog.indexWhere((m) =>
            m['uci'] == moveUci && (m['fenAfter'] == fenAfter || m['fenBefore'] == fenBefore));
        if (existingIndex != -1) {
          _moveLog[existingIndex] = moveEntry;
        } else {
          _moveLog.add(moveEntry);
        }
        _accuracy = result.overallAccuracy;
      });

      final pgn = DeepGameAnalyzerService.formatFullGamePgn(_moveLog);
      final opponentName = widget.matchType == 'quick_match'
          ? 'Stockfish Lvl ${widget.stockfishLevel}'
          : '${widget.islandTitle} - Round ${widget.roundIndex}';

      MatchHistoryService.instance.updateLiveMatchData(
        matchId: _matchId,
        matchType: widget.matchType,
        playerColor: _isPlayerWhite ? 'white' : 'black',
        opponentName: opponentName,
        stockfishLevel: widget.stockfishLevel,
        roundIndex: widget.roundIndex,
        islandTitle: widget.islandTitle,
        islandId: widget.matchType == 'training' ? '${widget.islandIndex}' : null,
        pieceTheme: TrainingThemeHelper.getTrainingPieceTheme(widget.islandIndex, widget.roundIndex),
        startedAt: _startedAt,
        moveLog: _moveLog,
        accuracy: _accuracy,
        pgn: pgn,
        fen: fenAfter,
      );
    }
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
          final char = (p.length >= 2) ? p[1] : 'P';
          rowFen += p.startsWith('W') ? char.toUpperCase() : char.toLowerCase();
        }
      }
      if (emptyCount > 0) rowFen += emptyCount.toString();
      rows.add(rowFen);
    }

    final castlingRights = _computeValidCastlingRights();
    return '${rows.join('/')} ${_isWhiteTurn ? 'w' : 'b'} $castlingRights - 0 1';
  }

  String _computeValidCastlingRights() {
    final buffer = StringBuffer();
    // White Kingside castling 'K': King at (7, 4) ['WK'] and Rook at (7, 7) ['WR']
    if (_boardState[7][4] == 'WK' && _boardState[7][7] == 'WR') {
      buffer.write('K');
    }
    // White Queenside castling 'Q': King at (7, 4) ['WK'] and Rook at (7, 0) ['WR']
    if (_boardState[7][4] == 'WK' && _boardState[7][0] == 'WR') {
      buffer.write('Q');
    }
    // Black Kingside castling 'k': King at (0, 4) ['BK'] and Rook at (0, 7) ['BR']
    if (_boardState[0][4] == 'BK' && _boardState[0][7] == 'BR') {
      buffer.write('k');
    }
    // Black Queenside castling 'q': King at (0, 4) ['BK'] and Rook at (0, 0) ['BR']
    if (_boardState[0][4] == 'BK' && _boardState[0][0] == 'BR') {
      buffer.write('q');
    }
    return buffer.isEmpty ? '-' : buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      builder: (context, settingsState) {
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
                title: Text(
                  '${widget.islandTitle} - ${settingsState.translate('round_label')} ${widget.roundIndex}/5',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    if (!_isMatchActive) {
                      Navigator.pop(context);
                    } else {
                      await _showExitOrSurrenderDialog(settingsState);
                    }
                  },
                ),
                actions: [
                  if (_isMatchActive)
                    IconButton(
                      icon: const Icon(Icons.flag_rounded, color: AppColors.error),
                      tooltip: settingsState.isArabic ? 'استسلام' : 'Surrender',
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
                      text: settingsState.isArabic
                          ? 'رقعة اللعب'
                          : 'Game Board',
                    ),
                    Tab(
                      icon: Icon(_isDeepAnalyzerMode
                          ? Icons.psychology_rounded
                          : Icons.analytics_rounded),
                      text: _isDeepAnalyzerMode
                          ? (settingsState.isArabic ? 'محلل المباراة' : 'Deep Analyzer')
                          : (settingsState.isArabic ? 'المحلل المباشر' : 'Live Analyzer'),
                    ),
                    Tab(
                      icon: const Icon(Icons.description_rounded),
                      text: settingsState.isArabic
                          ? 'تدوين PGN'
                          : 'Game PGN',
                    ),
                  ],
                ),
              ),
              body: SafeArea(
                child: TabBarView(
                  children: [
                    // --- TAB 1: GAME BOARD TAB ---
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMatchHeaderCard(settingsState),
                          const SizedBox(height: 10),
                          _buildTimerAndTurnBar(settingsState),
                          const SizedBox(height: 10),
                          TrainingBoardWidget(
                            boardState: _boardState,
                            settingsState: settingsState,
                            overridePieceTheme: TrainingThemeHelper.getTrainingPieceTheme(widget.islandIndex, widget.roundIndex),
                            isBoardFlipped: !_isPlayerWhite,
                            selectedRow: _selectedRow,
                            selectedCol: _selectedCol,
                            legalDestinations: _legalDestinations,
                            lastMoveFromRow: _lastMoveFromRow,
                            lastMoveFromCol: _lastMoveFromCol,
                            lastMoveToRow: _lastMoveToRow,
                            lastMoveToCol: _lastMoveToCol,
                            hintFromRow: _hintFromRow,
                            hintFromCol: _hintFromCol,
                            hintToRow: _hintToRow,
                            hintToCol: _hintToCol,
                            classificationIconPath: _reviewClassificationIcon,
                            classificationRow: _reviewClassificationRow,
                            classificationCol: _reviewClassificationCol,
                            isKingInCheck: (isWhite) =>
                                ChessLogic.isKingInCheck(_boardState, isWhite),
                            onSquareTapped: (row, col) =>
                                _onSquareTapped(row, col, settingsState),
                          ),
                          if (_hintsAllowed && _isMatchActive) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: _buildCircularHintButton(settingsState),
                            ),
                          ],
                          if (!_isDeepAnalyzerMode && _isMatchActive) ...[
                            const SizedBox(height: 10),
                            _buildLiveMoveAnalysisPanel(settingsState),
                          ],
                          const SizedBox(height: 14),
                          if (_isReviewingGame || (!_isMatchActive && _moveLog.isNotEmpty))
                            _buildPlaybackControlBar(settingsState)
                          else if (!_isMatchActive)
                            _buildStartMatchButton(settingsState),
                        ],
                      ),
                    ),

                    // --- TAB 2: GAME ANALYZER TAB ---
                    SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildMatchHeaderCard(settingsState),
                          const SizedBox(height: 14),
                          if (_isDeepAnalyzerMode && !_hasRunDeepAnalysis)
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppColors.primaryGold, width: 1.5),
                              ),
                              child: Column(
                                children: [
                                  const Icon(Icons.psychology_rounded, size: 52, color: AppColors.primaryGold),
                                  const SizedBox(height: 12),
                                  Text(
                                    _isMatchActive
                                        ? (settingsState.isArabic
                                            ? 'التحليل العميق متاح بعد انتهاء المباراة 🧠'
                                            : 'Deep Analysis Available After Match 🧠')
                                        : (settingsState.isArabic
                                            ? 'جاهز للتحليل العميق!'
                                            : 'Ready for Deep Analysis!'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _isMatchActive
                                        ? (settingsState.isArabic
                                            ? 'المباراة جارية حالياً بأقصى سرعة بدون تأخير. يمكنك إجراء تحليل عميق بعمق 20 فور انتهاء المباراة.'
                                            : 'Match is running at maximum speed. You can perform full Depth-20 analysis after the match ends.')
                                        : (settingsState.isArabic
                                            ? 'انقر للبدء بتحليل مباراتك كاملة بعمق 20 مع محرك Stockfish'
                                            : 'Click below to perform deep Depth-20 Stockfish analysis on your full game.'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 12, height: 1.4),
                                  ),
                                  if (!_isMatchActive && _moveLog.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    Builder(
                                      builder: (context) {
                                        final isAnalyzing = GlobalAnalysisService.instance.isAnalyzing;
                                        return ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isAnalyzing ? Colors.grey.shade400 : AppColors.primaryGold,
                                            foregroundColor: isAnalyzing ? Colors.grey.shade700 : Colors.black,
                                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          icon: isAnalyzing
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                                )
                                              : const Icon(Icons.analytics_rounded),
                                          label: Text(
                                            isAnalyzing
                                                ? (settingsState.isArabic ? 'التحليل جارٍ... ⏳' : 'Analysis in Progress... ⏳')
                                                : (settingsState.isArabic ? 'بدء التحليل العميق 🧠' : 'Start Deep Analysis 🧠'),
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          onPressed: isAnalyzing ? null : () => _runDeepGameAnalysis(settingsState),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            )
                          else ...[
                            _buildAnalyzerSummaryStats(settingsState),
                            const SizedBox(height: 16),
                            LiveGameAnalyzerWidget(
                              moveLog: _moveLog,
                              settingsState: settingsState,
                              evalBarValue: _evalBarValue,
                              overallAccuracy: _accuracy,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // --- TAB 3: GAME PGN TAB ---
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

  Widget _buildStartMatchButton(SettingsState settingsState) {
    final isAr = settingsState.isArabic;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.primaryGold, Color(0xFFFFB300)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGold.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.black,
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          icon: const Icon(Icons.play_arrow_rounded, size: 30),
          label: Text(
            isAr ? 'بدء الجولة ⚔️' : 'Start Round ⚔️',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          onPressed: () => _startMatchDirectly(settingsState),
        ),
      ),
    );
  }

  Widget _buildPlaybackControlBar(SettingsState settingsState) {
    final isDark = settingsState.isDarkMode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.primaryGold.withValues(alpha: 0.4)
              : AppColors.primaryMahogany.withValues(alpha: 0.3),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            settingsState.isArabic
                ? 'مراجعة النقلات: $_reviewMoveIndex / ${_moveLog.length}'
                : 'Review Move: $_reviewMoveIndex / ${_moveLog.length}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Rewind to start (⏮)
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 28),
                tooltip: settingsState.isArabic ? 'البداية' : 'Start',
                onPressed: () {
                  _stopPlayback();
                  _updateBoardStateForReviewIndex(0);
                },
              ),
              // Previous move (◀)
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 28),
                tooltip: settingsState.isArabic ? 'النقلة السابقة' : 'Previous Move',
                onPressed: () {
                  _stopPlayback();
                  _updateBoardStateForReviewIndex(_reviewMoveIndex - 1);
                },
              ),
              // Play / Pause (▶ / ⏸)
              InkWell(
                onTap: () {
                  _togglePlaybackTimer();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isPlayingBack ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.black,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isPlayingBack
                            ? (settingsState.isArabic ? 'إيقاف' : 'Pause')
                            : (settingsState.isArabic ? 'تشغيل (2ث)' : 'Play (2s)'),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Next move (▶)
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 28),
                tooltip: settingsState.isArabic ? 'النقلة التالية' : 'Next Move',
                onPressed: () {
                  _stopPlayback();
                  _updateBoardStateForReviewIndex(_reviewMoveIndex + 1);
                },
              ),
              // Fast-forward to end (⏭)
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 28),
                tooltip: settingsState.isArabic ? 'النهاية' : 'End',
                onPressed: () {
                  _stopPlayback();
                  _updateBoardStateForReviewIndex(_moveLog.length);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMatchHeaderCard(SettingsState settingsState) {
    final isDark = settingsState.isDarkMode;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.primaryGold.withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/icons/islands/island_${widget.islandIndex.clamp(1, 20)}.jpg',
              width: 38,
              height: 38,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.primaryGold,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.terrain_rounded, color: Colors.black54, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.islandTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${settingsState.translate('round_label')} ${widget.roundIndex}/5 • Stockfish Lvl ${widget.stockfishLevel}',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGold.withValues(alpha: 0.25),
                  AppColors.primaryGold.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.primaryGold, width: 1),
            ),
            child: Text(
              '${widget.eloRating} ELO',
              style: const TextStyle(
                color: AppColors.primaryGold,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerAndTurnBar(SettingsState settingsState) {
    final isDark = settingsState.isDarkMode;
    final isPlayerTurn = (_isWhiteTurn == _isPlayerWhite);
    final turnText = isPlayerTurn
        ? (settingsState.isArabic ? 'دورك للحركة' : 'Your Turn')
        : (settingsState.isArabic ? 'الخصم يفكر...' : 'Opponent Thinking...');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPlayerTurn
              ? AppColors.primaryGold.withValues(alpha: 0.5)
              : (isDark ? Colors.white12 : Colors.grey.shade300),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                Icons.circle,
                size: 14,
                color: _isWhiteTurn ? Colors.white : Colors.grey.shade900,
              ),
              const SizedBox(width: 8),
              Text(
                turnText,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isPlayerTurn ? AppColors.primaryGold : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
          if (_hasTimer)
            Row(
              children: [
                const Icon(Icons.timer_outlined, color: AppColors.primaryGold, size: 18),
                const SizedBox(width: 6),
                Text(
                  _formatTime(_remainingSeconds),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: _remainingSeconds <= 30 ? AppColors.error : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCircularHintButton(SettingsState settingsState) {
    final bool isHintEnabled = _isMatchActive &&
        _hintsRemaining > 0 &&
        !_hintUsedThisTurn &&
        (_isWhiteTurn == _isPlayerWhite);

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      elevation: isHintEnabled ? 6 : 0,
      shadowColor: AppColors.primaryGold.withValues(alpha: 0.4),
      child: InkWell(
        onTap: isHintEnabled ? () => _useHint(settingsState) : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isHintEnabled
                ? const LinearGradient(
                    colors: [AppColors.primaryGold, Color(0xFFFFB300)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isHintEnabled
                ? null
                : (settingsState.isDarkMode ? const Color(0xFF2A2A2E) : Colors.grey.shade400),
            border: Border.all(
              color: isHintEnabled ? Colors.white.withValues(alpha: 0.6) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.lightbulb_rounded,
                size: 26,
                color: isHintEnabled ? Colors.black : Colors.grey.shade600,
              ),
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isHintEnabled ? Colors.black : Colors.grey.shade700,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$_hintsRemaining',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isHintEnabled ? AppColors.primaryGold : Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveMoveAnalysisPanel(SettingsState settingsState) {
    final isDark = settingsState.isDarkMode;
    final isAr = settingsState.isArabic;

    // Retrieve last move pair details from _moveLog
    Map<String, dynamic>? whiteMove;
    Map<String, dynamic>? blackMove;
    int movePairNumber = 1;

    if (_moveLog.isNotEmpty) {
      final lastMove = _moveLog.last;
      final isLastMoveWhite = (lastMove['isWhite'] as bool?) ?? (lastMove['player'] == 'White');

      if (isLastMoveWhite) {
        whiteMove = lastMove;
        movePairNumber = ((_moveLog.length + 1) / 2).ceil();
        if (_moveLog.length >= 2) {
          final prevMove = _moveLog[_moveLog.length - 2];
          final isPrevWhite = (prevMove['isWhite'] as bool?) ?? (prevMove['player'] == 'White');
          if (!isPrevWhite) {
            blackMove = prevMove;
          }
        }
      } else {
        blackMove = lastMove;
        movePairNumber = (_moveLog.length / 2).ceil();
        if (_moveLog.length >= 2) {
          final prevMove = _moveLog[_moveLog.length - 2];
          final isPrevWhite = (prevMove['isWhite'] as bool?) ?? (prevMove['player'] == 'White');
          if (isPrevWhite) {
            whiteMove = prevMove;
          }
        }
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.primaryGold.withValues(alpha: 0.35)
              : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row with Title, Mini Advantage Bar & Move #
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset(
                    'assets/icons/1024x/critical_1024x.png',
                    width: 18,
                    height: 18,
                    errorBuilder: (ctx, err, stack) => const Icon(Icons.analytics_rounded, color: AppColors.primaryGold, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isAr ? 'تحليل النقلة الحالية' : 'Live Move Analysis',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildHeaderAdvantageBar(_evalBarValue, settingsState),
                  if (_moveLog.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isAr ? 'الجولة $movePairNumber' : 'Move #$movePairNumber',
                        style: const TextStyle(
                          color: AppColors.primaryGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Body: Move details or Ready status
          if (_moveLog.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF282830) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.sports_esports_rounded, color: Colors.grey.shade400, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAr ? 'التحليل المباشر جاهز' : 'Live Analysis Ready',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        Text(
                          isAr
                              ? 'قم بإجراء نقلتك لرؤية التقييم والتصنيف المباشر'
                              : 'Make your move to see real-time analysis & evaluation.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                // White Move Card
                Expanded(
                  child: _buildMoveAnalysisCard(
                    isWhite: true,
                    moveData: whiteMove,
                    settingsState: settingsState,
                  ),
                ),
                const SizedBox(width: 10),
                // Black Move Card
                Expanded(
                  child: _buildMoveAnalysisCard(
                    isWhite: false,
                    moveData: blackMove,
                    settingsState: settingsState,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Pure visual dual-colored horizontal advantage bar showing position evaluation ratio
  Widget _buildHeaderAdvantageBar(double evalBarValue, SettingsState settingsState) {
    final isDark = settingsState.isDarkMode;

    final clamped = evalBarValue.clamp(0.05, 0.95);
    final whiteFlex = (clamped * 100).round();
    final blackFlex = 100 - whiteFlex;

    return Container(
      width: 65,
      height: 14,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.grey.shade400,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Row(
          children: [
            Expanded(
              flex: whiteFlex,
              child: Container(
                color: const Color(0xFFECEFF1),
              ),
            ),
            Expanded(
              flex: blackFlex,
              child: Container(
                color: const Color(0xFF263238),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoveAnalysisCard({
    required bool isWhite,
    required Map<String, dynamic>? moveData,
    required SettingsState settingsState,
  }) {
    final isDark = settingsState.isDarkMode;
    final isAr = settingsState.isArabic;

    if (moveData == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF282830) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 12,
                  color: isWhite ? Colors.white : Colors.grey.shade900,
                ),
                const SizedBox(width: 6),
                Text(
                  isWhite ? (isAr ? 'الأبيض' : 'White') : (isAr ? 'الأسود' : 'Black'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isAr ? 'في الانتظار...' : 'Waiting...',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    final san = moveData['san'] as String? ?? (moveData['uci'] as String? ?? '');
    final isAnalyzing = (moveData['isAnalyzing'] as bool?) ?? false;

    // Show Skeleton Loader while Stockfish evaluates the move
    if (isAnalyzing) {
      return _buildSkeletonMoveAnalysisCard(
        isWhite: isWhite,
        san: san,
        settingsState: settingsState,
      );
    }

    final cls = moveData['classification'] as String? ?? 'good';
    final accuracy = moveData['accuracy'] as int?;

    String iconAsset = 'assets/icons/1024x/good_1024x.png';
    Color clsColor = AppColors.primaryGold;
    String clsLabel = cls.toUpperCase();

    switch (cls.toLowerCase()) {
      case 'brilliant':
        iconAsset = 'assets/icons/1024x/brilliant_1024x.png';
        clsColor = const Color(0xFF00E676);
        clsLabel = isAr ? 'رائعة' : 'Brilliant';
        break;
      case 'great':
        iconAsset = 'assets/icons/1024x/great_find_1024x.png';
        clsColor = const Color(0xFF00B0FF);
        clsLabel = isAr ? 'عظيمة' : 'Great';
        break;
      case 'best':
        iconAsset = 'assets/icons/1024x/best_1024x.png';
        clsColor = const Color(0xFF00E676);
        clsLabel = isAr ? 'الأفضل' : 'Best';
        break;
      case 'excellent':
        iconAsset = 'assets/icons/1024x/excellent_1024x.png';
        clsColor = const Color(0xFF76FF03);
        clsLabel = isAr ? 'ممتازة' : 'Excellent';
        break;
      case 'good':
      case 'okay':
        iconAsset = 'assets/icons/1024x/good_1024x.png';
        clsColor = const Color(0xFFB2FF59);
        clsLabel = isAr ? 'جيدة' : 'Good';
        break;
      case 'book':
        iconAsset = 'assets/icons/1024x/book_1024x.png';
        clsColor = const Color(0xFFA1887F);
        clsLabel = isAr ? 'افتتاحية' : 'Book';
        break;
      case 'inaccuracy':
        iconAsset = 'assets/icons/1024x/inaccuracy_1024x.png';
        clsColor = const Color(0xFFFFC400);
        clsLabel = isAr ? 'عدم دقة' : 'Inaccuracy';
        break;
      case 'mistake':
        iconAsset = 'assets/icons/1024x/mistake_1024x.png';
        clsColor = const Color(0xFFFF9100);
        clsLabel = isAr ? 'خطأ' : 'Mistake';
        break;
      case 'blunder':
        iconAsset = 'assets/icons/1024x/blunder_1024x.png';
        clsColor = const Color(0xFFFF1744);
        clsLabel = isAr ? 'خطأ فادح' : 'Blunder';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252530) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: clsColor.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.circle,
                size: 12,
                color: isWhite ? Colors.white : Colors.grey.shade900,
              ),
              const SizedBox(width: 6),
              Text(
                san,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: clsColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      iconAsset,
                      width: 14,
                      height: 14,
                      fit: BoxFit.contain,
                      errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      clsLabel,
                      style: TextStyle(
                        color: clsColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (accuracy != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$accuracy%',
                    style: TextStyle(
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Skeleton Loading Card displayed while Stockfish evaluates the played move
  Widget _buildSkeletonMoveAnalysisCard({
    required bool isWhite,
    required String san,
    required SettingsState settingsState,
  }) {
    final isDark = settingsState.isDarkMode;
    final isAr = settingsState.isArabic;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.35, end: 0.9),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOut,
      builder: (context, opacity, child) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF252530) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primaryGold.withValues(alpha: 0.35 * opacity),
              width: 1.2,
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
                      Icon(
                        Icons.circle,
                        size: 12,
                        color: isWhite ? Colors.white : Colors.grey.shade900,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        san,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.primaryGold.withValues(alpha: opacity),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Opacity(
                opacity: opacity,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.hourglass_empty_rounded,
                        size: 12,
                        color: AppColors.primaryGold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isAr ? 'جاري التحليل...' : 'Analyzing...',
                        style: const TextStyle(
                          color: AppColors.primaryGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAnalyzerSummaryStats(SettingsState settingsState) {
    int brilliantCount = 0;
    int greatCount = 0;
    int bestCount = 0;
    int excellentCount = 0;
    int goodCount = 0;
    int bookCount = 0;
    int inaccuracyCount = 0;
    int mistakeCount = 0;
    int blunderCount = 0;

    for (final m in _moveLog) {
      final moverIsWhite = (m['isWhite'] as bool?) ?? (m['player'] == 'White');
      if (moverIsWhite != _isPlayerWhite) continue;

      final cls = (m['classification'] as String? ?? '').toLowerCase();
      if (cls == 'brilliant') {
        brilliantCount++;
      } else if (cls == 'great') {
        greatCount++;
      } else if (cls == 'best') {
        bestCount++;
      } else if (cls == 'excellent') {
        excellentCount++;
      } else if (cls == 'good' || cls == 'okay') {
        goodCount++;
      } else if (cls == 'book') {
        bookCount++;
      } else if (cls == 'inaccuracy') {
        inaccuracyCount++;
      } else if (cls == 'mistake') {
        mistakeCount++;
      } else if (cls == 'blunder') {
        blunderCount++;
      }
    }

    final isDark = settingsState.isDarkMode;

    final categories = [
      {
        'title': settingsState.isArabic ? 'رائعة' : 'Brilliant',
        'count': brilliantCount,
        'icon': MoveClassification.brilliant.iconPath,
      },
      {
        'title': settingsState.isArabic ? 'عظيمة' : 'Great',
        'count': greatCount,
        'icon': MoveClassification.great.iconPath,
      },
      {
        'title': settingsState.isArabic ? 'الأفضل' : 'Best',
        'count': bestCount,
        'icon': MoveClassification.best.iconPath,
      },
      {
        'title': settingsState.isArabic ? 'ممتازة' : 'Excellent',
        'count': excellentCount,
        'icon': MoveClassification.excellent.iconPath,
      },
      {
        'title': settingsState.isArabic ? 'جيدة' : 'Okay',
        'count': goodCount,
        'icon': MoveClassification.good.iconPath,
      },
      {
        'title': settingsState.isArabic ? 'كتاب' : 'Book',
        'count': bookCount,
        'icon': MoveClassification.book.iconPath,
      },
      {
        'title': settingsState.isArabic ? 'غير دقيقة' : 'Inaccuracy',
        'count': inaccuracyCount,
        'icon': MoveClassification.inaccuracy.iconPath,
      },
      {
        'title': settingsState.isArabic ? 'خطأ' : 'Mistake',
        'count': mistakeCount,
        'icon': MoveClassification.mistake.iconPath,
      },
      {
        'title': settingsState.isArabic ? 'فادح' : 'Blunder',
        'count': blunderCount,
        'icon': MoveClassification.blunder.iconPath,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.primaryGold.withValues(alpha: 0.3)
              : AppColors.primaryMahogany.withValues(alpha: 0.2),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
            child: Text(
              settingsState.isArabic
                  ? (_isPlayerWhite ? 'إحصائيات نقلاتك (الأبيض)' : 'إحصائيات نقلاتك (الأسود)')
                  : (_isPlayerWhite ? 'Your Moves Breakdown (White)' : 'Your Moves Breakdown (Black)'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.primaryGold,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.35,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      cat['icon'] as String,
                      width: 22,
                      height: 22,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${cat['count']}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      cat['title'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            },
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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.description_rounded,
                          size: 22,
                          color: AppColors.primaryGold,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isAr ? 'تدوين المباراة (PGN)' : 'Live Game PGN Notation',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: pgnText.isNotEmpty
                          ? () {
                              Clipboard.setData(ClipboardData(text: pgnText));
                              AppSnackBar.showSuccess(
                                context,
                                isAr
                                    ? 'تم نسخ تدوين PGN بنجاح!'
                                    : 'Game PGN copied to clipboard!',
                                iconAsset: 'assets/icons/1024x/correct_1024x.png',
                                duration: const Duration(seconds: 2),
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
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
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
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade300,
                    ),
                  ),
                  child: pgnText.isEmpty
                      ? Center(
                          child: Text(
                            isAr
                                ? 'لم تبدأ المباراة بعد. ستظهر النقلات هنا تلقائياً.'
                                : 'No moves recorded yet. Moves will appear here automatically.',
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
}
