import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models/match_record_model.dart';

/// Local cache service for persisting chess matches offline in SharedPreferences.
/// Secured by User ID: Cross-user caching is strictly blocked so that when a user
/// signs out and another logs in, cached data from one account is never visible to another.
class LocalMatchCacheService {
  static final LocalMatchCacheService _instance = LocalMatchCacheService._internal();
  static LocalMatchCacheService get instance => _instance;
  LocalMatchCacheService._internal();

  final StreamController<List<MatchRecordModel>> _cacheStreamController =
      StreamController<List<MatchRecordModel>>.broadcast();

  Stream<List<MatchRecordModel>> get onCacheChanged => _cacheStreamController.stream;

  String _getCacheKey(String userId) => 'offline_cached_matches_$userId';

  String get _currentUserId {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && uid.isNotEmpty) return uid;
    return 'guest_user';
  }

  /// Triggered on user sign-in to establish cache access for the authenticated user ID.
  Future<void> onUserSignedIn(String userId) async {
    debugPrint('[LOCAL_CACHE] Establishing cache session for user: $userId');
    final matches = await getCachedMatches(targetUserId: userId);
    if (!_cacheStreamController.isClosed) {
      _cacheStreamController.add(matches);
    }
  }

  /// Triggered on user sign-out to close cache session and clear in-memory emissions.
  void onUserSignedOut() {
    debugPrint('[LOCAL_CACHE] Closing cache session on sign out.');
    if (!_cacheStreamController.isClosed) {
      _cacheStreamController.add([]);
    }
  }

  void _notifyListeners([String? userId]) {
    final targetId = userId ?? _currentUserId;
    getCachedMatches(targetUserId: targetId).then((list) {
      if (!_cacheStreamController.isClosed) {
        _cacheStreamController.add(list);
      }
    });
  }

  /// Saves or updates a match record in local device cache under the user's ID.
  Future<void> cacheMatch(MatchRecordModel match) async {
    if (match.moveCount == 0 && match.status == 'in_progress') {
      debugPrint('[LOCAL_CACHE] Skipping cache for unstarted match ${match.id}.');
      return;
    }

    final targetUserId = match.userId.isNotEmpty ? match.userId : _currentUserId;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = _getCacheKey(targetUserId);
      final List<String> cachedList = prefs.getStringList(userKey) ?? [];

      final Map<String, dynamic> matchMap = match.toMap();
      matchMap['userId'] = targetUserId;
      matchMap['startedAt'] = match.startedAt.toIso8601String();
      matchMap['updatedAt'] = match.updatedAt.toIso8601String();
      if (match.completedAt != null) {
        matchMap['completedAt'] = match.completedAt!.toIso8601String();
      }

      final jsonString = jsonEncode(matchMap);

      final index = cachedList.indexWhere((item) {
        try {
          final decoded = jsonDecode(item) as Map<String, dynamic>;
          return decoded['id'] == match.id;
        } catch (_) {
          return false;
        }
      });

      if (index != -1) {
        cachedList[index] = jsonString;
      } else {
        cachedList.add(jsonString);
      }

      await prefs.setStringList(userKey, cachedList);
      debugPrint('[LOCAL_CACHE] Match ${match.id} saved to cache for user $targetUserId (${match.moveCount} moves).');
      _notifyListeners(targetUserId);
    } catch (e) {
      debugPrint('[LOCAL_CACHE] Error caching match ${match.id} for user $targetUserId: $e');
    }
  }

  /// Retrieves a single cached match record by ID for the given user.
  Future<MatchRecordModel?> getCachedMatchById(String matchId, {String? targetUserId}) async {
    final matches = await getCachedMatches(targetUserId: targetUserId);
    for (final m in matches) {
      if (m.id == matchId) return m;
    }
    return null;
  }

  /// Retrieves offline cached match records strictly for the target user ID.
  /// Guarantees cross-user isolation: If the user ID does not match, records are NEVER returned.
  Future<List<MatchRecordModel>> getCachedMatches({String? targetUserId}) async {
    final activeUserId = (targetUserId != null && targetUserId.isNotEmpty) ? targetUserId : _currentUserId;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = _getCacheKey(activeUserId);
      List<String> cachedList = prefs.getStringList(userKey) ?? [];

      // Check legacy 'offline_cached_matches' key if user-specific cache is empty
      if (cachedList.isEmpty && prefs.containsKey('offline_cached_matches')) {
        final legacyList = prefs.getStringList('offline_cached_matches') ?? [];
        final List<String> migratedForUser = [];
        final List<String> remainingLegacy = [];

        for (final item in legacyList) {
          try {
            final map = jsonDecode(item) as Map<String, dynamic>;
            final matchUserId = map['userId'] as String? ?? '';
            if (matchUserId == activeUserId || (matchUserId.isEmpty && activeUserId == 'guest_user')) {
              map['userId'] = activeUserId;
              migratedForUser.add(jsonEncode(map));
            } else {
              remainingLegacy.add(item);
            }
          } catch (_) {}
        }

        if (migratedForUser.isNotEmpty) {
          await prefs.setStringList(userKey, migratedForUser);
          await prefs.setStringList('offline_cached_matches', remainingLegacy);
          cachedList = migratedForUser;
          debugPrint('[LOCAL_CACHE] Migrated ${migratedForUser.length} legacy cached match(es) to user $activeUserId');
        }
      }

      final List<MatchRecordModel> matches = [];

      for (final jsonStr in cachedList) {
        try {
          final Map<String, dynamic> map = jsonDecode(jsonStr) as Map<String, dynamic>;
          final matchUserId = map['userId'] as String? ?? '';

          // STRICT AUTHENTICATION GUARD: Ensure user ID matches data in cache ID!
          if (matchUserId.isNotEmpty && matchUserId != activeUserId) {
            debugPrint('[LOCAL_CACHE_SECURITY_BLOCKED] Skipping cached match belonging to another user ($matchUserId != $activeUserId)');
            continue;
          }

          final match = MatchRecordModel.fromMap(map, map['id'] as String? ?? '');
          if (match.moveCount >= 1 || match.status == 'completed') {
            matches.add(match);
          }
        } catch (e) {
          debugPrint('[LOCAL_CACHE] Error parsing cached match entry: $e');
        }
      }
      return matches;
    } catch (e) {
      debugPrint('[LOCAL_CACHE] Error fetching cached matches for $activeUserId: $e');
      return [];
    }
  }

  /// Removes a match record from local offline cache by matchId for a specific user.
  Future<void> removeCachedMatch(String matchId, {String? targetUserId}) async {
    final activeUserId = (targetUserId != null && targetUserId.isNotEmpty) ? targetUserId : _currentUserId;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userKey = _getCacheKey(activeUserId);
      final List<String> cachedList = prefs.getStringList(userKey) ?? [];
      final initialLength = cachedList.length;

      cachedList.removeWhere((item) {
        try {
          final decoded = jsonDecode(item) as Map<String, dynamic>;
          return decoded['id'] == matchId;
        } catch (_) {
          return false;
        }
      });

      if (cachedList.length != initialLength) {
        await prefs.setStringList(userKey, cachedList);
        debugPrint('[LOCAL_CACHE] Match $matchId removed from cache for user $activeUserId.');
        _notifyListeners(activeUserId);
      }
    } catch (e) {
      debugPrint('[LOCAL_CACHE] Error removing cached match $matchId for user $activeUserId: $e');
    }
  }

  /// Clears cached matches for a specific user ID.
  Future<void> clearCacheForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_getCacheKey(userId));
      debugPrint('[LOCAL_CACHE] Cache cleared for user $userId.');
      _notifyListeners(userId);
    } catch (e) {
      debugPrint('[LOCAL_CACHE] Error clearing cache for user $userId: $e');
    }
  }

  /// Clears all cached matches.
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('offline_cached_matches');
      await prefs.remove(_getCacheKey(_currentUserId));
      debugPrint('[LOCAL_CACHE] Offline match cache cleared.');
      _notifyListeners();
    } catch (e) {
      debugPrint('[LOCAL_CACHE] Error clearing cache: $e');
    }
  }
}
