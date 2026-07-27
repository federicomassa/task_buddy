import 'active_hours.dart';
import 'date_utils.dart';
import 'eisenhower.dart';
import '../models/task.dart';
import '../models/user_settings.dart';
import '../widgets/format_utils.dart';

/// A task whose due time makes it impossible to complete no matter how the
/// day is scheduled — its deadline (converted to virtual minutes) is earlier
/// than its own estimated duration, so even starting it first wouldn't help.
class InfeasibleTask {
  final Task task;
  final String reason;

  const InfeasibleTask({required this.task, required this.reason});
}

class PlanResult {
  /// Task id -> new estimatedExecutionTimeRanges, for tasks that fit within
  /// active hours and their own deadline (if any). Already split across any
  /// break the task's duration spans, using the active hours in effect at
  /// plan time.
  final Map<String, List<TaskTimeRange>> scheduledRanges;

  /// Tasks (from the input list) that could have been scheduled in principle
  /// but lost out to a higher-value combination of other tasks within the
  /// available capacity.
  final List<Task> unscheduled;

  /// Tasks that can never be completed by their own due time, regardless of
  /// what else is scheduled — reported separately from [unscheduled] since
  /// this points at a problem with the task itself (due time earlier than
  /// its estimate allows), not a capacity trade-off.
  final List<InfeasibleTask> infeasibleTasks;

  /// Unfilled stretches of active-hours time left after packing all
  /// scheduled tasks (only non-empty when every eligible task fit, i.e.
  /// [unscheduled] is empty) — candidates for "free time" placeholder
  /// blocks.
  final List<TimeRange> remainingGaps;

  final int totalActiveMinutes;
  final int totalEstimateMinutes;

  const PlanResult({
    required this.scheduledRanges,
    required this.unscheduled,
    required this.infeasibleTasks,
    required this.remainingGaps,
    required this.totalActiveMinutes,
    required this.totalEstimateMinutes,
  });
}

/// The DP operates on a coarser grid than raw minutes to keep its state
/// space small — deadlines and durations are rounded to this many minutes
/// before the knapsack runs. The final schedule is still packed using each
/// task's real, unrounded duration, so output precision is unaffected.
const _blockMinutes = 5;

/// Rounds [durationMinutes] up to the nearest block so the DP never
/// allocates less space than a task actually needs.
int _durationBlocks(int durationMinutes) => (durationMinutes + _blockMinutes - 1) ~/ _blockMinutes;

/// Rounds [deadlineMinutes] down to the nearest block so the DP never
/// assumes more time is available before a deadline than actually is.
int _deadlineBlocks(int deadlineMinutes) => deadlineMinutes ~/ _blockMinutes;

/// A task's deadline expressed in virtual minutes, plus whether that
/// deadline came from a real, same-day due time (as opposed to defaulting
/// to the full-capacity fallback for tasks with no meaningful intraday
/// cutoff).
class _Deadline {
  final int minutes;
  final bool isReal;

  const _Deadline({required this.minutes, required this.isReal});
}

/// A task's deadline is only ever taken literally when its [Task.dueDate]
/// falls on [today] — a null due date, or one from a past day (an overdue
/// task still eligible for today's plan), has no meaningful intraday cutoff
/// and is treated as unconstrained (deadline = full capacity).
_Deadline _deadlineFor(Task task, DateTime today, List<TimeRange> activeHours, int capacityMinutes) {
  final due = task.dueDate;
  if (due == null || dateOnly(due) != today) {
    return _Deadline(minutes: capacityMinutes, isReal: false);
  }
  final realMinutes = due.hour * 60 + due.minute;
  return _Deadline(minutes: virtualDeadlineFromReal(realMinutes, activeHours), isReal: true);
}

String _formatTimeOfDay(DateTime dateTime) {
  final hour24 = dateTime.hour;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'AM' : 'PM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  return '$hour12:$minute $period';
}

String _infeasibleReason(Task task) {
  final dueLabel = _formatTimeOfDay(task.dueDate!);
  final needed = formatEstimate(task.estimatedDuration!);
  return '"${task.title}" is due at $dueLabel but needs at least $needed — '
      "there isn't enough time left before the deadline even if nothing else is scheduled.";
}

