import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthService {
  Stream<User?> authStateChanges();

  User? get currentUser;

  Future<User> signIn({required String email, required String password});

  Future<User> signUp({required String email, required String password});

  Future<void> sendEmailVerification();

  /// Refreshes the current user's data (e.g. emailVerified) from the server.
  Future<void> reloadCurrentUser();

  Future<void> signOut();
}

class FirebaseAuthServiceImpl implements AuthService {
  final FirebaseAuth _auth;

  FirebaseAuthServiceImpl(this._auth);

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<User> signIn({required String email, required String password}) async {
    final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
    return credential.user!;
  }

  @override
  Future<User> signUp({required String email, required String password}) async {
    final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final user = credential.user!;
    await user.sendEmailVerification();
    return user;
  }

  @override
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  @override
  Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
