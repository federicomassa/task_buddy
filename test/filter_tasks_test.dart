import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/date_filter.dart';
import 'package:task_buddy/features/tasks/tasks_screen.dart';
import 'package:task_buddy/models/task.dart';

void main() {
  final today = DateTime(2026, 7, 25);
  final defaults = DateRangeFilter.defaults();

  Task task({
    required String id,
    bool isCompleted = false,
    DateTime? dueDate,
    List<String> categoryIds = const [],
  }) {
    return Task(
      id: id,
      userId: 'u1',
      title: 'Task $id',
      dueDate: dueDate,
      isRecurrent: false,
      categoryIds: categoryIds,
      isCompleted: isCompleted,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  test('active filter keeps incomplete tasks with a due date, sorted by due date', () {
    final tasks = [
      task(id: 't1', dueDate: DateTime(2026, 7, 25)),
      task(id: 't2', dueDate: DateTime(2026, 7, 20)),
      task(id: 't3'), // no due date, excluded
      task(id: 't4', dueDate: DateTime(2026, 7, 22), isCompleted: true), // completed, excluded
    ];
    final result = filterTasks(tasks, TaskFilter.active, null, defaults, today: today);
    expect(result.map((t) => t.id), ['t2', 't1']);
  });

  test('completed filter keeps only completed tasks', () {
    final tasks = [task(id: 't1', isCompleted: true), task(id: 't2')];
    final result = filterTasks(tasks, TaskFilter.completed, null, defaults, today: today);
    expect(result.map((t) => t.id), ['t1']);
  });

  test('backlog filter keeps incomplete tasks with no due date', () {
    final tasks = [
      task(id: 't1'),
      task(id: 't2', dueDate: DateTime(2026, 7, 20)),
      task(id: 't3', isCompleted: true),
    ];
    final result = filterTasks(tasks, TaskFilter.backlog, null, defaults, today: today);
    expect(result.map((t) => t.id), ['t1']);
  });

  test('category filter narrows further', () {
    final tasks = [
      task(id: 't1', categoryIds: ['c1']),
      task(id: 't2', categoryIds: ['c2']),
    ];
    final result = filterTasks(tasks, TaskFilter.backlog, 'c1', defaults, today: today);
    expect(result.map((t) => t.id), ['t1']);
  });

  test('all filter keeps every task regardless of status', () {
    final tasks = [
      task(id: 't1'),
      task(id: 't2', dueDate: DateTime(2026, 7, 20)),
      task(id: 't3', isCompleted: true),
    ];
    final result = filterTasks(tasks, TaskFilter.all, null, defaults, today: today);
    expect(result.map((t) => t.id), ['t1', 't2', 't3']);
  });

  group('time filter', () {
    test('today preset includes only due-today tasks (overdue toggle off)', () {
      final tasks = [
        task(id: 't1', dueDate: DateTime(2026, 7, 25)),
        task(id: 't2', dueDate: DateTime(2026, 7, 26)),
        task(id: 't3', dueDate: DateTime(2026, 7, 20)), // overdue
      ];
      final filter = const DateRangeFilter(preset: DatePreset.today, showOverdue: false);
      final result = filterTasks(tasks, TaskFilter.active, null, filter, today: today);
      expect(result.map((t) => t.id), ['t1']);
    });

    test('tomorrow preset includes only due-tomorrow tasks', () {
      final tasks = [
        task(id: 't1', dueDate: DateTime(2026, 7, 25)),
        task(id: 't2', dueDate: DateTime(2026, 7, 26)),
      ];
      final filter = const DateRangeFilter(preset: DatePreset.tomorrow, showOverdue: false);
      final result = filterTasks(tasks, TaskFilter.active, null, filter, today: today);
      expect(result.map((t) => t.id), ['t2']);
    });

    test('this week boundary: day 6 included, day 7 excluded', () {
      final tasks = [
        task(id: 't1', dueDate: DateTime(2026, 7, 31)), // today + 6
        task(id: 't2', dueDate: DateTime(2026, 8, 1)), // today + 7, excluded
      ];
      final filter = const DateRangeFilter(preset: DatePreset.thisWeek, showOverdue: false);
      final result = filterTasks(tasks, TaskFilter.active, null, filter, today: today);
      expect(result.map((t) => t.id), ['t1']);
    });

    test('showOverdue surfaces an overdue task even outside the active preset', () {
      final tasks = [
        task(id: 't1', dueDate: DateTime(2026, 7, 26)), // matches tomorrow preset
        task(id: 't2', dueDate: DateTime(2026, 7, 20)), // overdue, not tomorrow
      ];
      final filter = const DateRangeFilter(preset: DatePreset.tomorrow, showOverdue: true);
      final result = filterTasks(tasks, TaskFilter.active, null, filter, today: today);
      expect(result.map((t) => t.id), ['t2', 't1']);
    });

    test('showOverdue false with a preset hides overdue-but-non-matching tasks', () {
      final tasks = [
        task(id: 't1', dueDate: DateTime(2026, 7, 26)),
        task(id: 't2', dueDate: DateTime(2026, 7, 20)),
      ];
      final filter = const DateRangeFilter(preset: DatePreset.tomorrow, showOverdue: false);
      final result = filterTasks(tasks, TaskFilter.active, null, filter, today: today);
      expect(result.map((t) => t.id), ['t1']);
    });

    test('custom range is inclusive of both bounds', () {
      final tasks = [
        task(id: 't1', dueDate: DateTime(2026, 7, 27)),
        task(id: 't2', dueDate: DateTime(2026, 7, 29)),
        task(id: 't3', dueDate: DateTime(2026, 7, 30)), // outside range
      ];
      final filter = DateRangeFilter(
        preset: DatePreset.custom,
        customStart: DateTime(2026, 7, 27),
        customEnd: DateTime(2026, 7, 29),
        showOverdue: false,
      );
      final result = filterTasks(tasks, TaskFilter.active, null, filter, today: today);
      expect(result.map((t) => t.id), ['t1', 't2']);
    });
  });
}