/// Selects and packs the value-maximizing subset of [tasks] (all of which
/// must have a non-null [Task.estimatedDuration]) that can be completed
/// within the active hours and each task's own due time (if it falls on
/// [today]), via an earliest-deadline-first 0/1 knapsack DP: `DP[i][t] =
/// max(DP[i-1][t], DP[i-1][t-duration[i]] + wsjf[i])`, subject to `t <=
/// deadline[i]`. This finds a better combination than always committing to
/// the highest-score task first, e.g. preferring two smaller high-value
/// tasks over one long one that would crowd them out.
///
/// Tasks whose due time makes them impossible to complete regardless of
/// scheduling order (deadline earlier than their own duration) are reported
/// separately in [PlanResult.infeasibleTasks] rather than being fed into the
/// DP or counted as ordinary [PlanResult.unscheduled] tasks.
///
/// Selected tasks are packed back-to-back on [today], treating the active
/// hours as one continuous workday rather than isolated windows — so a task
/// is never held back just because it wouldn't fit before the next break.
/// Each task's virtual placement is immediately materialized into concrete
/// real-clock [TaskTimeRange]s (via [realSegmentsFromVirtualRange]),
/// splitting across any break it spans, using the active hours in effect
/// right now — the result is a fixed fact about [today], not something
/// re-derived later from a live active-hours setting.
PlanResult computePlan({
  required List<Task> tasks,
  required List<TimeRange> activeHours,
  required WsjfWeights weights,
  required DateTime today,
}) {
  final capacityMinutes = totalActiveMinutes(activeHours);
  final totalEstimateMinutes = tasks.fold<int>(0, (sum, t) => sum + t.estimatedDuration!.inMinutes);
  final capacityBlocks = capacityMinutes ~/ _blockMinutes;

  final infeasibleTasks = <InfeasibleTask>[];
  final eligible = <Task>[];
  final deadlineBlocksById = <String, int>{};

  for (final task in tasks) {
    final durationMinutes = task.estimatedDuration!.inMinutes;
    final deadline = _deadlineFor(task, today, activeHours, capacityMinutes);
    final durationBlocks = _durationBlocks(durationMinutes);
    final deadlineBlocks = _deadlineBlocks(deadline.minutes);

    if (deadline.isReal && deadlineBlocks < durationBlocks) {
      infeasibleTasks.add(InfeasibleTask(task: task, reason: _infeasibleReason(task)));
      continue;
    }
    eligible.add(task);
    deadlineBlocksById[task.id] = deadlineBlocks;
  }

  // Urgent tasks get a large fixed bonus on top of their WSJF score, so the
  // DP always prefers keeping a feasible urgent task over dropping it for
  // extra optional-task value, no matter how many small, high-density
  // optional tasks that value would otherwise buy — it only gives way when
  // there genuinely isn't room. `urgentBonus` is set larger than the total
  // value obtainable from every optional task combined, so no combination of
  // optional tasks can ever outweigh a single urgent one; ordinary WSJF
  // differences still decide priority within each tier (urgent vs. urgent,
  // optional vs. optional).
  final optionalScoreSum =
      eligible.where((t) => !t.isUrgent).fold<double>(0, (sum, t) => sum + (wsjfScore(t, weights) ?? 0));
  final urgentBonus = optionalScoreSum + 1;
  double taskValue(Task t) {
    final score = wsjfScore(t, weights) ?? 0;
    return t.isUrgent ? score + urgentBonus : score;
  }

  final originalIndex = {for (var i = 0; i < eligible.length; i++) eligible[i].id: i};
  final sorted = [...eligible]..sort((a, b) {
      final deadlineCompare = deadlineBlocksById[a.id]!.compareTo(deadlineBlocksById[b.id]!);
      if (deadlineCompare != 0) return deadlineCompare;
      final scoreA = wsjfScore(a, weights) ?? 0;
      final scoreB = wsjfScore(b, weights) ?? 0;
      final scoreCompare = scoreB.compareTo(scoreA);
      if (scoreCompare != 0) return scoreCompare;
      return originalIndex[a.id]!.compareTo(originalIndex[b.id]!);
    });

  final n = sorted.length;
  final dp = List.generate(n + 1, (_) => List<double>.filled(capacityBlocks + 1, 0));
  final keep = List.generate(n + 1, (_) => List<bool>.filled(capacityBlocks + 1, false));

  for (var i = 1; i <= n; i++) {
    final task = sorted[i - 1];
    final d = _durationBlocks(task.estimatedDuration!.inMinutes);
    final v = taskValue(task);
    final deadline = deadlineBlocksById[task.id]!;
    for (var t = 0; t <= capacityBlocks; t++) {
      if (t >= d && t <= deadline) {
        final includeValue = dp[i - 1][t - d] + v;
        if (includeValue > dp[i - 1][t]) {
          dp[i][t] = includeValue;
          keep[i][t] = true;
          continue;
        }
      }
      dp[i][t] = dp[i - 1][t];
    }
  }

  // dp[n][t] is NOT monotonic in t: once t exceeds some task's deadline, the
  // "include" branch that used it becomes unavailable even though it may
  // have produced a higher value at a smaller t. So the best achievable
  // value has to be found by scanning the whole row, not just taking t =
  // capacityBlocks.
  var bestT = 0;
  for (var t = 1; t <= capacityBlocks; t++) {
    if (dp[n][t] > dp[n][bestT]) bestT = t;
  }

  final selectedIds = <String>{};
  var cursor = bestT;
  for (var i = n; i >= 1; i--) {
    if (keep[i][cursor]) {
      selectedIds.add(sorted[i - 1].id);
      cursor -= _durationBlocks(sorted[i - 1].estimatedDuration!.inMinutes);
    }
  }

  final selectedInOrder = sorted.where((t) => selectedIds.contains(t.id)).toList();

  final scheduledRanges = <String, List<TaskTimeRange>>{};
  var virtualCursor = 0;
  for (final task in selectedInOrder) {
    final durationMinutes = task.estimatedDuration!.inMinutes;
    final segments = realSegmentsFromVirtualRange(virtualCursor, virtualCursor + durationMinutes, activeHours);
    scheduledRanges[task.id] = taskTimeRangesForDay(today, segments);
    virtualCursor += durationMinutes;
  }

  final unscheduled = tasks.where((t) => !selectedIds.contains(t.id) && !infeasibleTasks.any((it) => it.task.id == t.id)).toList();

  final remainingGaps = unscheduled.isEmpty
      ? realSegmentsFromVirtualRange(virtualCursor, capacityMinutes, activeHours)
      : const <TimeRange>[];

  return PlanResult(
    scheduledRanges: scheduledRanges,
    unscheduled: unscheduled,
    infeasibleTasks: infeasibleTasks,
    remainingGaps: remainingGaps,
    totalActiveMinutes: capacityMinutes,
    totalEstimateMinutes: totalEstimateMinutes,
  );
}
