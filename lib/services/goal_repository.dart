import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/goal.dart';

class GoalRepository {
  final FirebaseFirestore _db;

  GoalRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('goals');

  Stream<List<Goal>> streamStandaloneGoals(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .where('isHabitInstance', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Goal.fromFirestore).toList());
  }

  Stream<List<Goal>> streamHabitInstances(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .where('isHabitInstance', isEqualTo: true)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Goal.fromFirestore).toList());
  }

  /// All goal-linkable items (used for the task-linking dropdown).
  Stream<List<Goal>> streamAllGoals(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Goal.fromFirestore).toList());
  }

  Future<List<Goal>> fetchHabitInstances(String userId, String habitId) async {
    final snap = await _collection
        .where('userId', isEqualTo: userId)
        .where('habitId', isEqualTo: habitId)
        .orderBy('startDate', descending: true)
        .get();
    return snap.docs.map(Goal.fromFirestore).toList();
  }

  Future<void> addStandaloneGoal({
    required String userId,
    required String title,
    required String description,
    String? categoryId,
    int? targetCount,
  }) {
    return _collection.add({
      'userId': userId,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'isHabitInstance': false,
      'habitId': null,
      'startDate': null,
      'endDate': null,
      'targetCount': targetCount,
      'currentProgress': 0,
      'isCompleted': false,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> addHabitInstance({
    required String userId,
    required String habitId,
    required String title,
    required String description,
    String? categoryId,
    required int targetCount,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _collection.add({
      'userId': userId,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'isHabitInstance': true,
      'habitId': habitId,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'targetCount': targetCount,
      'currentProgress': 0,
      'isCompleted': false,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> updateGoal(Goal goal) {
    return _collection.doc(goal.id).update({
      'title': goal.title,
      'description': goal.description,
      'categoryId': goal.categoryId,
      'targetCount': goal.targetCount,
    });
  }

  Future<void> setCompleted(String goalId, bool isCompleted) {
    return _collection.doc(goalId).update({'isCompleted': isCompleted});
  }

  Future<void> deleteGoal(String goalId) {
    return _collection.doc(goalId).delete();
  }

  /// Adjusts currentProgress by [delta] and auto-completes when the target
  /// is reached (or un-completes when it drops back below target).
  Future<void> adjustProgress(String goalId, int delta) {
    final ref = _collection.doc(goalId);
    return _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final goal = Goal.fromFirestore(snap);
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
