import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/widgets.dart';

class AuthUser {
  const AuthUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.emailVerified,
  });

  final String uid;
  final String email;
  final String? displayName;
  final bool emailVerified;

  AuthUser copyWith({String? email, String? displayName, bool? emailVerified}) {
    return AuthUser(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }
}

class AuthFailure implements Exception {
  const AuthFailure(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

abstract class AuthService {
  const AuthService();

  AuthUser? get currentUser;
  Stream<AuthUser?> get authStateChanges;
  bool get isAvailable => true;
  String? get unavailableMessage => null;

  Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
  });

  Future<AuthUser> signIn({required String email, required String password});

  Future<AuthUser?> reloadCurrentUser();
  Future<void> sendEmailVerification();
  Future<void> sendPasswordResetEmail(String email);
  Future<void> signOut();

  static bool isValidEmail(String value) {
    final email = value.trim();
    if (email.isEmpty || email.length > 254 || email.contains(' ')) {
      return false;
    }
    return RegExp(
      r'^[A-Za-z0-9.!#$%&\x27*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
    ).hasMatch(email);
  }
}

class FirebaseAuthService extends AuthService {
  FirebaseAuthService({firebase_auth.FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance;

  final firebase_auth.FirebaseAuth _firebaseAuth;

  @override
  AuthUser? get currentUser => _mapUser(_firebaseAuth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges =>
      _firebaseAuth.authStateChanges().map(_mapUser);

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) {
        throw const AuthFailure(
          'missing-user',
          'Firebase did not return the newly created account. Please try again.',
        );
      }
      try {
        await user.updateDisplayName(displayName.trim());
      } on firebase_auth.FirebaseAuthException {
        // Hive still preserves the supplied name. A profile-name update
        // failure must not hide a successfully created Firebase account.
      }
      return AuthUser(
        uid: user.uid,
        email: user.email ?? email.trim(),
        displayName: displayName.trim(),
        emailVerified: user.emailVerified,
      );
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw _firebaseFailure(error);
    }
  }

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = _mapUser(credential.user);
      if (user == null) {
        throw const AuthFailure(
          'missing-user',
          'Firebase could not restore this account. Please try again.',
        );
      }
      return user;
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw _firebaseFailure(error);
    }
  }

  @override
  Future<AuthUser?> reloadCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    try {
      await user.reload();
      return _mapUser(_firebaseAuth.currentUser);
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw _firebaseFailure(error);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const AuthFailure(
        'signed-out',
        'Your sign-in session has ended. Please sign in again.',
      );
    }
    if (user.emailVerified) return;
    try {
      await user.sendEmailVerification();
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw _firebaseFailure(error);
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw _firebaseFailure(error);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } on firebase_auth.FirebaseAuthException catch (error) {
      throw _firebaseFailure(error);
    }
  }

  static AuthUser? _mapUser(firebase_auth.User? user) {
    if (user == null) return null;
    return AuthUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      emailVerified: user.emailVerified,
    );
  }

  static AuthFailure _firebaseFailure(
    firebase_auth.FirebaseAuthException error,
  ) {
    final message = switch (error.code) {
      'invalid-email' => 'Please enter a valid email address.',
      'email-already-in-use' =>
        'An account already exists for that email address.',
      'weak-password' =>
        'Choose a stronger password with at least 6 characters.',
      'user-disabled' =>
        'This account has been disabled. Contact the project administrator.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'The email or password is incorrect.',
      'network-request-failed' =>
        'Authentication needs an internet connection. Check your connection and try again.',
      'too-many-requests' =>
        'Too many attempts were made. Please wait before trying again.',
      'operation-not-allowed' =>
        'Email/password authentication is unavailable for this Firebase project.',
      'requires-recent-login' =>
        'Please sign in again before continuing with this account action.',
      _ =>
        'Firebase Authentication is temporarily unavailable. Please try again.',
    };
    return AuthFailure(error.code, message);
  }
}

class UnavailableAuthService extends AuthService {
  const UnavailableAuthService([
    this.reason =
        'Firebase Authentication is unavailable. Check your connection or app configuration.',
  ]);

  final String reason;

  @override
  bool get isAvailable => false;

  @override
  String get unavailableMessage => reason;

  @override
  AuthUser? get currentUser => null;

  @override
  Stream<AuthUser?> get authStateChanges => const Stream.empty();

  Never _unavailable() => throw AuthFailure('service-unavailable', reason);

  @override
  Future<AuthUser> register({
    required String email,
    required String password,
    required String displayName,
  }) async => _unavailable();

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async => _unavailable();

  @override
  Future<AuthUser?> reloadCurrentUser() async => _unavailable();

  @override
  Future<void> sendEmailVerification() async => _unavailable();

  @override
  Future<void> sendPasswordResetEmail(String email) async => _unavailable();

  @override
  Future<void> signOut() async => _unavailable();
}

class AuthServiceScope extends InheritedWidget {
  const AuthServiceScope({
    super.key,
    required this.service,
    required super.child,
  });

  final AuthService service;

  static AuthService? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthServiceScope>()?.service;

  static AuthService of(BuildContext context) {
    final service = maybeOf(context);
    assert(service != null, 'No AuthServiceScope found in this context.');
    return service!;
  }

  @override
  bool updateShouldNotify(AuthServiceScope oldWidget) =>
      service != oldWidget.service;
}
