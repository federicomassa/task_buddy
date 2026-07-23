import 'dart:ui' show Offset;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart' show DragUpdateDetails, DraggableDetails;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/clock.dart';
import '../core/date_utils.dart';
import '../core/error_reporter.dart';
import '../models/task.dart';
import '../services/auth_service.dart';
import '../services/category_repository.dart';
import '../services/goal_repository.dart';
import '../services/habit_cycle_service.dart';
import '../services/habit_repository.dart';
import '../services/task_repository.dart';

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

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return FirestoreTaskRepository(
    ref.watch(firestoreProvider),
    ref.watch(clockProvider),
    ref.watch(goalRepositoryProvider),
  );
});

final habitCycleServiceProvider = Provider<HabitCycleService>((ref) {
  return HabitCycleService(
    ref.watch(habitRepositoryProvider),
    ref.watch(goalRepositoryProvider),
    ref.watch(clockProvider),
  );
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

/// Tasks due today or overdue, and not yet scheduled for today — candidates
/// for the Today screen's unscheduled task list. Completed tasks stay in
/// the list (styled green by [taskCardStyle]) instead of disappearing.
final unscheduledTodayTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksStreamProvider).value ?? const <Task>[];
  final today = dateOnly(ref.watch(clockProvider).now());
  return tasks.where((t) {
    if (t.dueDate == null) return false;
    final due = dateOnly(t.dueDate!);
    if (due.isAfter(today)) return false;
    final sched = t.scheduledDate;
    final scheduledForToday = sched != null && dateOnly(sched) == today;
    return !scheduledForToday;
  }).toList();
});

/// Tasks already scheduled for today — rendered as blocks on the Today
/// screen's calendar. Completed tasks stay visible (styled green) instead
/// of disappearing.
final todayScheduledTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(tasksStreamProvider).value ?? const <Task>[];
  final today = dateOnly(ref.watch(clockProvider).now());
  return tasks.where((t) {
    if (t.scheduledDate == null) return false;
    return dateOnly(t.scheduledDate!) == today;
  }).toList();
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
