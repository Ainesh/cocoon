/// Mock classes for services used throughout tests.
///
/// Uses `mocktail` for creating mock instances of [AuthService],
/// [FirestoreService], and Firebase dependencies.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:couple_space/services/auth_service.dart';
import 'package:couple_space/services/firestore_service.dart';

// =============================================================================
// Service Mocks
// =============================================================================

class MockAuthService extends Mock implements AuthService {}

class MockFirestoreService extends Mock implements FirestoreService {}

// =============================================================================
// Firebase Auth Mocks
// =============================================================================

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class MockGoogleSignIn extends Mock implements GoogleSignIn {}

class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

// =============================================================================
// Firestore Mocks
// =============================================================================

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// Note: CollectionReference, DocumentReference, DocumentSnapshot,
// QueryDocumentSnapshot, and Query are sealed classes in cloud_firestore
// and cannot be mocked via `implements`. Use Firestore emulator for tests
// that need these.

// =============================================================================
// SharedPreferences
// =============================================================================

/// Sets up [SharedPreferences] with empty initial values for tests.
Future<void> setupTestSharedPreferences([
  Map<String, Object> values = const {},
]) async {
  SharedPreferences.setMockInitialValues(values);
}
