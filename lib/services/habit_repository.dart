import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/clock.dart';
import '../models/habit.dart';

abstract class HabitRepository {
  Stream<List<Habit>> streamHabits(String userId);

  Future<String> addHabit({
    required String userId,
    required String title,
    required String description,
    String? categoryId,
    required int targetCount,
    required HabitPeriod period,
    int? dueTimeMinutes,
  });

  Future<void> updateHabit(Habit habit);

  Future<void> deleteHabit(String habitId);
}

class FirestoreHabitRepository implements HabitRepository {
  final FirebaseFirestore _db;
  final Clock _clock;

  FirestoreHabitRepository(this._db, this._clock);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('habits');

  @override
  Stream<List<Habit>> streamHabits(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Habit.fromFirestore(d, now: _clock.now())).toList());
  }

  @override
  Future<String> addHabit({
    required String userId,
    required String title,
    required String description,
    String? categoryId,
    required int targetCount,
    required HabitPeriod period,
    int? dueTimeMinutes,
  }) async {
    final doc = await _collection.add({
      'userId': userId,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'targetCount': targetCount,
      'period': period.name,
      'dueTimeMinutes': dueTimeMinutes,
      'createdAt': Timestamp.now(),
    });
    return doc.id;
  }

  @override
  Future<void> updateHabit(Habit habit) {
    return _collection.doc(habit.id).update({
      'title': habit.title,
      'description': habit.description,
      'categoryId': habit.categoryId,
      'targetCount': habit.targetCount,
      'period': habit.period.name,
      'dueTimeMinutes': habit.dueTimeMinutes,
    });
  }

  @override
  Future<void> deleteHabit(String habitId) {
    return _collection.doc(habitId).delete();
  }
}
