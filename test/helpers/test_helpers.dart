/// Factory methods for creating test data objects.
///
/// Provides convenient constructors for [Moment], [Activity], [UserCheckIn],
/// [PulseConfig], [ScoreResult], and [AvatarData] with sensible defaults.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:couple_space/models/activity.dart';
import 'package:couple_space/models/avatar_data.dart';
import 'package:couple_space/models/moment.dart';
import 'package:couple_space/models/pulse_config.dart';
import 'package:couple_space/models/user_checkin.dart';
import 'package:couple_space/scoring/score_models.dart';

/// UTC midnight today — use for all test date defaults.
DateTime _todayUtc() {
  final now = DateTime.now();
  return DateTime.utc(now.year, now.month, now.day);
}

// =============================================================================
// Moment Factories
// =============================================================================

/// Creates a test [Moment] with sensible defaults.
Moment createTestMoment({
  String id = 'moment_1',
  String name = 'Date Night',
  MomentType type = MomentType.connect,
  DateTime? startDate,
  DateTime? endDate,
  TimeSlot? timeSlot,
  RepeatSchedule repeatSchedule = RepeatSchedule.never,
  String? notes,
  String createdBy = 'user_1',
  DateTime? createdAt,
  DateTime? updatedAt,
  int version = 1,
}) {
  return Moment(
    id: id,
    name: name,
    type: type,
    startDate: startDate ?? _todayUtc().add(const Duration(days: 1)),
    endDate: endDate,
    timeSlot: timeSlot,
    repeatSchedule: repeatSchedule,
    notes: notes,
    createdBy: createdBy,
    createdAt: createdAt,
    updatedAt: updatedAt,
    version: version,
  );
}

/// Creates a test [Moment] that represents an Escape (multi-day trip).
Moment createTestEscapeMoment({
  String id = 'escape_1',
  String name = 'Beach Trip',
  DateTime? startDate,
  DateTime? endDate,
}) {
  final start = startDate ?? _todayUtc().add(const Duration(days: 7));
  return createTestMoment(
    id: id,
    name: name,
    type: MomentType.escape,
    startDate: start,
    endDate: endDate ?? start.add(const Duration(days: 3)),
  );
}

// =============================================================================
// Activity Factories
// =============================================================================

/// Creates a test [Activity] with sensible defaults.
Activity createTestActivity({
  String id = 'activity_1',
  ActivityType type = ActivityType.checkin,
  String actorId = 'user_1',
  String actorName = 'Alex',
  DateTime? timestamp,
  EntityType? entityType,
  String? entityId,
  Map<String, dynamic>? metadata,
}) {
  return Activity(
    id: id,
    type: type,
    actorId: actorId,
    actorName: actorName,
    timestamp: timestamp ?? DateTime.now(),
    entityType: entityType,
    entityId: entityId,
    metadata: metadata,
  );
}

/// Creates a test moment-planned [Activity].
Activity createTestMomentPlannedActivity({
  String momentName = 'Date Night',
  String momentType = 'connect',
}) {
  return createTestActivity(
    type: ActivityType.momentPlanned,
    entityType: EntityType.moment,
    entityId: 'moment_1',
    metadata: {'momentName': momentName, 'momentType': momentType},
  );
}

// =============================================================================
// UserCheckIn Factories (new v2 format: scores map + configSnapshot)
// =============================================================================

/// Creates a test [UserCheckIn] with dynamic scores (1-100 scale).
///
/// Also supports legacy-style named params [connection], [intimacy], [peace]
/// which are mapped into the scores map.
UserCheckIn createTestCheckIn({
  String id = 'checkin_1',
  String userId = 'user_1',
  DateTime? timestamp,
  Map<String, int>? scores,
  ConfigSnapshot? configSnapshot,
  int connection = 70,
  int intimacy = 60,
  int peace = 80,
  String notes = '',
}) {
  final effectiveScores = scores ??
      {
        'connection': connection,
        'intimacy': intimacy,
        'peace': peace,
      };
  final effectiveSnapshot = configSnapshot ??
      ConfigSnapshot(
        activeAttributes: effectiveScores.keys.toList(),
        weights: {
          for (final k in effectiveScores.keys) k: 1.0 / effectiveScores.length,
        },
      );

  return UserCheckIn(
    id: id,
    userId: userId,
    timestamp: timestamp ?? DateTime.now(),
    scores: effectiveScores,
    configSnapshot: effectiveSnapshot,
    notes: notes,
  );
}

/// Creates a list of test check-ins for trend calculations.
List<UserCheckIn> createTestCheckInSeries({
  String userId = 'user_1',
  int count = 6,
}) {
  return List.generate(count, (i) {
    return createTestCheckIn(
      id: 'checkin_$i',
      userId: userId,
      timestamp: DateTime.now().subtract(Duration(days: count - i)),
      connection: 50 + (i % 4) * 10,
      intimacy: 40 + (i % 3) * 10,
      peace: 60 + (i % 5) * 10,
    );
  });
}

// =============================================================================
// PulseConfig Factories
// =============================================================================

