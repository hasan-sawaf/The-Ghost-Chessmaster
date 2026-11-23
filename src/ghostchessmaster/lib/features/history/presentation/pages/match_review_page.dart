import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ghostchessmaster/core/utils/load_images.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../../core/services/global_analysis_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../engine/domain/chess_evaluator.dart';
import '../../../settings/presentation/bloc/settings_state.dart';
import '../../../training/presentation/widgets/live_game_analyzer_widget.dart';
import '../../../training/presentation/widgets/training_board_widget.dart';
import '../../../../core/widgets/app_snack_bar.dart';
import '../../data/match_history_service.dart';
import '../../domain/models/match_record_model.dart';

class MatchReviewPage extends StatefulWidget {
  final MatchRecordModel match;
  final SettingsState settingsState;

  const MatchReviewPage({
    super.key,
    required this.match,
    required this.settingsState,
  });

  /// Opens the MatchReviewPage after displaying a smooth loading dialog to ensure all
  /// moves, analysis, and evaluations are 100% loaded before rendering.
  static Future<void> open(
    BuildContext context, {
    required MatchRecordModel match,
    required SettingsState settingsState,
  }) async {
    final isAr = settingsState.isArabic;
    final isDark = settingsState.isDarkMode;

    // 1. If match already has full moves loaded, push directly (0ms lag)
    if ((match.liveMoveLog.isNotEmpty || match.deepMoveLog != null) &&
        (match.liveMoveLog.length >= match.moveCount || match.moveCount == 0)) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MatchReviewPage(
            match: match,
            settingsState: settingsState,
          ),
        ),
      );
      return;
    }

    // 2. Otherwise, show a sleek loading dialog while fetching from cache / Firebase
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
          content: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    color: AppColors.primaryGold,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isAr ? 'جاري تحميل تفاصيل المباراة...' : 'Loading Match Details...',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAr ? 'يتم جلب سجل النقلات والتحليلات ♟️' : 'Fetching move log and analysis ♟️',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    MatchRecordModel? fullMatch;
    try {
      fullMatch = await MatchHistoryService.instance.getMatchRecordById(match.id);
    } catch (e) {
      debugPrint('[MATCH_REVIEW] Error pre-loading match: $e');
    }

    // Close loading dialog if context is still mounted, then push review page
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MatchReviewPage(
            match: fullMatch ?? match,
            settingsState: settingsState,
          ),
        ),
      );
    }
  }

  @override
  State<MatchReviewPage> createState() => _MatchReviewPageState();
}

class _MatchReviewPageState extends State<MatchReviewPage> {
  late List<List<String?>> _boardState;
  late List<Map<String, dynamic>> _moveLog; // Primary Live Game Analysis move log
  List<Map<String, dynamic>>? _deepMoveLog; // Separate Deep Game Analysis move log
  late int _accuracy;
  int? _deepAccuracy;
  int _reviewMoveIndex = 0;
  bool _isPlayingBack = false;
  Timer? _playbackTimer;

  bool _hasRunDeepAnalysis = false;

  String? _reviewClassificationIcon;
  int? _reviewClassificationRow;
  int? _reviewClassificationCol;
  int? _lastMoveFromRow;
  int? _lastMoveFromCol;
  int? _lastMoveToRow;
  int? _lastMoveToCol;

  StreamSubscription<MatchRecordModel?>? _matchStreamSub;

  @override
  void initState() {
    super.initState();
    _applyMatchRecord(widget.match, isInitial: true);
    _resetBoardState();

    final effectiveLog = (_hasRunDeepAnalysis && _deepMoveLog != null && _deepMoveLog!.isNotEmpty)
        ? _deepMoveLog!
        : _moveLog;
    if (effectiveLog.isNotEmpty) {
      _reviewMoveIndex = effectiveLog.length;
      _updateBoardStateForReviewIndex(_reviewMoveIndex);
    }

    // 1. Real-time stream of match updates from local cache & Firestore
    _matchStreamSub = MatchHistoryService.instance
        .streamMatchRecordById(widget.match.id)
        .listen((record) {
      if (record != null && mounted) {
        _applyMatchRecord(record);
      }
    });

    // 2. Real-time listener for GlobalAnalysisService progress & background completion
    GlobalAnalysisService.instance.addListener(_onGlobalAnalysisChanged);
  }

