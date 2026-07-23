import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/habit_instance_utils.dart';
import 'package:task_buddy/models/goal.dart';

void main() {
  Goal instance({
    required String id,
    required String habitId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return Goal(
      id: id,
      userId: 'u1',
      title: 'Habit instance',
      description: '',
      isHabitInstance: true,
      habitId: habitId,
      startDate: startDate,
      endDate: endDate,
      currentProgress: 0,
      isCompleted: false,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  final now = DateTime(2026, 7, 22, 12);

  test('returns the instance containing now', () {
    final instances = [
      instance(id: 'g1', habitId: 'h1', startDate: DateTime(2026, 7, 15), endDate: DateTime(2026, 7, 22)),
      instance(id: 'g2', habitId: 'h1', startDate: DateTime(2026, 7, 22), endDate: DateTime(2026, 7, 29)),
    ];
    expect(currentHabitInstance(instances, 'h1', now)?.id, 'g2');
  });

  test('falls back to the first match when none contains now', () {
    final instances = [
      instance(id: 'g1', habitId: 'h1', startDate: DateTime(2026, 6, 1), endDate: DateTime(2026, 6, 8)),
    ];
    expect(currentHabitInstance(instances, 'h1', now)?.id, 'g1');
  });

  test('no matches for the habit returns null', () {
    expect(currentHabitInstance(const [], 'h1', now), isNull);
  });

  test('only considers instances matching the given habitId', () {
    final instances = [
      instance(id: 'g1', habitId: 'other', startDate: DateTime(2026, 7, 22), endDate: DateTime(2026, 7, 29)),
    ];
    expect(currentHabitInstance(instances, 'h1', now), isNull);
  });
}
