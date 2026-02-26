/// Check-in model for Couple Space app.
///
/// Represents a user's relationship check-in with dynamic pulse attribute
/// scores on a 1-100 scale stored in compact format:
/// ```json
/// "scores": {"connection": {"value": 80, "weight": 0.33}, ...}
/// ```
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import '../scoring/score_models.dart';

/// Represents a single check-in entry from a user.
class UserCheckIn {
  const UserCheckIn({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.scores,
    required this.configSnapshot,
    this.notes = '',
  });

  /// Unique identifier (Firestore document ID).
  final String id;

  /// User ID who submitted this check-in.
  final String userId;

  /// When the check-in was submitted.
  final DateTime timestamp;

  /// Attribute scores (1-100). Keys are attribute IDs.
  final Map<String, int> scores;

  /// The pulse configuration that was active when this check-in was created.
  final ConfigSnapshot configSnapshot;

  /// Optional notes or appreciation.
  final String notes;

  // -------------------------------------------------------------------------
  // Convenience getters
  // -------------------------------------------------------------------------

  int get connection => scores['connection'] ?? 0;
  int get intimacy => scores['intimacy'] ?? 0;
  int get peace => scores['peace'] ?? 0;

  // -------------------------------------------------------------------------
  // Firestore serialisation
  // -------------------------------------------------------------------------

  factory UserCheckIn.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserCheckIn.fromJson(doc.id, data);
  }

  /// Parses the compact scores format:
  /// ```json
  /// "scores": {"connection": {"value": 80, "weight": 0.33}, ...}
  /// ```
  factory UserCheckIn.fromJson(String id, Map<String, dynamic> json) {
    try {
      final rawScores = Map<String, dynamic>.from(
        json['scores'] as Map? ?? {},
      );

      final scores = rawScores.map(
        (k, v) => MapEntry(k, ((v as Map)['value'] as num).toInt()),
      );
      final snapshot = ConfigSnapshot.fromScoresMap(rawScores);

      return UserCheckIn(
        id: id,
        userId: json['userId'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? (json['timestamp'] as Timestamp).toDate()
            : DateTime.now(),
        scores: scores,
        configSnapshot: snapshot,
        notes: json['notes'] as String? ?? '',
      );
    } catch (_) {
      // Malformed document — return empty check-in so streams don't break
      return UserCheckIn(
        id: id,
        userId: json['userId'] as String? ?? '',
        timestamp: json['timestamp'] != null
            ? (json['timestamp'] as Timestamp).toDate()
            : DateTime.now(),
        scores: const {},
        configSnapshot: const ConfigSnapshot(
          activeAttributes: [],
          weights: {},
        ),
        notes: '',
      );
    }
  }

  /// Compact JSON for Firestore:
  /// ```json
  /// "scores": {"connection": {"value": 80, "weight": 0.33}, ...}
  /// ```
  Map<String, dynamic> toJson() {
    final compactScores = <String, dynamic>{};
    for (final attr in scores.keys) {
      compactScores[attr] = {
        'value': scores[attr],
        'weight': configSnapshot.weights[attr] ?? 0,
      };
    }

    return {
      'userId': userId,
      'timestamp': Timestamp.fromDate(timestamp),
      'scores': compactScores,
      'notes': notes,
    };
  }

  bool get isToday {
    final now = DateTime.now();
    return timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  UserCheckIn copyWith({
    String? id,
    String? userId,
    DateTime? timestamp,
    Map<String, int>? scores,
    ConfigSnapshot? configSnapshot,
    String? notes,
  }) {
    return UserCheckIn(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      scores: scores ?? this.scores,
      configSnapshot: configSnapshot ?? this.configSnapshot,
      notes: notes ?? this.notes,
    );
  }
}
