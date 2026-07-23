import '../core/clock.dart';
import '../core/period_utils.dart';
import '../models/habit.dart';
import 'goal_repository.dart';
import 'habit_repository.dart';

/// Ensures every habit template has a live goal instance for the current
/// period, lazily rolling over expired instances on app launch/focus.
class HabitCycleService {
  final HabitRepository _habitRepository;
  final GoalRepository _goalRepository;
  final Clock _clock;

  HabitCycleService(this._habitRepository, this._goalRepository, this._clock);

  Future<void> reconcile(String userId) async {
    final habits = await _habitRepository.streamHabits(userId).first;
    await Future.wait(habits.map((habit) => _reconcileHabit(userId, habit)));
  }

  Future<void> _reconcileHabit(String userId, Habit habit) async {
    final instances = await _goalRepository.fetchHabitInstances(userId, habit.id);
    final now = _clock.now();
    final range = currentPeriodRange(habit.recurrenceInterval, habit.recurrenceUnit, now);

    final hasCurrentInstance = instances.any(
      (g) => g.startDate != null && g.endDate != null && !now.isBefore(g.startDate!) && now.isBefore(g.endDate!),
    );

    if (!hasCurrentInstance) {
      final dueTimeMinutes = habit.dueTimeMinutes;
      await _goalRepository.addHabitInstance(
        userId: userId,
        habitId: habit.id,
        title: habit.title,
        description: habit.description,
        categoryId: habit.categoryId,
        targetCount: habit.targetCount,
        startDate: range.start,
        endDate: range.end,
        dueDate: dueTimeMinutes != null
            ? nextOccurrenceOfTimeOfDay(dueTimeMinutes, now)
            : null,
      );
    }
  }

  /// Creates a new habit template and its first cycle instance, using the
  /// same period-range/due-time logic as [reconcile]. Sequential by
  /// necessity (the instance needs the newly created habit's id).
  Future<void> createHabitWithFirstInstance({
    required String userId,
    required String title,
    required String description,
    required String? categoryId,
    required int targetCount,
    required int recurrenceInterval,
    required RecurrenceUnit recurrenceUnit,
    required int? dueTimeMinutes,
  }) async {
    final habitId = await _habitRepository.addHabit(
      userId: userId,
      title: title,
      description: description,
      categoryId: categoryId,
      targetCount: targetCount,
      recurrenceInterval: recurrenceInterval,
      recurrenceUnit: recurrenceUnit,
      dueTimeMinutes: dueTimeMinutes,
    );
    final now = _clock.now();
    final range = currentPeriodRange(recurrenceInterval, recurrenceUnit, now);
    await _goalRepository.addHabitInstance(
      userId: userId,
      habitId: habitId,
      title: title,
      description: description,
      categoryId: categoryId,
      targetCount: targetCount,
      startDate: range.start,
      endDate: range.end,
      dueDate: dueTimeMinutes != null ? nextOccurrenceOfTimeOfDay(dueTimeMinutes, now) : null,
    );
  }

  /// Updates a habit template and, if a cycle is currently in progress,
  /// mirrors the editable fields onto that instance too so it doesn't keep
  /// showing stale title/description/category/target after the edit.
  /// Recurrence/due-time changes only apply to future cycles, since the
  /// current instance's period has already been fixed.
  Future<void> updateHabitAndCurrentInstance(Habit habit) async {
    await _habitRepository.updateHabit(habit);

    final instances = await _goalRepository.fetchHabitInstances(habit.userId, habit.id);
    final now = _clock.now();
    final currentMatches = instances.where(
      (g) => g.startDate != null && g.endDate != null && !now.isBefore(g.startDate!) && now.isBefore(g.endDate!),
    );
    if (currentMatches.isEmpty) return;
    final current = currentMatches.first;

    await _goalRepository.updateGoal(current.copyWith(
      title: habit.title,
      description: habit.description,
      categoryId: habit.categoryId,
      targetCount: habit.targetCount,
    ));
  }
}
