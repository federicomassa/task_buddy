import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/date_filter.dart';
import 'package:task_buddy/features/goals/goals_screen.dart';
import 'package:task_buddy/models/goal.dart';
import 'package:task_buddy/models/habit.dart';

void main() {
  final now = DateTime(2026, 7, 25, 10);
  final today = DateTime(2026, 7, 25);
  final defaults = DateRangeFilter.defaults();

  Habit habit({required String id, String? categoryId}) {
    return Habit(
      id: id,
      userId: 'u1',
      title: 'Habit $id',
      description: '',
      categoryId: categoryId,
      targetCount: 1,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  Goal instance({
    required String id,
    required String habitId,
    bool isCompleted = false,
    DateTime? dueDate,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return Goal(
      id: id,
      userId: 'u1',
      title: 'Instance $id',
      description: '',
      isHabitInstance: true,
      habitId: habitId,
      startDate: startDate,
      endDate: endDate,
      dueDate: dueDate,
      currentProgress: 0,
      isCompleted: isCompleted,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  test('all filter keeps every habit regardless of current instance', () {
    final habits = [habit(id: 'h1'), habit(id: 'h2')];
    final instances = [instance(id: 'i1', habitId: 'h1', isCompleted: true)];
    final result = filterHabits(habits, instances, HabitFilter.all, null, defaults, now: now, today: today);
    expect(result.map((h) => h.id), ['h1', 'h2']);
  });

  test('active filter keeps only habits whose current instance is incomplete', () {
    final habits = [habit(id: 'h1'), habit(id: 'h2'), habit(id: 'h3')];
    final instances = [
      instance(id: 'i1', habitId: 'h1', isCompleted: false),
      instance(id: 'i2', habitId: 'h2', isCompleted: true),
      // h3 has no instance at all
    ];
    final result = filterHabits(habits, instances, HabitFilter.active, null, defaults, now: now, today: today);
    expect(result.map((h) => h.id), ['h1']);
  });

  test('completed filter keeps only habits whose current instance is completed', () {
    final habits = [habit(id: 'h1'), habit(id: 'h2')];
    final instances = [
      instance(id: 'i1', habitId: 'h1', isCompleted: false),
      instance(id: 'i2', habitId: 'h2', isCompleted: true),
    ];
    final result = filterHabits(habits, instances, HabitFilter.completed, null, defaults, now: now, today: today);
    expect(result.map((h) => h.id), ['h2']);
  });

  test('category filter narrows further', () {
    final habits = [habit(id: 'h1', categoryId: 'c1'), habit(id: 'h2', categoryId: 'c2')];
    final result = filterHabits(habits, [], HabitFilter.all, 'c1', defaults, now: now, today: today);
    expect(result.map((h) => h.id), ['h1']);
  });

  test('time filter matches the current instance due date', () {
    final habits = [habit(id: 'h1'), habit(id: 'h2')];
    final instances = [
      instance(id: 'i1', habitId: 'h1', dueDate: DateTime(2026, 7, 25)),
      instance(id: 'i2', habitId: 'h2', dueDate: DateTime(2026, 7, 30)),
    ];
    final filter = const DateRangeFilter(preset: DatePreset.today, showOverdue: false);
    final result = filterHabits(habits, instances, HabitFilter.all, null, filter, now: now, today: today);
    expect(result.map((h) => h.id), ['h1']);
  });
}
