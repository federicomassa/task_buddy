import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/insights_calculations.dart';
import 'package:task_buddy/models/category.dart';
import 'package:task_buddy/models/goal.dart';
import 'package:task_buddy/models/habit.dart';
import 'package:task_buddy/models/task.dart';

void main() {
  final now = DateTime(2026, 7, 22);

  Habit habit(String id) => Habit(
        id: id,
        userId: 'u1',
        title: 'Habit $id',
        description: '',
        targetCount: 1,
        period: HabitPeriod.weekly,
        createdAt: now,
      );

  Goal instance({required String id, required String habitId, DateTime? endDate, bool isCompleted = false}) {
    return Goal(
      id: id,
      userId: 'u1',
      title: 'Instance',
      description: '',
      isHabitInstance: true,
      habitId: habitId,
      endDate: endDate,
      currentProgress: 0,
      isCompleted: isCompleted,
      createdAt: now,
    );
  }

  group('computeHabitConsistencyRates', () {
    test('no past instances maps to 0', () {
      final rates = computeHabitConsistencyRates([habit('h1')], const [], now);
      expect(rates['Habit h1'], 0);
    });

    test('computes completion percentage from past instances only', () {
      final instances = [
        instance(id: 'g1', habitId: 'h1', endDate: DateTime(2026, 7, 1), isCompleted: true),
        instance(id: 'g2', habitId: 'h1', endDate: DateTime(2026, 7, 8), isCompleted: false),
        // Not yet ended relative to `now` — excluded.
        instance(id: 'g3', habitId: 'h1', endDate: DateTime(2026, 7, 29), isCompleted: true),
      ];
      final rates = computeHabitConsistencyRates([habit('h1')], instances, now);
      expect(rates['Habit h1'], 50.0);
    });
  });

  group('computeCategoryDistribution', () {
    Task task({required String id, required bool isCompleted, DateTime? completedAt, List<String> categoryIds = const []}) {
      return Task(
        id: id,
        userId: 'u1',
        title: 'Task $id',
        isRecurrent: false,
        categoryIds: categoryIds,
        isCompleted: isCompleted,
        completedAt: completedAt,
        createdAt: now,
      );
    }

    final category = Category(id: 'c1', userId: 'u1', name: 'Work', colorHex: '#FF0000', createdAt: now);

    test('counts only completed tasks within the last 30 days', () {
      final tasks = [
        task(id: 't1', isCompleted: true, completedAt: DateTime(2026, 7, 20), categoryIds: ['c1']),
        task(id: 't2', isCompleted: true, completedAt: DateTime(2026, 6, 1), categoryIds: ['c1']),
        task(id: 't3', isCompleted: false),
      ];
      final counts = computeCategoryDistribution(tasks, [category], now);
      expect(counts, {'Work': 1});
    });

    test('uncategorized tasks count separately', () {
      final tasks = [task(id: 't1', isCompleted: true, completedAt: DateTime(2026, 7, 20))];
      final counts = computeCategoryDistribution(tasks, [category], now);
      expect(counts, {'Uncategorized': 1});
    });

    test('unresolvable categoryId counts as Unknown', () {
      final tasks = [
        task(id: 't1', isCompleted: true, completedAt: DateTime(2026, 7, 20), categoryIds: ['missing']),
      ];
      final counts = computeCategoryDistribution(tasks, [category], now);
      expect(counts, {'Unknown': 1});
    });

    test('a task in multiple categories counts once per category', () {
      final tasks = [
        task(id: 't1', isCompleted: true, completedAt: DateTime(2026, 7, 20), categoryIds: ['c1', 'missing']),
      ];
      final counts = computeCategoryDistribution(tasks, [category], now);
      expect(counts, {'Work': 1, 'Unknown': 1});
    });
  });
}
