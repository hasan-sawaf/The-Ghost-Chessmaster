import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/services/connectivity_service.dart';
import '../../../models/firestore_constants.dart';
import '../../../models/island_model.dart';
import '../../../models/user_island_model.dart';

/// Data model representing campaign progress for an island (UI-layer view model).
/// Wraps [UserIslandModel] with additional round-game tracking for local cache.
class IslandProgressModel {
  final int islandIndex;
  final int completedRounds; // 0..4
  final bool isUnlocked;
  final Map<int, String> roundLastGameIds; // roundIndex (1..4) -> matchId

  IslandProgressModel({
    required this.islandIndex,
    required this.completedRounds,
    required this.isUnlocked,
    required this.roundLastGameIds,
  });

  bool get isComplete => completedRounds >= 4;

  /// Converts to a map for local SharedPreferences cache storage.
  Map<String, dynamic> toMap() {
    final Map<String, String> stringGameIds = {};
    roundLastGameIds.forEach((k, v) {
      stringGameIds[k.toString()] = v;
    });

    return {
      'islandIndex': islandIndex,
      'completedRounds': completedRounds,
      'isUnlocked': isUnlocked,
      'roundLastGameIds': stringGameIds,
    };
  }

  factory IslandProgressModel.fromMap(Map<String, dynamic> map, int index) {
    final rawGames = map['roundLastGameIds'] as Map<String, dynamic>? ?? {};
    final Map<int, String> parsedGames = {};
    rawGames.forEach((k, v) {
      final roundIdx = int.tryParse(k.toString());
      if (roundIdx != null && v is String) {
        parsedGames[roundIdx] = v;
      }
    });

    return IslandProgressModel(
      islandIndex: map['islandIndex'] as int? ?? index,
      completedRounds: map['completedRounds'] as int? ?? 0,
      isUnlocked: map['isUnlocked'] as bool? ?? (index == 1),
      roundLastGameIds: parsedGames,
    );
  }

  /// Constructs from a [UserIslandModel] Firestore document + local round game IDs.
  factory IslandProgressModel.fromUserIsland(UserIslandModel model, Map<int, String> roundGameIds) {
    final mergedGames = Map<int, String>.from(roundGameIds);
    if (model.roundOneMatchId != null && model.roundOneMatchId!.isNotEmpty) {
      mergedGames[1] = model.roundOneMatchId!;
    }
    if (model.roundTwoMatchId != null && model.roundTwoMatchId!.isNotEmpty) {
      mergedGames[2] = model.roundTwoMatchId!;
    }
    if (model.roundThreeMatchId != null && model.roundThreeMatchId!.isNotEmpty) {
      mergedGames[3] = model.roundThreeMatchId!;
    }
    if (model.roundFourMatchId != null && model.roundFourMatchId!.isNotEmpty) {
      mergedGames[4] = model.roundFourMatchId!;
    }

    return IslandProgressModel(
      islandIndex: model.islandId,
      completedRounds: model.completedRounds,
      isUnlocked: model.isUnlocked,
      roundLastGameIds: mergedGames,
    );
  }

  /// Converts to [UserIslandModel] for Firestore serialization with all 4 round match IDs.
  UserIslandModel toUserIsland(String userId) {
    return UserIslandModel(
      userId: userId,
      islandId: islandIndex,
      completedRounds: completedRounds,
      isUnlocked: isUnlocked,
      isCompleted: isComplete,
      roundOneMatchId: roundLastGameIds[1],
      roundTwoMatchId: roundLastGameIds[2],
      roundThreeMatchId: roundLastGameIds[3],
      roundFourMatchId: roundLastGameIds[4],
    );
  }
}

/// Service managing island campaign progress, round game IDs, local caching, and offline Firebase sync.
/// Strictly scoped per User ID to prevent cross-account cache leakage.
///
/// Uses root `user_island` Firestore collection with composite document IDs: `{userId}_{islandId}`.
class TrainingCampaignService {
  static final TrainingCampaignService _instance = TrainingCampaignService._internal();
  static TrainingCampaignService get instance => _instance;
  TrainingCampaignService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String _roundsKey(String userId) => 'training_campaign_completed_rounds_v2_$userId';
  String _lastGamesKey(String userId) => 'training_campaign_last_games_v2_$userId';
  String _pendingSyncKey(String userId) => 'training_campaign_pending_sync_v2_$userId';

  final StreamController<Map<int, IslandProgressModel>> _campaignStreamController =
      StreamController<Map<int, IslandProgressModel>>.broadcast();

