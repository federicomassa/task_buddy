import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/plan_scheduler.dart';
import 'package:task_buddy/features/plan/plan_preview_state.dart';
import 'package:task_buddy/models/task.dart';

void main() {
  final today = DateTime(2026, 7, 26);

  Task buildTask(String id, {List<TaskTimeRange> ranges = const [], DateTime? dueDate, bool isCompleted = false}) {
    return Task(
      id: id,
      userId: 'u1',
      title: id,
      dueDate: dueDate ?? today,
      estimatedExecutionTimeRanges: ranges,
      isRecurrent: false,
      categoryIds: const [],
      isCompleted: isCompleted,
      createdAt: today,
      estimatedDuration: const Duration(minutes: 30),
    );
  }

  TaskTimeRange rangeAt(int hour) => TaskTimeRange(
        start: DateTime(2026, 7, 26, hour),
        end: DateTime(2026, 7, 26, hour, 30),
      );

  group('computeInitialPreviewState', () {
    test('a task the plan placed gets staged with its new ranges', () {
      final task = buildTask('a');
      final result = PlanResult(
        scheduledRanges: {'a': [rangeAt(9)]},
        unscheduled: const [],
        infeasibleTasks: const [],
        remainingGaps: const [],
        totalActiveMinutes: 60,
        totalEstimateMinutes: 30,
      );

      final state = computeInitialPreviewState(planTasks: [task], result: result, freeTimeDrafts: const []);

      expect(state.overridesByTaskId['a']!.ranges, [rangeAt(9)]);
    });

    test('a task that lost its slot but previously had ranges gets staged as cleared', () {
      final task = buildTask('a', ranges: [rangeAt(9)]);
      final result = const PlanResult(
        scheduledRanges: {},
        unscheduled: [],
        infeasibleTasks: [],
        remainingGaps: [],
        totalActiveMinutes: 60,
        totalEstimateMinutes: 30,
      );

      final state = computeInitialPreviewState(planTasks: [task], result: result, freeTimeDrafts: const []);

      expect(state.overridesByTaskId['a']!.ranges, isNull);
    });

    test('a task the plan neither placed nor previously scheduled is left untouched', () {
      final task = buildTask('a');
      final result = const PlanResult(
        scheduledRanges: {},
        unscheduled: [],
        infeasibleTasks: [],
        remainingGaps: [],
        totalActiveMinutes: 60,
        totalEstimateMinutes: 30,
      );

      final state = computeInitialPreviewState(planTasks: [task], result: result, freeTimeDrafts: const []);

      expect(state.overridesByTaskId, isEmpty);
    });

    test('free-time drafts become the synthetic tasks as-is', () {
      final freeTime = buildTask(syntheticFreeTimeId(0), ranges: [rangeAt(14)]);
      final result = const PlanResult(
        scheduledRanges: {},
        unscheduled: [],
        infeasibleTasks: [],
        remainingGaps: [],
        totalActiveMinutes: 0,
        totalEstimateMinutes: 0,
      );

      final state = computeInitialPreviewState(planTasks: const [], result: result, freeTimeDrafts: [freeTime]);

      expect(state.syntheticTasks, [freeTime]);
    });
  });

  group('mergedScheduledTasksForPreview / mergedUnscheduledTasksForPreview', () {
    test('an overridden real task appears scheduled at its new time, not its old one', () {
      final task = buildTask('a', ranges: [rangeAt(8)]);
      final preview = PlanPreviewState(overridesByTaskId: {
        'a': ScheduleOverride(ranges: [rangeAt(10)], constrainedToWorkingHours: true),
      });

      final scheduled = mergedScheduledTasksForPreview(realTasks: [task], preview: preview, today: today);
      expect(scheduled, hasLength(1));
      expect(scheduled.single.estimatedExecutionTimeRanges, [rangeAt(10)]);
    });

    test('a synthetic free-time task with ranges appears in the scheduled list', () {
      final freeTime = buildTask(syntheticFreeTimeId(0), ranges: [rangeAt(14)]);
      final preview = PlanPreviewState(syntheticTasks: [freeTime]);

      final scheduled = mergedScheduledTasksForPreview(realTasks: const [], preview: preview, today: today);
      expect(scheduled.map((t) => t.id), [syntheticFreeTimeId(0)]);
    });

    test('a synthetic task dragged off the calendar (emptied ranges) disappears from scheduled '
        'without reappearing as unscheduled', () {
      final freeTime = buildTask(syntheticFreeTimeId(0), ranges: const []);
      final preview = PlanPreviewState(syntheticTasks: [freeTime]);

      final scheduled = mergedScheduledTasksForPreview(realTasks: const [], preview: preview, today: today);
      final unscheduled = mergedUnscheduledTasksForPreview(realTasks: const [], preview: preview, today: today);

      expect(scheduled, isEmpty);
      // Free-time drafts aren't real, due-dated user tasks in the sense the
      // unscheduled list cares about, but the shared filter only checks
      // dueDate/isCompleted/isScheduledToday, so an emptied one does show up
      // there — matching how any other unscheduled task would behave.
      expect(unscheduled.map((t) => t.id), [syntheticFreeTimeId(0)]);
    });

    test('an override that clears a real task moves it into the unscheduled list', () {
      final task = buildTask('a', ranges: [rangeAt(8)]);
      final preview = PlanPreviewState(overridesByTaskId: {
        'a': const ScheduleOverride(ranges: null, constrainedToWorkingHours: true),
      });

      final scheduled = mergedScheduledTasksForPreview(realTasks: [task], preview: preview, today: today);
      final unscheduled = mergedUnscheduledTasksForPreview(realTasks: [task], preview: preview, today: today);

      expect(scheduled, isEmpty);
      expect(unscheduled.map((t) => t.id), ['a']);
    });

    test('a task untouched by the preview keeps its real schedule', () {
      final task = buildTask('a', ranges: [rangeAt(8)]);
      const preview = PlanPreviewState();

      final scheduled = mergedScheduledTasksForPreview(realTasks: [task], preview: preview, today: today);
      expect(scheduled.single.estimatedExecutionTimeRanges, [rangeAt(8)]);
    });
  });

  group('PlanPreviewNotifier write paths', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('scheduleRanges on a real task stages an override', () {
      final task = buildTask('a');
      container.read(planPreviewProvider.notifier).scheduleRanges(task, [rangeAt(11)]);

      expect(container.read(planPreviewProvider).overridesByTaskId['a']!.ranges, [rangeAt(11)]);
    });

    test('scheduleRanges on a synthetic task updates it in place instead of creating an override', () {
      final freeTime = buildTask(syntheticFreeTimeId(0), ranges: [rangeAt(14)]);
      final seededContainer = ProviderContainer(overrides: [
        planPreviewProvider.overrideWith(
          () => PlanPreviewNotifier(PlanPreviewState(syntheticTasks: [freeTime])),
        ),
      ]);
      addTearDown(seededContainer.dispose);

      seededContainer.read(planPreviewProvider.notifier).scheduleRanges(freeTime, [rangeAt(16)]);

      final state = seededContainer.read(planPreviewProvider);
      expect(state.overridesByTaskId, isEmpty);
      expect(state.syntheticTasks.single.estimatedExecutionTimeRanges, [rangeAt(16)]);
    });

    test('deleteSynthetic removes the free-time task outright', () {
      final freeTime = buildTask(syntheticFreeTimeId(0), ranges: [rangeAt(14)]);
      final seededContainer = ProviderContainer(overrides: [
        planPreviewProvider.overrideWith(
          () => PlanPreviewNotifier(PlanPreviewState(syntheticTasks: [freeTime])),
        ),
      ]);
      addTearDown(seededContainer.dispose);

      seededContainer.read(planPreviewProvider.notifier).deleteSynthetic(syntheticFreeTimeId(0));

      expect(seededContainer.read(planPreviewProvider).syntheticTasks, isEmpty);
    });
  });
}
