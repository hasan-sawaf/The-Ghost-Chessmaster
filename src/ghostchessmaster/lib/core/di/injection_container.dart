import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/settings/presentation/bloc/settings_bloc.dart';

final sl = GetIt.instance; // sl = Service Locator

Future<void> initDependencyInjection() async {
  // --- External Dependencies ---
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);

  // --- Data Sources ---
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(firebaseAuth: sl()),
  );

  // --- Repositories ---
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl()),
  );

  // --- BLoCs ---
  sl.registerFactory<AuthBloc>(
    () => AuthBloc(authRepository: sl()),
  );

  sl.registerFactory<SettingsBloc>(
    () => SettingsBloc(),
  );
}
