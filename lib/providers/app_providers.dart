import 'dart:ui' show Offset;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart' show DragUpdateDetails, DraggableDetails;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../core/date_utils.dart';
import '../core/error_reporter.dart';
import '../core/filter_state.dart';
import '../core/today_task_filters.dart';
import '../models/task.dart';
import '../models/family.dart';
import '../services/auth_service.dart';
import '../services/category_repository.dart';
import '../services/family_repository.dart';
import '../services/goal_repository.dart';
import '../services/habit_cycle_service.dart';
import '../services/habit_repository.dart';
import '../services/notification_service.dart';
import '../services/task_repository.dart';
import '../services/user_settings_repository.dart';

final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final clockProvider = Provider<Clock>((ref) => const SystemClock());

final errorReporterProvider = Provider<ErrorReporter>((ref) => const SnackBarErrorReporter());

final authServiceProvider = Provider<AuthService>((ref) {
  return FirebaseAuthServiceImpl(FirebaseAuth.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges();
});

/// The signed-in user's uid. Guarded by AuthGate, so this only resolves
/// once a user is present.
final currentUserIdProvider = Provider<String>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    throw StateError('currentUserIdProvider read before authentication');
  }
  return user.uid;
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return FirestoreCategoryRepository(ref.watch(firestoreProvider), ref.watch(clockProvider));
});

final habitRepositoryProvider = Provider<HabitRepository>((ref) {
  return FirestoreHabitRepository(ref.watch(firestoreProvider), ref.watch(clockProvider));
});

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  return FirestoreGoalRepository(ref.watch(firestoreProvider), ref.watch(clockProvider));
});

/// The real, Firestore-backed task repository. Kept separate from
/// [taskRepositoryProvider] so the plan-preview screen can override just the
/// latter (to sandbox schedule writes in memory) while still reaching this
/// one directly to flush the preview to Firestore on confirm.
final realTaskRepositoryProvider = Provider<TaskRepository>((ref) {
  return FirestoreTaskRepository(
    ref.watch(firestoreProvider),
    ref.watch(clockProvider),
    ref.watch(goalRepositoryProvider),
  );
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) => ref.watch(realTaskRepositoryProvider));

final habitCycleServiceProvider = Provider<HabitCycleService>((ref) {
  return HabitCycleService(
    ref.watch(habitRepositoryProvider),
    ref.watch(goalRepositoryProvider),
    ref.watch(clockProvider),
  );
});

final userSettingsRepositoryProvider = Provider<UserSettingsRepository>((ref) {
  return FirestoreUserSettingsRepository(ref.watch(firestoreProvider));
});

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FirestoreFamilyRepository(ref.watch(firestoreProvider), ref.watch(clockProvider));
});

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

final categoriesStreamProvider = StreamProvider((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(categoryRepositoryProvider).streamCategories(userId);
});

final habitsStreamProvider = StreamProvider((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(habitRepositoryProvider).streamHabits(userId);
});

final standaloneGoalsStreamProvider = StreamProvider((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(goalRepositoryProvider).streamStandaloneGoals(userId);
});

final habitInstancesStreamProvider = StreamProvider((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(goalRepositoryProvider).streamHabitInstances(userId);
});

final allGoalsStreamProvider = StreamProvider((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(goalRepositoryProvider).streamAllGoals(userId);
});

final tasksStreamProvider = StreamProvider((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(taskRepositoryProvider).streamTasks(userId);
});

final userSettingsStreamProvider = StreamProvider((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(userSettingsRepositoryProvider).streamSettings(userId);
});

final myFamilyIdStreamProvider = StreamProvider<String?>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ref.watch(familyRepositoryProvider).streamMyFamilyId(userId);
});

final myFamilyStreamProvider = StreamProvider<Family?>((ref) {
  final familyId = ref.watch(myFamilyIdStreamProvider).value;
  if (familyId == null) return Stream.value(null);
  return ref.watch(familyRepositoryProvider).streamFamily(familyId);
});

/// Whether the current user is a member of a family — gates the "Family
/// task" toggle in the task form, since a task can't be marked Family
/// without one to belong to.
final isInFamilyProvider = Provider<bool>((ref) {
  return ref.watch(myFamilyIdStreamProvider).value != null;
});

/// All of the current user's family's Family-tagged tasks, claimed or not —
/// so a member can see another member's edits to a task even after it's
/// been claimed, not just while it's sitting unclaimed.
final familyTasksStreamProvider = StreamProvider<List<Task>>((ref) {
  final familyId = ref.watch(myFamilyIdStreamProvider).value;
  if (familyId == null) return Stream.value(const <Task>[]);
  return ref.watch(taskRepositoryProvider).streamFamilyTasks(familyId);
});

/// Today's date, stripped of time-of-day. Centralized so every screen that
/// needs "today" (for overdue checks, due-date filtering, etc.) shares the
/// exact same value instead of each recomputing `dateOnly(clockProvider.now())`
/// — a previous divergence (one call site used the raw timestamp) caused
/// tasks due later today to be misclassified as overdue.
final todayProvider = Provider<DateTime>((ref) => dateOnly(ref.watch(clockProvider).now()));

