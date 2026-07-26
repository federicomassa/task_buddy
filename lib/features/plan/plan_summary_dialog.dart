import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/plan_scheduler.dart';
import '../../models/task.dart';
import '../../models/user_settings.dart';
import '../../providers/app_providers.dart';
import '../../services/task_repository.dart';

enum _CapacityChoice { proceed, insertFreeTime, goBack }

/// Entry point for the "Schedule my day" button: computes the WSJF plan, and
/// if the estimated tasks don't fill the user's active hours, asks how to
/// handle the shortfall before applying anything. Stays on the matrix screen
/// throughout — scheduled tasks naturally leave their quadrant (they're no
/// longer "unscheduled"), but a snackbar summarizes the result instead of
/// navigating the user away.
Future<void> runScheduleMyDay(
  BuildContext context,
  WidgetRef ref, {
  required List<Task> tasks,
  required UserSettings settings,
  required DateTime today,
}) async {
  final estimatedTasks = tasks.where((t) => t.timeEstimate != null).toList();
  final repo = ref.read(taskRepositoryProvider);
  final messenger = ScaffoldMessenger.of(context);

  final result = computePlan(
    tasks: estimatedTasks,
    activeHours: settings.activeHourRanges,
    weights: settings.wsjfWeights,
    today: today,
  );

  if (result.totalEstimateMinutes >= result.totalActiveMinutes) {
    await _applyPlan(repo, estimatedTasks, result);
    _showSummary(messenger, result);
    return;
  }

  final choice = await showDialog<_CapacityChoice>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Shorter than your active hours'),
      content: const Text(
        'The total time estimate for your tasks is shorter than your active hours. '
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

  switch (choice) {
    case _CapacityChoice.proceed:
      await _applyPlan(repo, estimatedTasks, result);
      _showSummary(messenger, result);
      break;
    case _CapacityChoice.insertFreeTime:
      await Future.wait([
        for (final gap in result.remainingGaps)
          repo.addTask(
            userId: ref.read(currentUserIdProvider),
            title: 'Free time',
            dueDate: today,
            scheduledDate: DateTime(
              today.year,
              today.month,
              today.day,
              gap.startMinutes ~/ 60,
              gap.startMinutes % 60,
            ),
            isRecurrent: false,
            timeEstimate: Duration(minutes: gap.endMinutes - gap.startMinutes),
          ),
      ]);
      await _applyPlan(repo, estimatedTasks, result);
      _showSummary(messenger, result, addedFreeTimeSlots: result.remainingGaps.length);
      break;
    case _CapacityChoice.goBack:
    case null:
      break;
  }
}

/// Writes every task's new scheduledDate concurrently (rather than one
/// `await` at a time) so they leave the matrix's quadrants together instead
/// of visibly draining out one by one.
Future<void> _applyPlan(TaskRepository repo, List<Task> tasks, PlanResult result) async {
  await Future.wait([
    for (final task in tasks)
      if (result.scheduledTimes[task.id] case final scheduledDate?) repo.scheduleTask(task, scheduledDate),
  ]);
}

void _showSummary(ScaffoldMessengerState messenger, PlanResult result, {int addedFreeTimeSlots = 0}) {
  final scheduledCount = result.scheduledTimes.length;
  final parts = <String>['Scheduled $scheduledCount task${scheduledCount == 1 ? '' : 's'}'];
  if (addedFreeTimeSlots > 0) {
    parts.add('added $addedFreeTimeSlots free time slot${addedFreeTimeSlots == 1 ? '' : 's'}');
  }
  if (result.unscheduled.isNotEmpty) {
    parts.add("${result.unscheduled.length} didn't fit in your active hours");
  }
  messenger.showSnackBar(SnackBar(content: Text('${parts.join(', ')}.')));
}
