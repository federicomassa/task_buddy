import 'date_utils.dart';
import '../models/task.dart';

/// Whether [task] has an execution time range that falls on [today] — the
/// shared notion of "scheduled for today" used by both the real Today
/// providers and the plan-preview's merged lists.
bool isScheduledToday(Task task, DateTime today) =>
    task.estimatedExecutionTimeRanges.any((r) => dateOnly(r.start) == today);

/// Tasks scheduled for today — rendered as calendar blocks.
List<Task> scheduledTasksForToday(List<Task> tasks, DateTime today) {
  return tasks.where((t) => t.estimatedExecutionTimeRanges.isNotEmpty && isScheduledToday(t, today)).toList();
}

/// Tasks due today or overdue, not yet scheduled for today, and not
/// completed — candidates for the unscheduled list.
List<Task> unscheduledTasksForToday(List<Task> tasks, DateTime today) {
  return tasks.where((t) {
    if (t.isCompleted) return false;
    if (t.dueDate == null) return false;
    final due = dateOnly(t.dueDate!);
    if (due.isAfter(today)) return false;
    return !isScheduledToday(t, today);
  }).toList();
}
