import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity> signInWithEmail({required String email, required String password});
  Future<UserEntity> signUpWithEmail({required String email, required String password});
  Future<void> signOut();
  Stream<UserEntity?> get authStateChanges;
  UserEntity? get currentUser;
}
