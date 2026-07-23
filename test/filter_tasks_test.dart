import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/features/tasks/tasks_screen.dart';
import 'package:task_buddy/models/task.dart';

void main() {
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
    final result = filterTasks(tasks, TaskFilter.active, null);
    expect(result.map((t) => t.id), ['t2', 't1']);
  });

  test('completed filter keeps only completed tasks', () {
    final tasks = [task(id: 't1', isCompleted: true), task(id: 't2')];
    final result = filterTasks(tasks, TaskFilter.completed, null);
    expect(result.map((t) => t.id), ['t1']);
  });

  test('backlog filter keeps incomplete tasks with no due date', () {
    final tasks = [
      task(id: 't1'),
      task(id: 't2', dueDate: DateTime(2026, 7, 20)),
      task(id: 't3', isCompleted: true),
    ];
    final result = filterTasks(tasks, TaskFilter.backlog, null);
    expect(result.map((t) => t.id), ['t1']);
  });

  test('category filter narrows further', () {
    final tasks = [
      task(id: 't1', categoryIds: ['c1']),
      task(id: 't2', categoryIds: ['c2']),
    ];
    final result = filterTasks(tasks, TaskFilter.backlog, 'c1');
    expect(result.map((t) => t.id), ['t1']);
  });
}
