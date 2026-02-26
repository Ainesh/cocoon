/// Abstract interface for score contribution sources.
///
/// Currently only check-ins contribute to the relationship health score.
/// In the future, moments, app activity, and other signals can implement
/// this interface to feed into the scoring engine.
library;

import 'score_models.dart';

/// A single score contribution from any source.
class ScoreContribution {
  const ScoreContribution({
    required this.sourceType,
    required this.userId,
    required this.timestamp,
    required this.attributeScores,
    required this.configSnapshot,
  });

  /// Identifies the source (e.g. 'checkin', 'moment', 'activity').
  final String sourceType;

  /// User who generated this contribution.
  final String userId;

  /// When this contribution occurred.
  final DateTime timestamp;

  /// Scores per attribute (1-100). Only includes attributes that were
  /// active at the time.
  final Map<String, int> attributeScores;

  /// The config snapshot that was active when this contribution was created.
  final ConfigSnapshot configSnapshot;
}

/// Interface for sources that contribute to the relationship health score.
///
/// Implement this for each type of score source (check-ins, moments, etc.).
abstract class ScoreSource {
  /// Returns all contributions within the given time window.
  ///
  /// [from] inclusive, [to] exclusive.
  List<ScoreContribution> getContributions({
    required DateTime from,
    required DateTime to,
  });
}