/// Tasks due today or overdue, and not yet scheduled for today — candidates
/// for the Today screen's unscheduled task list. Completed tasks are
/// excluded since this list is for planning the day.
final unscheduledTodayTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksStreamProvider).value ?? const <Task>[];
  return unscheduledTasksForToday(tasks, ref.watch(todayProvider));
});

/// Active tasks due today or earlier, regardless of whether they're already
/// scheduled — the "Help me plan" matrix's pool. Unlike
/// [unscheduledTodayTasksProvider] (which feeds the Today screen's
/// unscheduled list and deliberately excludes anything already on the
/// calendar), the matrix is for triaging the *whole* day, including tasks
/// you've already dragged onto the calendar, so re-running "Schedule my day"
/// can re-plan them too.
final planEligibleTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksStreamProvider).value ?? const <Task>[];
  final today = ref.watch(todayProvider);
  return tasks.where((t) {
    if (t.isCompleted) return false;
    if (t.dueDate == null) return false;
    final due = dateOnly(t.dueDate!);
    return !due.isAfter(today);
  }).toList();
});

/// Tasks already scheduled for today — rendered as blocks on the Today
/// screen's calendar. Completed tasks stay visible (styled green) instead
/// of disappearing.
final todayScheduledTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksStreamProvider).value ?? const <Task>[];
  return scheduledTasksForToday(tasks, ref.watch(todayProvider));
});

/// Live position of a task card being dragged toward the calendar (from
/// either the unscheduled list or another calendar block being
/// rescheduled), updated on every pointer move so the calendar can render a
/// snapped ghost block that tracks the drag in real time. `DragTarget.onMove`
/// alone isn't a reliable way to drive this, since it only fires while the
/// pointer is over the target's own hit-test area — driving it from the
/// draggable's `onDragUpdate` instead means it fires on every pointer move.
class DragPreview {
  final Task task;
  final Offset globalPosition;

  const DragPreview({required this.task, required this.globalPosition});
}

class DragPreviewNotifier extends Notifier<DragPreview?> {
  @override
  DragPreview? build() => null;

  void set(DragPreview? value) => state = value;
}

final dragPreviewProvider = NotifierProvider<DragPreviewNotifier, DragPreview?>(
  DragPreviewNotifier.new,
);

/// Whether dropping a task onto the calendar is allowed to overlap another
/// scheduled task. Defaults to `false` (pure reordering: drops cascade-shift
/// colliding tasks out of the way — see [resolveOverlapFreeDrop]). In-memory
/// only, resets to the default on cold start.
class AllowOverlapNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final allowOverlapProvider = NotifierProvider<AllowOverlapNotifier, bool>(
  AllowOverlapNotifier.new,
);

/// Filter selections for the Tasks tab. In-memory only (resets on cold
/// start) but promoted out of widget state so the filter button (in the
/// AppBar) and the filter bottom sheet (a separate widget subtree) can share
/// it without prop drilling.
class TaskFilterNotifier extends Notifier<TaskFilterState> {
  @override
  TaskFilterState build() => TaskFilterState.defaults();

  void update(TaskFilterState Function(TaskFilterState) fn) => state = fn(state);
}

final taskFilterProvider = NotifierProvider<TaskFilterNotifier, TaskFilterState>(
  TaskFilterNotifier.new,
);

/// Filter selections for the Goals tab. See [TaskFilterNotifier].
class GoalFilterNotifier extends Notifier<GoalFilterState> {
  @override
  GoalFilterState build() => GoalFilterState.defaults();

  void update(GoalFilterState Function(GoalFilterState) fn) => state = fn(state);
}

final goalFilterProvider = NotifierProvider<GoalFilterNotifier, GoalFilterState>(
  GoalFilterNotifier.new,
);

/// Filter selections for the Habits tab. See [TaskFilterNotifier].
class HabitFilterNotifier extends Notifier<HabitFilterState> {
  @override
  HabitFilterState build() => HabitFilterState.defaults();

  void update(HabitFilterState Function(HabitFilterState) fn) => state = fn(state);
}

final habitFilterProvider = NotifierProvider<HabitFilterNotifier, HabitFilterState>(
  HabitFilterNotifier.new,
);

/// Shared onDragUpdate/onDragEnd wiring for task cards that report their
/// drag position into [dragPreviewProvider] (used by both the calendar's
/// scheduled blocks and the unscheduled list's schedule cards).
extension DragPreviewRef on WidgetRef {
  void Function(DragUpdateDetails) onTaskDragUpdate(Task task) {
    return (details) => read(dragPreviewProvider.notifier).set(
          DragPreview(task: task, globalPosition: details.globalPosition),
        );
  }

  void Function(DraggableDetails) onTaskDragEnd() {
    return (_) => read(dragPreviewProvider.notifier).set(null);
  }
}
