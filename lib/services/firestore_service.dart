/// Firestore service for Couple Space app.
///
/// Manages all Firestore database operations with secure collection separation.
/// This service provides a single point of access for all database operations,
/// ensuring consistent error handling and data validation.
///
/// ## Collections
///
/// | Collection | Purpose | Subcollections |
/// |------------|---------|----------------|
/// | `invites` | One-time invite codes | - |
/// | `spaces` | Couple space metadata | `events`, `checkins` |
/// | `users` | User profiles | - |
///
/// ## Usage
///
/// ```dart
/// final service = FirestoreService();
///
/// // Create a space
/// final result = await service.createSpace(
///   userId: 'uid',
///   spaceName: 'Our Space',
///   userName: 'Alex',
///   avatarKey: 'heart_red',
/// );
///
/// // Watch real-time updates
/// service.watchRecentCheckIns(spaceId).listen((checkIns) {
///   // Handle updates
/// });
/// ```
///
/// ## Security
///
/// All operations are designed to work with Firestore security rules that:
/// - Require authentication for all operations
/// - Restrict space access to members only
/// - Validate data structure on writes
library;

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/moment.dart';
import '../models/space_event.dart';
import '../models/user_checkin.dart';

// -----------------------------------------------------------------------------
// Result Types
// -----------------------------------------------------------------------------

/// Result of attempting to join a couple space.
enum JoinResult {
  success('Successfully joined the space!'),
  inviteNotFound('Invalid invite code. Please check and try again.'),
  inviteExpired('This invite code has expired.'),
  spaceFull('This space already has 2 members.'),
  alreadyMember('You\'re already a member of this space.');

  const JoinResult(this.message);
  final String message;
}

/// Data returned after successfully creating a space.
class CreateSpaceResult {
  const CreateSpaceResult({
    required this.spaceId,
    required this.inviteCode,
  });

  final String spaceId;
  final String inviteCode;
}

// -----------------------------------------------------------------------------
// Firestore Service
// -----------------------------------------------------------------------------

