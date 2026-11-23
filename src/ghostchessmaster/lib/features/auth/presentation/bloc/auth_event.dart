import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequestedEvent extends AuthEvent {}

class SignInSubmittedEvent extends AuthEvent {
  final String email;
  final String password;

  const SignInSubmittedEvent({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class SignUpSubmittedEvent extends AuthEvent {
  final String email;
  final String password;

  const SignUpSubmittedEvent({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class SignOutRequestedEvent extends AuthEvent {}

class ClearAuthErrorEvent extends AuthEvent {}
