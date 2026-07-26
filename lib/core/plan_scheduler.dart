import 'active_hours.dart';
import 'eisenhower.dart';
import '../models/task.dart';
import '../models/user_settings.dart';

class PlanResult {
  /// Task id -> new estimatedExecutionTimeRanges, for tasks that fit within
  /// active hours. Already split across any break the task's duration
  /// spans, using the active hours in effect at plan time.
  final Map<String, List<TaskTimeRange>> scheduledRanges;

  /// Tasks (from the input list) that didn't fit into the active hours.
  final List<Task> unscheduled;

  /// Unfilled stretches of active-hours time left after packing all tasks
  /// (only non-empty when every task fit, i.e. [totalEstimateMinutes] <
  /// [totalActiveMinutes]) — candidates for "free time" placeholder blocks.
  final List<TimeRange> remainingGaps;

  final int totalActiveMinutes;
  final int totalEstimateMinutes;

  const PlanResult({
    required this.scheduledRanges,
    required this.unscheduled,
    required this.remainingGaps,
    required this.totalActiveMinutes,
    required this.totalEstimateMinutes,
  });
}

/// Packs [tasks] (all of which must have a non-null [Task.estimatedDuration])
/// back-to-back on [today], in descending WSJF-score order, treating the
/// active hours as one continuous workday rather than isolated windows —
/// so a task is never held back just because it wouldn't fit before the
/// next break. Each task's virtual placement is immediately materialized
/// into concrete real-clock [TaskTimeRange]s (via [realSegmentsFromVirtualRange]),
/// splitting across any break it spans, using the active hours in effect
/// right now — the result is a fixed fact about [today], not something
/// re-derived later from a live active-hours setting. Tasks that don't fit
/// in the total active time at all are reported in [PlanResult.unscheduled].
PlanResult computePlan({
  required List<Task> tasks,
  required List<TimeRange> activeHours,
  required WsjfWeights weights,
  required DateTime today,
}) {
  final capacityMinutes = totalActiveMinutes(activeHours);
  final totalEstimateMinutes = tasks.fold<int>(0, (sum, t) => sum + t.estimatedDuration!.inMinutes);

  final sorted = [...tasks]..sort((a, b) {
      final scoreA = wsjfScore(a, weights) ?? 0;
      final scoreB = wsjfScore(b, weights) ?? 0;
      return scoreB.compareTo(scoreA);
    });

  final scheduledRanges = <String, List<TaskTimeRange>>{};
  final unscheduled = <Task>[];
  var virtualCursor = 0;

  for (final task in sorted) {
    final durationMinutes = task.estimatedDuration!.inMinutes;
    if (virtualCursor + durationMinutes > capacityMinutes) {
      unscheduled.add(task);
      continue;
    }

    final segments = realSegmentsFromVirtualRange(virtualCursor, virtualCursor + durationMinutes, activeHours);
    scheduledRanges[task.id] = taskTimeRangesForDay(today, segments);
    virtualCursor += durationMinutes;
  }

  final remainingGaps = unscheduled.isEmpty
      ? realSegmentsFromVirtualRange(virtualCursor, capacityMinutes, activeHours)
      : const <TimeRange>[];

  return PlanResult(
    scheduledRanges: scheduledRanges,
    unscheduled: unscheduled,
    remainingGaps: remainingGaps,
    totalActiveMinutes: capacityMinutes,
    totalEstimateMinutes: totalEstimateMinutes,
  );
}
