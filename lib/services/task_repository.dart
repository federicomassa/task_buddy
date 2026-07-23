import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/clock.dart';
import '../models/task.dart';
import 'goal_repository.dart';

abstract class TaskRepository {
  Stream<List<Task>> streamTasks(String userId);

  Future<void> addTask({
    required String userId,
    required String title,
    DateTime? dueDate,
    DateTime? scheduledDate,
    required bool isRecurrent,
    RecurrenceRule? recurrenceRule,
    List<String> categoryIds = const [],
    String? linkedGoalId,
    Duration? timeEstimate,
  });

  Future<void> updateTask(Task task);

  Future<void> deleteTask(String taskId);

  /// Toggles task completion and, if the task is linked to a goal and
  /// flagged to contribute, increments/decrements that goal's progress.
  Future<void> toggleComplete(Task task);

  /// Flags whether a completed [task] counts toward its linked goal's
  /// target. If the task is already completed, the goal's progress is
  /// adjusted immediately to match.
  Future<void> setContributesToCount(Task task, bool contributesToCount);

  Future<void> scheduleTask(Task task, DateTime scheduledDate);

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
  Future<void> addTask({
    required String userId,
    required String title,
    DateTime? dueDate,
    DateTime? scheduledDate,
    required bool isRecurrent,
    RecurrenceRule? recurrenceRule,
    List<String> categoryIds = const [],
    String? linkedGoalId,
    Duration? timeEstimate,
  }) {
    return _collection.add({
      'userId': userId,
      'title': title,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'scheduledDate': scheduledDate != null ? Timestamp.fromDate(scheduledDate) : null,
      'isRecurrent': isRecurrent,
      'recurrenceRule': recurrenceRule?.name,
      'categoryIds': categoryIds,
      'linkedGoalId': linkedGoalId,
      'contributesToCount': false,
      'isCompleted': false,
      'completedAt': null,
      'createdAt': Timestamp.now(),
      'timeEstimateMinutes': timeEstimate?.inMinutes,
    });
  }

  @override
  Future<void> updateTask(Task task) {
    return _collection.doc(task.id).update({
      'title': task.title,
      'dueDate': task.dueDate != null ? Timestamp.fromDate(task.dueDate!) : null,
      'scheduledDate': task.scheduledDate != null ? Timestamp.fromDate(task.scheduledDate!) : null,
      'isRecurrent': task.isRecurrent,
      'recurrenceRule': task.recurrenceRule?.name,
      'categoryIds': task.categoryIds,
      'linkedGoalId': task.linkedGoalId,
      'contributesToCount': task.contributesToCount,
      'timeEstimateMinutes': task.timeEstimate?.inMinutes,
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
  Future<void> scheduleTask(Task task, DateTime scheduledDate) {
    return updateTask(task.copyWith(scheduledDate: scheduledDate));
  }

  @override
  Future<void> unscheduleTask(Task task) {
    return updateTask(task.copyWith(scheduledDate: null));
  }
}