  Stream<Map<int, IslandProgressModel>> get onCampaignChanged => _campaignStreamController.stream;

  String get _currentUserId {
    final uid = _auth.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) return uid;
    return 'guest_user';
  }

  /// Reference to parent document `user_island/{userId}`.
  DocumentReference<Map<String, dynamic>> _userParentDocRef(String userId) {
    return _firestore
        .collection(FirestoreConstants.userIslandCollection)
        .doc(userId);
  }

  /// Reference to a specific user-island document in `user_island/{userId}/islands/{islandId}`.
  DocumentReference<Map<String, dynamic>> _userIslandDocRef(String userId, int islandId) {
    return _userParentDocRef(userId)
        .collection(FirestoreConstants.userIslandSubcollection)
        .doc('$islandId');
  }

  /// Query all user-island documents for a specific user under `user_island/{userId}/islands/`.
  CollectionReference<Map<String, dynamic>> _userIslandQuery(String userId) {
    return _userParentDocRef(userId)
        .collection(FirestoreConstants.userIslandSubcollection);
  }

  /// Seeds the static `islands` collection in Firestore with the 20 default training island definitions,
  /// including `hint_num`, `time`, and `inc_time` configuration fields.
  Future<void> seedDefaultIslands() async {
    if (!InternetConnectivityService.instance.isOnline) return;

    try {
      final collectionRef = _firestore.collection(FirestoreConstants.islandsCollection);
      debugPrint('[ISLANDS_SEED] Seeding/Updating static islands collection in Firestore (${IslandModel.defaultIslands.length} islands)...');
      final batch = _firestore.batch();

      for (final island in IslandModel.defaultIslands) {
        final docRef = collectionRef.doc(island.id.toString());
        batch.set(docRef, island.toMap(), SetOptions(merge: true));
      }

      await batch.commit();
      debugPrint('[ISLANDS_SEED] Successfully uploaded/updated all 20 training islands in Firestore islands collection.');
    } catch (e) {
      debugPrint('[ISLANDS_SEED] Error seeding islands collection: $e');
    }
  }

  /// Initialize service & perform initial sync check for active user
  Future<void> initialize({String? userId}) async {
    final activeUserId = (userId != null && userId.isNotEmpty) ? userId : _currentUserId;
    await loadCampaignProgress(targetUserId: activeUserId);
    if (InternetConnectivityService.instance.isOnline) {
      await seedDefaultIslands();
      await syncCampaignToFirebase(userId: activeUserId);
    }
  }

  /// Triggered on sign out to clear session campaign state
  void onUserSignedOut() {
    debugPrint('[CAMPAIGN_CACHE] Closing campaign session on sign out.');
    final Map<int, IslandProgressModel> defaultMap = {};
    for (int i = 1; i <= FirestoreConstants.totalIslands; i++) {
      defaultMap[i] = IslandProgressModel(
        islandIndex: i,
        completedRounds: 0,
        isUnlocked: i == 1,
        roundLastGameIds: {},
      );
    }
    if (!_campaignStreamController.isClosed) {
      _campaignStreamController.add(defaultMap);
    }
  }

  /// Load campaign progress from local device cache first, then merge with Firebase Firestore
  Future<Map<int, IslandProgressModel>> loadCampaignProgress({String? targetUserId}) async {
    final activeUserId = (targetUserId != null && targetUserId.isNotEmpty) ? targetUserId : _currentUserId;
    final prefs = await SharedPreferences.getInstance();

    final userRoundsKey = _roundsKey(activeUserId);
    final userGamesKey = _lastGamesKey(activeUserId);

    // 1. Read local cached completed rounds for target user
    String? roundsJsonStr = prefs.getString(userRoundsKey);
    if (roundsJsonStr == null && prefs.containsKey('training_campaign_completed_rounds_v2')) {
      roundsJsonStr = prefs.getString('training_campaign_completed_rounds_v2');
      if (roundsJsonStr != null) {
        await prefs.setString(userRoundsKey, roundsJsonStr);
      }
    }

    final Map<int, int> cachedRounds = {1: 0};
    if (roundsJsonStr != null && roundsJsonStr.isNotEmpty) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(roundsJsonStr);
        parsed.forEach((k, v) {
          final idx = int.tryParse(k);
          if (idx != null && v is int) {
            cachedRounds[idx] = v;
          }
        });
      } catch (e) {
        debugPrint('[CAMPAIGN_CACHE] Error parsing cached rounds: $e');
      }
    }

    // 2. Read local cached last played round games for target user
    String? gamesJsonStr = prefs.getString(userGamesKey);
    if (gamesJsonStr == null && prefs.containsKey('training_campaign_last_games_v2')) {
      gamesJsonStr = prefs.getString('training_campaign_last_games_v2');
      if (gamesJsonStr != null) {
        await prefs.setString(userGamesKey, gamesJsonStr);
      }
    }

    final Map<String, String> cachedGames = {}; // "islandIndex_roundIndex" -> matchId
    if (gamesJsonStr != null && gamesJsonStr.isNotEmpty) {
      try {
        final Map<String, dynamic> parsed = jsonDecode(gamesJsonStr);
        parsed.forEach((k, v) {
          if (v is String) {
            cachedGames[k] = v;
          }
        });
      } catch (e) {
        debugPrint('[CAMPAIGN_CACHE] Error parsing cached last games: $e');
      }
    }

    // Build local IslandProgressModel map
    final Map<int, IslandProgressModel> localMap = {};
    for (int i = 1; i <= FirestoreConstants.totalIslands; i++) {
      final completed = cachedRounds[i] ?? 0;
      final prevCompleted = i == 1 ? 4 : (cachedRounds[i - 1] ?? 0);
      final unlocked = i == 1 || prevCompleted >= 4;

      final Map<int, String> roundGames = {};
      for (int r = 1; r <= FirestoreConstants.roundsPerIsland; r++) {
        final key = '${i}_$r';
        if (cachedGames.containsKey(key)) {
          roundGames[r] = cachedGames[key]!;
        }
      }

      localMap[i] = IslandProgressModel(
        islandIndex: i,
        completedRounds: completed,
        isUnlocked: unlocked,
        roundLastGameIds: roundGames,
      );
    }

    _campaignStreamController.add(localMap);

    // 3. If online, seed static islands collection if missing and fetch from Firebase Firestore `user_island` collection and merge
    if (InternetConnectivityService.instance.isOnline) {
      seedDefaultIslands();
      try {
        final querySnapshot = await _userIslandQuery(activeUserId).get();

        if (querySnapshot.docs.isNotEmpty) {
          for (final doc in querySnapshot.docs) {
            final remoteModel = UserIslandModel.fromSnapshot(doc);
            final islandIdx = remoteModel.islandId;
            final localModel = localMap[islandIdx];

            void mergeRoundMatchId(int roundNum, String? remoteMatchId) {
              if (remoteMatchId != null && remoteMatchId.isNotEmpty) {
                final key = '${islandIdx}_$roundNum';
                if (!cachedGames.containsKey(key) || cachedGames[key]!.isEmpty) {
                  cachedGames[key] = remoteMatchId;
                }
              }
            }

            mergeRoundMatchId(1, remoteModel.roundOneMatchId);
            mergeRoundMatchId(2, remoteModel.roundTwoMatchId);
            mergeRoundMatchId(3, remoteModel.roundThreeMatchId);
            mergeRoundMatchId(4, remoteModel.roundFourMatchId);

            if (localModel == null || remoteModel.completedRounds > localModel.completedRounds) {
              cachedRounds[islandIdx] = remoteModel.completedRounds;
            }
          }

          // Re-save merged data locally for target user
          await _saveLocalCache(prefs, cachedRounds, cachedGames, userId: activeUserId);
          
          // Re-build final map
          for (int i = 1; i <= FirestoreConstants.totalIslands; i++) {
            final completed = cachedRounds[i] ?? 0;
            final prevCompleted = i == 1 ? 4 : (cachedRounds[i - 1] ?? 0);
            final unlocked = i == 1 || prevCompleted >= 4;

            final Map<int, String> roundGames = {};
            for (int r = 1; r <= FirestoreConstants.roundsPerIsland; r++) {
              final key = '${i}_$r';
              if (cachedGames.containsKey(key)) {
                roundGames[r] = cachedGames[key]!;
              }
            }

            localMap[i] = IslandProgressModel(
              islandIndex: i,
              completedRounds: completed,
              isUnlocked: unlocked,
              roundLastGameIds: roundGames,
            );
          }
          _campaignStreamController.add(localMap);
        }
      } catch (e) {
        debugPrint('[CAMPAIGN_FIREBASE] Error fetching remote campaign progress ($e). Used local cache.');
      }
    }

    return localMap;
  }

  /// Save round completion & last played game for a played round (win, lose, or surrender)
  Future<void> recordPlayedRoundGame({
    required int islandIndex,
    required int roundIndex,
    required String matchId,
    required bool isWin,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _currentUserId;

    // 1. Read existing local cache for active user
    final currentProgress = await loadCampaignProgress(targetUserId: userId);

    final islandModel = currentProgress[islandIndex] ??
        IslandProgressModel(
          islandIndex: islandIndex,
          completedRounds: 0,
          isUnlocked: islandIndex == 1,
          roundLastGameIds: {},
        );

    int newCompletedRounds = islandModel.completedRounds;

    // If user WON this round, advance completed rounds count if roundIndex is greater
    if (isWin) {
      if (roundIndex > newCompletedRounds) {
        newCompletedRounds = roundIndex.clamp(0, FirestoreConstants.roundsPerIsland);
      }
    }

    final Map<int, String> updatedRoundGames = Map.from(islandModel.roundLastGameIds);
    updatedRoundGames[roundIndex] = matchId;

    // Update memory map
    final Map<int, int> roundsMap = {};
    final Map<String, String> gamesMap = {};

    currentProgress.forEach((idx, model) {
      roundsMap[idx] = model.completedRounds;
      model.roundLastGameIds.forEach((r, gId) {
        gamesMap['${idx}_$r'] = gId;
      });
    });

    roundsMap[islandIndex] = newCompletedRounds;
    gamesMap['${islandIndex}_$roundIndex'] = matchId;

    // If island is now 4/4 complete, ensure next island is unlocked
    if (newCompletedRounds >= FirestoreConstants.roundsPerIsland && islandIndex < FirestoreConstants.totalIslands) {
      roundsMap.putIfAbsent(islandIndex + 1, () => 0);
    }

    // 2. ALWAYS save to local device cache first under user ID
    await _saveLocalCache(prefs, roundsMap, gamesMap, userId: userId);
    await prefs.setBool(_pendingSyncKey(userId), true);

    // Notify listeners immediately
    await loadCampaignProgress(targetUserId: userId);

    // 3. If online, push update directly to Firebase Firestore `user_island` collection
    if (InternetConnectivityService.instance.isOnline) {
      await syncCampaignToFirebase(userId: userId);
    }
  }

  /// Sync all pending local campaign progress & 4 round game IDs to Firebase Firestore `user_island` collection.
  /// Uses batch writes for efficiency (up to 20 island documents).
  Future<void> syncCampaignToFirebase({String? userId}) async {
    if (!InternetConnectivityService.instance.isOnline) {
      debugPrint('[CAMPAIGN_SYNC] Device offline. Skipping campaign sync.');
      return;
    }

    final activeUserId = (userId != null && userId.isNotEmpty) ? userId : _currentUserId;

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentMap = await loadCampaignProgress(targetUserId: activeUserId);

      // Ensure parent document user_island/{userId} exists in Firestore
      await _userParentDocRef(activeUserId).set({
        'user_id': activeUserId,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final batch = _firestore.batch();
      int batchCount = 0;

      currentMap.forEach((islandIdx, model) {
        if (model.completedRounds > 0 || model.roundLastGameIds.isNotEmpty || model.isUnlocked) {
          final userIsland = model.toUserIsland(activeUserId);
          final docRef = _userIslandDocRef(activeUserId, islandIdx);
          batch.set(docRef, userIsland.toMap(), SetOptions(merge: true));
          batchCount++;
        }
      });

      if (batchCount == 0) return;

      await batch.commit();
      await prefs.setBool(_pendingSyncKey(activeUserId), false);
      debugPrint('[CAMPAIGN_SYNC] Successfully synced $batchCount island(s) to user_island/$activeUserId/islands/ in Firestore.');
    } catch (e) {
      debugPrint('[CAMPAIGN_SYNC] Error syncing campaign progress to Firestore: $e');
    }
  }

  /// Get the stored game ID for a specific island & round
  Future<String?> getLastGameIdForRound(int islandIndex, int roundIndex, {String? userId}) async {
    final campaign = await loadCampaignProgress(targetUserId: userId);
    final island = campaign[islandIndex];
    return island?.roundLastGameIds[roundIndex];
  }

  Future<void> _saveLocalCache(
    SharedPreferences prefs,
    Map<int, int> roundsMap,
    Map<String, String> gamesMap, {
    String? userId,
  }) async {
    final activeUserId = (userId != null && userId.isNotEmpty) ? userId : _currentUserId;
    final Map<String, int> roundsJsonMap = {};
    roundsMap.forEach((k, v) => roundsJsonMap[k.toString()] = v);
    await prefs.setString(_roundsKey(activeUserId), jsonEncode(roundsJsonMap));
    await prefs.setString(_lastGamesKey(activeUserId), jsonEncode(gamesMap));
  }
}
