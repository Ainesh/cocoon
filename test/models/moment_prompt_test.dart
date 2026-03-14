import 'package:flutter_test/flutter_test.dart';

import 'package:couple_space/models/memory.dart';
import 'package:couple_space/models/moment.dart';

void main() {
  // Simulate the client-side filtering from getPastMomentsAwaitingMemory:
  //   status == planned AND isPast AND within 14-day cutoff
  List<Moment> filterForPrompt(List<Moment> moments) {
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final cutoff = today.subtract(const Duration(days: 14));

    return moments
        .where((m) {
          if (m.status != MomentStatus.planned) return false;
          final end = m.endDate ?? m.startDate;
          return end.isBefore(today) && end.isAfter(cutoff);
        })
        .toList()
      ..sort((a, b) =>
          (b.endDate ?? b.startDate).compareTo(a.endDate ?? a.startDate));
  }

  Moment _moment({
    required String id,
    required DateTime startDate,
    DateTime? endDate,
    MomentStatus status = MomentStatus.planned,
  }) {
    return Moment(
      id: id,
      name: 'Test $id',
      type: MomentType.connect,
      startDate: startDate,
      endDate: endDate,
      createdBy: 'user_1',
      status: status,
    );
  }

  group('Prompt eligibility filtering', () {
    test('past planned moment within 14 days is eligible', () {
      final m = _moment(
        id: '1',
        startDate: DateTime.now().toUtc().subtract(const Duration(days: 3)),
      );
      final result = filterForPrompt([m]);
      expect(result, hasLength(1));
      expect(result.first.id, '1');
    });

    test('past planned moment older than 14 days is excluded', () {
      final m = _moment(
        id: '1',
        startDate: DateTime.now().toUtc().subtract(const Duration(days: 20)),
      );
      expect(filterForPrompt([m]), isEmpty);
    });

    test('future planned moment is excluded (not past)', () {
      final m = _moment(
        id: '1',
        startDate: DateTime.now().toUtc().add(const Duration(days: 5)),
      );
      expect(filterForPrompt([m]), isEmpty);
    });

    test('past moment with status == lived is excluded', () {
      final m = _moment(
        id: '1',
        startDate: DateTime.now().toUtc().subtract(const Duration(days: 3)),
        status: MomentStatus.lived,
      );
      expect(filterForPrompt([m]), isEmpty);
    });

    test('past moment with status == missed is excluded', () {
      final m = _moment(
        id: '1',
        startDate: DateTime.now().toUtc().subtract(const Duration(days: 3)),
        status: MomentStatus.missed,
      );
      expect(filterForPrompt([m]), isEmpty);
    });

    test('only planned past moments are returned, sorted newest first', () {
      final moments = [
        _moment(
          id: 'old',
          startDate: DateTime.now().toUtc().subtract(const Duration(days: 10)),
        ),
        _moment(
          id: 'recent',
          startDate: DateTime.now().toUtc().subtract(const Duration(days: 2)),
        ),
        _moment(
          id: 'lived',
          startDate: DateTime.now().toUtc().subtract(const Duration(days: 5)),
          status: MomentStatus.lived,
        ),
        _moment(
          id: 'missed',
          startDate: DateTime.now().toUtc().subtract(const Duration(days: 4)),
          status: MomentStatus.missed,
        ),
        _moment(
          id: 'future',
          startDate: DateTime.now().toUtc().add(const Duration(days: 3)),
        ),
      ];

      final result = filterForPrompt(moments);
      expect(result, hasLength(2));
      expect(result[0].id, 'recent');
      expect(result[1].id, 'old');
    });

    test('escape moment uses endDate for past check', () {
      final now = DateTime.now().toUtc();
      final m = Moment(
        id: 'escape_1',
        name: 'Trip',
        type: MomentType.escape,
        startDate: now.subtract(const Duration(days: 10)),
        endDate: now.subtract(const Duration(days: 3)),
        createdBy: 'user_1',
        status: MomentStatus.planned,
      );
      final result = filterForPrompt([m]);
      expect(result, hasLength(1));
    });

    test('escape moment still ongoing (endDate in future) is excluded', () {
      final now = DateTime.now().toUtc();
      final m = Moment(
        id: 'escape_ongoing',
        name: 'Trip',
        type: MomentType.escape,
        startDate: now.subtract(const Duration(days: 3)),
        endDate: now.add(const Duration(days: 2)),
        createdBy: 'user_1',
        status: MomentStatus.planned,
      );
      expect(filterForPrompt([m]), isEmpty);
    });

    test('moment with no status field defaults to planned (backward compat)', () {
      final m = Moment(
        id: 'legacy',
        name: 'Old moment',
        type: MomentType.celebrate,
        startDate: DateTime.now().toUtc().subtract(const Duration(days: 5)),
        createdBy: 'user_1',
      );
      expect(m.status, MomentStatus.planned);
      final result = filterForPrompt([m]);
      expect(result, hasLength(1));
    });

    test('user backs out of memory creation — moment stays planned, prompt reappears', () {
      final m = _moment(
        id: 'backed_out',
        startDate: DateTime.now().toUtc().subtract(const Duration(days: 2)),
        status: MomentStatus.planned,
      );

      // First check: eligible
      expect(filterForPrompt([m]), hasLength(1));

      // User taps "Lived it" but backs out — status stays planned (no status change)
      // Second check: still eligible
      expect(filterForPrompt([m]), hasLength(1));

      // User actually seals a memory — sealMemory sets status to lived
      final mLived = m.copyWith(status: MomentStatus.lived);
      expect(filterForPrompt([mLived]), isEmpty);
    });
  });
}
