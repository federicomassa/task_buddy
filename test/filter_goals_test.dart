import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/features/goals/goals_screen.dart';
import 'package:task_buddy/models/goal.dart';

void main() {
  Goal goal({required String id, bool isCompleted = false, String? categoryId}) {
    return Goal(
      id: id,
      userId: 'u1',
      title: 'Goal $id',
      description: '',
      categoryId: categoryId,
      isHabitInstance: false,
      currentProgress: 0,
      isCompleted: isCompleted,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  test('active filter keeps only incomplete goals', () {
    final goals = [goal(id: 'g1'), goal(id: 'g2', isCompleted: true)];
    final result = filterGoals(goals, GoalFilter.active, null);
    expect(result.map((g) => g.id), ['g1']);
  });

  test('completed filter keeps only completed goals', () {
    final goals = [goal(id: 'g1'), goal(id: 'g2', isCompleted: true)];
    final result = filterGoals(goals, GoalFilter.completed, null);
    expect(result.map((g) => g.id), ['g2']);
  });

  test('category filter narrows further', () {
    final goals = [
      goal(id: 'g1', categoryId: 'c1'),
      goal(id: 'g2', categoryId: 'c2'),
    ];
    final result = filterGoals(goals, GoalFilter.active, 'c1');
    expect(result.map((g) => g.id), ['g1']);
  });
}
