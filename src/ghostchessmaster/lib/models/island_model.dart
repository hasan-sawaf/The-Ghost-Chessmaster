import 'package:cloud_firestore/cloud_firestore.dart';

/// Static lookup model for training island definitions in the `islands` Firestore collection.
/// Predefined configuration records for each of the 20 training islands.
class IslandModel {
  final int id; // PK: 1..20
  final String title;
  final int targetElo;
  final int hintNum; // number of hints available for matches on this island
  final int time; // match timer in minutes (0 = infinite/unlimited time)
  final int incTime; // time increment per move in seconds

  IslandModel({
    required this.id,
    required this.title,
    required this.targetElo,
    required this.hintNum,
    required this.time,
    required this.incTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'target_elo': targetElo,
      'hint_num': hintNum,
      'time': time,
      'inc_time': incTime,
    };
  }

  factory IslandModel.fromMap(Map<String, dynamic> map, int fallbackId) {
    final id = (map['id'] as num?)?.toInt() ?? fallbackId;
    return IslandModel(
      id: id,
      title: map['title'] as String? ?? 'Island $fallbackId',
      targetElo: (map['target_elo'] as num?)?.toInt() ?? 800,
      hintNum: (map['hint_num'] as num?)?.toInt() ?? getHintNumForIsland(id),
      time: (map['time'] as num?)?.toInt() ?? getTimeForIsland(id),
      incTime: (map['inc_time'] as num?)?.toInt() ?? getIncTimeForIsland(id),
    );
  }

  factory IslandModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return IslandModel.fromMap(data, int.tryParse(doc.id) ?? 0);
  }

  IslandModel copyWith({
    int? id,
    String? title,
    int? targetElo,
    int? hintNum,
    int? time,
    int? incTime,
  }) {
    return IslandModel(
      id: id ?? this.id,
      title: title ?? this.title,
      targetElo: targetElo ?? this.targetElo,
      hintNum: hintNum ?? this.hintNum,
      time: time ?? this.time,
      incTime: incTime ?? this.incTime,
    );
  }

  /// Helper methods for default values per island range
  static int getHintNumForIsland(int islandId) {
    if (islandId <= 5) return 5;
    if (islandId <= 10) return 3;
    if (islandId <= 15) return 1;
    return 0;
  }

  static int getTimeForIsland(int islandId) {
    if (islandId <= 5) return 0;
    if (islandId <= 10) return 10;
    if (islandId <= 15) return 10;
    return 5;
  }

  static int getIncTimeForIsland(int islandId) {
    if (islandId <= 5) return 0;
    if (islandId <= 10) return 3;
    if (islandId <= 15) return 2;
    return 1;
  }

  /// Predefined list of all 20 training islands with ELO, hint_num, time, and inc_time configurations.
  static final List<IslandModel> defaultIslands = [
    IslandModel(id: 1, title: 'Beginner Shore', targetElo: 800, hintNum: 5, time: 0, incTime: 0),
    IslandModel(id: 2, title: 'Pawn Plains', targetElo: 900, hintNum: 5, time: 0, incTime: 0),
    IslandModel(id: 3, title: 'Knights Meadow', targetElo: 1000, hintNum: 5, time: 0, incTime: 0),
    IslandModel(id: 4, title: 'Bishops Crossing', targetElo: 1100, hintNum: 5, time: 0, incTime: 0),
    IslandModel(id: 5, title: 'Rooks Bastion', targetElo: 1200, hintNum: 5, time: 0, incTime: 0),
    IslandModel(id: 6, title: 'Queens Garden', targetElo: 1300, hintNum: 3, time: 10, incTime: 3),
    IslandModel(id: 7, title: 'Kings Court', targetElo: 1400, hintNum: 3, time: 10, incTime: 3),
    IslandModel(id: 8, title: 'Tactical Bay', targetElo: 1500, hintNum: 3, time: 10, incTime: 3),
    IslandModel(id: 9, title: 'Strategic Strait', targetElo: 1600, hintNum: 3, time: 10, incTime: 3),
    IslandModel(id: 10, title: 'Endgame Atoll', targetElo: 1700, hintNum: 3, time: 10, incTime: 3),
    IslandModel(id: 11, title: 'Fortress Island', targetElo: 1800, hintNum: 1, time: 10, incTime: 2),
    IslandModel(id: 12, title: 'Sacrifice Shores', targetElo: 1900, hintNum: 1, time: 10, incTime: 2),
    IslandModel(id: 13, title: 'Combination Cove', targetElo: 2000, hintNum: 1, time: 10, incTime: 2),
    IslandModel(id: 14, title: 'Positional Peak', targetElo: 2100, hintNum: 1, time: 10, incTime: 2),
    IslandModel(id: 15, title: 'Grandmaster Gulf', targetElo: 2200, hintNum: 1, time: 10, incTime: 2),
    IslandModel(id: 16, title: 'Champions Cliff', targetElo: 2300, hintNum: 0, time: 5, incTime: 1),
    IslandModel(id: 17, title: 'Elite Enclave', targetElo: 2400, hintNum: 0, time: 5, incTime: 1),
    IslandModel(id: 18, title: 'Masters Mountain', targetElo: 2500, hintNum: 0, time: 5, incTime: 1),
    IslandModel(id: 19, title: 'Legends Landing', targetElo: 2600, hintNum: 0, time: 5, incTime: 1),
    IslandModel(id: 20, title: 'Infinity Realm', targetElo: 2800, hintNum: 0, time: 5, incTime: 1),
  ];
}
