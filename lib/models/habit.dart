import 'package:cloud_firestore/cloud_firestore.dart';

enum HabitPeriod { weekly, monthly }

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
  final DateTime createdAt;

  Habit({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.categoryId,
    required this.targetCount,
    required this.period,
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
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
