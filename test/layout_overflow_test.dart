import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task_buddy/features/plan/plan_screen.dart';
import 'package:task_buddy/models/category.dart';
import 'package:task_buddy/models/goal.dart';
import 'package:task_buddy/models/task.dart';
import 'package:task_buddy/providers/app_providers.dart';
import 'package:task_buddy/widgets/goal_card.dart';
import 'package:task_buddy/widgets/task_schedule_card.dart';
import 'package:task_buddy/widgets/task_tile.dart';

Task _task({
  required String id,
  required String title,
  DateTime? dueDate,
  DateTime? scheduledDate,
  Duration? estimatedDuration,
  bool isRecurrent = false,
  bool isCompleted = false,
  List<String> categoryIds = const [],
}) {
  return Task(
    id: id,
    userId: 'u1',
    title: title,
    dueDate: dueDate,
    estimatedExecutionTimeRanges: scheduledDate != null && estimatedDuration != null
        ? [TaskTimeRange(start: scheduledDate, end: scheduledDate.add(estimatedDuration))]
        : const [],
    isRecurrent: isRecurrent,
    recurrenceRule: isRecurrent ? RecurrenceRule.daily : null,
    categoryIds: categoryIds,
    isCompleted: isCompleted,
    createdAt: DateTime(2026, 1, 1),
    estimatedDuration: estimatedDuration,
  );
}

List<Category> _categories() => [
      Category(id: 'c1', userId: 'u1', name: 'Work', colorHex: '#FF0000', createdAt: DateTime(2026, 1, 1)),
      Category(id: 'c2', userId: 'u1', name: 'Personal errands', colorHex: '#00FF00', createdAt: DateTime(2026, 1, 1)),
      Category(id: 'c3', userId: 'u1', name: 'Health & fitness', colorHex: '#0000FF', createdAt: DateTime(2026, 1, 1)),
    ];

void main() {
  final today = DateTime(2026, 7, 22);

  testWidgets('TaskScheduleCard with heavy content at phone width', (tester) async {
    final task = _task(
      id: 't1',
      title: 'A pretty long task title that will wrap onto a second line easily',
      dueDate: DateTime(2026, 7, 20),
      scheduledDate: DateTime(2026, 7, 22, 9, 0),
      estimatedDuration: const Duration(hours: 1, minutes: 30),
      isRecurrent: true,
      isCompleted: true,
      categoryIds: ['c1', 'c2', 'c3'],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: TaskScheduleCard(task: task, categories: _categories(), today: today),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('TaskTile with heavy content at phone width', (tester) async {
    final task = _task(
      id: 't2',
      title: 'Another long task title for the Tasks tab list item',
      dueDate: DateTime(2026, 7, 20, 14, 30),
      scheduledDate: DateTime(2026, 7, 22, 9, 0),
      estimatedDuration: const Duration(hours: 1, minutes: 30),
      isRecurrent: true,
      categoryIds: ['c1', 'c2', 'c3'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: TaskTile(
              task: task,
              categories: _categories(),
              onToggle: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('GoalCard with description + due date + progress + category at phone width', (tester) async {
    final goal = Goal(
      id: 'g1',
      userId: 'u1',
      title: 'Read more books',
      description: 'A goal with a fairly long description to fill out the subtitle column',
      categoryId: 'c1',
      isHabitInstance: false,
      dueDate: DateTime(2026, 8, 1, 18, 0),
      targetCount: 10,
      currentProgress: 4,
      isCompleted: false,
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: GoalCard(goal: goal, categories: _categories(), onToggleCompleted: (_) {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  // Regression test for a fixed SizedBox(height: 400) calendar pane that
  // overflowed the Column whenever the available body height dropped
  // below ~401px; plan_screen.dart now uses Expanded(flex: 2) instead.
  testWidgets('PlanScreen mobile layout at a screen height that leaves it tight', (tester) async {
    tester.view.physicalSize = const Size(360, 420);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tasksStreamProvider.overrideWith((ref) => const Stream<List<Task>>.empty()),
          categoriesStreamProvider.overrideWith((ref) => const Stream<List<Category>>.empty()),
        ],
        child: const MaterialApp(home: PlanScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