/// Service class for Firestore operations with secure collection separation.
///
/// Collections:
/// - `invites/{code}` - Temporary invite codes (deleted after use)
/// - `spaces/{spaceId}` - Space name and member IDs
/// - `users/{uid}` - User profile data
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Collection names
  static const String _invitesCollection = 'invites';
  static const String _spacesCollection = 'spaces';
  static const String _usersCollection = 'users';

  // Local storage key
  static const String _spaceIdKey = 'user_space_id';

  // Invite code configuration
  static const int _inviteCodeLength = 6;
  static const String _inviteCodeChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static const Duration _inviteExpiration = Duration(days: 7);

  // ---------------------------------------------------------------------------
  // Space Creation
  // ---------------------------------------------------------------------------

  /// Creates a new couple space with a separate invite code.
  ///
  /// Returns [CreateSpaceResult] containing both spaceId and inviteCode.
  /// The invite code is stored separately and deleted after partner joins.
  Future<CreateSpaceResult> createSpace({
    required String userId,
    required String spaceName,
    required String userName,
    required String avatarKey,
  }) async {
    // Create the space document
    final spaceRef = _firestore.collection(_spacesCollection).doc();
    final spaceId = spaceRef.id;

    await spaceRef.set({
      'name': spaceName,
      'memberIds': [userId],
      'createdBy': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create user profile
    await _createOrUpdateUserProfile(
      userId: userId,
      name: userName,
      avatar: avatarKey,
      spaceId: spaceId,
    );

    // Generate invite code
    final inviteCode = await _createInvite(spaceId: spaceId, createdBy: userId);

    // Save space ID locally
    await saveSpaceId(spaceId);

    return CreateSpaceResult(spaceId: spaceId, inviteCode: inviteCode);
  }

  // ---------------------------------------------------------------------------
  // Invite Management
  // ---------------------------------------------------------------------------

  /// Creates a new invite code for a space.
  Future<String> _createInvite({
    required String spaceId,
    required String createdBy,
  }) async {
    final inviteCode = await _generateUniqueInviteCode();
    final expiresAt = DateTime.now().add(_inviteExpiration);

    await _firestore.collection(_invitesCollection).doc(inviteCode).set({
      'spaceId': spaceId,
      'createdBy': createdBy,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });

    return inviteCode;
  }

  /// Regenerates an invite code for a space (deletes old one if exists).
  Future<String> regenerateInvite({
    required String spaceId,
    required String userId,
  }) async {
    // Delete any existing invites for this space
    final existingInvites = await _firestore
        .collection(_invitesCollection)
        .where('spaceId', isEqualTo: spaceId)
        .get();

    for (final doc in existingInvites.docs) {
      await doc.reference.delete();
    }

    // Create new invite
    return _createInvite(spaceId: spaceId, createdBy: userId);
  }

  /// Gets the current invite code for a space, or creates one if none exists.
  Future<String?> getOrCreateInvite({
    required String spaceId,
    required String userId,
  }) async {
    // Check for existing valid invite
    final existingInvites = await _firestore
        .collection(_invitesCollection)
        .where('spaceId', isEqualTo: spaceId)
        .limit(1)
        .get();

    if (existingInvites.docs.isNotEmpty) {
      final invite = existingInvites.docs.first;
      final expiresAt = (invite.data()['expiresAt'] as Timestamp).toDate();

      // If not expired, return it
      if (expiresAt.isAfter(DateTime.now())) {
        return invite.id;
      }

      // Expired, delete it
      await invite.reference.delete();
    }

    // Create new invite
    return _createInvite(spaceId: spaceId, createdBy: userId);
  }

  // ---------------------------------------------------------------------------
  // Join Space
  // ---------------------------------------------------------------------------

  /// Joins an existing couple space using an invite code.
  ///
  /// Validates the invite, adds user to space, creates user profile,
  /// and deletes the invite code (one-time use).
  Future<JoinResult> joinSpace({
    required String inviteCode,
    required String userId,
    required String userName,
    required String avatarKey,
  }) async {
    // Get invite document
    final inviteRef = _firestore.collection(_invitesCollection).doc(inviteCode);
    final inviteDoc = await inviteRef.get();

    // Validate invite exists
    if (!inviteDoc.exists) {
      return JoinResult.inviteNotFound;
    }

    final inviteData = inviteDoc.data()!;
    final spaceId = inviteData['spaceId'] as String;
    final expiresAt = (inviteData['expiresAt'] as Timestamp).toDate();

    // Check if expired
    if (expiresAt.isBefore(DateTime.now())) {
      await inviteRef.delete(); // Clean up expired invite
      return JoinResult.inviteExpired;
    }

    // Get space document
    final spaceRef = _firestore.collection(_spacesCollection).doc(spaceId);
    final spaceDoc = await spaceRef.get();

    if (!spaceDoc.exists) {
      await inviteRef.delete(); // Clean up orphaned invite
      return JoinResult.inviteNotFound;
    }

    final spaceData = spaceDoc.data()!;
    final memberIds = List<String>.from(spaceData['memberIds'] ?? []);

    // Check if space is full
    if (memberIds.length >= 2) {
      return JoinResult.spaceFull;
    }

    // Check if user is already a member
    if (memberIds.contains(userId)) {
      return JoinResult.alreadyMember;
    }

    // Add user to space
    await spaceRef.update({
      'memberIds': FieldValue.arrayUnion([userId]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create user profile
    await _createOrUpdateUserProfile(
      userId: userId,
      name: userName,
      avatar: avatarKey,
      spaceId: spaceId,
    );

    // Delete the invite (one-time use)
    await inviteRef.delete();

    // Save space ID locally
    await saveSpaceId(spaceId);

    return JoinResult.success;
  }

  /// Gets the space ID from an invite code (for redirection after join).
  Future<String?> getSpaceIdFromInvite(String inviteCode) async {
    final inviteDoc =
        await _firestore.collection(_invitesCollection).doc(inviteCode).get();

    if (!inviteDoc.exists) return null;

    return inviteDoc.data()?['spaceId'] as String?;
  }

  // ---------------------------------------------------------------------------
  // User Profile
  // ---------------------------------------------------------------------------

  /// Creates or updates a user profile.
  Future<void> _createOrUpdateUserProfile({
    required String userId,
    required String name,
    required String avatar,
    required String spaceId,
  }) async {
    final userRef = _firestore.collection(_usersCollection).doc(userId);
    final userDoc = await userRef.get();

    if (userDoc.exists) {
      // Update existing profile
      await userRef.update({
        'name': name,
        'avatar': avatar,
        'spaceId': spaceId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      // Create new profile
      await userRef.set({
        'name': name,
        'avatar': avatar,
        'spaceId': spaceId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Gets a user's profile.
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final doc =
        await _firestore.collection(_usersCollection).doc(userId).get();
    return doc.exists ? doc.data() : null;
  }

  /// Updates user profile fields.
  Future<void> updateUserProfile({
    required String userId,
    String? name,
    String? avatar,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (name != null) updates['name'] = name;
    if (avatar != null) updates['avatar'] = avatar;

    await _firestore.collection(_usersCollection).doc(userId).update(updates);
  }

  // ---------------------------------------------------------------------------
  // Space Queries
  // ---------------------------------------------------------------------------

  /// Gets space details by ID.
  Future<Map<String, dynamic>?> getSpace(String spaceId) async {
    final doc =
        await _firestore.collection(_spacesCollection).doc(spaceId).get();

    if (!doc.exists) return null;

    return {'id': doc.id, ...doc.data()!};
  }

  /// Gets space details with member profiles.
  Future<Map<String, dynamic>?> getSpaceWithMembers(String spaceId) async {
    final spaceDoc =
        await _firestore.collection(_spacesCollection).doc(spaceId).get();

    if (!spaceDoc.exists) return null;

    final spaceData = spaceDoc.data()!;
    final memberIds = List<String>.from(spaceData['memberIds'] ?? []);

    // Fetch member profiles
    final members = <Map<String, dynamic>>[];
    for (final memberId in memberIds) {
      final profile = await getUserProfile(memberId);
      if (profile != null) {
        members.add({'userId': memberId, ...profile});
      }
    }

    return {
      'id': spaceDoc.id,
      ...spaceData,
      'members': members,
    };
  }

  /// Updates the name of a space.
  Future<void> updateSpaceName(String spaceId, String newName) async {
    await _firestore.collection(_spacesCollection).doc(spaceId).update({
      'name': newName,
    });
  }

  /// Gets the space ID for a given user.
  Future<String?> getUserSpaceId(String userId) async {
    // Check local storage first
    final savedSpaceId = await getSavedSpaceId();
    if (savedSpaceId != null) {
      if (await _verifyUserMembership(savedSpaceId, userId)) {
        return savedSpaceId;
      }
      await clearSavedSpaceId();
    }

    // Check user profile
    final profile = await getUserProfile(userId);
    if (profile != null && profile['spaceId'] != null) {
      final spaceId = profile['spaceId'] as String;
      if (await _verifyUserMembership(spaceId, userId)) {
        await saveSpaceId(spaceId);
        return spaceId;
      }
    }

    // Query spaces collection as fallback
    final query = await _firestore
        .collection(_spacesCollection)
        .where('memberIds', arrayContains: userId)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final spaceId = query.docs.first.id;
    await saveSpaceId(spaceId);
    return spaceId;
  }

  /// Verifies that a user is a member of a specific space.
  Future<bool> _verifyUserMembership(String spaceId, String userId) async {
    final doc =
        await _firestore.collection(_spacesCollection).doc(spaceId).get();

    if (!doc.exists) return false;

    final memberIds = List<String>.from(doc.data()?['memberIds'] ?? []);
    return memberIds.contains(userId);
  }

  // ---------------------------------------------------------------------------
  // Local Storage
  // ---------------------------------------------------------------------------

  Future<void> saveSpaceId(String spaceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_spaceIdKey, spaceId);
  }

  Future<String?> getSavedSpaceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_spaceIdKey);
  }

  Future<void> clearSavedSpaceId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_spaceIdKey);
  }

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  /// Returns a stream of upcoming events for a space.
  ///
  /// Events are sorted by scheduledAt and filtered to only include
  /// events within [daysAhead] days from now.
  Stream<List<SpaceEvent>> watchUpcomingEvents(
    String spaceId, {
    int daysAhead = 14,
  }) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endDate = startOfToday.add(Duration(days: daysAhead));

    return _firestore
        .collection(_spacesCollection)
        .doc(spaceId)
        .collection('events')
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(endDate))
        .orderBy('scheduledAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => SpaceEvent.fromFirestore(doc)).toList();
    });
  }

  /// Creates a new event in a couple space.
  Future<String> createEvent({
    required String spaceId,
    required String title,
    required EventType type,
    required DateTime scheduledAt,
    required String createdBy,
  }) async {
    final eventRef = _firestore
        .collection(_spacesCollection)
        .doc(spaceId)
        .collection('events')
        .doc();

    final event = SpaceEvent(
      id: eventRef.id,
      title: title,
      type: type,
      scheduledAt: scheduledAt,
      createdBy: createdBy,
    );

    await eventRef.set(event.toJson());

    // Update space's updatedAt timestamp
    await _firestore.collection(_spacesCollection).doc(spaceId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return eventRef.id;
  }

  /// Deletes an event from a couple space.
  Future<void> deleteEvent({
    required String spaceId,
    required String eventId,
  }) async {
    await _firestore
        .collection(_spacesCollection)
        .doc(spaceId)
        .collection('events')
        .doc(eventId)
        .delete();
  }

  /// Updates an existing event.
  Future<void> updateEvent({
    required String spaceId,
    required String eventId,
    String? title,
    EventType? type,
    DateTime? scheduledAt,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (title != null) updates['title'] = title;
    if (type != null) updates['type'] = type.value;
    if (scheduledAt != null) {
      updates['scheduledAt'] = Timestamp.fromDate(scheduledAt);
    }

    await _firestore
        .collection(_spacesCollection)
        .doc(spaceId)
        .collection('events')
        .doc(eventId)
        .update(updates);
  }

  // ---------------------------------------------------------------------------
  // Moments
  // ---------------------------------------------------------------------------

  /// Returns a stream of upcoming moments for a space.
  ///
  /// Moments are sorted by startDate and include all future moments
  /// plus any multi-day moments that span today.
  Stream<List<Moment>> watchUpcomingMoments(
    String spaceId, {
    int daysAhead = 60,
  }) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endDate = startOfToday.add(Duration(days: daysAhead));

    return _firestore
        .collection(_spacesCollection)
        .doc(spaceId)
        .collection('moments')
        .where('startDate', isLessThan: Timestamp.fromDate(endDate))
        .orderBy('startDate')
        .snapshots()
        .map((snapshot) {
      final moments = snapshot.docs
          .map((doc) => Moment.fromFirestore(doc))
          .where((m) => m.isUpcoming || m.spansToday)
          .toList();
      return moments;
    });
  }

  /// Gets the next upcoming moment for display on dashboard.
  Future<List<Moment>> getUpcomingMoments(
    String spaceId, {
    int limit = 5,
  }) async {
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);

      final snapshot = await _firestore
          .collection(_spacesCollection)
          .doc(spaceId)
          .collection('moments')
          .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .orderBy('startDate')
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => Moment.fromFirestore(doc)).toList();
    } catch (e) {
      debugPrint('Error getting upcoming moments: $e');
      return [];
    }
  }

  /// Creates a new moment in a couple space.
  Future<String> createMoment({
    required String spaceId,
    required String name,
    required MomentType type,
    required DateTime startDate,
    required String createdBy,
    DateTime? endDate,
    TimeSlot? timeSlot,
    RepeatSchedule repeatSchedule = RepeatSchedule.never,
  }) async {
    final momentRef = _firestore
        .collection(_spacesCollection)
        .doc(spaceId)
        .collection('moments')
        .doc();

    final moment = Moment(
      id: momentRef.id,
      name: name,
      type: type,
      startDate: startDate,
      endDate: endDate,
      timeSlot: timeSlot,
      repeatSchedule: repeatSchedule,
      createdBy: createdBy,
    );

    await momentRef.set(moment.toJson());

    // Update space's updatedAt timestamp
    await _firestore.collection(_spacesCollection).doc(spaceId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return momentRef.id;
  }

  /// Deletes a moment from a couple space.
  Future<void> deleteMoment({
    required String spaceId,
    required String momentId,
  }) async {
    await _firestore
        .collection(_spacesCollection)
        .doc(spaceId)
        .collection('moments')
        .doc(momentId)
        .delete();
  }

  /// Updates an existing moment.
  Future<void> updateMoment({
    required String spaceId,
    required String momentId,
    String? name,
    MomentType? type,
    DateTime? startDate,
    DateTime? endDate,
    TimeSlot? timeSlot,
    RepeatSchedule? repeatSchedule,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (name != null) updates['name'] = name;
    if (type != null) updates['type'] = type.value;
    if (startDate != null) {
      updates['startDate'] = Timestamp.fromDate(startDate);
    }
    if (endDate != null) {
      updates['endDate'] = Timestamp.fromDate(endDate);
    }
    if (timeSlot != null) updates['timeSlot'] = timeSlot.value;
    if (repeatSchedule != null) updates['repeatSchedule'] = repeatSchedule.value;

    await _firestore
        .collection(_spacesCollection)
        .doc(spaceId)
        .collection('moments')
        .doc(momentId)
        .update(updates);
  }

  // ---------------------------------------------------------------------------
  // Check-ins
  // ---------------------------------------------------------------------------

  /// Returns a stream of recent check-ins for a space.
  ///
  /// Check-ins are sorted by timestamp (newest first) and filtered to
  /// include only check-ins within [daysBack] days from now.
  Stream<List<UserCheckIn>> watchRecentCheckIns(
    String spaceId, {
    int daysBack = 30,
  }) {
    final cutoffDate = DateTime.now().subtract(Duration(days: daysBack));

    return _firestore
        .collection(_spacesCollection)
        .doc(spaceId)
        .collection('checkins')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate))
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => UserCheckIn.fromFirestore(doc)).toList();
    });
  }

  /// Gets recent check-ins for a specific user in a space.
  Future<List<UserCheckIn>> getUserCheckIns(
    String spaceId,
    String userId, {
    int limit = 4,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_spacesCollection)
          .doc(spaceId)
          .collection('checkins')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) => UserCheckIn.fromFirestore(doc)).toList();
    } catch (e) {
      // If composite index doesn't exist, fall back to fetching all and filtering
      debugPrint('Falling back to manual filtering: $e');
      final snapshot = await _firestore
          .collection(_spacesCollection)
          .doc(spaceId)
          .collection('checkins')
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => UserCheckIn.fromFirestore(doc))
          .where((c) => c.userId == userId)
          .take(limit)
          .toList();
    }
  }

  /// Submits a new check-in for the current user.
  Future<String> submitCheckIn({
    required String spaceId,
    required String userId,
    required int connection,
    required int intimacy,
    required int stress,
    String notes = '',
  }) async {
    final now = DateTime.now();
    // Document ID format: {userId}_{timestamp} for easy querying
    final docId = '${userId}_${now.millisecondsSinceEpoch}';

    final checkInRef = _firestore
        .collection(_spacesCollection)
        .doc(spaceId)
        .collection('checkins')
        .doc(docId);

    final checkIn = UserCheckIn(
      id: docId,
      userId: userId,
      timestamp: now,
      connection: connection,
      intimacy: intimacy,
      stress: stress,
      notes: notes,
    );

    await checkInRef.set(checkIn.toJson());

    // Update space's updatedAt timestamp
    await _firestore.collection(_spacesCollection).doc(spaceId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docId;
  }

  /// Gets combined check-in statistics for all members in a space.
  ///
  /// Returns stats based on check-ins from the last [days] days.
  Future<CheckInStats> getSpaceCheckInStats(
    String spaceId, {
    int days = 30,
    String? currentUserId,
  }) async {
    try {
      final now = DateTime.now();
      final cutoffDate = now.subtract(Duration(days: days));
      
      // Get all check-ins from the last N days
      final snapshot = await _firestore
          .collection(_spacesCollection)
          .doc(spaceId)
          .collection('checkins')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate))
          .get();
      
      if (snapshot.docs.isEmpty) {
        debugPrint('No check-ins in the last $days days');
        return CheckInStats.empty;
      }
      
      final allCheckIns = snapshot.docs
          .map((doc) => UserCheckIn.fromJson(doc.id, doc.data()))
          .toList();

      debugPrint('Check-ins in last $days days: ${allCheckIns.length}');

      // Sort by timestamp for trend calculation
      allCheckIns.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return CheckInStats.fromCheckIns(allCheckIns, currentUserId: currentUserId);
    } catch (e) {
      debugPrint('Error getting check-in stats: $e');
      return CheckInStats.empty;
    }
  }

  /// Gets the most recent check-in activity for display.
  /// Gets daily health scores for the last N days.
  /// Returns a list of maps with 'date' and 'score' (0-100 scale).
  Future<List<Map<String, dynamic>>> getDailyHealthScores(
    String spaceId, {
    int days = 7,
  }) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final cutoffDate = today.subtract(Duration(days: days - 1));
      
      final snapshot = await _firestore
          .collection(_spacesCollection)
          .doc(spaceId)
          .collection('checkins')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate))
          .orderBy('timestamp', descending: false)
          .get();
      
      // Group check-ins by day
      final Map<String, List<UserCheckIn>> byDay = {};
      for (final doc in snapshot.docs) {
        final checkIn = UserCheckIn.fromFirestore(doc);
        final dayKey = '${checkIn.timestamp.year}-${checkIn.timestamp.month}-${checkIn.timestamp.day}';
        byDay.putIfAbsent(dayKey, () => []).add(checkIn);
      }
      
      // Build result for each day
      final result = <Map<String, dynamic>>[];
      for (int i = 0; i < days; i++) {
        final date = cutoffDate.add(Duration(days: i));
        final dayKey = '${date.year}-${date.month}-${date.day}';
        final dayCheckIns = byDay[dayKey] ?? [];
        
        double score = 0;
        if (dayCheckIns.isNotEmpty) {
          // Calculate average health score for this day (1-10 scale -> 0-100)
          double totalScore = 0;
          for (final c in dayCheckIns) {
            final connectionPct = c.connection * 10;
            final intimacyPct = c.intimacy * 10;
            final peacePct = (10 - c.stress) * 10;
            totalScore += (connectionPct + intimacyPct + peacePct) / 3;
          }
          score = totalScore / dayCheckIns.length;
        }
        
        result.add({
          'date': date,
          'score': score,
          'hasCheckIn': dayCheckIns.isNotEmpty,
        });
      }
      
      return result;
    } catch (e) {
      debugPrint('Error getting daily health scores: $e');
      return [];
    }
  }
  
  /// Calculates the current check-in streak (consecutive days).
  Future<int> getCheckInStreak(String spaceId) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Get check-ins from last 60 days (more than enough to find streak)
      final cutoffDate = today.subtract(const Duration(days: 60));
      
      final snapshot = await _firestore
          .collection(_spacesCollection)
          .doc(spaceId)
          .collection('checkins')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(cutoffDate))
          .orderBy('timestamp', descending: true)
          .get();
      
      if (snapshot.docs.isEmpty) return 0;
      
      // Get unique days with check-ins
      final Set<String> daysWithCheckIns = {};
      for (final doc in snapshot.docs) {
        final checkIn = UserCheckIn.fromFirestore(doc);
        final dayKey = '${checkIn.timestamp.year}-${checkIn.timestamp.month}-${checkIn.timestamp.day}';
        daysWithCheckIns.add(dayKey);
      }
      
      // Count consecutive days starting from today (or yesterday if no check-in today)
      int streak = 0;
      var checkDate = today;
      final todayKey = '${today.year}-${today.month}-${today.day}';
      
      // If no check-in today, start from yesterday
      if (!daysWithCheckIns.contains(todayKey)) {
        checkDate = today.subtract(const Duration(days: 1));
      }
      
      while (true) {
        final dayKey = '${checkDate.year}-${checkDate.month}-${checkDate.day}';
        if (daysWithCheckIns.contains(dayKey)) {
          streak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
      
      return streak;
    } catch (e) {
      debugPrint('Error calculating streak: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getRecentCheckInActivity(
    String spaceId, {
    int limit = 5,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_spacesCollection)
          .doc(spaceId)
          .collection('checkins')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      debugPrint('Found ${snapshot.docs.length} check-ins for activity');

      final activity = <Map<String, dynamic>>[];

      for (final doc in snapshot.docs) {
        final checkIn = UserCheckIn.fromFirestore(doc);
        final profile = await getUserProfile(checkIn.userId);

        activity.add({
          'checkIn': checkIn,
          'userName': profile?['name'] ?? 'Partner',
        });
      }

      return activity;
    } catch (e) {
      debugPrint('Error getting check-in activity: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // Private Helpers
  // ---------------------------------------------------------------------------

  Future<String> _generateUniqueInviteCode() async {
    String code;
    bool exists;

    do {
      code = _generateInviteCode();
      final doc =
          await _firestore.collection(_invitesCollection).doc(code).get();
      exists = doc.exists;
    } while (exists);

    return code;
  }

  String _generateInviteCode() {
    final random = Random.secure();
    return List.generate(
      _inviteCodeLength,
      (_) => _inviteCodeChars[random.nextInt(_inviteCodeChars.length)],
    ).join();
  }
}
