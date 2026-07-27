import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/plan_scheduler.dart';
import '../../core/today_task_filters.dart';
import '../../models/task.dart';

/// Id prefix for free-time placeholder drafts proposed by the plan preview
/// but not yet persisted to Firestore — [Task.addTask] ignores the id it's
/// given (Firestore assigns the real one), so this prefix never leaks into
/// storage; it only exists to let the preview's write paths recognize "this
/// task isn't real yet" without a separate lookup table.
const _syntheticFreeTimePrefix = '__preview_free_time_';

bool isSyntheticFreeTimeId(String id) => id.startsWith(_syntheticFreeTimePrefix);

String syntheticFreeTimeId(int index) => '$_syntheticFreeTimePrefix$index';

/// A staged (not-yet-persisted) change to an existing real task's schedule.
/// `ranges: null` means "unschedule this task".
class ScheduleOverride {
  final List<TaskTimeRange>? ranges;
  final bool constrainedToWorkingHours;

  const ScheduleOverride({required this.ranges, required this.constrainedToWorkingHours});
}

class SchedulingPreviewState {
  final Map<String, ScheduleOverride> overridesByTaskId;
  final List<Task> syntheticTasks;

  const SchedulingPreviewState({this.overridesByTaskId = const {}, this.syntheticTasks = const []});

  SchedulingPreviewState copyWith({Map<String, ScheduleOverride>? overridesByTaskId, List<Task>? syntheticTasks}) {
    return SchedulingPreviewState(
      overridesByTaskId: overridesByTaskId ?? this.overridesByTaskId,
      syntheticTasks: syntheticTasks ?? this.syntheticTasks,
    );
  }
}

List<Task> _applyOverrides(List<Task> realTasks, SchedulingPreviewState preview) {
  return [
    for (final t in realTasks)
      if (preview.overridesByTaskId[t.id] case final o?)
        t.copyWith(
          estimatedExecutionTimeRanges: o.ranges ?? const <TaskTimeRange>[],
          constrainedToWorkingHours: o.constrainedToWorkingHours,
        )
      else
        t,
    ...preview.syntheticTasks,
  ];
}

/// Pure, unit-testable: merges [realTasks] with [preview]'s staged changes,
/// then applies the ordinary "scheduled today" filter.
List<Task> mergedScheduledTasksForPreview({
  required List<Task> realTasks,
  required SchedulingPreviewState preview,
  required DateTime today,
}) {
  return scheduledTasksForToday(_applyOverrides(realTasks, preview), today);
}

/// Pure, unit-testable: merges [realTasks] with [preview]'s staged changes,
/// then applies the ordinary "unscheduled today" filter.
List<Task> mergedUnscheduledTasksForPreview({
  required List<Task> realTasks,
  required SchedulingPreviewState preview,
  required DateTime today,
}) {
  return unscheduledTasksForToday(_applyOverrides(realTasks, preview), today);
}

/// Computes the scheduling preview's starting state right after
/// `runScheduleMyDay`'s dialogs resolve, mirroring the old direct-apply
/// logic: a task in [planTasks] that [result] placed gets staged with its
/// new ranges; one that didn't get placed but previously had ranges gets
/// staged as cleared; anything else in [planTasks] is left untouched.
/// [freeTimeDrafts] (if any) become the preview's synthetic tasks as-is.
/// Pure, so it can run at [SchedulingPreviewNotifier] construction time rather
/// than as an imperative post-mount mutation (which would race Riverpod's
/// "no modifying providers during build" guard).
SchedulingPreviewState computeInitialPreviewState({
  required List<Task> planTasks,
  required PlanResult result,
  required List<Task> freeTimeDrafts,
}) {
  final overrides = <String, ScheduleOverride>{};
  for (final task in planTasks) {
    final ranges = result.scheduledRanges[task.id];
    if (ranges != null) {
      overrides[task.id] = ScheduleOverride(ranges: ranges, constrainedToWorkingHours: task.constrainedToWorkingHours);
    } else if (task.estimatedExecutionTimeRanges.isNotEmpty) {
      overrides[task.id] = const ScheduleOverride(ranges: null, constrainedToWorkingHours: true);
    }
  }
  return SchedulingPreviewState(overridesByTaskId: overrides, syntheticTasks: freeTimeDrafts);
}

class SchedulingPreviewNotifier extends Notifier<SchedulingPreviewState> {
  final SchedulingPreviewState _initialState;

  SchedulingPreviewNotifier([this._initialState = const SchedulingPreviewState()]);

  @override
  SchedulingPreviewState build() => _initialState;

  void scheduleRanges(Task task, List<TaskTimeRange> ranges, {bool? constrainedToWorkingHours}) {
    if (isSyntheticFreeTimeId(task.id)) {
      state = state.copyWith(syntheticTasks: [
        for (final t in state.syntheticTasks)
          if (t.id == task.id)
            t.copyWith(
              estimatedExecutionTimeRanges: ranges,
              constrainedToWorkingHours: constrainedToWorkingHours,
            )
          else
            t,
      ]);
      return;
    }
    state = state.copyWith(overridesByTaskId: {
      ...state.overridesByTaskId,
      task.id: ScheduleOverride(
        ranges: ranges,
        constrainedToWorkingHours: constrainedToWorkingHours ?? task.constrainedToWorkingHours,
      ),
    });
  }

  void unschedule(Task task) {
    if (isSyntheticFreeTimeId(task.id)) {
      state = state.copyWith(syntheticTasks: [
        for (final t in state.syntheticTasks)
          if (t.id == task.id) t.copyWith(estimatedExecutionTimeRanges: const <TaskTimeRange>[]) else t,
      ]);
      return;
    }
    state = state.copyWith(overridesByTaskId: {
      ...state.overridesByTaskId,
      task.id: const ScheduleOverride(ranges: null, constrainedToWorkingHours: true),
    });
  }

  void deleteSynthetic(String id) {
    state = state.copyWith(syntheticTasks: state.syntheticTasks.where((t) => t.id != id).toList());
  }
}

final schedulingPreviewProvider = NotifierProvider<SchedulingPreviewNotifier, SchedulingPreviewState>(SchedulingPreviewNotifier.new);
