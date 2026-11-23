import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../models/firestore_constants.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<UserModel> signInWithEmail(String email, String password);
  Future<UserModel> signUpWithEmail(String email, String password);
  Future<void> signOut();
  Stream<UserModel?> get authStateChanges;
  UserModel? get currentUser;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth firebaseAuth;

  AuthRemoteDataSourceImpl({required this.firebaseAuth});

  @override
  Future<UserModel> signInWithEmail(String email, String password) async {
    final credential = await firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    if (credential.user == null) {
      throw Exception('user-not-found');
    }
    final userModel = UserModel.fromFirebaseUser(credential.user!);

    // Ensure user profile document exists in Firestore `users` collection (upsert)
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreConstants.usersCollection)
          .doc(userModel.uid)
          .set(userModel.toMap(), SetOptions(merge: true));
    } catch (_) {
      // Silently handle Firestore errors — Auth sign-in is the primary operation
    }

    return userModel;
  }

  @override
  Future<UserModel> signUpWithEmail(String email, String password) async {
    final credential = await firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    if (credential.user == null) {
      throw Exception('auth_failed');
    }
    final userModel = UserModel.fromFirebaseUser(credential.user!);

    // Write user profile document to Firestore `users` collection
    try {
      await FirebaseFirestore.instance
          .collection(FirestoreConstants.usersCollection)
          .doc(userModel.uid)
          .set(userModel.toMap(), SetOptions(merge: true));
    } catch (_) {
      // Silently handle Firestore errors — Auth sign-up is the primary operation
    }

    return userModel;
  }

  @override
  Future<void> signOut() async {
    await firebaseAuth.signOut();
  }

  @override
  Stream<UserModel?> get authStateChanges {
    return firebaseAuth.authStateChanges().map((user) {
      return user != null ? UserModel.fromFirebaseUser(user) : null;
    });
  }

  @override
  UserModel? get currentUser {
    final user = firebaseAuth.currentUser;
    return user != null ? UserModel.fromFirebaseUser(user) : null;
  }
}
