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

/// A concrete, wall-clock block of time a task is planned to run in — e.g.
/// 09:00-10:30 on 2026-07-22. Distinct from [TimeRange] in user_settings.dart
/// (minutes-since-midnight, no date), which describes a recurring
/// time-of-day window like active hours, not a specific moment in time.
class TaskTimeRange {
  final DateTime start;
  final DateTime end;

  const TaskTimeRange({required this.start, required this.end});

  Duration get duration => end.difference(start);

  factory TaskTimeRange.fromFirestore(Map<String, dynamic> map) {
    return TaskTimeRange(
      start: (map['start'] as Timestamp).toDate(),
      end: (map['end'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'start': Timestamp.fromDate(start),
        'end': Timestamp.fromDate(end),
      };

  @override
  bool operator ==(Object other) =>
      other is TaskTimeRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

class Task {
  final String id;
  final String userId;
  final String title;
  final DateTime? dueDate;
  final List<TaskTimeRange> estimatedExecutionTimeRanges;
  final bool isRecurrent;
  final RecurrenceRule? recurrenceRule;
  final List<String> categoryIds;
  final String? linkedGoalId;
  final bool contributesToCount;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final Duration? estimatedDuration;
  final bool isImportant;
  final bool isUrgent;
  final bool constrainedToWorkingHours;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.dueDate,
    this.estimatedExecutionTimeRanges = const [],
    required this.isRecurrent,
    this.recurrenceRule,
    required this.categoryIds,
    this.linkedGoalId,
    this.contributesToCount = false,
    required this.isCompleted,
    this.completedAt,
    required this.createdAt,
    this.estimatedDuration,
    this.isImportant = false,
    this.isUrgent = false,
    this.constrainedToWorkingHours = true,
  });

  factory Task.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc, {required DateTime now}) {
    final data = doc.data()!;
    final estimateMinutes = data['estimatedDurationMinutes'] as int?;
    return Task(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      dueDate: (data['dueDate'] as Timestamp?)?.toDate(),
      estimatedExecutionTimeRanges: (data['estimatedExecutionTimeRanges'] as List<dynamic>?)
              ?.map((r) => TaskTimeRange.fromFirestore(Map<String, dynamic>.from(r as Map)))
              .toList() ??
          const [],
      isRecurrent: data['isRecurrent'] as bool? ?? false,
      recurrenceRule: recurrenceRuleFromString(data['recurrenceRule'] as String?),
      categoryIds: (data['categoryIds'] as List<dynamic>?)?.cast<String>() ?? [],
      linkedGoalId: data['linkedGoalId'] as String?,
      contributesToCount: data['contributesToCount'] as bool? ?? false,
      isCompleted: data['isCompleted'] as bool? ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? now,
      estimatedDuration: estimateMinutes != null ? Duration(minutes: estimateMinutes) : null,
      isImportant: data['isImportant'] as bool? ?? false,
      isUrgent: data['isUrgent'] as bool? ?? false,
      constrainedToWorkingHours: data['constrainedToWorkingHours'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'estimatedExecutionTimeRanges': estimatedExecutionTimeRanges.map((r) => r.toFirestore()).toList(),
      'isRecurrent': isRecurrent,
      'recurrenceRule': recurrenceRule?.name,
      'categoryIds': categoryIds,
      'linkedGoalId': linkedGoalId,
      'contributesToCount': contributesToCount,
      'isCompleted': isCompleted,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'estimatedDurationMinutes': estimatedDuration?.inMinutes,
      'isImportant': isImportant,
      'isUrgent': isUrgent,
      'constrainedToWorkingHours': constrainedToWorkingHours,
    };
  }

  Task copyWith({
    String? title,
    Object? dueDate = _unset,
    Object? estimatedExecutionTimeRanges = _unset,
    bool? isRecurrent,
    RecurrenceRule? recurrenceRule,
    List<String>? categoryIds,
    String? linkedGoalId,
    bool? contributesToCount,
    bool? isCompleted,
    DateTime? completedAt,
    Object? estimatedDuration = _unset,
    bool? isImportant,
    bool? isUrgent,
    bool? constrainedToWorkingHours,
  }) {
    return Task(
      id: id,
      userId: userId,
      title: title ?? this.title,
      dueDate: identical(dueDate, _unset) ? this.dueDate : dueDate as DateTime?,
      estimatedExecutionTimeRanges: identical(estimatedExecutionTimeRanges, _unset)
          ? this.estimatedExecutionTimeRanges
          : estimatedExecutionTimeRanges as List<TaskTimeRange>,
      isRecurrent: isRecurrent ?? this.isRecurrent,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      categoryIds: categoryIds ?? this.categoryIds,
      linkedGoalId: linkedGoalId ?? this.linkedGoalId,
      contributesToCount: contributesToCount ?? this.contributesToCount,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      createdAt: createdAt,
      estimatedDuration: identical(estimatedDuration, _unset) ? this.estimatedDuration : estimatedDuration as Duration?,
      isImportant: isImportant ?? this.isImportant,
      isUrgent: isUrgent ?? this.isUrgent,
      constrainedToWorkingHours: constrainedToWorkingHours ?? this.constrainedToWorkingHours,
    );
  }
}
