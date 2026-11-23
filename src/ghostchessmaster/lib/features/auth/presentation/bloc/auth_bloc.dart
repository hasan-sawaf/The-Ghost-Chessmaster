import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../history/data/local_match_cache_service.dart';
import '../../../history/data/match_history_service.dart';
import '../../../profile/data/board_connection_service.dart';
import '../../../training/data/training_campaign_service.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository})
      : super(
          authRepository.currentUser != null
              ? AuthenticatedState(authRepository.currentUser!)
              : AuthInitialState(),
        ) {
    on<AuthCheckRequestedEvent>((event, emit) async {
      final currentUser = authRepository.currentUser;
      if (currentUser != null) {
        emit(AuthenticatedState(currentUser));
        // Execute background data synchronization without delaying UI state
        LocalMatchCacheService.instance.onUserSignedIn(currentUser.uid);
        TrainingCampaignService.instance.loadCampaignProgress(targetUserId: currentUser.uid);
        MatchHistoryService.instance.syncCachedMatchesToFirebase(userId: currentUser.uid);
        BoardConnectionService.instance.loadConnectionState();
      } else {
        LocalMatchCacheService.instance.onUserSignedOut();
        TrainingCampaignService.instance.onUserSignedOut();
        BoardConnectionService.instance.onUserSignedOut();
        emit(const UnauthenticatedState());
      }
    });

    on<SignInSubmittedEvent>((event, emit) async {
      emit(AuthLoadingState());
      try {
        final user = await authRepository.signInWithEmail(
          email: event.email,
          password: event.password,
        );
        await LocalMatchCacheService.instance.onUserSignedIn(user.uid);
        await TrainingCampaignService.instance.loadCampaignProgress(targetUserId: user.uid);
        MatchHistoryService.instance.syncCachedMatchesToFirebase(userId: user.uid);
        BoardConnectionService.instance.loadConnectionState();
        emit(AuthenticatedState(user));
      } on FirebaseAuthException catch (e) {
        emit(UnauthenticatedState(errorMessage: _mapErrorCode(e.code)));
      } catch (e) {
        emit(UnauthenticatedState(errorMessage: _mapErrorCode(e.toString())));
      }
    });

    on<SignUpSubmittedEvent>((event, emit) async {
      emit(AuthLoadingState());
      try {
        final user = await authRepository.signUpWithEmail(
          email: event.email,
          password: event.password,
        );
        await LocalMatchCacheService.instance.onUserSignedIn(user.uid);
        await TrainingCampaignService.instance.loadCampaignProgress(targetUserId: user.uid);
        MatchHistoryService.instance.syncCachedMatchesToFirebase(userId: user.uid);
        BoardConnectionService.instance.loadConnectionState();
        emit(AuthenticatedState(user));
      } on FirebaseAuthException catch (e) {
        emit(UnauthenticatedState(errorMessage: _mapErrorCode(e.code)));
      } catch (e) {
        emit(UnauthenticatedState(errorMessage: _mapErrorCode(e.toString())));
      }
    });

    on<SignOutRequestedEvent>((event, emit) async {
      emit(AuthLoadingState());
      await authRepository.signOut();
      LocalMatchCacheService.instance.onUserSignedOut();
      TrainingCampaignService.instance.onUserSignedOut();
      BoardConnectionService.instance.onUserSignedOut();
      emit(const UnauthenticatedState());
    });

    on<ClearAuthErrorEvent>((event, emit) {
      if (state is UnauthenticatedState) {
        emit(const UnauthenticatedState(errorMessage: null));
      }
    });
  }

  String _mapErrorCode(String error) {
    if (error.contains('user-not-found')) return 'user_not_found';
    if (error.contains('wrong-password') || error.contains('invalid-credential')) {
      return 'wrong_password';
    }
    if (error.contains('email-already-in-use')) return 'email_in_use';
    if (error.contains('weak-password')) return 'weak_password';
    if (error.contains('invalid-email')) return 'invalid_email';
    return 'auth_failed';
  }
}
