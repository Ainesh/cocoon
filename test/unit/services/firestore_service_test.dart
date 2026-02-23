/// Unit tests for FirestoreService.
///
/// Covers: FS result types, MomentConflictException, local storage,
/// and invite code configuration from the test plan.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:couple_space/services/firestore_service.dart';
import '../../helpers/mock_services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ===========================================================================
  // Result Types
  // ===========================================================================

  group('JoinResult', () {
    test('each result has a non-empty message', () {
      for (final result in JoinResult.values) {
        expect(result.message, isNotEmpty);
      }
    });

    test('success message is positive', () {
      expect(JoinResult.success.message, contains('Successfully'));
    });

    test('inviteNotFound message mentions invalid code', () {
      expect(JoinResult.inviteNotFound.message, contains('Invalid'));
    });

    test('inviteExpired message mentions expired', () {
      expect(JoinResult.inviteExpired.message, contains('expired'));
    });

    test('spaceFull message mentions 2 members', () {
      expect(JoinResult.spaceFull.message, contains('2 members'));
    });

    test('alreadyMember message indicates membership', () {
      expect(JoinResult.alreadyMember.message, contains('already'));
    });
  });

  // ===========================================================================
  // CreateSpaceResult
  // ===========================================================================

  group('CreateSpaceResult', () {
    test('stores spaceId and inviteCode', () {
      const result = CreateSpaceResult(
        spaceId: 'space_123',
        inviteCode: 'ABC123',
      );

      expect(result.spaceId, 'space_123');
      expect(result.inviteCode, 'ABC123');
    });
  });

  // ===========================================================================
  // MomentConflictException
  // ===========================================================================

  group('MomentConflictException', () {
    test('stores message and displays via toString', () {
      final exception = MomentConflictException('Version mismatch');
      expect(exception.message, 'Version mismatch');
      expect(exception.toString(), 'Version mismatch');
    });

    test('implements Exception', () {
      final exception = MomentConflictException('test');
      expect(exception, isA<Exception>());
    });
  });

  // ===========================================================================
  // Local Storage (injecting mock Firestore to avoid Firebase.initializeApp)
  // ===========================================================================

  group('Local Storage', () {
    late FirestoreService service;
    late MockFirebaseFirestore mockFirestore;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockFirestore = MockFirebaseFirestore();
      service = FirestoreService(firestore: mockFirestore);
    });

    test('saveSpaceId and getSavedSpaceId round-trip', () async {
      await service.saveSpaceId('space_abc');
      final saved = await service.getSavedSpaceId();
      expect(saved, 'space_abc');
    });

    test('clearSavedSpaceId removes stored value', () async {
      await service.saveSpaceId('space_abc');
      await service.clearSavedSpaceId();
      final saved = await service.getSavedSpaceId();
      expect(saved, isNull);
    });

    test('getSavedSpaceId returns null when nothing saved', () async {
      final saved = await service.getSavedSpaceId();
      expect(saved, isNull);
    });
  });

  // ===========================================================================
  // Invite Code Configuration
  // ===========================================================================

  group('Invite Code Configuration', () {
    test('service can be instantiated with mock Firestore', () {
      final mockFirestore = MockFirebaseFirestore();
      final service = FirestoreService(firestore: mockFirestore);
      expect(service, isNotNull);
    });
  });
}
