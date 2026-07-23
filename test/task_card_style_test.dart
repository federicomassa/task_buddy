import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/task_card_style.dart';
import 'package:task_buddy/models/task.dart';

void main() {
  final today = DateTime(2026, 7, 22);
  final yesterday = DateTime(2026, 7, 21);

  Task buildTask({DateTime? dueDate, Duration? timeEstimate}) {
    return Task(
      id: 't1',
      userId: 'u1',
      title: 'Test task',
      dueDate: dueDate,
      isRecurrent: false,
      categoryIds: const [],
      isCompleted: false,
      createdAt: today,
      timeEstimate: timeEstimate,
    );
  }

  group('taskCardStyle', () {
    test('due today with estimate is blue, height scales with duration', () {
      final task = buildTask(dueDate: today, timeEstimate: const Duration(minutes: 90));
      final style = taskCardStyle(task, today: today);
      expect(style.color, Colors.blue);
      expect(style.height, 90);
    });

    test('due today without estimate is grey, small fixed height', () {
      final task = buildTask(dueDate: today);
      final style = taskCardStyle(task, today: today);
      expect(style.color, Colors.grey);
      expect(style.height, 40);
    });

    test('overdue with estimate is red', () {
      final task = buildTask(dueDate: yesterday, timeEstimate: const Duration(hours: 1));
      final style = taskCardStyle(task, today: today);
      expect(style.color, Colors.red);
      expect(style.height, 60);
    });

    test('overdue without estimate is dull red, small fixed height', () {
      final task = buildTask(dueDate: yesterday);
      final style = taskCardStyle(task, today: today);
      expect(style.color, dullRed);
      expect(style.height, 40);
    });

    test('height is clamped to max for very long estimates', () {
      final task = buildTask(dueDate: today, timeEstimate: const Duration(hours: 10));
      final style = taskCardStyle(task, today: today);
      expect(style.height, 200);
    });

    test('height is clamped to min for very short estimates', () {
      final task = buildTask(dueDate: today, timeEstimate: const Duration(minutes: 1));
      final style = taskCardStyle(task, today: today);
      expect(style.height, 40);
    });
  });

  group('taskBlockHeight', () {
    test('unclamped and reflects real duration', () {
      final task = buildTask(dueDate: today, timeEstimate: const Duration(hours: 10));
      expect(taskBlockHeight(task), 600);
    });

    test('falls back to default when no estimate', () {
      final task = buildTask(dueDate: today);
      expect(taskBlockHeight(task), 40);
    });
  });

  group('isTaskOverdue', () {
    test('null dueDate is never overdue', () {
      final task = buildTask();
      expect(isTaskOverdue(task, today: today), false);
    });

    test('dueDate before today is overdue', () {
      final task = buildTask(dueDate: yesterday);
      expect(isTaskOverdue(task, today: today), true);
    });

    test('dueDate today is not overdue', () {
      final task = buildTask(dueDate: DateTime(2026, 7, 22, 23, 59));
      expect(isTaskOverdue(task, today: today), false);
    });
  });
}
