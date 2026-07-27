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
      estimatedDuration: Duration(minutes: minutes),
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

      expect(result.scheduledRanges['high'], [
        TaskTimeRange(start: DateTime(2026, 7, 22, 9, 0), end: DateTime(2026, 7, 22, 9, 30)),
      ]);
      expect(result.scheduledRanges['low'], [
        TaskTimeRange(start: DateTime(2026, 7, 22, 9, 30), end: DateTime(2026, 7, 22, 10, 0)),
      ]);
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
      // which splits into a morning segment and a 13:00-13:30 segment once
      // mapped back to real time. `small` then starts exactly where `big`'s
      // virtual time left off: 13:30.
      expect(result.scheduledRanges['big'], [
        TaskTimeRange(start: DateTime(2026, 7, 22, 9, 0), end: DateTime(2026, 7, 22, 11, 0)),
        TaskTimeRange(start: DateTime(2026, 7, 22, 13, 0), end: DateTime(2026, 7, 22, 13, 30)),
      ]);
      expect(result.scheduledRanges['small'], [
        TaskTimeRange(start: DateTime(2026, 7, 22, 13, 30), end: DateTime(2026, 7, 22, 14, 30)),
      ]);
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

      expect(result.scheduledRanges, isEmpty);
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

    test('picks the higher-combined-value pair of deadline-bound tasks over '
        'a single long unconstrained one that would crowd them out', () {
      // Capacity: 9:00-10:40 = 100 min.
      final a = buildTask('a', isImportant: true, isUrgent: true, minutes: 100); // score 10/100 = 0.1
      final b = Task(
        id: 'b',
        userId: 'u1',
        title: 'b',
        isRecurrent: false,
        categoryIds: const [],
        isCompleted: false,
        createdAt: today,
        estimatedDuration: const Duration(minutes: 40),
        isImportant: true,
        isUrgent: true, // score 10/40 = 0.25
        dueDate: DateTime(2026, 7, 22, 9, 40), // virtual deadline 40 -> must run first
      );
      final c = buildTask('c', isImportant: true, minutes: 40); // score 3/40 = 0.075

      final result = computePlan(
        tasks: [a, b, c],
        activeHours: const [TimeRange(startMinutes: 9 * 60, endMinutes: 10 * 60 + 40)],
        weights: weights,
        today: today,
      );

      expect(result.scheduledRanges.containsKey('b'), isTrue);
      expect(result.scheduledRanges.containsKey('c'), isTrue);
      expect(result.scheduledRanges.containsKey('a'), isFalse);
      expect(result.unscheduled, [a]);
      expect(result.infeasibleTasks, isEmpty);
    });

    test('a task due earlier than its own duration allows is reported as '
        'infeasible, not unscheduled', () {
      final task = Task(
        id: 'tight',
        userId: 'u1',
        title: 'Finish report',
        isRecurrent: false,
        categoryIds: const [],
        isCompleted: false,
        createdAt: today,
        estimatedDuration: const Duration(minutes: 60),
        dueDate: DateTime(2026, 7, 22, 9, 15),
      );

      final result = computePlan(
        tasks: [task],
        activeHours: const [TimeRange(startMinutes: 9 * 60, endMinutes: 17 * 60)],
        weights: weights,
        today: today,
      );

      expect(result.infeasibleTasks, hasLength(1));
      expect(result.infeasibleTasks.single.task.id, 'tight');
      expect(result.infeasibleTasks.single.reason, contains('Finish report'));
      expect(result.infeasibleTasks.single.reason, contains('9:15 AM'));
      expect(result.infeasibleTasks.single.reason, contains('1h'));
      expect(result.unscheduled, isEmpty);
      expect(result.scheduledRanges, isEmpty);
    });

    test('urgent tasks are guaranteed a slot over any amount of optional '
        "packing, as long as they'd fit", () {
      // 8h of capacity. Two urgent tasks (5h25m + 2h30m = 475min) leave only
      // 5 spare minutes, yet score far lower per-minute than the tiny
      // optional tasks below -- plain WSJF-value knapsacking would drop one
      // or both long urgent tasks in favor of packing many small ones.
      final bigUrgent1 = buildTask('big1', isImportant: true, isUrgent: true, minutes: 5 * 60 + 25);
      final bigUrgent2 = buildTask('big2', isImportant: true, isUrgent: true, minutes: 2 * 60 + 30);
      final tinyOptional = [
        for (var i = 0; i < 8; i++) buildTask('tiny$i', minutes: 15), // P3 each, high score/minute
      ];

      final result = computePlan(
        tasks: [...tinyOptional, bigUrgent1, bigUrgent2],
        activeHours: const [TimeRange(startMinutes: 9 * 60, endMinutes: 17 * 60)], // 480 min
        weights: weights,
        today: today,
      );

      expect(result.scheduledRanges.containsKey('big1'), isTrue);
      expect(result.scheduledRanges.containsKey('big2'), isTrue);
    });

    test('an overdue task keeps its old due time from acting as a same-day '
        'deadline', () {
      final task = Task(
        id: 'overdue',
        userId: 'u1',
        title: 'overdue',
        isRecurrent: false,
        categoryIds: const [],
        isCompleted: false,
        createdAt: today,
        estimatedDuration: const Duration(minutes: 60),
        dueDate: DateTime(2026, 7, 21, 8, 0), // yesterday, 08:00 -- before the day even starts
      );

      final result = computePlan(
        tasks: [task],
        activeHours: const [TimeRange(startMinutes: 9 * 60, endMinutes: 12 * 60)],
        weights: weights,
        today: today,
      );

      expect(result.infeasibleTasks, isEmpty);
      expect(result.scheduledRanges['overdue'], [
        TaskTimeRange(start: DateTime(2026, 7, 22, 9, 0), end: DateTime(2026, 7, 22, 10, 0)),
      ]);
    });
  });
}
