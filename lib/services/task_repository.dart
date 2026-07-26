import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/clock.dart';
import '../models/task.dart';
import 'goal_repository.dart';

abstract class TaskRepository {
  Stream<List<Task>> streamTasks(String userId);

  /// Creates a new task from [draft]. Only the user-editable fields are
  /// used — [Task.id], [Task.createdAt], [Task.isCompleted],
  /// [Task.completedAt], and [Task.contributesToCount] are ignored in favor
  /// of the new task's own defaults, so callers can pass a placeholder
  /// (e.g. `id: ''`) for those.
  Future<void> addTask(Task draft);

  Future<void> updateTask(Task task);

  Future<void> deleteTask(String taskId);

  /// Toggles task completion and, if the task is linked to a goal and
  /// flagged to contribute, increments/decrements that goal's progress.
  Future<void> toggleComplete(Task task);

  /// Flags whether a completed [task] counts toward its linked goal's
  /// target. If the task is already completed, the goal's progress is
  /// adjusted immediately to match.
  Future<void> setContributesToCount(Task task, bool contributesToCount);

  Future<void> scheduleTaskRanges(Task task, List<TaskTimeRange> ranges);

  Future<void> unscheduleTask(Task task);
}

class FirestoreTaskRepository implements TaskRepository {
  final FirebaseFirestore _db;
  final Clock _clock;
  final GoalRepository _goalRepository;

  FirestoreTaskRepository(this._db, this._clock, this._goalRepository);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('tasks');

  @override
  Stream<List<Task>> streamTasks(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Task.fromFirestore(d, now: _clock.now())).toList());
  }

  @override
  Future<void> addTask(Task draft) {
    final data = draft.toFirestore();
    data['contributesToCount'] = false;
    data['isCompleted'] = false;
    data['completedAt'] = null;
    data['createdAt'] = Timestamp.now();
    return _collection.add(data);
  }

  @override
  Future<void> updateTask(Task task) {
    return _collection.doc(task.id).update({
      'title': task.title,
      'dueDate': task.dueDate != null ? Timestamp.fromDate(task.dueDate!) : null,
      'estimatedExecutionTimeRanges': task.estimatedExecutionTimeRanges.map((r) => r.toFirestore()).toList(),
      'isRecurrent': task.isRecurrent,
      'recurrenceRule': task.recurrenceRule?.name,
      'categoryIds': task.categoryIds,
      'linkedGoalId': task.linkedGoalId,
      'contributesToCount': task.contributesToCount,
      'estimatedDurationMinutes': task.estimatedDuration?.inMinutes,
      'isImportant': task.isImportant,
      'isUrgent': task.isUrgent,
      'constrainedToWorkingHours': task.constrainedToWorkingHours,
    });
  }

  @override
  Future<void> deleteTask(String taskId) {
    return _collection.doc(taskId).delete();
  }

  /// The task write is a plain (non-transactional) update so it gets
  /// Firestore's local latency compensation and shows up in `streamTasks`
  /// immediately, instead of waiting on a server round-trip. The goal
  /// progress update still needs a transaction (it's a read-modify-write
  /// on a counter), but it runs after and independently, so it never gates
  /// the task's own completed state.
  @override
  Future<void> toggleComplete(Task task) async {
    final taskRef = _collection.doc(task.id);
    final newCompleted = !task.isCompleted;
    final goalId = task.linkedGoalId;

    await taskRef.update({
      'isCompleted': newCompleted,
      'completedAt': newCompleted ? Timestamp.now() : null,
    });

    if (goalId == null || !task.contributesToCount) return;

    await _goalRepository.adjustProgress(goalId, newCompleted ? 1 : -1);
  }

  @override
  Future<void> setContributesToCount(Task task, bool contributesToCount) async {
    if (task.contributesToCount == contributesToCount) return;

    await _collection.doc(task.id).update({'contributesToCount': contributesToCount});

    final goalId = task.linkedGoalId;
    if (goalId == null || !task.isCompleted) return;

    await _goalRepository.adjustProgress(goalId, contributesToCount ? 1 : -1);
  }

  @override
  Future<void> scheduleTaskRanges(Task task, List<TaskTimeRange> ranges) {
    return updateTask(task.copyWith(estimatedExecutionTimeRanges: ranges));
  }

  @override
  Future<void> unscheduleTask(Task task) {
    return updateTask(task.copyWith(estimatedExecutionTimeRanges: []));
  }
}
