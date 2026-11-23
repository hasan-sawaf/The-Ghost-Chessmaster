import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a physical hardware chess board in the `boards` Firestore collection.
class BoardModel {
  final String id; // PK: Hardware Board ID
  final String boardName;
  final DateTime? lastActive;

  BoardModel({
    required this.id,
    required this.boardName,
    this.lastActive,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'board_name': boardName,
      'last_active': lastActive != null ? Timestamp.fromDate(lastActive!) : FieldValue.serverTimestamp(),
    };
  }

  factory BoardModel.fromMap(Map<String, dynamic> map, String docId) {
    return BoardModel(
      id: map['id'] as String? ?? docId,
      boardName: map['board_name'] as String? ?? '',
      lastActive: _parseTimestamp(map['last_active']),
    );
  }

  factory BoardModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BoardModel.fromMap(data, doc.id);
  }

  BoardModel copyWith({
    String? id,
    String? boardName,
    DateTime? lastActive,
  }) {
    return BoardModel(
      id: id ?? this.id,
      boardName: boardName ?? this.boardName,
      lastActive: lastActive ?? this.lastActive,
    );
  }

  static DateTime? _parseTimestamp(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }
}
