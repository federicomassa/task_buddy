import 'package:cloud_firestore/cloud_firestore.dart';

enum RecurrenceUnit { days, weeks, months }

RecurrenceUnit recurrenceUnitFromString(String value) {
  return RecurrenceUnit.values.firstWhere(
    (u) => u.name == value,
    orElse: () => RecurrenceUnit.days,
  );
}

class Habit {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String? categoryId;

  /// How many times ("x") the habit must be completed per cycle.
  final int targetCount;

  /// Cycle length ("y"): a new cycle starts every [recurrenceInterval]
  /// [recurrenceUnit], e.g. targetCount=3, recurrenceInterval=2,
  /// recurrenceUnit=weeks means "3 times every 2 weeks".
  final int recurrenceInterval;
  final RecurrenceUnit recurrenceUnit;

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
    this.recurrenceInterval = 1,
    this.recurrenceUnit = RecurrenceUnit.days,
    this.dueTimeMinutes,
    required this.createdAt,
  });

  factory Habit.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, {required DateTime now}) {
    final data = doc.data()!;
    return Habit(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      description: data['description'] as String? ?? '',
      categoryId: data['categoryId'] as String?,
      targetCount: (data['targetCount'] as num?)?.toInt() ?? 1,
      recurrenceInterval: (data['recurrenceInterval'] as num?)?.toInt() ?? 1,
      recurrenceUnit: recurrenceUnitFromString(data['recurrenceUnit'] as String? ?? 'days'),
      dueTimeMinutes: (data['dueTimeMinutes'] as num?)?.toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? now,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'targetCount': targetCount,
      'recurrenceInterval': recurrenceInterval,
      'recurrenceUnit': recurrenceUnit.name,
      'dueTimeMinutes': dueTimeMinutes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
