import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/active_hours.dart';
import '../../core/plan_scheduler.dart';
import '../../models/task.dart';
import '../../models/user_settings.dart';
import '../../providers/app_providers.dart';
import 'scheduling_preview_screen.dart';
import 'scheduling_preview_state.dart';

enum _CapacityChoice { proceed, insertFreeTime, goBack }

enum _InfeasibleChoice { goBack, scheduleRest }

/// Entry point for the "Schedule my day" button: computes the WSJF plan, and
/// if the estimated tasks don't fill the user's active hours, asks how to
/// handle the shortfall — then pushes a [SchedulingPreviewScreen] so the user can
/// see and adjust the proposal before anything is written to Firestore.
Future<void> runScheduleMyDay(
  BuildContext context,
  WidgetRef ref, {
  required List<Task> tasks,
  required UserSettings settings,
  required DateTime today,
}) async {
  final estimatedTasks = tasks.where((t) => t.estimatedDuration != null).toList();

  final result = computePlan(
    tasks: estimatedTasks,
    activeHours: settings.activeHourRanges,
    weights: settings.wsjfWeights,
    today: today,
  );

  if (result.infeasibleTasks.isNotEmpty) {
    final infeasibleChoice = await showDialog<_InfeasibleChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Some tasks can't be scheduled today"),
        content: SingleChildScrollView(
          child: Text(result.infeasibleTasks.map((it) => it.reason).join('\n\n')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_InfeasibleChoice.goBack),
            child: const Text('Go back'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(_InfeasibleChoice.scheduleRest),
            child: const Text('Schedule the rest'),
          ),
        ],
      ),
    );
    if (infeasibleChoice != _InfeasibleChoice.scheduleRest) return;
    if (!context.mounted) return;
  }

  if (result.totalEstimateMinutes >= result.totalActiveMinutes) {
    _pushPreview(context, result: result, planTasks: estimatedTasks, freeTimeDrafts: const []);
    return;
  }

  final choice = await showDialog<_CapacityChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Shorter than your active hours'),
      content: const Text(
        'The total estimated duration for your tasks is shorter than your active hours. '
        'Do you want to...',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(_CapacityChoice.goBack),
          child: const Text('Go back'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(_CapacityChoice.insertFreeTime),
          child: const Text('Add free time'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(_CapacityChoice.proceed),
          child: const Text('Proceed as is'),
        ),
      ],
    ),
  );
  if (!context.mounted) return;

  switch (choice) {
    case _CapacityChoice.proceed:
      _pushPreview(context, result: result, planTasks: estimatedTasks, freeTimeDrafts: const []);
      break;
    case _CapacityChoice.insertFreeTime:
      final drafts = _freeTimeDrafts(
        result.remainingGaps,
        today: today,
        userId: ref.read(currentUserIdProvider),
        now: ref.read(clockProvider).now(),
      );
      _pushPreview(context, result: result, planTasks: estimatedTasks, freeTimeDrafts: drafts);
      break;
    case _CapacityChoice.goBack:
    case null:
      break;
  }
}

/// Builds not-yet-persisted free-time placeholder drafts for each of
/// [gaps], one per remaining gap in the active hours — these only become
/// real Firestore tasks if the plan preview is confirmed.
List<Task> _freeTimeDrafts(
  List<TimeRange> gaps, {
  required DateTime today,
  required String userId,
  required DateTime now,
}) {
  return [
    for (var i = 0; i < gaps.length; i++)
      Task(
        id: syntheticFreeTimeId(i),
        userId: userId,
        title: 'Free time',
        dueDate: today,
        estimatedExecutionTimeRanges: taskTimeRangesForDay(today, [gaps[i]]),
        isRecurrent: false,
        categoryIds: const [],
        isCompleted: false,
        createdAt: now,
        estimatedDuration: Duration(minutes: gaps[i].endMinutes - gaps[i].startMinutes),
      ),
  ];
}

void _pushPreview(
  BuildContext context, {
  required PlanResult result,
  required List<Task> planTasks,
  required List<Task> freeTimeDrafts,
}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SchedulingPreviewScreen(result: result, planTasks: planTasks, freeTimeDrafts: freeTimeDrafts),
  ));
}
