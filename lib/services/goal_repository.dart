import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/clock.dart';
import '../models/goal.dart';

abstract class GoalRepository {
  Stream<List<Goal>> streamStandaloneGoals(String userId);

  Stream<List<Goal>> streamHabitInstances(String userId);

  /// All goal-linkable items (used for the task-linking dropdown).
  Stream<List<Goal>> streamAllGoals(String userId);

  Future<List<Goal>> fetchHabitInstances(String userId, String habitId);

  Future<void> addStandaloneGoal({
    required String userId,
    required String title,
    required String description,
    String? categoryId,
    DateTime? dueDate,
    int? targetCount,
  });

  Future<void> addHabitInstance({
    required String userId,
    required String habitId,
    required String title,
    required String description,
    String? categoryId,
    required int targetCount,
    required DateTime startDate,
    required DateTime endDate,
    DateTime? dueDate,
  });

  Future<void> updateGoal(Goal goal);

  Future<void> setCompleted(String goalId, bool isCompleted);

  Future<void> deleteGoal(String goalId);

  /// Adjusts currentProgress by [delta] and auto-completes when the target
  /// is reached (or un-completes when it drops back below target).
  Future<void> adjustProgress(String goalId, int delta);
}

class FirestoreGoalRepository implements GoalRepository {
  final FirebaseFirestore _db;
  final Clock _clock;

  FirestoreGoalRepository(this._db, this._clock);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('goals');

  @override
  Stream<List<Goal>> streamStandaloneGoals(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .where('isHabitInstance', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Goal.fromFirestore(d, now: _clock.now())).toList());
  }

  @override
  Stream<List<Goal>> streamHabitInstances(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .where('isHabitInstance', isEqualTo: true)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Goal.fromFirestore(d, now: _clock.now())).toList());
  }

  @override
  Stream<List<Goal>> streamAllGoals(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Goal.fromFirestore(d, now: _clock.now())).toList());
  }

  @override
  Future<List<Goal>> fetchHabitInstances(String userId, String habitId) async {
    final snap = await _collection
        .where('userId', isEqualTo: userId)
        .where('habitId', isEqualTo: habitId)
        .orderBy('startDate', descending: true)
        .get();
    return snap.docs.map((d) => Goal.fromFirestore(d, now: _clock.now())).toList();
  }

  Map<String, dynamic> _baseGoalFields({
    required String userId,
    required String title,
    required String description,
    String? categoryId,
    DateTime? dueDate,
    int? targetCount,
  }) {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      'targetCount': targetCount,
      'currentProgress': 0,
      'isCompleted': false,
      'createdAt': Timestamp.now(),
    };
  }

  @override
  Future<void> addStandaloneGoal({
    required String userId,
    required String title,
    required String description,
    String? categoryId,
    DateTime? dueDate,
    int? targetCount,
  }) {
    return _collection.add({
      ..._baseGoalFields(
        userId: userId,
        title: title,
        description: description,
        categoryId: categoryId,
        dueDate: dueDate,
        targetCount: targetCount,
      ),
      'isHabitInstance': false,
      'habitId': null,
      'startDate': null,
      'endDate': null,
    });
  }

  @override
  Future<void> addHabitInstance({
    required String userId,
    required String habitId,
    required String title,
    required String description,
    String? categoryId,
    required int targetCount,
    required DateTime startDate,
    required DateTime endDate,
    DateTime? dueDate,
  }) {
    return _collection.add({
      ..._baseGoalFields(
        userId: userId,
        title: title,
        description: description,
        categoryId: categoryId,
        dueDate: dueDate,
        targetCount: targetCount,
      ),
      'isHabitInstance': true,
      'habitId': habitId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
    });
  }

  @override
  Future<void> updateGoal(Goal goal) {
    return _collection.doc(goal.id).update({
      'title': goal.title,
      'description': goal.description,
      'categoryId': goal.categoryId,
      'dueDate': goal.dueDate != null ? Timestamp.fromDate(goal.dueDate!) : null,
      'targetCount': goal.targetCount,
    });
  }

  @override
  Future<void> setCompleted(String goalId, bool isCompleted) {
    return _collection.doc(goalId).update({'isCompleted': isCompleted});
  }

  @override
  Future<void> deleteGoal(String goalId) {
    return _collection.doc(goalId).delete();
  }

  @override
  Future<void> adjustProgress(String goalId, int delta) {
    final ref = _collection.doc(goalId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final goal = Goal.fromFirestore(snap, now: _clock.now());
      final newProgress = (goal.currentProgress + delta).clamp(0, 1 << 30);
      final target = goal.targetCount;
      final nowCompleted = target != null && newProgress >= target;
      tx.update(ref, {
        'currentProgress': newProgress,
        'isCompleted': nowCompleted,
      });
    });
  }
}
