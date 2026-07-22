import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/goal.dart';
import '../models/task.dart';

class TaskRepository {
  final FirebaseFirestore _db;

  TaskRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('tasks');
  CollectionReference<Map<String, dynamic>> get _goalsCollection =>
      _db.collection('goals');

  Stream<List<Task>> streamTasks(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Task.fromFirestore).toList());
  }

  Future<void> addTask({
    required String userId,
    required String title,
    DateTime? dueDate,
    required bool isRecurrent,
    RecurrenceRule? recurrenceRule,
    List<String> categoryIds = const [],
    String? linkedGoalId,
  }) {
    return _collection.add({
      'userId': userId,
      'title': title,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'isRecurrent': isRecurrent,
      'recurrenceRule': recurrenceRule?.name,
      'categoryIds': categoryIds,
      'linkedGoalId': linkedGoalId,
      'isCompleted': false,
      'completedAt': null,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> updateTask(Task task) {
    return _collection.doc(task.id).update({
      'title': task.title,
      'dueDate': task.dueDate != null ? Timestamp.fromDate(task.dueDate!) : null,
      'isRecurrent': task.isRecurrent,
      'recurrenceRule': task.recurrenceRule?.name,
      'categoryIds': task.categoryIds,
      'linkedGoalId': task.linkedGoalId,
    });
  }

  Future<void> deleteTask(String taskId) {
    return _collection.doc(taskId).delete();
  }

  /// Toggles task completion and, if the task is linked to a goal,
  /// increments/decrements that goal's progress in the same transaction.
  Future<void> toggleComplete(Task task) {
    final taskRef = _collection.doc(task.id);
    final newCompleted = !task.isCompleted;
    final goalId = task.linkedGoalId;

    return _db.runTransaction((tx) async {
      DocumentReference<Map<String, dynamic>>? goalRef;
      Goal? goal;
      if (goalId != null) {
        goalRef = _goalsCollection.doc(goalId);
        final goalSnap = await tx.get(goalRef);
        if (goalSnap.exists) {
          goal = Goal.fromFirestore(goalSnap);
        }
      }

      tx.update(taskRef, {
        'isCompleted': newCompleted,
        'completedAt': newCompleted ? Timestamp.now() : null,
      });

      if (goalRef != null && goal != null) {
        final delta = newCompleted ? 1 : -1;
        final newProgress = (goal.currentProgress + delta).clamp(0, 1 << 30);
        final target = goal.targetCount;
        final nowCompleted = target != null && newProgress >= target;
        tx.update(goalRef, {
          'currentProgress': newProgress,
          'isCompleted': nowCompleted,
        });
      }
    });
  }
}