  void _applyMatchRecord(MatchRecordModel record, {bool isInitial = false}) {
    final newMoveLog = List<Map<String, dynamic>>.from(record.liveMoveLog.isNotEmpty ? record.liveMoveLog : record.moveLog);
    final newDeepLog = record.deepMoveLog != null && record.deepMoveLog!.isNotEmpty
        ? List<Map<String, dynamic>>.from(record.deepMoveLog!)
        : null;
    final isDeep = record.deepAnalyzed || (newDeepLog != null && newDeepLog.isNotEmpty);
    final newLiveAcc = record.liveAccuracy > 0 ? record.liveAccuracy : record.accuracy;
    final newDeepAcc = record.deepAccuracy ?? (isDeep ? record.accuracy : null);

    if (isInitial) {
      _moveLog = newMoveLog;
      _deepMoveLog = newDeepLog;
      _accuracy = newLiveAcc;
      _deepAccuracy = newDeepAcc;
      _hasRunDeepAnalysis = isDeep;
    } else {
      setState(() {
        _moveLog = newMoveLog;
        _deepMoveLog = newDeepLog;
        _accuracy = newLiveAcc;
        _deepAccuracy = newDeepAcc;
        _hasRunDeepAnalysis = isDeep;

        final effectiveLog = (isDeep && newDeepLog != null && newDeepLog.isNotEmpty)
            ? newDeepLog
            : newMoveLog;

        if (effectiveLog.isNotEmpty) {
          _updateBoardStateForReviewIndex(_reviewMoveIndex.clamp(1, effectiveLog.length));
        }
      });
    }
  }

  void _onGlobalAnalysisChanged() {
    if (!mounted) return;
    final globalService = GlobalAnalysisService.instance;
    if (globalService.activeMatchId == widget.match.id) {
      if (globalService.completedMatchRecord != null &&
          globalService.completedMatchRecord!.id == widget.match.id) {
        _applyMatchRecord(globalService.completedMatchRecord!);
      } else {
        setState(() {}); // Update live progress bar state
      }
    }
  }

