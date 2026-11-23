import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String uid;
  final String email;
  final String displayName;
  final int eloRating;
  final DateTime? createdAt;

  const UserEntity({
    required this.uid,
    required this.email,
    this.displayName = '',
    this.eloRating = 800,
    this.createdAt,
  });

  @override
  List<Object?> get props => [uid, email, displayName, eloRating, createdAt];
}
