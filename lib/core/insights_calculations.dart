import '../models/category.dart';
import '../models/goal.dart';
import '../models/habit.dart';
import '../models/task.dart';

/// Percentage (0-100) of past (ended) instances of each habit that were
/// completed. Habits with no past instances yet map to 0.
Map<String, double> computeHabitConsistencyRates(
  List<Habit> habits,
  List<Goal> instances,
  DateTime now,
) {
  final rates = <String, double>{};
  for (final habit in habits) {
    final past = instances
        .where((g) => g.habitId == habit.id && g.endDate != null && g.endDate!.isBefore(now))
        .toList();
    if (past.isEmpty) {
      rates[habit.title] = 0;
      continue;
    }
    final completed = past.where((g) => g.isCompleted).length;
    rates[habit.title] = completed / past.length * 100;
  }
  return rates;
}

/// Category-name -> completed-task-count for tasks completed within the
/// last 30 days (relative to [now]). Tasks with no category count under
/// 'Uncategorized'; tasks whose categoryId doesn't resolve count under
/// 'Unknown'.
Map<String, int> computeCategoryDistribution(
  List<Task> tasks,
  List<Category> categories,
  DateTime now,
) {
  final cutoff = now.subtract(const Duration(days: 30));
  final counts = <String, int>{};

  for (final task in tasks) {
    if (!task.isCompleted || task.completedAt == null) continue;
    if (task.completedAt!.isBefore(cutoff)) continue;
    if (task.categoryIds.isEmpty) {
      counts['Uncategorized'] = (counts['Uncategorized'] ?? 0) + 1;
      continue;
    }
    for (final categoryId in task.categoryIds) {
      var name = 'Unknown';
      for (final c in categories) {
        if (c.id == categoryId) {
          name = c.name;
          break;
        }
      }
      counts[name] = (counts[name] ?? 0) + 1;
    }
  }
  return counts;
}
