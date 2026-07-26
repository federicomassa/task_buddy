import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/eisenhower.dart';
import 'package:task_buddy/models/task.dart';
import 'package:task_buddy/models/user_settings.dart';

void main() {
  final today = DateTime(2026, 7, 22);
  const weights = WsjfWeights(importantUrgent: 10, urgentOnly: 5, importantOnly: 3, neither: 1);

  Task buildTask({bool isImportant = false, bool isUrgent = false, Duration? timeEstimate}) {
    return Task(
      id: 't1',
      userId: 'u1',
      title: 'Test task',
      isRecurrent: false,
      categoryIds: const [],
      isCompleted: false,
      createdAt: today,
      timeEstimate: timeEstimate,
      isImportant: isImportant,
      isUrgent: isUrgent,
    );
  }

  group('quadrantOf', () {
    test('important & urgent', () {
      expect(quadrantOf(buildTask(isImportant: true, isUrgent: true)), EisenhowerQuadrant.importantUrgent);
    });

    test('urgent only', () {
      expect(quadrantOf(buildTask(isUrgent: true)), EisenhowerQuadrant.urgentOnly);
    });

    test('important only', () {
      expect(quadrantOf(buildTask(isImportant: true)), EisenhowerQuadrant.importantOnly);
    });

    test('neither', () {
      expect(quadrantOf(buildTask()), EisenhowerQuadrant.neither);
    });
  });

  group('priorityWeight', () {
    test('maps each quadrant to its configured weight', () {
      expect(priorityWeight(EisenhowerQuadrant.importantUrgent, weights), 10);
      expect(priorityWeight(EisenhowerQuadrant.urgentOnly, weights), 5);
      expect(priorityWeight(EisenhowerQuadrant.importantOnly, weights), 3);
      expect(priorityWeight(EisenhowerQuadrant.neither, weights), 1);
    });
  });

  group('wsjfScore', () {
    test('null when there is no time estimate', () {
      expect(wsjfScore(buildTask(isImportant: true, isUrgent: true), weights), isNull);
    });

    test('weight divided by duration in minutes', () {
      final task = buildTask(isImportant: true, isUrgent: true, timeEstimate: const Duration(minutes: 20));
      expect(wsjfScore(task, weights), 0.5);
    });

    test('lower priority quadrant scores lower for the same duration', () {
      final p0 = buildTask(isImportant: true, isUrgent: true, timeEstimate: const Duration(minutes: 30));
      final p3 = buildTask(timeEstimate: const Duration(minutes: 30));
      expect(wsjfScore(p0, weights)! > wsjfScore(p3, weights)!, isTrue);
    });
  });
}
