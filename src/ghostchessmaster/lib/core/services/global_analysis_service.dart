import 'package:flutter/material.dart';
import 'package:ghostchessmaster/core/services/chess_sound_service.dart';
import 'package:ghostchessmaster/core/widgets/app_snack_bar.dart';
import 'package:ghostchessmaster/features/engine/domain/deep_game_analyzer_service.dart';
import 'package:ghostchessmaster/features/engine/services/stockfish_engine_service.dart';
import 'package:ghostchessmaster/features/history/data/match_history_service.dart';
import 'package:ghostchessmaster/features/history/domain/models/match_record_model.dart';
import 'package:ghostchessmaster/features/history/presentation/pages/match_review_page.dart';
import 'package:ghostchessmaster/features/navigation/presentation/pages/main_navigation_page.dart';
import 'package:ghostchessmaster/features/settings/presentation/bloc/settings_state.dart';
import 'package:ghostchessmaster/main.dart';

/// Global manager for Background Deep Analysis & Dynamic Island Notification.
class GlobalAnalysisService extends ChangeNotifier {
  static final GlobalAnalysisService instance = GlobalAnalysisService._internal();
  GlobalAnalysisService._internal();

  bool _isAnalyzing = false;
  bool _isMinimized = false;
  int _currentMove = 0;
  int _totalMoves = 0;
  double _progress = 0.0;
  String? _activeMatchId;
  MatchRecordModel? _activeMatchRecord;

  bool _showCompletionBanner = false;
  MatchRecordModel? _completedMatchRecord;

  // Getters
  bool get isAnalyzing => _isAnalyzing;
  bool get isMinimized => _isMinimized;
  int get currentMove => _currentMove;
  int get totalMoves => _totalMoves;
  double get progress => _progress;
  String? get activeMatchId => _activeMatchId;
  MatchRecordModel? get activeMatchRecord => _activeMatchRecord;

  bool get showCompletionBanner => _showCompletionBanner;
  MatchRecordModel? get completedMatchRecord => _completedMatchRecord;

  void minimizeToBackground() {
    _isMinimized = true;
    notifyListeners();
  }

  void expandIsland() {
    _isMinimized = false;
    notifyListeners();
  }

  void dismissCompletionBanner() {
    _showCompletionBanner = false;
    notifyListeners();
  }

  /// Launches Full Deep Analysis at Depth 20 for a match record.
  Future<bool> startDeepAnalysis({
    required BuildContext context,
    required MatchRecordModel matchRecord,
    required List<Map<String, dynamic>> rawMoveLog,
    required SettingsState settingsState,
  }) async {
    if (_isAnalyzing) {
      AppSnackBar.showWarning(
        context,
        settingsState.isArabic
            ? 'هناك تحليل عميق يعمل بالفعل في الخلفية! 🧠'
            : 'Another deep analysis is already running in background! 🧠',
      );
      return false;
    }

    if (rawMoveLog.isEmpty) {
      AppSnackBar.showWarning(
        context,
        settingsState.isArabic
            ? 'لا توجد نقلات مسجلة لتحليلها!'
            : 'No recorded moves to analyze!',
      );
      return false;
    }

    _isAnalyzing = true;
    _isMinimized = false;
    _showCompletionBanner = false;
    _currentMove = 0;
    _totalMoves = rawMoveLog.length;
    _progress = 0.0;
    _activeMatchId = matchRecord.id;
    _activeMatchRecord = matchRecord;
    notifyListeners();

    // 1. Ensure Stockfish Engine is 100% initialized & calibrated for Depth 20
    final isReady = await StockfishEngineService.instance.ensureEngineReady(elo: null);

    if (!isReady) {
      _isAnalyzing = false;
      notifyListeners();
      if (context.mounted) {
        AppSnackBar.showError(
          context,
          settingsState.isArabic
              ? 'تعذر تجهيز محرك Stockfish للتحليل العميق!'
              : 'Failed to initialize Stockfish Engine for Deep Analysis!',
        );
      }
      return false;
    }

    // 2. Engine 100% Ready at Depth 20 Snackbar
    if (context.mounted) {
      AppSnackBar.showSuccess(
        context,
        settingsState.isArabic
            ? 'محرك الشطرنج (Stockfish) جاهز 100% للتحليل العميق بعمق 20! 🚀'
            : 'Stockfish Engine is 100% ready at Depth 20 for Deep Analysis! 🚀',
        iconAsset: 'assets/icons/1024x/best_1024x.png',
      );
    }

    // 3. Perform Deep Game Analysis
    final isPlayerWhite = matchRecord.playerColor.toLowerCase() == 'white';

    try {
      final result = await DeepGameAnalyzerService.instance.analyzeFullGameDeeply(
        rawMoveLog: List<Map<String, dynamic>>.from(rawMoveLog),
        isPlayerWhite: isPlayerWhite,
        onProgress: (current, total, pct) {
          _currentMove = current;
          _totalMoves = total;
          _progress = pct;
          notifyListeners();
        },
      );

      final moveLog = List<Map<String, dynamic>>.from(result['moveLog'] as List);
      final accuracy = result['overallAccuracy'] as int;
      final pgn = result['pgn'] as String;

      // 4. Save to Firestore
      await MatchHistoryService.instance.updateDeepAnalysisData(
        matchId: matchRecord.id,
        moveLog: moveLog,
        accuracy: accuracy,
        pgn: pgn,
      );

      // Fetch fresh updated match record
      final updatedMatch = await MatchHistoryService.instance.getMatchRecordById(matchRecord.id) ?? matchRecord;

      _isAnalyzing = false;
      _isMinimized = true;
      _showCompletionBanner = true;
      _completedMatchRecord = updatedMatch;
      notifyListeners();

      // Play completion sound effect
      ChessSoundService.instance.playGameEnd(settingsState.isSoundEnabled);

      return true;
    } catch (e) {
      debugPrint('[GLOBAL_ANALYSIS] Error during deep analysis: $e');
      _isAnalyzing = false;
      notifyListeners();
      return false;
    }
  }

  /// Navigates to the completed analyzed match review page, ensuring HistoryPage is directly beneath it in the back stack.
  void openCompletedMatch(BuildContext context, SettingsState settingsState) {
    if (_completedMatchRecord == null) return;
    _showCompletionBanner = false;
    notifyListeners();

    final targetMatch = _completedMatchRecord!;
    final navState = appNavigatorKey.currentState;
    if (navState != null) {
      navState.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigationPage(initialIndex: 2),
        ),
        (route) => false,
      );
      navState.push(
        MaterialPageRoute(
          builder: (_) => MatchReviewPage(
            match: targetMatch,
            settingsState: settingsState,
          ),
        ),
      );
    } else {
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const MainNavigationPage(initialIndex: 2),
        ),
        (route) => false,
      );
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => MatchReviewPage(
            match: targetMatch,
            settingsState: settingsState,
          ),
        ),
      );
    }
  }
}
