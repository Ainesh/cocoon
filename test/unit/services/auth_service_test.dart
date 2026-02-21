/// Unit tests for AuthService.
///
/// Covers: AUTH-01 through AUTH-12 from the test plan.
/// Uses mocktail for mocking FirebaseAuth and GoogleSignIn dependencies.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:couple_space/services/auth_service.dart';
import '../../helpers/mock_services.dart';

/// Mock for FirebaseAuthException (constructor is @protected).
class MockFirebaseAuthException extends Mock
    implements FirebaseAuthException {}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockGoogleSignIn mockGoogleSignIn;
  late AuthService authService;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockGoogleSignIn = MockGoogleSignIn();
    SharedPreferences.setMockInitialValues({});
    authService = AuthService(auth: mockAuth, googleSignIn: mockGoogleSignIn);
  });

  /// Helper to create a mock FirebaseAuthException with a given code.
  MockFirebaseAuthException createAuthException(
    String code, [
    String? message,
  ]) {
    final exception = MockFirebaseAuthException();
    when(() => exception.code).thenReturn(code);
    when(() => exception.message).thenReturn(message);
    return exception;
  }

  // ===========================================================================
  // User State
  // ===========================================================================

  group('User State', () {
    // AUTH-07
    test('currentUser returns null when not authenticated', () {
      when(() => mockAuth.currentUser).thenReturn(null);
      expect(authService.currentUser, isNull);
    });

    // AUTH-08
    test('isAuthenticated returns true when user is signed in', () {
      final mockUser = MockUser();
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      expect(authService.isAuthenticated, isTrue);
    });

    test('isAuthenticated returns false when no user', () {
      when(() => mockAuth.currentUser).thenReturn(null);
      expect(authService.isAuthenticated, isFalse);
    });
  });

  // ===========================================================================
  // Email Auth
  // ===========================================================================

  group('Email Authentication', () {
    // AUTH-01
    test('signUp creates user and saves token', () async {
      final mockCredential = MockUserCredential();
      final mockUser = MockUser();

      when(() => mockAuth.createUserWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockCredential);
      when(() => mockCredential.user).thenReturn(mockUser);
      when(() => mockUser.getIdToken()).thenAnswer((_) async => 'test_token');

      final result = await authService.signUp(
        email: 'test@example.com',
        password: 'password123',
      );

      expect(result, mockCredential);
      verify(() => mockAuth.createUserWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password123',
          )).called(1);
    });

    // AUTH-02
    test('signIn authenticates existing user and saves token', () async {
      final mockCredential = MockUserCredential();
      final mockUser = MockUser();

      when(() => mockAuth.signInWithEmailAndPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockCredential);
      when(() => mockCredential.user).thenReturn(mockUser);
      when(() => mockUser.getIdToken()).thenAnswer((_) async => 'test_token');

      final result = await authService.signIn(
        email: '  test@example.com  ',
        password: 'password123',
      );

      expect(result, mockCredential);
      // Verify email is trimmed
      verify(() => mockAuth.signInWithEmailAndPassword(
            email: 'test@example.com',
            password: 'password123',
          )).called(1);
    });
  });

  // ===========================================================================
  // Google Sign-In
  // ===========================================================================

  group('Google Sign-In', () {
    // AUTH-04
    test('signInWithGoogle returns null when user cancels', () async {
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async => null);
      when(() => mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

      final result = await authService.signInWithGoogle();
      expect(result, isNull);
    });
  });

  // ===========================================================================
  // Sign Out
  // ===========================================================================

  group('Sign Out', () {
    // AUTH-06
    test('signOut clears local storage and signs out', () async {
      when(() => mockGoogleSignIn.isSignedIn())
          .thenAnswer((_) async => true);
      when(() => mockGoogleSignIn.signOut()).thenAnswer((_) async => null);
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await authService.signOut();

      verify(() => mockAuth.signOut()).called(1);
      verify(() => mockGoogleSignIn.signOut()).called(1);
    });

    test('signOut skips Google sign out when not signed in with Google',
        () async {
      when(() => mockGoogleSignIn.isSignedIn())
          .thenAnswer((_) async => false);
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      await authService.signOut();

      verify(() => mockAuth.signOut()).called(1);
      verifyNever(() => mockGoogleSignIn.signOut());
    });
  });

  // ===========================================================================
  // Token Management
  // ===========================================================================

  group('Token Management', () {
    // AUTH-09
    test('hasStoredToken returns true when token exists', () async {
      SharedPreferences.setMockInitialValues({'user_token': 'abc123'});
      expect(await authService.hasStoredToken(), isTrue);
    });

    // AUTH-10
    test('hasStoredToken returns false when no token', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await authService.hasStoredToken(), isFalse);
    });

    test('getStoredToken returns token value', () async {
      SharedPreferences.setMockInitialValues({'user_token': 'abc123'});
      expect(await authService.getStoredToken(), 'abc123');
    });

    test('getStoredToken returns null when no token', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await authService.getStoredToken(), isNull);
    });
  });

  // ===========================================================================
  // Error Handling
  // ===========================================================================

  group('Error Handling', () {
    // AUTH-11
    test('getErrorMessage maps all known error codes correctly', () {
      final testCases = {
        'weak-password': 'The password provided is too weak.',
        'email-already-in-use': 'An account already exists for that email.',
        'user-not-found': 'No user found for that email.',
        'wrong-password': 'Wrong password provided.',
        'invalid-email': 'The email address is invalid.',
        'user-disabled': 'This account has been disabled.',
        'too-many-requests': 'Too many attempts. Please try again later.',
        'invalid-credential': 'Invalid email or password.',
      };

      for (final entry in testCases.entries) {
        final error = createAuthException(entry.key);
        expect(
          authService.getErrorMessage(error),
          entry.value,
          reason: 'Failed for code: ${entry.key}',
        );
      }
    });

    // AUTH-12
    test('getErrorMessage returns raw message for unknown codes', () {
      final error = createAuthException(
        'some-unknown-code',
        'Something went wrong',
      );
      final message = authService.getErrorMessage(error);
      expect(message, contains('some-unknown-code'));
      expect(message, contains('Something went wrong'));
    });

    test('getErrorMessage handles operation-not-allowed code', () {
      final error = createAuthException('operation-not-allowed');
      expect(
        authService.getErrorMessage(error),
        contains('not enabled'),
      );
    });

    test('getErrorMessage handles admin-restricted-operation code', () {
      final error = createAuthException('admin-restricted-operation');
      expect(
        authService.getErrorMessage(error),
        contains('not enabled'),
      );
    });

    test(
        'getErrorMessage handles account-exists-with-different-credential code',
        () {
      final error =
          createAuthException('account-exists-with-different-credential');
      expect(
        authService.getErrorMessage(error),
        contains('different sign-in credentials'),
      );
    });
  });
}
