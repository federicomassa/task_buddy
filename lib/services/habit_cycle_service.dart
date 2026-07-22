import '../core/period_utils.dart';
import '../models/habit.dart';
import 'goal_repository.dart';
import 'habit_repository.dart';

/// Ensures every habit template has a live goal instance for the current
/// period, lazily rolling over expired instances on app launch/focus.
class HabitCycleService {
  final HabitRepository _habitRepository;
  final GoalRepository _goalRepository;

  HabitCycleService(this._habitRepository, this._goalRepository);

  Future<void> reconcile(String userId) async {
    final habits = await _habitRepository.streamHabits(userId).first;
    for (final habit in habits) {
      await _reconcileHabit(userId, habit);
    }
  }

  Future<void> _reconcileHabit(String userId, Habit habit) async {
    final instances = await _goalRepository.fetchHabitInstances(userId, habit.id);
    final now = DateTime.now();
    final range = currentPeriodRange(habit.period, now);

    final hasCurrentInstance = instances.any(
      (g) => g.startDate != null && g.endDate != null && !now.isBefore(g.startDate!) && now.isBefore(g.endDate!),
    );

    if (!hasCurrentInstance) {
      await _goalRepository.addHabitInstance(
        userId: userId,
        habitId: habit.id,
        title: habit.title,
        description: habit.description,
        categoryId: habit.categoryId,
        targetCount: habit.targetCount,
        startDate: range.start,
        endDate: range.end,
      );
    }
  }
}