/// Creates a test [PulseConfig] with customisable picks.
PulseConfig createTestPulseConfig({
  Map<String, List<String>>? userPicks,
  DateTime? updatedAt,
}) {
  return PulseConfig(
    userPicks: userPicks ??
        {
          'user_a': ['connection', 'trust', 'communication'],
          'user_b': ['connection', 'intimacy', 'trust'],
        },
    updatedAt: updatedAt,
  );
}

// =============================================================================
// ScoreResult Factories
// =============================================================================

/// Creates a test [ScoreResult] for widget tests.
ScoreResult createTestScoreResult({
  int overallScore = 72,
  Map<String, double>? attributeScores,
  Map<String, double>? attributeTrends,
  double overallTrend = 0.1,
  InsightLabel insight = InsightLabel.steady,
  int checkInCount = 10,
  int userCheckInCount = 5,
  int partnerCheckInCount = 5,
  int streak = 3,
  Map<String, double>? weights,
}) {
  return ScoreResult(
    overallScore: overallScore,
    attributeScores: attributeScores ??
        {'connection': 75, 'intimacy': 68, 'peace': 72},
    attributeTrends: attributeTrends ??
        {'connection': 0.1, 'intimacy': 0.05, 'peace': -0.02},
    overallTrend: overallTrend,
    weeklyScores: List.generate(
      4,
      (i) => WeeklyScore(
        weekIndex: i,
        startDate: DateTime.now().subtract(Duration(days: 28 - i * 7)),
        endDate: DateTime.now().subtract(Duration(days: 22 - i * 7)),
        overallScore: 65.0 + i * 3,
        hasData: true,
      ),
    ),
    insight: insight,
    checkInCount: checkInCount,
    userCheckInCount: userCheckInCount,
    partnerCheckInCount: partnerCheckInCount,
    streak: streak,
    weights: weights ??
        {'connection': 0.333, 'intimacy': 0.167, 'peace': 0.167, 'trust': 0.333},
  );
}

// =============================================================================
// AvatarData Factories
// =============================================================================

/// Creates a test [AvatarData].
AvatarData createTestAvatarData({
  String id = 'avatar_1',
  String name = 'Happy',
  IconData icon = Icons.sentiment_very_satisfied,
}) {
  return AvatarData(id: id, name: name, icon: icon);
}

/// Creates a test [AvatarSelection].
AvatarSelection createTestAvatarSelection({
  AvatarData? avatar,
  AvatarColor color = AvatarColor.blue,
}) {
  return AvatarSelection(
    avatar: avatar ?? createTestAvatarData(),
    color: color,
  );
}

// =============================================================================
// Firestore Data Factories
// =============================================================================

/// Creates a Firestore-compatible map for a Moment.
Map<String, dynamic> createTestMomentJson({
  String name = 'Date Night',
  String type = 'connect',
  DateTime? startDate,
  DateTime? endDate,
  String? timeSlot,
  String repeatSchedule = 'never',
  String? notes,
  String createdBy = 'user_1',
  int version = 1,
}) {
  return {
    'name': name,
    'type': type,
    'startDate': Timestamp.fromDate(startDate ?? DateTime.now()),
    if (endDate != null) 'endDate': Timestamp.fromDate(endDate),
    if (timeSlot != null) 'timeSlot': timeSlot,
    'repeatSchedule': repeatSchedule,
    if (notes != null) 'notes': notes,
    'createdBy': createdBy,
    'createdAt': Timestamp.fromDate(DateTime.now()),
    'updatedAt': Timestamp.fromDate(DateTime.now()),
    'version': version,
  };
}

/// Creates a Firestore-compatible map for a UserCheckIn (compact format).
///
/// ```json
/// "scores": {"connection": {"value": 70, "weight": 0.33}, ...}
/// ```
Map<String, dynamic> createTestCheckInJson({
  String userId = 'user_1',
  DateTime? timestamp,
  Map<String, int>? scores,
  Map<String, double>? weights,
  int connection = 70,
  int intimacy = 60,
  int peace = 80,
  String notes = '',
}) {
  final effectiveScores = scores ??
      {'connection': connection, 'intimacy': intimacy, 'peace': peace};
  final effectiveWeights = weights ??
      {for (final k in effectiveScores.keys) k: 1.0 / effectiveScores.length};

  final compactScores = <String, dynamic>{};
  for (final k in effectiveScores.keys) {
    compactScores[k] = {
      'value': effectiveScores[k],
      'weight': effectiveWeights[k] ?? 0,
    };
  }

  return {
    'userId': userId,
    'timestamp': Timestamp.fromDate(timestamp ?? DateTime.now()),
    'scores': compactScores,
    'notes': notes,
  };
}

/// Creates a Firestore-compatible map for an Activity.
Map<String, dynamic> createTestActivityJson({
  String type = 'checkin',
  String actorId = 'user_1',
  String actorName = 'Alex',
  DateTime? timestamp,
  String? entityType,
  String? entityId,
  Map<String, dynamic>? metadata,
}) {
  return {
    'type': type,
    'actorId': actorId,
    'actorName': actorName,
    'timestamp': Timestamp.fromDate(timestamp ?? DateTime.now()),
    if (entityType != null) 'entityType': entityType,
    if (entityId != null) 'entityId': entityId,
    if (metadata != null) 'metadata': metadata,
  };
}
