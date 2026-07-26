import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/date_filter.dart';
import 'package:task_buddy/features/goals/goals_screen.dart';
import 'package:task_buddy/models/goal.dart';

void main() {
  final today = DateTime(2026, 7, 25);
  final defaults = DateRangeFilter.defaults();

  Goal goal({
    required String id,
    bool isCompleted = false,
    String? categoryId,
    DateTime? dueDate,
  }) {
    return Goal(
      id: id,
      userId: 'u1',
      title: 'Goal $id',
      description: '',
      categoryId: categoryId,
      isHabitInstance: false,
      dueDate: dueDate,
      currentProgress: 0,
      isCompleted: isCompleted,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  test('active filter keeps incomplete goals with a due date, sorted by due date', () {
    final goals = [
      goal(id: 'g1', dueDate: DateTime(2026, 7, 25)),
      goal(id: 'g2', dueDate: DateTime(2026, 7, 20)),
      goal(id: 'g3'), // no due date, excluded
      goal(id: 'g4', dueDate: DateTime(2026, 7, 22), isCompleted: true), // completed, excluded
    ];
    final result = filterGoals(goals, GoalFilter.active, null, defaults, today: today);
    expect(result.map((g) => g.id), ['g2', 'g1']);
  });

  test('completed filter keeps only completed goals', () {
    final goals = [
      goal(id: 'g1', dueDate: DateTime(2026, 7, 25)),
      goal(id: 'g2', isCompleted: true),
    ];
    final result = filterGoals(goals, GoalFilter.completed, null, defaults, today: today);
    expect(result.map((g) => g.id), ['g2']);
  });

  test('backlog filter keeps incomplete goals with no due date', () {
    final goals = [
      goal(id: 'g1'),
      goal(id: 'g2', dueDate: DateTime(2026, 7, 20)),
      goal(id: 'g3', isCompleted: true),
    ];
    final result = filterGoals(goals, GoalFilter.backlog, null, defaults, today: today);
    expect(result.map((g) => g.id), ['g1']);
  });

  test('category filter narrows further', () {
    final goals = [
      goal(id: 'g1', categoryId: 'c1', dueDate: DateTime(2026, 7, 25)),
      goal(id: 'g2', categoryId: 'c2', dueDate: DateTime(2026, 7, 25)),
    ];
    final result = filterGoals(goals, GoalFilter.active, 'c1', defaults, today: today);
    expect(result.map((g) => g.id), ['g1']);
  });

  group('time filter', () {
    test('today preset includes only due-today goals', () {
      final goals = [
        goal(id: 'g1', dueDate: DateTime(2026, 7, 25)),
        goal(id: 'g2', dueDate: DateTime(2026, 7, 26)),
      ];
      final filter = const DateRangeFilter(preset: DatePreset.today, showOverdue: false);
      final result = filterGoals(goals, GoalFilter.active, null, filter, today: today);
      expect(result.map((g) => g.id), ['g1']);
    });

    test('showOverdue surfaces an overdue goal even outside the active preset', () {
      final goals = [
        goal(id: 'g1', dueDate: DateTime(2026, 7, 26)),
        goal(id: 'g2', dueDate: DateTime(2026, 7, 20)), // overdue
      ];
      final filter = const DateRangeFilter(preset: DatePreset.tomorrow, showOverdue: true);
      final result = filterGoals(goals, GoalFilter.active, null, filter, today: today);
      expect(result.map((g) => g.id), ['g2', 'g1']);
    });
  });
}