  @override
  void dispose() {
    _matchStreamSub?.cancel();
    GlobalAnalysisService.instance.removeListener(_onGlobalAnalysisChanged);
    _playbackTimer?.cancel();
    super.dispose();
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
    final effectiveMoveLog = (_hasRunDeepAnalysis && _deepMoveLog != null && _deepMoveLog!.isNotEmpty)
        ? _deepMoveLog!
        : _moveLog;

    if (effectiveMoveLog.isEmpty || index <= 0) {
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

    final targetIndex = index.clamp(1, effectiveMoveLog.length);
    final move = effectiveMoveLog[targetIndex - 1];
    final fenAfter = (move['fenAfter'] ?? move['fen_after'] ?? '').toString();
    final moveUci = (move['uci'] ?? move['move'] ?? '').toString();
    final rawIcon = (move['icon'] ?? move['classification'] ?? '').toString();
    final iconPath = rawIcon.isNotEmpty ? AppImageHelper.getClassificationIconPath(rawIcon) : null;

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

  Future<void> _runDeepGameAnalysis(SettingsState settingsState) async {
    if (!InternetConnectivityService.instance.isOnline) {
      AppSnackBar.showWarning(
        context,
        settingsState.isArabic
            ? 'التحليل العميق غير متاح بدون اتصال بالإنترنت! 📡'
            : 'Deep Game Analysis requires an active internet connection! 📡',
        iconAsset: 'assets/icons/1024x/inaccuracy_1024x.png',
      );
      return;
    }

    final success = await GlobalAnalysisService.instance.startDeepAnalysis(
      context: context,
      matchRecord: widget.match,
      rawMoveLog: _moveLog,
      settingsState: settingsState,
    );

    if (success && mounted) {
      final updatedMatch = await MatchHistoryService.instance.getMatchRecordById(widget.match.id);
      if (updatedMatch != null && mounted) {
        setState(() {
          _moveLog = List<Map<String, dynamic>>.from(updatedMatch.liveMoveLog);
          _deepMoveLog = updatedMatch.deepMoveLog != null ? List<Map<String, dynamic>>.from(updatedMatch.deepMoveLog!) : null;
          _hasRunDeepAnalysis = true;
          _accuracy = updatedMatch.liveAccuracy > 0 ? updatedMatch.liveAccuracy : updatedMatch.accuracy;
          _deepAccuracy = updatedMatch.deepAccuracy ?? updatedMatch.accuracy;

          final effectiveLog = (_deepMoveLog != null && _deepMoveLog!.isNotEmpty)
              ? _deepMoveLog!
              : _moveLog;

          if (effectiveLog.isNotEmpty) {
            _updateBoardStateForReviewIndex(_reviewMoveIndex.clamp(1, effectiveLog.length));
          }
        });
      }
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

  @override
  Widget build(BuildContext context) {
    final settingsState = widget.settingsState;
    final isPlayerWhite = widget.match.playerColor.toLowerCase() == 'white';

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            settingsState.isArabic
                ? 'مراجعة المباراة: ${widget.match.opponentName}'
                : 'Match Review: ${widget.match.opponentName}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
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
                text: settingsState.isArabic ? 'رقعة اللعب' : 'Game Board',
              ),
              Tab(
                icon: const Icon(Icons.analytics_rounded),
                text: settingsState.isArabic ? 'تحليل المباراة' : 'Game Analysis',
              ),
              Tab(
                icon: const Icon(Icons.description_rounded),
                text: settingsState.isArabic ? 'تدوين PGN' : 'Game PGN',
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              // --- TAB 1: GAME BOARD & PLAYBACK ---
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderCard(settingsState),
                    const SizedBox(height: 14),
                    TrainingBoardWidget(
                      boardState: _boardState,
                      settingsState: settingsState,
                      overridePieceTheme: widget.match.pieceTheme,
                      isBoardFlipped: !isPlayerWhite,
                      selectedRow: null,
                      selectedCol: null,
                      legalDestinations: const [],
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
                      isKingInCheck: (_) => false,
                      onSquareTapped: (row, col) {},
                    ),
                    const SizedBox(height: 16),
                    _buildPlaybackControlBar(settingsState),
                  ],
                ),
              ),

              // --- TAB 2: GAME ANALYZER ---
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeaderCard(settingsState),
                    const SizedBox(height: 14),
                    Builder(
                      builder: (context) {
                        final globalService = GlobalAnalysisService.instance;
                        final isAnalyzingThisMatch = globalService.isAnalyzing && globalService.activeMatchId == widget.match.id;

                        if (isAnalyzingThisMatch) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: settingsState.isDarkMode ? AppColors.darkCard : AppColors.lightCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.primaryGold, width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: AppColors.primaryGold,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        settingsState.isArabic
                                            ? 'جاري التحليل العميق (Stockfish Depth 20)...'
                                            : 'Deep Analysis in Progress (Depth 20)...',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                    ),
                                    Text(
                                      '${(globalService.progress * 100).toInt()}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryGold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: globalService.progress > 0 ? globalService.progress : null,
                                    minHeight: 8,
                                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGold),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      settingsState.isArabic
                                          ? 'تحليل النقلة ${globalService.currentMove} من ${globalService.totalMoves}'
                                          : 'Analyzing move ${globalService.currentMove} of ${globalService.totalMoves}',
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                    Text(
                                      settingsState.isArabic ? 'في الخلفية 🧠' : 'In Background 🧠',
                                      style: const TextStyle(fontSize: 11, color: AppColors.primaryGold, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }

                        if (!_hasRunDeepAnalysis) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: settingsState.isDarkMode
                                  ? AppColors.darkCard
                                  : AppColors.lightCard,
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
                                        (widget.match.hasRealAnalysis || _accuracy > 0 || widget.match.accuracy > 0)
                                            ? (settingsState.isArabic
                                                ? 'ترقية إلى التحليل العميق 🧠'
                                                : 'Upgrade to Deep Game Analysis 🧠')
                                            : (settingsState.isArabic
                                                ? 'لم يتم تحليل المباراة بعد 🧠'
                                                : 'No Game Analysis Performed Yet 🧠'),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  (widget.match.hasRealAnalysis || _accuracy > 0 || widget.match.accuracy > 0)
                                      ? (settingsState.isArabic
                                          ? 'قم بإجراء تحليل عميق بمحرك Stockfish Depth-20 للحصول على تصنيفات دقيقة ودراسة جميع النقلات!'
                                          : 'Run Stockfish Depth-20 engine analysis to get precise move classifications and full game report!')
                                      : (settingsState.isArabic
                                          ? 'تم لعب هذه المباراة في وضع التحليل العميق (بدون تحليل مباشر). انقر فوق الزر أدناه لبدء تحليل Stockfish Depth-20 وتوليد جميع تصنيفات النقلات والدقة!'
                                          : 'This match was played in Deep Analysis Mode (without Live Analysis). Tap the button below to start Stockfish Depth-20 analysis and generate full move classifications, accuracy scores, and engine evaluations!'),
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                                const SizedBox(height: 12),
                                Builder(
                                  builder: (context) {
                                    final isOnline = InternetConnectivityService.instance.isOnline;
                                    return SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isOnline ? AppColors.primaryGold : Colors.grey.shade400,
                                          foregroundColor: isOnline ? Colors.black : Colors.grey.shade700,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        icon: Icon(isOnline ? Icons.play_circle_fill_rounded : Icons.wifi_off_rounded),
                                        label: Text(
                                          isOnline
                                              ? (settingsState.isArabic ? 'بدء التحليل العميق الآن' : 'Start Deep Analysis Now')
                                              : (settingsState.isArabic ? 'يتطلب اتصال بالإنترنت 📡' : 'Requires Internet Connection 📡'),
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        onPressed: isOnline ? () => _runDeepGameAnalysis(settingsState) : null,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.success, width: 1.2),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  settingsState.isArabic
                                      ? 'تم إجراء التحليل العميق بنجاح (Stockfish Depth 20)! 🎯'
                                      : 'Deep Game Analysis Completed (Stockfish Depth 20)! 🎯',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (!_hasRunDeepAnalysis) ...[
                      if (widget.match.hasRealAnalysis || _accuracy > 0 || widget.match.accuracy > 0) ...[
                        _buildAnalyzerSummaryStats(
                          settingsState,
                          isPlayerWhite,
                          _accuracy > 0 ? _accuracy : widget.match.accuracy,
                        ),
                        const SizedBox(height: 16),
                        LiveGameAnalyzerWidget(
                          moveLog: _moveLog,
                          settingsState: settingsState,
                          evalBarValue: 0.5,
                          overallAccuracy: _accuracy > 0 ? _accuracy : widget.match.accuracy,
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: settingsState.isDarkMode ? AppColors.darkCard : AppColors.lightCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: settingsState.isDarkMode ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.analytics_outlined,
                                size: 48,
                                color: Colors.grey.withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                settingsState.isArabic
                                    ? 'لا يوجد تحليل مباشر ولا تحليل عميق'
                                    : 'No Live Analysis & No Deep Analysis',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                settingsState.isArabic
                                    ? 'انقر على "بدء التحليل العميق الآن" أعلاه لتحليل المباراة وتوليد التقرير.'
                                    : 'Click "Start Deep Analysis Now" above to analyze this game with Stockfish.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.success, width: 1.2),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                settingsState.isArabic
                                    ? 'تم إجراء التحليل العميق بنجاح (Stockfish Depth 20)! 🎯'
                                    : 'Deep Game Analysis Completed (Stockfish Depth 20)! 🎯',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildAnalyzerSummaryStats(settingsState, isPlayerWhite, _deepAccuracy ?? _accuracy),
                      const SizedBox(height: 16),
                      LiveGameAnalyzerWidget(
                        moveLog: _deepMoveLog ?? _moveLog,
                        settingsState: settingsState,
                        evalBarValue: 0.5,
                        overallAccuracy: _deepAccuracy ?? _accuracy,
                      ),
                    ],
                  ],
                ),
              ),

              // --- TAB 3: GAME PGN ---
              _buildGamePgnTab(settingsState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(SettingsState settingsState) {
    final isVictory = widget.match.result == 'victory';
    final isDraw = widget.match.result == 'draw';
    final isResigned = widget.match.resultReason == 'surrendered';
    final resultColor = isVictory
        ? AppColors.success
        : (isDraw ? AppColors.warning : AppColors.error);

    final resultLabel = isResigned
        ? (settingsState.isArabic ? 'خسارة (استسلام)' : 'RESIGNED')
        : settingsState.translate(widget.match.result).toUpperCase();

    final effectiveMoveLog = (_hasRunDeepAnalysis && _deepMoveLog != null && _deepMoveLog!.isNotEmpty)
        ? _deepMoveLog!
        : _moveLog;

    final int moveCount = effectiveMoveLog.isNotEmpty ? effectiveMoveLog.length : widget.match.moveCount;

    final int resolvedAccuracy = _hasRunDeepAnalysis
        ? (_deepAccuracy ?? (_accuracy > 0 ? _accuracy : widget.match.accuracy))
        : (_accuracy > 0 ? _accuracy : (_deepAccuracy ?? widget.match.accuracy));

    final bool hasAnyAnalysis = _hasRunDeepAnalysis || resolvedAccuracy > 0 || widget.match.hasRealAnalysis;

    final String accuracyText;
    if (_hasRunDeepAnalysis && (_deepAccuracy != null || resolvedAccuracy > 0)) {
      accuracyText = '$moveCount ${settingsState.isArabic ? "نقلات" : "moves"} • ${settingsState.isArabic ? "الدقة" : "Accuracy"}: $resolvedAccuracy%';
    } else if (resolvedAccuracy > 0) {
      accuracyText = '$moveCount ${settingsState.isArabic ? "نقلات" : "moves"} • ${settingsState.isArabic ? "دقة اللعب المباشر" : "Live Acc"}: $resolvedAccuracy%';
    } else if (!hasAnyAnalysis) {
      accuracyText = '$moveCount ${settingsState.isArabic ? "نقلات" : "moves"} • ${settingsState.isArabic ? "لم يتم التحليل العميق" : "Not Deep Analyzed"}';
    } else {
      accuracyText = '$moveCount ${settingsState.isArabic ? "نقلات" : "moves"}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: settingsState.isDarkMode ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: settingsState.isDarkMode ? AppColors.darkBorder : AppColors.lightBorder,
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
                  widget.match.opponentName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  accuracyText,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: resultColor),
            ),
            child: Text(
              resultLabel,
              style: TextStyle(
                color: resultColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControlBar(SettingsState settingsState) {
    final isDark = settingsState.isDarkMode;
    final effectiveMoveLog = (_hasRunDeepAnalysis && _deepMoveLog != null && _deepMoveLog!.isNotEmpty)
        ? _deepMoveLog!
        : _moveLog;
    final int logLength = effectiveMoveLog.length;

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
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            settingsState.isArabic
                ? 'مراجعة النقلات: $_reviewMoveIndex / $logLength'
                : 'Review Move: $_reviewMoveIndex / $logLength',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 28),
                tooltip: settingsState.isArabic ? 'البداية' : 'Start',
                onPressed: () {
                  _stopPlayback();
                  _updateBoardStateForReviewIndex(0);
                },
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 28),
                tooltip: settingsState.isArabic ? 'النقلة السابقة' : 'Previous Move',
                onPressed: () {
                  _stopPlayback();
                  _updateBoardStateForReviewIndex(_reviewMoveIndex - 1);
                },
              ),
              InkWell(
                onTap: _togglePlaybackTimer,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGold,
                    borderRadius: BorderRadius.circular(12),
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
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 28),
                tooltip: settingsState.isArabic ? 'النقلة التالية' : 'Next Move',
                onPressed: () {
                  _stopPlayback();
                  _updateBoardStateForReviewIndex(_reviewMoveIndex + 1);
                },
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 28),
                tooltip: settingsState.isArabic ? 'النهاية' : 'End',
                onPressed: () {
                  _stopPlayback();
                  _updateBoardStateForReviewIndex(logLength);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyzerSummaryStats(SettingsState settingsState, bool isPlayerWhite, int targetAccuracy) {
    int brilliantCount = 0;
    int greatCount = 0;
    int bestCount = 0;
    int excellentCount = 0;
    int goodCount = 0;
    int bookCount = 0;
    int inaccuracyCount = 0;
    int mistakeCount = 0;
    int blunderCount = 0;

    final targetLog = _deepMoveLog ?? _moveLog;

    for (final m in targetLog) {
      final moverIsWhite = (m['isWhite'] as bool?) ?? (m['player'] == 'White');
      if (moverIsWhite != isPlayerWhite) continue;

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
      {'title': settingsState.isArabic ? 'رائعة' : 'Brilliant', 'count': brilliantCount, 'icon': MoveClassification.brilliant.iconPath},
      {'title': settingsState.isArabic ? 'عظيمة' : 'Great', 'count': greatCount, 'icon': MoveClassification.great.iconPath},
      {'title': settingsState.isArabic ? 'الأفضل' : 'Best', 'count': bestCount, 'icon': MoveClassification.best.iconPath},
      {'title': settingsState.isArabic ? 'ممتازة' : 'Excellent', 'count': excellentCount, 'icon': MoveClassification.excellent.iconPath},
      {'title': settingsState.isArabic ? 'جيدة' : 'Okay', 'count': goodCount, 'icon': MoveClassification.good.iconPath},
      {'title': settingsState.isArabic ? 'كتاب' : 'Book', 'count': bookCount, 'icon': MoveClassification.book.iconPath},
      {'title': settingsState.isArabic ? 'غير دقيقة' : 'Inaccuracy', 'count': inaccuracyCount, 'icon': MoveClassification.inaccuracy.iconPath},
      {'title': settingsState.isArabic ? 'خطأ' : 'Mistake', 'count': mistakeCount, 'icon': MoveClassification.mistake.iconPath},
      {'title': settingsState.isArabic ? 'فادح' : 'Blunder', 'count': blunderCount, 'icon': MoveClassification.blunder.iconPath},
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.primaryGold.withValues(alpha: 0.3) : AppColors.primaryMahogany.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 4, right: 4),
            child: Text(
              settingsState.isArabic
                  ? (isPlayerWhite ? 'إحصائيات نقلاتك (الأبيض)' : 'إحصائيات نقلاتك (الأسود)')
                  : (isPlayerWhite ? 'Your Moves Breakdown (White)' : 'Your Moves Breakdown (Black)'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primaryGold),
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
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(cat['icon'] as String, width: 22, height: 22, fit: BoxFit.contain),
                    const SizedBox(height: 4),
                    Text('${cat['count']}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                    Text(cat['title'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9, color: Colors.grey)),
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
    final pgnText = widget.match.pgn;
    final isDark = settingsState.isDarkMode;
    final isAr = settingsState.isArabic;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderCard(settingsState),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.lightCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.primaryGold.withValues(alpha: 0.3) : AppColors.primaryMahogany.withValues(alpha: 0.2),
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
                        Text(isAr ? 'تدوين المباراة (PGN)' : 'Game PGN Notation', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                            Text(isAr ? 'نسخ PGN' : 'Copy PGN', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
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
                      ? Center(child: Text(isAr ? 'لا يوجد تدوين PGN لهذا اللقاء.' : 'No PGN recorded for this match.', style: const TextStyle(fontSize: 13, color: Colors.grey)))
                      : SelectableText(
                          pgnText,
                          style: TextStyle(fontFamily: 'monospace', fontSize: 14, height: 1.6, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
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
