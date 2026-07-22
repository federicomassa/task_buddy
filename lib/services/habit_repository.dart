import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/habit.dart';

class HabitRepository {
  final FirebaseFirestore _db;

  HabitRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('habits');

  Stream<List<Habit>> streamHabits(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(Habit.fromFirestore).toList());
  }

  Future<String> addHabit({
    required String userId,
    required String title,
    required String description,
    String? categoryId,
    required int targetCount,
    required HabitPeriod period,
  }) async {
    final doc = await _collection.add({
      'userId': userId,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'targetCount': targetCount,
      'period': period.name,
      'createdAt': Timestamp.now(),
    });
    return doc.id;
  }

  Future<void> updateHabit(Habit habit) {
    return _collection.doc(habit.id).update({
      'title': habit.title,
      'description': habit.description,
      'categoryId': habit.categoryId,
      'targetCount': habit.targetCount,
      'period': habit.period.name,
    });
  }

  Future<void> deleteHabit(String habitId) {
    return _collection.doc(habitId).delete();
  }
}
