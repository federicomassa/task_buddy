import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/plan_scheduler.dart';
import '../../models/task.dart';
import '../../providers/app_providers.dart';
import '../today/calendar_pane.dart';
import '../today/unscheduled_list_pane.dart';
import 'plan_preview_state.dart';
import 'preview_task_repository.dart';

/// Shows the proposed "Schedule my day" plan rendered exactly like the
/// Today screen's body, but entirely sandboxed: every schedule-changing
/// write the user makes while adjusting it (drag-and-drop, unscheduling)
/// lands in an in-memory notifier instead of Firestore. Nothing is
/// persisted unless the user taps the confirm checkmark; backing out
/// discards everything for free, since the nested ProviderScope holding
/// the preview state is simply disposed.
class PlanPreviewScreen extends StatelessWidget {
  final PlanResult result;
  final List<Task> planTasks;
  final List<Task> freeTimeDrafts;

  const PlanPreviewScreen({
    super.key,
    required this.result,
    required this.planTasks,
    required this.freeTimeDrafts,
  });

  @override
  Widget build(BuildContext context) {
    final initialState = computeInitialPreviewState(
      planTasks: planTasks,
      result: result,
      freeTimeDrafts: freeTimeDrafts,
    );

    return ProviderScope(
      overrides: [
        planPreviewProvider.overrideWith(() => PlanPreviewNotifier(initialState)),
        allowOverlapProvider.overrideWith(AllowOverlapNotifier.new),
        todayScheduledTasksProvider.overrideWith((ref) => mergedScheduledTasksForPreview(
              realTasks: ref.watch(tasksStreamProvider).value ?? const <Task>[],
              preview: ref.watch(planPreviewProvider),
              today: ref.watch(todayProvider),
            )),
        unscheduledTodayTasksProvider.overrideWith((ref) => mergedUnscheduledTasksForPreview(
              realTasks: ref.watch(tasksStreamProvider).value ?? const <Task>[],
              preview: ref.watch(planPreviewProvider),
              today: ref.watch(todayProvider),
            )),
        taskRepositoryProvider.overrideWith(
          (ref) => PreviewTaskRepository(ref.watch(realTaskRepositoryProvider), ref.read(planPreviewProvider.notifier)),
        ),
      ],
      child: const _PlanPreviewBody(),
    );
  }
}

class _PlanPreviewBody extends ConsumerWidget {
  static const double _wideBreakpoint = 600;

  const _PlanPreviewBody();

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(realTaskRepositoryProvider);
    final preview = ref.read(planPreviewProvider);
    final realTasksById = {for (final t in ref.read(tasksStreamProvider).value ?? const <Task>[]) t.id: t};
    final navigator = Navigator.of(context);

    await Future.wait([
      for (final entry in preview.overridesByTaskId.entries)
        if (realTasksById[entry.key] case final task?)
          if (entry.value.ranges != null)
            repo.scheduleTaskRanges(task, entry.value.ranges!, constrainedToWorkingHours: entry.value.constrainedToWorkingHours)
          else
            repo.unscheduleTask(task),
      for (final synthetic in preview.syntheticTasks)
        if (synthetic.estimatedExecutionTimeRanges.isNotEmpty) repo.addTask(synthetic),
    ]);

    if (!context.mounted) return;
    navigator
      ..pop()
      ..pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final isWide = MediaQuery.sizeOf(context).width >= _wideBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview plan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Confirm plan',
            onPressed: () => _confirm(context, ref),
          ),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                Expanded(flex: 2, child: DayCalendarView(today: today)),
                const VerticalDivider(width: 1),
                Expanded(flex: 1, child: UnscheduledTaskList(today: today)),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 2, child: DayCalendarView(today: today)),
                const Divider(height: 1),
                Expanded(child: UnscheduledTaskList(today: today)),
              ],
            ),
    );
  }
}
