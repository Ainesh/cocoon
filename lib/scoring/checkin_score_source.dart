/// Check-in based score source implementation.
///
/// Converts [UserCheckIn] objects into [ScoreContribution]s that the
/// scoring engine can process.
library;

import '../models/user_checkin.dart';
import 'score_source.dart';

/// Produces [ScoreContribution]s from check-in data.
class CheckInScoreSource implements ScoreSource {
  CheckInScoreSource(this._checkIns);

  final List<UserCheckIn> _checkIns;

  @override
  List<ScoreContribution> getContributions({
    required DateTime from,
    required DateTime to,
  }) {
    return _checkIns
        .where((c) => !c.timestamp.isBefore(from) && c.timestamp.isBefore(to))
        .map(
          (c) => ScoreContribution(
            sourceType: 'checkin',
            userId: c.userId,
            timestamp: c.timestamp,
            attributeScores: c.scores,
            configSnapshot: c.configSnapshot,
          ),
        )
        .toList();
  }
}
