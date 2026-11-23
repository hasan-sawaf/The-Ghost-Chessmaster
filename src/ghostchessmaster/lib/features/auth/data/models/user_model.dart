import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/user_entity.dart';

/// Data model for the `users` Firestore collection.
/// Extends [UserEntity] with Firestore serialization methods.
class UserModel extends UserEntity {
  const UserModel({
    required super.uid,
    required super.email,
    super.displayName,
    super.eloRating,
    super.createdAt,
  });

  /// Factory from Firebase Auth [User] object (on sign-in / sign-up).
  factory UserModel.fromFirebaseUser(User user) {
    return UserModel(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? '',
      eloRating: 800,
      createdAt: user.metadata.creationTime ?? DateTime.now(),
    );
  }

  /// Serializes model to Firestore-compatible map (snake_case keys).
  Map<String, dynamic> toMap() {
    return {
      'id': uid,
      'email': email,
      'display_name': displayName,
      'elo_rating': eloRating,
      'created_at': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  /// Deserializes from Firestore document data map.
  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      uid: map['id'] as String? ?? docId,
      email: map['email'] as String? ?? '',
      displayName: map['display_name'] as String? ?? '',
      eloRating: (map['elo_rating'] as num?)?.toInt() ?? 800,
      createdAt: _parseTimestamp(map['created_at']),
    );
  }

  /// Deserializes from a Firestore [DocumentSnapshot].
  factory UserModel.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel.fromMap(data, doc.id);
  }

  /// Creates a copy with updated fields.
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    int? eloRating,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      eloRating: eloRating ?? this.eloRating,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static DateTime? _parseTimestamp(dynamic val) {
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    return null;
  }
}
