import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/plan_scheduler.dart';
import 'package:task_buddy/models/task.dart';
import 'package:task_buddy/models/user_settings.dart';

void main() {
  final today = DateTime(2026, 7, 22);
  const weights = WsjfWeights(importantUrgent: 10, urgentOnly: 5, importantOnly: 3, neither: 1);

  Task buildTask(String id, {bool isImportant = false, bool isUrgent = false, required int minutes}) {
    return Task(
      id: id,
      userId: 'u1',
      title: id,
      isRecurrent: false,
      categoryIds: const [],
      isCompleted: false,
      createdAt: today,
      timeEstimate: Duration(minutes: minutes),
      isImportant: isImportant,
      isUrgent: isUrgent,
    );
  }

  group('computePlan', () {
    test('schedules highest-score task first, packed sequentially in a window', () {
      final low = buildTask('low', minutes: 30); // P3
      final high = buildTask('high', isImportant: true, isUrgent: true, minutes: 30); // P0
      final result = computePlan(
        tasks: [low, high],
        activeHours: const [TimeRange(startMinutes: 9 * 60, endMinutes: 12 * 60)],
        weights: weights,
        today: today,
      );

      expect(result.scheduledTimes['high'], DateTime(2026, 7, 22, 9, 0));
      expect(result.scheduledTimes['low'], DateTime(2026, 7, 22, 9, 30));
      expect(result.unscheduled, isEmpty);
    });

    test('packing treats active hours as one continuous timeline: a task '
        'that spans a break does not block the next task from starting '
        'right where it left off', () {
      // score(big) = 10/150 = 0.0667, score(small) = 1/60 = 0.0167, so big
      // is processed first.
      final big = buildTask('big', isImportant: true, isUrgent: true, minutes: 150);
      final small = buildTask('small', minutes: 60);
      final result = computePlan(
        tasks: [big, small],
        activeHours: const [
          TimeRange(startMinutes: 9 * 60, endMinutes: 11 * 60), // 120 min
          TimeRange(startMinutes: 13 * 60, endMinutes: 18 * 60),
        ],
        weights: weights,
        today: today,
      );

      // `big` (150min) starts at 9:00 and, on the continuous timeline, runs
      // through the whole morning window (120min) plus 30 more minutes —
      // which land at 13:00-13:30 once mapped back to real time. `small`
      // then starts exactly where `big`'s virtual time left off: 13:30.
      expect(result.scheduledTimes['big'], DateTime(2026, 7, 22, 9, 0));
      expect(result.scheduledTimes['small'], DateTime(2026, 7, 22, 13, 30));
      expect(result.unscheduled, isEmpty);
    });

    test('tasks that do not fit anywhere are reported as unscheduled', () {
      final task = buildTask('big', minutes: 500);
      final result = computePlan(
        tasks: [task],
        activeHours: const [TimeRange(startMinutes: 9 * 60, endMinutes: 12 * 60)],
        weights: weights,
        today: today,
      );

      expect(result.scheduledTimes, isEmpty);
      expect(result.unscheduled, [task]);
    });

    test('reports remaining gaps when tasks fit with time to spare', () {
      final task = buildTask('a', isImportant: true, isUrgent: true, minutes: 60);
      final result = computePlan(
        tasks: [task],
        activeHours: const [
          TimeRange(startMinutes: 9 * 60, endMinutes: 12 * 60), // 180 min
          TimeRange(startMinutes: 13 * 60, endMinutes: 18 * 60), // 300 min
        ],
        weights: weights,
        today: today,
      );

      expect(result.totalActiveMinutes, 480);
      expect(result.totalEstimateMinutes, 60);
      expect(result.remainingGaps, [
        const TimeRange(startMinutes: 10 * 60, endMinutes: 12 * 60),
        const TimeRange(startMinutes: 13 * 60, endMinutes: 18 * 60),
      ]);
    });

    test('no remaining gaps when some tasks are unscheduled', () {
      final task = buildTask('big', minutes: 500);
      final result = computePlan(
        tasks: [task],
        activeHours: const [TimeRange(startMinutes: 9 * 60, endMinutes: 12 * 60)],
        weights: weights,
        today: today,
      );

      expect(result.remainingGaps, isEmpty);
    });
  });
}
