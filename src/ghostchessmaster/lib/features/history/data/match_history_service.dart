import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/connectivity_service.dart';
import '../domain/models/match_record_model.dart';
import 'local_match_cache_service.dart';
import '../../../models/firestore_constants.dart';
import '../../../models/move_analysis_detail_model.dart';

/// Service responsible for persisting, syncing, and fetching user matches & game analysis in Firebase Firestore & local device cache.
class MatchHistoryService {
  static final MatchHistoryService _instance = MatchHistoryService._internal();
  static MatchHistoryService get instance => _instance;
  MatchHistoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Helper to get current active User ID or fallback guest ID
  String get _currentUserId {
    final uid = _auth.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) return uid;
    return 'guest_user';
  }

  /// Reference to root matches history collection
  CollectionReference<Map<String, dynamic>> _matchesRef() {
    return _firestore.collection(FirestoreConstants.matchesHistoryCollection);
  }

  /// Reference to move analysis detail subcollection under `matches_history/{matchId}/move_analysis_detail/`
  CollectionReference<Map<String, dynamic>> _moveAnalysisRef(String matchId) {
    return _matchesRef().doc(matchId).collection(FirestoreConstants.moveAnalysisDetailSubcollection);
  }

  /// Helper to parse island index number from an island title string
  int _parseIslandIndexFromTitle(String? title) {
    if (title == null || title.isEmpty) return 0;
    final match = RegExp(r'\d+').firstMatch(title);
    if (match != null) {
      return int.tryParse(match.group(0)!) ?? 0;
    }
    final lower = title.toLowerCase();
    if (lower.contains('beginner')) return 1;
    if (lower.contains('pawn')) return 2;
    if (lower.contains('knight')) return 3;
    if (lower.contains('bishop')) return 4;
    if (lower.contains('rook')) return 5;
    if (lower.contains('queen')) return 6;
    if (lower.contains('king')) return 7;
    if (lower.contains('tactical')) return 8;
    if (lower.contains('strategic')) return 9;
    if (lower.contains('endgame')) return 10;
    return 0;
  }

  /// Write move analysis to subcollection `matches_history/{matchId}/move_analysis_detail/{moveNumber}` using batch writes
  Future<void> _writeMoveAnalysisToFirestore(String matchId, List<Map<String, dynamic>> moveLog, String analysisType) async {
    if (moveLog.isEmpty) return;

    try {
      final ref = _moveAnalysisRef(matchId);
      var batch = _firestore.batch();
      int operationCount = 0;

      for (int i = 0; i < moveLog.length; i++) {
        final moveNumber = i + 1;
        final docId = '$moveNumber'; // Document ID = moveNumber ('1', '2', ..., '20')
        final model = MoveAnalysisDetailModel.fromLegacyMoveLogEntry(
          moveLogEntry: moveLog[i],
          matchId: matchId,
          moveNumber: moveNumber,
          analysisType: analysisType,
        );

        batch.set(ref.doc(docId), model.toFirestoreMap(), SetOptions(merge: true));
        operationCount++;

        if (operationCount >= 450) {
          await batch.commit();
          batch = _firestore.batch();
          operationCount = 0;
        }
      }

      if (operationCount > 0) {
        await batch.commit();
      }
      debugPrint('[MATCH_HISTORY] Successfully wrote $operationCount move_analysis_detail document(s) for match $matchId ($analysisType) to subcollection.');
    } catch (e) {
      debugPrint('[MATCH_HISTORY] Error writing move_analysis_detail for match $matchId: $e');
    }
  }

  /// Read move analysis details for a match from subcollection `matches_history/{matchId}/move_analysis_detail/`.
  /// Sorts in Dart memory so no Firestore composite index is required.
  Future<List<Map<String, dynamic>>> _readMoveAnalysisFromFirestore(String matchId, {String? analysisType}) async {
    try {
      final snapshot = await _moveAnalysisRef(matchId).get();

      if (snapshot.docs.isEmpty) {
        debugPrint('[MATCH_HISTORY] No move_analysis_detail documents found in Firestore subcollection for match $matchId.');
        return [];
      }

      final list = snapshot.docs
          .map((doc) => MoveAnalysisDetailModel.fromFirestoreDoc(doc))
          .where((model) => analysisType == null || model.analysisType == analysisType)
          .map((model) => model.toLegacyMoveLogEntry())
          .toList();

      // Sort in memory by moveNumber
      list.sort((a, b) {
        final numA = (a['moveNumber'] as num?)?.toInt() ?? (a['num'] as num?)?.toInt() ?? 0;
        final numB = (b['moveNumber'] as num?)?.toInt() ?? (b['num'] as num?)?.toInt() ?? 0;
        return numA.compareTo(numB);
      });

      debugPrint('[MATCH_HISTORY] Successfully loaded ${list.length} move_analysis_detail document(s) from Firestore for match $matchId (type: ${analysisType ?? "all"}).');
      return list;
    } catch (e) {
      debugPrint('[MATCH_HISTORY] Error reading move_analysis_detail for match $matchId: $e');
      return [];
    }
  }

  /// Sync all locally cached offline matches to Firebase Firestore when Internet is restored.
  Future<void> syncCachedMatchesToFirebase({String? userId}) async {
    if (!InternetConnectivityService.instance.isOnline) {
      debugPrint('[MATCH_SYNC] Skipping sync because device is offline.');
      return;
    }

    final activeUserId = (userId != null && userId.isNotEmpty) ? userId : _currentUserId;

    try {
      final cachedMatches = await LocalMatchCacheService.instance.getCachedMatches(targetUserId: activeUserId);
      if (cachedMatches.isEmpty) {
        debugPrint('[MATCH_SYNC] No offline cached matches to sync for user $activeUserId.');
        return;
      }

      debugPrint('[MATCH_SYNC] Starting sync for ${cachedMatches.length} cached offline match(es) for user $activeUserId...');

      for (final match in cachedMatches) {
        final targetUserId = match.userId.isNotEmpty ? match.userId : activeUserId;
        final docRef = _matchesRef().doc(match.id);

        try {
          // Upload/update full match data to matches_history
          await docRef.set(match.toFirestoreMap(), SetOptions(merge: true));

          // Upload move analysis subcollection documents
          if (match.liveMoveLog.isNotEmpty) {
            await _writeMoveAnalysisToFirestore(match.id, match.liveMoveLog, FirestoreConstants.analysisTypeLive);
          }
          if (match.deepMoveLog != null && match.deepMoveLog!.isNotEmpty) {
            await _writeMoveAnalysisToFirestore(match.id, match.deepMoveLog!, FirestoreConstants.analysisTypeDeep);
          }

          debugPrint('[MATCH_SYNC] Successfully uploaded/synced match ${match.id} and move_analysis_detail to Firebase for user $targetUserId.');
        } catch (e) {
          debugPrint('[MATCH_SYNC] Error syncing match ${match.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('[MATCH_SYNC] Error during cached matches sync: $e');
    }
  }

  /// Create a new match record in local cache and Firestore.
  Future<void> createMatchRecord(MatchRecordModel match) async {
    // MANDATORY RULE: Matches with 4 or fewer moves MUST NOT be created/saved!
    if (match.liveMoveLog.length <= 4 && match.moveCount <= 4) {
      debugPrint('[MATCH_HISTORY] Skipping createMatchRecord for match ${match.id} because moveCount <= 4.');
      return;
    }

    final userId = match.userId.isNotEmpty ? match.userId : _currentUserId;

    // Auto-resolve islandId if missing and matchType is training
    MatchRecordModel recordToSave = match;
    if ((recordToSave.islandId == null || recordToSave.islandId!.isEmpty) && recordToSave.matchType == 'training') {
      final derivedIdx = _parseIslandIndexFromTitle(recordToSave.islandTitle);
      if (derivedIdx > 0) {
        recordToSave = recordToSave.copyWith(islandId: '$derivedIdx');
      }
    }

    // ALWAYS store in local device cache first
    await LocalMatchCacheService.instance.cacheMatch(recordToSave);

    if (InternetConnectivityService.instance.isOnline) {
      try {
        await _matchesRef().doc(recordToSave.id).set(recordToSave.toFirestoreMap(), SetOptions(merge: true));

        if (recordToSave.liveMoveLog.isNotEmpty) {
          await _writeMoveAnalysisToFirestore(recordToSave.id, recordToSave.liveMoveLog, FirestoreConstants.analysisTypeLive);
        }
        if (recordToSave.deepMoveLog != null && recordToSave.deepMoveLog!.isNotEmpty) {
          await _writeMoveAnalysisToFirestore(recordToSave.id, recordToSave.deepMoveLog!, FirestoreConstants.analysisTypeDeep);
        }

        debugPrint('[MATCH_HISTORY] Match ${recordToSave.id} created in Firestore for user $userId (island_id=${recordToSave.islandId}).');
      } catch (e) {
        debugPrint('[MATCH_HISTORY] Firestore write failed ($e). Kept match ${recordToSave.id} in local cache.');
      }
    }
  }

  /// Update live game data incrementally after each move in Live Analysis Mode.
  Future<void> updateLiveMatchData({
    required String matchId,
    String matchType = 'quick_match',
    String playerColor = 'white',
    String opponentName = 'Stockfish AI',
    int stockfishLevel = 5,
    int? roundIndex,
    String? islandTitle,
    String? islandId,
    String pieceTheme = 'Standered',
    DateTime? startedAt,
    required List<Map<String, dynamic>> moveLog,
    required int accuracy,
    required String pgn,
    required String fen,
  }) async {
    if (moveLog.length <= 4) {
      debugPrint('[MATCH_HISTORY] Skipping updateLiveMatchData for match $matchId because move count (${moveLog.length}) <= 4.');
      return;
    }

    final userId = _currentUserId;
    final sanitizeLog = moveLog.map((m) => Map<String, dynamic>.from(m)).toList();
    final startTime = startedAt ?? DateTime.now();

    final existing = await getMatchRecordById(matchId, userId: userId);
    final isAlreadyCompleted = existing != null && existing.status == 'completed';

    final String status = isAlreadyCompleted ? existing.status : 'in_progress';
    final String result = isAlreadyCompleted ? existing.result : 'ongoing';
    final String? resultReason = isAlreadyCompleted ? existing.resultReason : null;
    final DateTime? completedAt = isAlreadyCompleted ? existing.completedAt : null;
    final int resolvedAccuracy = accuracy > 0 ? accuracy : (existing?.accuracy ?? 0);
    final int resolvedLiveAccuracy = accuracy > 0 ? accuracy : (existing?.liveAccuracy ?? 0);

    final resolvedPieceTheme = (pieceTheme != 'Standered' && pieceTheme.isNotEmpty)
        ? pieceTheme
        : (existing?.pieceTheme.isNotEmpty == true ? existing!.pieceTheme : pieceTheme);

    final resolvedIslandId = islandId ??
        existing?.islandId ??
        (matchType == 'training' && islandTitle != null && _parseIslandIndexFromTitle(islandTitle) > 0
            ? '${_parseIslandIndexFromTitle(islandTitle)}'
            : null);

    final liveMatch = MatchRecordModel(
      id: matchId,
      userId: userId,
      boardId: existing?.boardId,
      islandId: resolvedIslandId,
      matchType: matchType,
      analyzerMode: isAlreadyCompleted ? existing.analyzerMode : 'live_game_analysis',
      deepAnalyzed: isAlreadyCompleted ? existing.deepAnalyzed : false,
      playerColor: playerColor,
      opponentName: opponentName,
      roundIndex: roundIndex,
      islandTitle: islandTitle,
      stockfishLevel: stockfishLevel,
      status: status,
      result: result,
      resultReason: resultReason,
      accuracy: resolvedAccuracy,
      liveAccuracy: resolvedLiveAccuracy,
      deepAccuracy: existing?.deepAccuracy,
      moveCount: sanitizeLog.length,
      pgn: pgn,
      fen: fen,
      moveLog: sanitizeLog,
      liveMoveLog: sanitizeLog,
      deepMoveLog: existing?.deepMoveLog,
      pieceTheme: resolvedPieceTheme,
      startedAt: existing?.startedAt ?? startTime,
      updatedAt: DateTime.now(),
      completedAt: completedAt,
    );

    // ALWAYS store in local device cache first
    await LocalMatchCacheService.instance.cacheMatch(liveMatch);

    if (InternetConnectivityService.instance.isOnline) {
      try {
        await _matchesRef().doc(matchId).set(liveMatch.toFirestoreMap(), SetOptions(merge: true));
        await _writeMoveAnalysisToFirestore(matchId, sanitizeLog, FirestoreConstants.analysisTypeLive);
        debugPrint('[MATCH_HISTORY] Live match $matchId updated in Firestore after move (${moveLog.length} moves, island_id=$resolvedIslandId).');
      } catch (e) {
        debugPrint('[MATCH_HISTORY] Firestore live update failed ($e). Kept in local cache.');
      }
    }
  }

  /// Update deep analysis result in local device cache and Firestore.
  /// Replaces existing move log & live analysis with the newly calculated Deep Game Analysis.
  Future<void> updateDeepAnalysisData({
    required String matchId,
    required List<Map<String, dynamic>> moveLog,
    required int accuracy,
    required String pgn,
  }) async {
    final userId = _currentUserId;

    if (moveLog.isEmpty) return;

    final existing = await getMatchRecordById(matchId, userId: userId);

    final updatedMatch = MatchRecordModel(
      id: matchId,
      userId: existing?.userId ?? userId,
      boardId: existing?.boardId,
      islandId: existing?.islandId,
      matchType: existing?.matchType ?? 'quick_match',
      analyzerMode: FirestoreConstants.analyzerModeDeep,
      deepAnalyzed: true,
      playerColor: existing?.playerColor ?? 'white',
      opponentName: existing?.opponentName ?? 'Stockfish AI',
      roundIndex: existing?.roundIndex,
      islandTitle: existing?.islandTitle,
      stockfishLevel: existing?.stockfishLevel ?? 5,
      status: existing?.status ?? 'completed',
      result: existing?.result ?? 'completed',
      resultReason: existing?.resultReason,
      accuracy: accuracy, // Replace overall accuracy with Deep Analysis accuracy
      liveAccuracy: existing?.liveAccuracy ?? accuracy,
      deepAccuracy: accuracy,
      moveCount: moveLog.length,
      pgn: pgn,
      fen: moveLog.isNotEmpty
          ? (moveLog.last['fenAfter'] as String? ?? existing?.fen ?? '')
          : (existing?.fen ?? ''),
      moveLog: moveLog, // Replace move log with Deep Game Analysis
      liveMoveLog: moveLog, // Replace live move log with Deep Game Analysis
      deepMoveLog: moveLog, // Set deep move log
      pieceTheme: existing?.pieceTheme ?? 'Standered',
      startedAt: existing?.startedAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      completedAt: existing?.completedAt ?? DateTime.now(),
    );

    // 1. Store updated Deep Analysis in local device cache
    await LocalMatchCacheService.instance.cacheMatch(updatedMatch);

    if (InternetConnectivityService.instance.isOnline) {
      try {
        // 2. Save root match document to matches_history
        await _matchesRef().doc(matchId).set(updatedMatch.toFirestoreMap(), SetOptions(merge: true));

        // 3. Write deep move analysis documents to move_analysis_detail subcollection (1..N)
        await _writeMoveAnalysisToFirestore(matchId, moveLog, FirestoreConstants.analysisTypeDeep);

        debugPrint('[MATCH_HISTORY] Deep analysis saved to Firestore for match $matchId and move_analysis_detail updated.');
      } catch (e) {
        debugPrint('[MATCH_HISTORY] Error updating deep analysis in Firestore ($e). Preserved in local cache.');
      }
    }
  }

  /// Complete and finalize a match in local device cache and Firestore.
  /// Saves ALL completed or surrendered matches regardless of move count!
  Future<void> completeMatchRecord({
    required String matchId,
    String matchType = 'quick_match',
    String playerColor = 'white',
    String opponentName = 'Stockfish AI',
    int stockfishLevel = 5,
    int? roundIndex,
    String? islandTitle,
    String? islandId,
    String pieceTheme = 'Standered',
    DateTime? startedAt,
    required String status,
    required String result,
    String? resultReason,
    int accuracy = 0,
    bool isDeepAnalyzed = false,
    bool isLiveAnalyzed = false,
    required String pgn,
    List<Map<String, dynamic>>? finalMoveLog,
  }) async {
    final userId = _currentUserId;

    final cached = await getMatchRecordById(matchId, userId: userId);
    final resolvedMatchType = matchType;
    final resolvedPlayerColor = playerColor;
    final resolvedOpponentName = opponentName;
    final resolvedStockfishLevel = stockfishLevel;
    final resolvedRoundIndex = roundIndex ?? cached?.roundIndex;
    final resolvedIslandTitle = islandTitle ?? cached?.islandTitle;

    final resolvedIslandId = islandId ??
        cached?.islandId ??
        (resolvedMatchType == 'training' && resolvedIslandTitle != null && _parseIslandIndexFromTitle(resolvedIslandTitle) > 0
            ? '${_parseIslandIndexFromTitle(resolvedIslandTitle)}'
            : null);

    final resolvedPieceTheme = (pieceTheme != 'Standered' && pieceTheme.isNotEmpty)
        ? pieceTheme
        : (cached?.pieceTheme.isNotEmpty == true ? cached!.pieceTheme : pieceTheme);
    final resolvedStartedAt = startedAt ?? cached?.startedAt ?? DateTime.now();

    final liveLog = (finalMoveLog != null && finalMoveLog.isNotEmpty)
        ? finalMoveLog
        : (cached?.liveMoveLog.isNotEmpty == true ? cached!.liveMoveLog : (cached?.moveLog ?? []));

    final movesCount = liveLog.length;

    // Only discard if match was aborted before any moves were played
    if (movesCount == 0) {
      debugPrint('[MATCH_HISTORY] Match $matchId has 0 moves. Discarding & deleting match record.');
      await deleteMatchRecord(matchId);
      return;
    }

    // Determine analyzer mode: only set to 'live_game_analysis' if live analysis was actually performed
    final String resolvedAnalyzerMode;
    final int resolvedAccuracy;
    final int resolvedLiveAccuracy;
    if (isDeepAnalyzed) {
      resolvedAnalyzerMode = 'deep_game_analysis';
      resolvedAccuracy = accuracy;
      resolvedLiveAccuracy = accuracy;
    } else if (isLiveAnalyzed || accuracy > 0) {
      resolvedAnalyzerMode = 'live_game_analysis';
      resolvedAccuracy = accuracy;
      resolvedLiveAccuracy = accuracy;
    } else {
      resolvedAnalyzerMode = 'none';
      resolvedAccuracy = 0;
      resolvedLiveAccuracy = 0;
    }

    final completedMatch = MatchRecordModel(
      id: matchId,
      userId: userId,
      boardId: cached?.boardId,
      islandId: resolvedIslandId,
      matchType: resolvedMatchType,
      analyzerMode: resolvedAnalyzerMode,
      deepAnalyzed: isDeepAnalyzed,
      playerColor: resolvedPlayerColor,
      opponentName: resolvedOpponentName,
      roundIndex: resolvedRoundIndex,
      islandTitle: resolvedIslandTitle,
      stockfishLevel: resolvedStockfishLevel,
      status: status,
      result: result,
      resultReason: resultReason,
      accuracy: resolvedAccuracy,
      liveAccuracy: resolvedLiveAccuracy,
      deepAccuracy: cached?.deepAccuracy,
      moveCount: movesCount,
      pgn: pgn,
      fen: liveLog.isNotEmpty
          ? (liveLog.last['fenAfter'] as String? ?? '')
          : (cached?.fen ?? ''),
      moveLog: liveLog,
      liveMoveLog: liveLog,
      deepMoveLog: cached?.deepMoveLog,
      pieceTheme: resolvedPieceTheme,
      startedAt: resolvedStartedAt,
      updatedAt: DateTime.now(),
      completedAt: DateTime.now(),
    );

    // ALWAYS store completed match in local device cache first
    await LocalMatchCacheService.instance.cacheMatch(completedMatch);

    if (InternetConnectivityService.instance.isOnline) {
      try {
        // 1. Save match document to matches_history collection
        await _matchesRef().doc(matchId).set(completedMatch.toFirestoreMap(), SetOptions(merge: true));

        // 2. Save move_analysis_detail subcollection documents (1..N)
        if (completedMatch.liveMoveLog.isNotEmpty) {
          await _writeMoveAnalysisToFirestore(matchId, completedMatch.liveMoveLog, FirestoreConstants.analysisTypeLive);
        }
        if (completedMatch.deepMoveLog != null && completedMatch.deepMoveLog!.isNotEmpty) {
          await _writeMoveAnalysisToFirestore(matchId, completedMatch.deepMoveLog!, FirestoreConstants.analysisTypeDeep);
        }

        debugPrint(
          '[MATCH_HISTORY] Match $matchId finalized in Firestore with matchType=$resolvedMatchType, island_id=$resolvedIslandId, movesCount=$movesCount, result=$result.',
        );
      } catch (e) {
        debugPrint(
          '[MATCH_HISTORY] Error completing match in Firestore ($e). Preserved in local cache.',
        );
      }
    }
  }

  /// Helper to merge a list of Firestore documents and local cached matches seamlessly.
  List<MatchRecordModel> _mergeMatchLists(
    List<MatchRecordModel> firestoreList,
    List<MatchRecordModel> cachedList,
    String? filterMatchType,
  ) {
    final Map<String, MatchRecordModel> map = {};

    for (final m in firestoreList) {
      if (filterMatchType != null && m.matchType != filterMatchType) continue;
      map[m.id] = m;
    }

    for (final cached in cachedList) {
      if (filterMatchType != null && cached.matchType != filterMatchType) {
        continue;
      }

      if (!map.containsKey(cached.id)) {
        map[cached.id] = cached;
      } else {
        final existing = map[cached.id]!;
        if (cached.deepAnalyzed || cached.updatedAt.isAfter(existing.updatedAt) || cached.liveMoveLog.length > existing.liveMoveLog.length) {
          map[cached.id] = cached;
        }
      }
    }

    final combined = map.values
        .where((m) => m.moveCount > 4 || m.liveMoveLog.length > 4)
        .toList();
    combined.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return combined;
  }

  /// Real-time Stream of matches for a user, combining local cache & Firestore snapshots.
  Stream<List<MatchRecordModel>> streamUserMatches({
    String? userId,
    required String matchType,
  }) {
    final controller = StreamController<List<MatchRecordModel>>.broadcast();
    final targetUserId = (userId != null && userId.isNotEmpty) ? userId : _currentUserId;

    List<MatchRecordModel> currentFirestore = [];
    List<MatchRecordModel> currentCached = [];

    void emitMerged() {
      final merged = _mergeMatchLists(
        currentFirestore,
        currentCached,
        matchType,
      );
      if (!controller.isClosed) {
        controller.add(merged);
      }
    }

    StreamSubscription? cacheSub;
    StreamSubscription? firestoreSub;

    controller.onListen = () {
      LocalMatchCacheService.instance.getCachedMatches(targetUserId: targetUserId).then((cachedList) {
        currentCached = cachedList;
        emitMerged();
      });

      cacheSub = LocalMatchCacheService.instance.onCacheChanged.listen((cachedList) {
        currentCached = cachedList;
        emitMerged();
      });

      try {
        Query<Map<String, dynamic>> query = _matchesRef().where('user_id', isEqualTo: targetUserId);
        query = query.where('match_type', isEqualTo: matchType);

        firestoreSub = query.snapshots().listen(
          (snapshot) {
            currentFirestore = snapshot.docs
                .map((doc) => MatchRecordModel.fromFirestoreDoc(doc))
                .toList();
            emitMerged();
          },
          onError: (e) {
            debugPrint('[MATCH_HISTORY] Firestore stream error ($e). Continuing with local cache.');
            emitMerged();
          },
        );
      } catch (e) {
        debugPrint('[MATCH_HISTORY] Firestore setup error ($e). Continuing with local cache.');
        emitMerged();
      }
    };

    controller.onCancel = () {
      cacheSub?.cancel();
      firestoreSub?.cancel();
    };

    return controller.stream;
  }

  /// Stream of all user matches combining local cache & Firestore.
  Stream<List<MatchRecordModel>> streamAllUserMatches({String? userId}) {
    final controller = StreamController<List<MatchRecordModel>>.broadcast();
    final targetUserId = (userId != null && userId.isNotEmpty) ? userId : _currentUserId;

    List<MatchRecordModel> currentFirestore = [];
    List<MatchRecordModel> currentCached = [];

    void emitMerged() {
      final merged = _mergeMatchLists(currentFirestore, currentCached, null);
      if (!controller.isClosed) {
        controller.add(merged);
      }
    }

    StreamSubscription? cacheSub;
    StreamSubscription? firestoreSub;

    controller.onListen = () {
      LocalMatchCacheService.instance.getCachedMatches(targetUserId: targetUserId).then((cachedList) {
        currentCached = cachedList;
        emitMerged();
      });

      cacheSub = LocalMatchCacheService.instance.onCacheChanged.listen((cachedList) {
        currentCached = cachedList;
        emitMerged();
      });

      try {
        firestoreSub = _matchesRef().where('user_id', isEqualTo: targetUserId).snapshots().listen(
          (snapshot) {
            currentFirestore = snapshot.docs
                .map((doc) => MatchRecordModel.fromFirestoreDoc(doc))
                .toList();
            emitMerged();
          },
          onError: (e) {
            debugPrint('[MATCH_HISTORY] Firestore stream error ($e). Continuing with local cache.');
            emitMerged();
          },
        );
      } catch (e) {
        debugPrint('[MATCH_HISTORY] Firestore setup error ($e). Continuing with local cache.');
        emitMerged();
      }
    };

    controller.onCancel = () {
      cacheSub?.cancel();
      firestoreSub?.cancel();
    };

    return controller.stream;
  }

  /// Real-time stream of a specific match record by ID combining local device cache & Firestore snapshots.
  Stream<MatchRecordModel?> streamMatchRecordById(String matchId, {String? userId}) {
    final controller = StreamController<MatchRecordModel?>.broadcast();
    final targetUserId = (userId != null && userId.isNotEmpty) ? userId : _currentUserId;

    StreamSubscription? cacheSub;
    StreamSubscription? firestoreSub;

    controller.onListen = () {
      // 1. Immediately emit current cached match if available
      getMatchRecordById(matchId, userId: targetUserId).then((cached) {
        if (!controller.isClosed && cached != null) {
          controller.add(cached);
        }
      });

      // 2. Listen to local cache changes
      cacheSub = LocalMatchCacheService.instance.onCacheChanged.listen((matches) {
        MatchRecordModel? match;
        for (final m in matches) {
          if (m.id == matchId) {
            match = m;
            break;
          }
        }
        if (match != null && !controller.isClosed) {
          controller.add(match);
        }
      });

      // 3. Listen to Firestore match document updates
      try {
        firestoreSub = _matchesRef().doc(matchId).snapshots().listen(
          (snapshot) async {
            if (snapshot.exists && snapshot.data() != null) {
              final docMatch = MatchRecordModel.fromFirestoreDoc(snapshot);
              final cached = await LocalMatchCacheService.instance.getCachedMatchById(matchId);
              final merged = MatchRecordModel(
                id: docMatch.id,
                userId: docMatch.userId,
                boardId: docMatch.boardId ?? cached?.boardId,
                islandId: docMatch.islandId ?? cached?.islandId,
                matchType: docMatch.matchType,
                analyzerMode: docMatch.analyzerMode,
                deepAnalyzed: docMatch.deepAnalyzed || (cached?.deepAnalyzed ?? false),
                playerColor: docMatch.playerColor,
                opponentName: docMatch.opponentName,
                roundIndex: docMatch.roundIndex ?? cached?.roundIndex,
                islandTitle: docMatch.islandTitle ?? cached?.islandTitle,
                stockfishLevel: docMatch.stockfishLevel,
                status: docMatch.status,
                result: docMatch.result,
                resultReason: docMatch.resultReason ?? cached?.resultReason,
                accuracy: docMatch.accuracy,
                liveAccuracy: docMatch.liveAccuracy,
                deepAccuracy: docMatch.deepAccuracy ?? cached?.deepAccuracy,
                moveCount: docMatch.moveCount,
                pgn: docMatch.pgn,
                fen: docMatch.fen,
                moveLog: (cached?.moveLog != null && cached!.moveLog.isNotEmpty) ? cached.moveLog : docMatch.moveLog,
                liveMoveLog: (cached?.liveMoveLog != null && cached!.liveMoveLog.isNotEmpty) ? cached.liveMoveLog : docMatch.liveMoveLog,
                deepMoveLog: (cached?.deepMoveLog != null && cached!.deepMoveLog!.isNotEmpty) ? cached.deepMoveLog : docMatch.deepMoveLog,
                pieceTheme: docMatch.pieceTheme,
                startedAt: docMatch.startedAt,
                updatedAt: docMatch.updatedAt,
                completedAt: docMatch.completedAt ?? cached?.completedAt,
              );
              if (!controller.isClosed) {
                controller.add(merged);
              }
            }
          },
          onError: (e) {
            debugPrint('[MATCH_HISTORY] Firestore match stream notice: $e');
          },
        );
      } catch (e) {
        debugPrint('[MATCH_HISTORY] Firestore setup notice: $e');
      }
    };

    controller.onCancel = () {
      cacheSub?.cancel();
      firestoreSub?.cancel();
    };

    return controller.stream;
  }

  /// One-time fetch of user matches.
  Future<List<MatchRecordModel>> getUserMatches({
    String? userId,
    required String matchType,
  }) async {
    final targetUserId = (userId != null && userId.isNotEmpty) ? userId : _currentUserId;
    List<MatchRecordModel> firestoreList = [];

    if (InternetConnectivityService.instance.isOnline) {
      try {
        final snapshot = await _matchesRef()
            .where('user_id', isEqualTo: targetUserId)
            .where('match_type', isEqualTo: matchType)
            .get();
        firestoreList = snapshot.docs
            .map((doc) => MatchRecordModel.fromFirestoreDoc(doc))
            .toList();
      } catch (e) {
        debugPrint('[MATCH_HISTORY] Error fetching user matches from Firestore: $e');
      }
    }

    final cachedList = await LocalMatchCacheService.instance.getCachedMatches(targetUserId: targetUserId);
    return _mergeMatchLists(firestoreList, cachedList, matchType);
  }

  /// One-time fetch of a single match record by ID.
  /// Returns immediately from local device cache (0ms lag) when available,
  /// falling back to Firestore if missing.
  Future<MatchRecordModel?> getMatchRecordById(
    String matchId, {
    String? userId,
  }) async {
    final targetUserId = (userId != null && userId.isNotEmpty) ? userId : _currentUserId;

    // 1. Check local device cache FIRST for instant response (0ms lag)
    final cachedList = await LocalMatchCacheService.instance.getCachedMatches(targetUserId: targetUserId);
    for (final m in cachedList) {
      if (m.id == matchId && (m.liveMoveLog.isNotEmpty || m.moveLog.isNotEmpty)) {
        debugPrint('[MATCH_HISTORY] Match $matchId retrieved instantly from local cache (0ms lag).');
        return m;
      }
    }

    // 2. If missing from cache or cache has empty moves, fetch from Firestore
    if (InternetConnectivityService.instance.isOnline) {
      try {
        final doc = await _matchesRef().doc(matchId).get();
        if (doc.exists && doc.data() != null) {
          var matchData = doc.data()!;

          // Read move analysis subcollection documents exclusively from Firestore
          final liveMoves = await _readMoveAnalysisFromFirestore(matchId, analysisType: FirestoreConstants.analysisTypeLive);
          final deepMoves = await _readMoveAnalysisFromFirestore(matchId, analysisType: FirestoreConstants.analysisTypeDeep);

          if (deepMoves.isNotEmpty) {
            matchData['deep_move_log'] = deepMoves;
            matchData['move_log'] = deepMoves;
          }
          if (liveMoves.isNotEmpty) {
            matchData['live_move_log'] = liveMoves;
            if (deepMoves.isEmpty) {
              matchData['move_log'] = liveMoves;
            }
          }

          final firestoreMatch = MatchRecordModel.fromMap(matchData, matchId);
          await LocalMatchCacheService.instance.cacheMatch(firestoreMatch);
          return firestoreMatch;
        }
      } catch (e) {
        debugPrint('[MATCH_HISTORY] Error fetching match record from Firestore: $e');
      }
    }

    // Fallback: return any matching cached record even if move log is empty
    for (final m in cachedList) {
      if (m.id == matchId) return m;
    }

    return null;
  }

  /// Delete a match document from Firestore & local cache by matchId.
  Future<void> deleteMatchRecord(String matchId, {String? userId}) async {
    final targetUserId = (userId != null && userId.isNotEmpty) ? userId : _currentUserId;
    await LocalMatchCacheService.instance.removeCachedMatch(matchId, targetUserId: targetUserId);
    if (InternetConnectivityService.instance.isOnline) {
      try {
        await _matchesRef().doc(matchId).delete();
        debugPrint('[MATCH_HISTORY] Match $matchId deleted from Firestore.');
      } catch (e) {
        debugPrint('[MATCH_HISTORY] Error deleting match record: $e');
      }
    }
  }
}
