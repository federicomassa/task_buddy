import '../models/goal.dart';

/// The habit instance whose [start, end) range contains [now], if any;
/// otherwise the most-recently-started instance for that habit, if any.
Goal? currentHabitInstance(List<Goal> instances, String habitId, DateTime now) {
  final matches = instances.where((g) => g.habitId == habitId).toList();
  for (final g in matches) {
    if (g.startDate != null &&
        g.endDate != null &&
        !now.isBefore(g.startDate!) &&
        now.isBefore(g.endDate!)) {
      return g;
    }
  }
  return matches.isNotEmpty ? matches.first : null;
}
