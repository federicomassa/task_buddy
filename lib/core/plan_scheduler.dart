import 'active_hours.dart';
import 'eisenhower.dart';
import '../models/task.dart';
import '../models/user_settings.dart';

class PlanResult {
  /// Task id -> new scheduledDate, for tasks that fit within active hours.
  final Map<String, DateTime> scheduledTimes;

  /// Tasks (from the input list) that didn't fit into the active hours.
  final List<Task> unscheduled;

  /// Unfilled stretches of active-hours time left after packing all tasks
  /// (only non-empty when every task fit, i.e. [totalEstimateMinutes] <
  /// [totalActiveMinutes]) — candidates for "free time" placeholder blocks.
  final List<TimeRange> remainingGaps;

  final int totalActiveMinutes;
  final int totalEstimateMinutes;

  const PlanResult({
    required this.scheduledTimes,
    required this.unscheduled,
    required this.remainingGaps,
    required this.totalActiveMinutes,
    required this.totalEstimateMinutes,
  });
}

/// Packs [tasks] (all of which must have a non-null [Task.timeEstimate])
/// back-to-back on [today], in descending WSJF-score order, treating the
/// active hours as one continuous workday rather than isolated windows —
/// so a task is never held back just because it wouldn't fit before the
/// next break. Each task gets a single real start time (via
/// [realMinutesFromVirtual]); if its duration actually spans a break, that
/// only shows up when rendering it (see [taskRealSegments]), not here.
/// Tasks that don't fit in the total active time at all are reported in
/// [PlanResult.unscheduled].
PlanResult computePlan({
  required List<Task> tasks,
  required List<TimeRange> activeHours,
  required WsjfWeights weights,
  required DateTime today,
}) {
  final capacityMinutes = totalActiveMinutes(activeHours);
  final totalEstimateMinutes = tasks.fold<int>(0, (sum, t) => sum + t.timeEstimate!.inMinutes);

  final sorted = [...tasks]..sort((a, b) {
      final scoreA = wsjfScore(a, weights) ?? 0;
      final scoreB = wsjfScore(b, weights) ?? 0;
      return scoreB.compareTo(scoreA);
    });

  final scheduledTimes = <String, DateTime>{};
  final unscheduled = <Task>[];
  var virtualCursor = 0;

  for (final task in sorted) {
    final durationMinutes = task.timeEstimate!.inMinutes;
    if (virtualCursor + durationMinutes > capacityMinutes) {
      unscheduled.add(task);
      continue;
    }

    final realStart = realMinutesFromVirtual(virtualCursor, activeHours)!;
    scheduledTimes[task.id] = DateTime(
      today.year,
      today.month,
      today.day,
      realStart ~/ 60,
      realStart % 60,
    );
    virtualCursor += durationMinutes;
  }

  final remainingGaps = unscheduled.isEmpty
      ? realSegmentsFromVirtualRange(virtualCursor, capacityMinutes, activeHours)
      : const <TimeRange>[];

  return PlanResult(
    scheduledTimes: scheduledTimes,
    unscheduled: unscheduled,
    remainingGaps: remainingGaps,
    totalActiveMinutes: capacityMinutes,
    totalEstimateMinutes: totalEstimateMinutes,
  );
}
