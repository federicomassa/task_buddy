import 'package:cloud_firestore/cloud_firestore.dart';

enum HabitPeriod { daily, weekly, monthly }

HabitPeriod habitPeriodFromString(String value) {
  return HabitPeriod.values.firstWhere(
    (p) => p.name == value,
    orElse: () => HabitPeriod.weekly,
  );
}

class Habit {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String? categoryId;
  final int targetCount;
  final HabitPeriod period;

  /// Time of day (minutes since midnight, 0-1439) each cycle instance is due
  /// by. Optional — when unset, an instance is only due at its period end.
  final int? dueTimeMinutes;
  final DateTime createdAt;

  Habit({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.categoryId,
    required this.targetCount,
    required this.period,
    this.dueTimeMinutes,
    required this.createdAt,
  });

  factory Habit.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Habit(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      description: data['description'] as String? ?? '',
      categoryId: data['categoryId'] as String?,
      targetCount: (data['targetCount'] as num?)?.toInt() ?? 1,
      period: habitPeriodFromString(data['period'] as String? ?? 'weekly'),
      dueTimeMinutes: (data['dueTimeMinutes'] as num?)?.toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'targetCount': targetCount,
      'period': period.name,
      'dueTimeMinutes': dueTimeMinutes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
