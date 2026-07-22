import 'package:cloud_firestore/cloud_firestore.dart';

enum RecurrenceRule { daily, weekly, monthly }

RecurrenceRule? recurrenceRuleFromString(String? value) {
  if (value == null) return null;
  return RecurrenceRule.values.firstWhere(
    (r) => r.name == value,
    orElse: () => RecurrenceRule.daily,
  );
}

const _unset = Object();

class Task {
  final String id;
  final String userId;
  final String title;
  final DateTime? dueDate;
  final bool isRecurrent;
  final RecurrenceRule? recurrenceRule;
  final List<String> categoryIds;
  final String? linkedGoalId;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final Duration? timeEstimate;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.dueDate,
    required this.isRecurrent,
    this.recurrenceRule,
    required this.categoryIds,
    this.linkedGoalId,
    required this.isCompleted,
    this.completedAt,
    required this.createdAt,
    this.timeEstimate,
  });

  factory Task.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final estimateMinutes = data['timeEstimateMinutes'] as int?;
    return Task(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      isRecurrent: data['isRecurrent'] as bool? ?? false,
      recurrenceRule: recurrenceRuleFromString(data['recurrenceRule'] as String?),
      categoryIds: (data['categoryIds'] as List<dynamic>?)?.cast<String>() ?? [],
      linkedGoalId: data['linkedGoalId'] as String?,
      isCompleted: data['isCompleted'] as bool? ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      timeEstimate: estimateMinutes != null ? Duration(minutes: estimateMinutes) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'isRecurrent': isRecurrent,
      'recurrenceRule': recurrenceRule?.name,
      'categoryIds': categoryIds,
      'linkedGoalId': linkedGoalId,
      'isCompleted': isCompleted,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'timeEstimateMinutes': timeEstimate?.inMinutes,
    };
  }

  Task copyWith({
    String? title,
    Object? dueDate = _unset,
    bool? isRecurrent,
    RecurrenceRule? recurrenceRule,
    List<String>? categoryIds,
    String? linkedGoalId,
    bool? isCompleted,
    DateTime? completedAt,
    Object? timeEstimate = _unset,
  }) {
    return Task(
      id: id,
      userId: userId,
      title: title ?? this.title,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
      isRecurrent: isRecurrent ?? this.isRecurrent,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      categoryIds: categoryIds ?? this.categoryIds,
      linkedGoalId: linkedGoalId ?? this.linkedGoalId,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      timeEstimate: identical(timeEstimate, _unset) ? this.timeEstimate : timeEstimate as Duration?,
    );
  }
}
