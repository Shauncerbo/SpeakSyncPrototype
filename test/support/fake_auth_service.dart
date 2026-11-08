import 'dart:async';

import 'package:speaksync_prototype/auth_service.dart';

class FakeAuthService extends AuthService {
  FakeAuthService({
    AuthUser? currentUser,
    AuthUser? signInUser,
    AuthUser? registrationUser,
    this.failure,
  }) : _currentUser = currentUser,
       signInUser =
           signInUser ??
           const AuthUser(
             uid: 'test-user',
             email: 'student@example.com',
             displayName: 'Test Student',
             emailVerified: true,
           ),
       registrationUser =
           registrationUser ??
           const AuthUser(
             uid: 'new-user',
             email: 'new.student@example.com',
             displayName: 'New Student',
             emailVerified: false,
           );

  AuthUser? _currentUser;
  AuthUser signInUser;
  AuthUser registrationUser;
  AuthFailure? failure;
  final StreamController<AuthUser?> _changes =
      StreamController<AuthUser?>.broadcast();

  int signInCalls = 0;
  int registrationCalls = 0;
  int verificationEmailCalls = 0;
  int reloadCalls = 0;
  int passwordResetCalls = 0;
  int signOutCalls = 0;
  String? lastResetEmail;

  @override
  AuthUser? get currentUser => _currentUser;

  @override
  Stream<AuthUser?> get authStateChanges => _changes.stream;

  void setUser(AuthUser? user) {
    _currentUser = user;
    _changes.add(user);
  }

  void markCurrentUserVerified() {
    final user = _currentUser;
    if (user != null) setUser(user.copyWith(emailVerified: true));
  }

  void _throwIfNeeded() {
    final value = failure;
    if (value != null) throw value;
  }

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    registrationCalls++;
    _throwIfNeeded();
    final user = AuthUser(
      uid: registrationUser.uid,
      email: email,
      displayName: displayName,
      emailVerified: registrationUser.emailVerified,
    );
    setUser(user);
    return user;
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    _throwIfNeeded();
    final user = signInUser.copyWith(email: email);
    setUser(user);
    return user;
  }

  @override
  Future<AuthUser?> reloadCurrentUser() async {
    reloadCalls++;
    _throwIfNeeded();
    return _currentUser;
  }

  @override
  Future<void> sendEmailVerification() async {
    verificationEmailCalls++;
    _throwIfNeeded();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    passwordResetCalls++;
    lastResetEmail = email;
    _throwIfNeeded();
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _throwIfNeeded();
    setUser(null);
  }

  Future<void> dispose() => _changes.close();
}
