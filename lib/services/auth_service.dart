/// Authentication service for Couple Space app.
///
/// Handles all Firebase Authentication operations including sign up, sign in,
/// Google sign-in, sign out, and local token management via SharedPreferences.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service class that wraps Firebase Authentication with local token storage.
///
/// Usage:
/// ```dart
/// final authService = AuthService();
///
/// // Sign up a new user
/// await authService.signUp(email: 'user@example.com', password: 'password123');
///
/// // Sign in existing user
/// await authService.signIn(email: 'user@example.com', password: 'password123');
///
/// // Sign in with Google
/// await authService.signInWithGoogle();
///
/// // Check current user
/// final user = authService.currentUser;
///
/// // Sign out
/// await authService.signOut();
/// ```
class AuthService {
  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? _sharedGoogleSignIn;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  // Singleton GoogleSignIn to prevent "Future already completed" error on web
  static final GoogleSignIn _sharedGoogleSignIn = GoogleSignIn();

  // Flag to prevent multiple simultaneous sign-in attempts
  static bool _isSigningIn = false;

  // Local storage keys
  static const String _tokenKey = 'user_token';
  static const String _spaceIdKey = 'user_space_id';

  // ---------------------------------------------------------------------------
  // User State
  // ---------------------------------------------------------------------------

  /// Returns the currently signed-in [User], or `null` if not authenticated.
  User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes.
  ///
  /// Emits a [User] when signed in, or `null` when signed out.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Returns `true` if a user is currently signed in.
  bool get isAuthenticated => currentUser != null;

  // ---------------------------------------------------------------------------
  // Authentication Methods
  // ---------------------------------------------------------------------------

  /// Creates a new user account with email and password.
  ///
  /// Throws [FirebaseAuthException] on failure.
  /// Returns [UserCredential] on success.
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _saveToken(credential.user);
    return credential;
  }

  /// Signs in an existing user with email and password.
  ///
  /// Throws [FirebaseAuthException] on failure.
  /// Returns [UserCredential] on success.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _saveToken(credential.user);
    return credential;
  }

  /// Signs in with Google.
  ///
  /// This method handles the complete Google Sign-In flow including:
  /// - Triggering the Google Sign-In UI
  /// - Getting Google credentials
  /// - Creating Firebase credential and signing in
  ///
  /// Returns [UserCredential] on success.
  /// Returns `null` if the user cancels the sign-in or if already signing in.
  /// Throws [FirebaseAuthException] on Firebase errors.
  Future<UserCredential?> signInWithGoogle() async {
    // Prevent multiple simultaneous sign-in attempts (fixes web "Future already completed" error)
    if (_isSigningIn) {
      return null;
    }

    _isSigningIn = true;

    try {
      // Sign out first to ensure clean state (prevents web issues)
      await _googleSignIn.signOut();

      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // User canceled the sign-in
      if (googleUser == null) {
        return null;
      }

      // Obtain the auth details from the Google Sign-In
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential for Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      await _saveToken(userCredential.user);
      return userCredential;
    } finally {
      _isSigningIn = false;
    }
  }

  /// Signs out the current user and clears all local storage.
  ///
  /// Also signs out from Google if signed in with Google.
  Future<void> signOut() async {
    // Sign out from Google (if signed in with Google)
    if (await _googleSignIn.isSignedIn()) {
      await _googleSignIn.signOut();
    }

    await _auth.signOut();
    await _clearAllLocalData();
  }

  // ---------------------------------------------------------------------------
  // Token Management
  // ---------------------------------------------------------------------------

  /// Saves the user's ID token to local storage.
  Future<void> _saveToken(User? user) async {
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = await user.getIdToken();
    if (token != null) {
      await prefs.setString(_tokenKey, token);
    }
  }

  /// Clears all auth-related local data (token and space ID).
  Future<void> _clearAllLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([prefs.remove(_tokenKey), prefs.remove(_spaceIdKey)]);
  }

  /// Returns `true` if a stored token exists in local storage.
  Future<bool> hasStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_tokenKey);
  }

  /// Retrieves the stored auth token, or `null` if not found.
  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // ---------------------------------------------------------------------------
  // Error Handling
  // ---------------------------------------------------------------------------

  /// Converts a [FirebaseAuthException] to a user-friendly error message.
  ///
  /// Handles common Firebase Auth error codes with clear messages.
  String getErrorMessage(FirebaseAuthException e) {
    return switch (e.code) {
      'weak-password' => 'The password provided is too weak.',
      'email-already-in-use' => 'An account already exists for that email.',
      'user-not-found' => 'No user found for that email.',
      'wrong-password' => 'Wrong password provided.',
      'invalid-email' => 'The email address is invalid.',
      'user-disabled' => 'This account has been disabled.',
      'too-many-requests' => 'Too many attempts. Please try again later.',
      'invalid-credential' => 'Invalid email or password.',
      'operation-not-allowed' || 'admin-restricted-operation' =>
        'This sign-in method is not enabled. Enable it in Firebase Console.',
      'account-exists-with-different-credential' =>
        'An account already exists with the same email but different sign-in credentials.',
      _ => '[${e.code}] ${e.message ?? 'An unexpected error occurred'}',
    };
  }
}
