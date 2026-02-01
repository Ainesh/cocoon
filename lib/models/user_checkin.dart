/// Check-in model for Couple Space app.
///
/// Represents a user's relationship check-in with scores for
/// connection, intimacy, and stress levels.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single check-in entry from a user.
class UserCheckIn {
  const UserCheckIn({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.connection,
    required this.intimacy,
    required this.stress,
    this.notes = '',
  });

  /// Unique identifier (Firestore document ID).
  final String id;

  /// User ID who submitted this check-in.
  final String userId;

  /// When the check-in was submitted.
  final DateTime timestamp;

  /// Connection score (1-10).
  final int connection;

  /// Intimacy score (1-10).
  final int intimacy;

  /// Stress level (1-10, higher = more stressed).
  final int stress;

  /// Optional notes or appreciation.
  final String notes;

  /// Creates a UserCheckIn from Firestore document.
  factory UserCheckIn.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserCheckIn.fromJson(doc.id, data);
  }

  /// Creates a UserCheckIn from JSON data.
  factory UserCheckIn.fromJson(String id, Map<String, dynamic> json) {
    return UserCheckIn(
      id: id,
      userId: json['userId'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? (json['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
      connection: json['connection'] as int? ?? 5,
      intimacy: json['intimacy'] as int? ?? 5,
      stress: json['stress'] as int? ?? 5,
      notes: json['notes'] as String? ?? '',
    );
  }

  /// Converts this check-in to JSON for Firestore storage.
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'timestamp': Timestamp.fromDate(timestamp),
      'connection': connection,
      'intimacy': intimacy,
      'stress': stress,
      'notes': notes,
    };
  }

  /// Returns true if this check-in is from today.
  bool get isToday {
    final now = DateTime.now();
    return timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;
  }

  /// Returns a human-readable time ago string.
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

  /// Creates a copy with updated fields.
  UserCheckIn copyWith({
    String? id,
    String? userId,
    DateTime? timestamp,
    int? connection,
    int? intimacy,
    int? stress,
    String? notes,
  }) {
    return UserCheckIn(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      connection: connection ?? this.connection,
      intimacy: intimacy ?? this.intimacy,
      stress: stress ?? this.stress,
      notes: notes ?? this.notes,
    );
  }
}

/// Aggregated check-in statistics for a user.
class CheckInStats {
  const CheckInStats({
    required this.avgConnection,
    required this.avgIntimacy,
    required this.avgStress,
    required this.checkInCount,
    this.connectionTrend = 0,
    this.intimacyTrend = 0,
  });

  /// Average connection score.
  final double avgConnection;

  /// Average intimacy score.
  final double avgIntimacy;

  /// Average stress level.
  final double avgStress;

  /// Number of check-ins included in stats.
  final int checkInCount;

  /// Connection trend (-1 to 1, positive = improving).
  final double connectionTrend;

  /// Intimacy trend (-1 to 1, positive = improving).
  final double intimacyTrend;

  /// Empty stats for when there's no data.
  static const empty = CheckInStats(
    avgConnection: 0,
    avgIntimacy: 0,
    avgStress: 0,
    checkInCount: 0,
  );

  /// Calculates stats from a list of check-ins.
  factory CheckInStats.fromCheckIns(List<UserCheckIn> checkIns) {
    if (checkIns.isEmpty) return empty;

    final connection = checkIns.map((c) => c.connection).reduce((a, b) => a + b);
    final intimacy = checkIns.map((c) => c.intimacy).reduce((a, b) => a + b);
    final stress = checkIns.map((c) => c.stress).reduce((a, b) => a + b);
    final count = checkIns.length;

    // Calculate trend (compare first half vs second half)
    double connectionTrend = 0;
    double intimacyTrend = 0;

    if (count >= 4) {
      final mid = count ~/ 2;
      final older = checkIns.sublist(mid);
      final newer = checkIns.sublist(0, mid);

      final olderConnAvg = older.map((c) => c.connection).reduce((a, b) => a + b) / older.length;
      final newerConnAvg = newer.map((c) => c.connection).reduce((a, b) => a + b) / newer.length;
      connectionTrend = (newerConnAvg - olderConnAvg) / 10; // Normalize to -1 to 1

      final olderIntAvg = older.map((c) => c.intimacy).reduce((a, b) => a + b) / older.length;
      final newerIntAvg = newer.map((c) => c.intimacy).reduce((a, b) => a + b) / newer.length;
      intimacyTrend = (newerIntAvg - olderIntAvg) / 10;
    }

    return CheckInStats(
      avgConnection: connection / count,
      avgIntimacy: intimacy / count,
      avgStress: stress / count,
      checkInCount: count,
      connectionTrend: connectionTrend.clamp(-1, 1),
      intimacyTrend: intimacyTrend.clamp(-1, 1),
    );
  }
}
