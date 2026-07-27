import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/models/task.dart';

void main() {
  Task buildTask() {
    return Task(
      id: 't1',
      userId: 'u1',
      title: 'task',
      isRecurrent: false,
      categoryIds: const [],
      isCompleted: false,
      createdAt: DateTime(2026, 7, 26),
      estimatedExecutionTimeRanges: [
        TaskTimeRange(start: DateTime(2026, 7, 26, 9), end: DateTime(2026, 7, 26, 10)),
      ],
    );
  }

  group('Task.copyWith', () {
    test('clears estimatedExecutionTimeRanges to an explicitly-typed empty list', () {
      final task = buildTask();
      final cleared = task.copyWith(estimatedExecutionTimeRanges: const <TaskTimeRange>[]);
      expect(cleared.estimatedExecutionTimeRanges, isEmpty);
    });

    test('replaces estimatedExecutionTimeRanges with new ranges', () {
      final task = buildTask();
      final newRanges = [
        TaskTimeRange(start: DateTime(2026, 7, 26, 11), end: DateTime(2026, 7, 26, 12)),
      ];
      final rescheduled = task.copyWith(estimatedExecutionTimeRanges: newRanges);
      expect(rescheduled.estimatedExecutionTimeRanges, newRanges);
    });

    test('omitting estimatedExecutionTimeRanges leaves it unchanged', () {
      final task = buildTask();
      final copy = task.copyWith(title: 'renamed');
      expect(copy.estimatedExecutionTimeRanges, task.estimatedExecutionTimeRanges);
    });

    test('clears familyId to null', () {
      final task = buildTask().copyWith(isFamilyTask: true, familyId: 'f1');
      final cleared = task.copyWith(isFamilyTask: false, familyId: null);
      expect(cleared.familyId, isNull);
    });

    test('replaces familyId with a new value', () {
      final task = buildTask();
      final updated = task.copyWith(familyId: 'f1');
      expect(updated.familyId, 'f1');
    });

    test('omitting familyId leaves it unchanged', () {
      final task = buildTask().copyWith(isFamilyTask: true, familyId: 'f1');
      final copy = task.copyWith(title: 'renamed');
      expect(copy.familyId, 'f1');
    });
  });

  group('Task defaults', () {
    test('a task with no explicit ownerIds defaults to owning itself', () {
      final task = buildTask();
      expect(task.ownerIds, ['u1']);
    });
  });
}
