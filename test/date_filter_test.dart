import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/date_filter.dart';
import 'package:task_buddy/models/goal.dart';

void main() {
  final today = DateTime(2026, 7, 25);

  group('matchesDatePreset', () {
    test('null preset always matches, including null dueDate', () {
      expect(matchesDatePreset(null, null, today: today), true);
      expect(matchesDatePreset(DateTime(2026, 7, 25), null, today: today), true);
    });

    test('null dueDate never matches a concrete preset', () {
      for (final preset in [DatePreset.today, DatePreset.tomorrow, DatePreset.thisWeek]) {
        expect(matchesDatePreset(null, preset, today: today), false);
      }
    });

    test('today preset matches only today', () {
      expect(matchesDatePreset(DateTime(2026, 7, 25), DatePreset.today, today: today), true);
      expect(matchesDatePreset(DateTime(2026, 7, 24), DatePreset.today, today: today), false);
      expect(matchesDatePreset(DateTime(2026, 7, 26), DatePreset.today, today: today), false);
    });

    test('tomorrow preset matches only tomorrow', () {
      expect(matchesDatePreset(DateTime(2026, 7, 26), DatePreset.tomorrow, today: today), true);
      expect(matchesDatePreset(DateTime(2026, 7, 25), DatePreset.tomorrow, today: today), false);
    });

    test('thisWeek preset is a rolling 7-day window starting today', () {
      expect(matchesDatePreset(DateTime(2026, 7, 25), DatePreset.thisWeek, today: today), true);
      expect(matchesDatePreset(DateTime(2026, 7, 31), DatePreset.thisWeek, today: today), true);
      expect(matchesDatePreset(DateTime(2026, 8, 1), DatePreset.thisWeek, today: today), false);
      expect(matchesDatePreset(DateTime(2026, 7, 24), DatePreset.thisWeek, today: today), false);
    });

    test('custom range is inclusive of both bounds', () {
      final start = DateTime(2026, 7, 20);
      final end = DateTime(2026, 7, 22);
      expect(
        matchesDatePreset(
          DateTime(2026, 7, 20),
          DatePreset.custom,
          today: today,
          customStart: start,
          customEnd: end,
        ),
        true,
      );
      expect(
        matchesDatePreset(
          DateTime(2026, 7, 22),
          DatePreset.custom,
          today: today,
          customStart: start,
          customEnd: end,
        ),
        true,
      );
      expect(
        matchesDatePreset(
          DateTime(2026, 7, 23),
          DatePreset.custom,
          today: today,
          customStart: start,
          customEnd: end,
        ),
        false,
      );
    });

    test('custom range with only one bound is unbounded on the other side', () {
      expect(
        matchesDatePreset(
          DateTime(2099, 1, 1),
          DatePreset.custom,
          today: today,
          customStart: DateTime(2026, 7, 20),
        ),
        true,
      );
    });
  });

  group('isGoalOverdue', () {
    Goal goal({DateTime? dueDate, bool isCompleted = false}) {
      return Goal(
        id: 'g1',
        userId: 'u1',
        title: 'Goal',
        description: '',
        isHabitInstance: false,
        dueDate: dueDate,
        currentProgress: 0,
        isCompleted: isCompleted,
        createdAt: today,
      );
    }

    test('null dueDate is never overdue', () {
      expect(isGoalOverdue(goal(), today: today), false);
    });

    test('dueDate before today is overdue', () {
      expect(isGoalOverdue(goal(dueDate: DateTime(2026, 7, 24)), today: today), true);
    });

    test('completed goal with past dueDate is not overdue', () {
      expect(
        isGoalOverdue(goal(dueDate: DateTime(2026, 7, 24), isCompleted: true), today: today),
        false,
      );
    });
  });

  group('matchesTimeFilter', () {
    test('overdue toggle ORs with preset match', () {
      const filter = DateRangeFilter(preset: DatePreset.tomorrow, showOverdue: true);
      expect(
        matchesTimeFilter(
          dueDate: DateTime(2026, 7, 20),
          isOverdue: true,
          filter: filter,
          today: today,
        ),
        true,
      );
    });

    test('overdue toggle off falls back to preset-only match', () {
      const filter = DateRangeFilter(preset: DatePreset.tomorrow, showOverdue: false);
      expect(
        matchesTimeFilter(
          dueDate: DateTime(2026, 7, 20),
          isOverdue: true,
          filter: filter,
          today: today,
        ),
        false,
      );
    });

    test('defaults (no preset, overdue on) always match', () {
      final filter = DateRangeFilter.defaults();
      expect(
        matchesTimeFilter(dueDate: null, isOverdue: false, filter: filter, today: today),
        true,
      );
    });
  });
}
