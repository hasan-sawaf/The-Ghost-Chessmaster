import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<UserEntity> signInWithEmail({required String email, required String password}) async {
    return await remoteDataSource.signInWithEmail(email, password);
  }

  @override
  Future<UserEntity> signUpWithEmail({required String email, required String password}) async {
    return await remoteDataSource.signUpWithEmail(email, password);
  }

  @override
  Future<void> signOut() async {
    await remoteDataSource.signOut();
  }

  @override
  Stream<UserEntity?> get authStateChanges => remoteDataSource.authStateChanges;

  @override
  UserEntity? get currentUser => remoteDataSource.currentUser;
}
