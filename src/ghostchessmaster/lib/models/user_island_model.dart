import 'package:cloud_firestore/cloud_firestore.dart';

/// Junction table model tracking a user's progress on a specific training island.
/// Stored in root collection `user_island` with composite document ID: `{userId}_{islandId}`.
class UserIslandModel {
  final String userId; // FK → users.id
  final int islandId; // FK → islands.id
  final int completedRounds; // 0..4
  final bool isUnlocked;
  final bool isCompleted;
  final String? roundOneMatchId; // FK → matches_history.id for Round 1 (or null if unplayed)
  final String? roundTwoMatchId; // FK → matches_history.id for Round 2 (or null if unplayed)
  final String? roundThreeMatchId; // FK → matches_history.id for Round 3 (or null if unplayed)
  final String? roundFourMatchId; // FK → matches_history.id for Round 4 (or null if unplayed)

  UserIslandModel({
    required this.userId,
    required this.islandId,
    required this.completedRounds,
    required this.isUnlocked,
    this.isCompleted = false,
    this.roundOneMatchId,
    this.roundTwoMatchId,
    this.roundThreeMatchId,
    this.roundFourMatchId,
  });

  /// Subcollection document ID for Firestore: `{islandId}` (e.g. `'1'`, `'2'`, ..., `'20'`)
  String get documentId => '$islandId';

  bool get isComplete => completedRounds >= 4;

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'island_id': islandId,
      'completed_rounds': completedRounds,
      'is_unlocked': isUnlocked,
      'is_completed': isComplete,
      'round_one_match_id': roundOneMatchId,
      'round_two_match_id': roundTwoMatchId,
      'round_three_match_id': roundThreeMatchId,
      'round_four_match_id': roundFourMatchId,
    };
  }

  factory UserIslandModel.fromMap(Map<String, dynamic> map, String docId) {
    String userId = map['user_id'] as String? ?? '';
    int islandId = (map['island_id'] as num?)?.toInt() ?? int.tryParse(docId) ?? 0;

    return UserIslandModel(
      userId: userId,
      islandId: islandId,
      completedRounds: (map['completed_rounds'] as num?)?.toInt() ?? 0,
      isUnlocked: map['is_unlocked'] as bool? ?? (islandId == 1),
      isCompleted: map['is_completed'] as bool? ?? false,
      roundOneMatchId: map['round_one_match_id'] as String?,
      roundTwoMatchId: map['round_two_match_id'] as String?,
      roundThreeMatchId: map['round_three_match_id'] as String?,
      roundFourMatchId: map['round_four_match_id'] as String?,
    );
  }

  factory UserIslandModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserIslandModel.fromMap(data, doc.id);
  }

  UserIslandModel copyWith({
    String? userId,
    int? islandId,
    int? completedRounds,
    bool? isUnlocked,
    bool? isCompleted,
    String? roundOneMatchId,
    String? roundTwoMatchId,
    String? roundThreeMatchId,
    String? roundFourMatchId,
  }) {
    return UserIslandModel(
      userId: userId ?? this.userId,
      islandId: islandId ?? this.islandId,
      completedRounds: completedRounds ?? this.completedRounds,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isCompleted: isCompleted ?? this.isCompleted,
      roundOneMatchId: roundOneMatchId ?? this.roundOneMatchId,
      roundTwoMatchId: roundTwoMatchId ?? this.roundTwoMatchId,
      roundThreeMatchId: roundThreeMatchId ?? this.roundThreeMatchId,
      roundFourMatchId: roundFourMatchId ?? this.roundFourMatchId,
    );
  }
}
