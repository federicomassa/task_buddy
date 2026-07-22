import 'package:cloud_firestore/cloud_firestore.dart';

class Goal {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String? categoryId;
  final bool isHabitInstance;
  final String? habitId;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? targetCount;
  final int currentProgress;
  final bool isCompleted;
  final DateTime createdAt;

  Goal({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    this.categoryId,
    required this.isHabitInstance,
    this.habitId,
    this.startDate,
    this.endDate,
    this.targetCount,
    required this.currentProgress,
    required this.isCompleted,
    required this.createdAt,
  });

  factory Goal.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Goal(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      description: data['description'] as String? ?? '',
      categoryId: data['categoryId'] as String?,
      isHabitInstance: data['isHabitInstance'] as bool? ?? false,
      habitId: data['habitId'] as String?,
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      targetCount: (data['targetCount'] as num?)?.toInt(),
      currentProgress: (data['currentProgress'] as num?)?.toInt() ?? 0,
      isCompleted: data['isCompleted'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'isHabitInstance': isHabitInstance,
      'habitId': habitId,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'targetCount': targetCount,
      'currentProgress': currentProgress,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Goal copyWith({
    String? title,
    String? description,
    String? categoryId,
    int? targetCount,
    int? currentProgress,
    bool? isCompleted,
  }) {
    return Goal(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      isHabitInstance: isHabitInstance,
      habitId: habitId,
      startDate: startDate,
      endDate: endDate,
      targetCount: targetCount ?? this.targetCount,
      currentProgress: currentProgress ?? this.currentProgress,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
    );
  }
}
