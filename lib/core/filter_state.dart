import 'package:flutter/material.dart';

import 'date_filter.dart';

enum TaskFilter { all, active, completed, backlog }

extension TaskFilterLabel on TaskFilter {
  String get label {
    switch (this) {
      case TaskFilter.all:
        return 'All';
      case TaskFilter.active:
        return 'Active';
      case TaskFilter.completed:
        return 'Done';
      case TaskFilter.backlog:
        return 'Backlog';
    }
  }

  IconData get icon {
    switch (this) {
      case TaskFilter.all:
        return Icons.list_alt_outlined;
      case TaskFilter.active:
        return Icons.flag_outlined;
      case TaskFilter.completed:
        return Icons.check_circle_outline;
      case TaskFilter.backlog:
        return Icons.inbox_outlined;
    }
  }
}

enum GoalFilter { all, active, completed, backlog }

extension GoalFilterLabel on GoalFilter {
  String get label {
    switch (this) {
      case GoalFilter.all:
        return 'All';
      case GoalFilter.active:
        return 'Active';
      case GoalFilter.completed:
        return 'Done';
      case GoalFilter.backlog:
        return 'Backlog';
    }
  }

  IconData get icon {
    switch (this) {
      case GoalFilter.all:
        return Icons.list_alt_outlined;
      case GoalFilter.active:
        return Icons.flag_outlined;
      case GoalFilter.completed:
        return Icons.check_circle_outline;
      case GoalFilter.backlog:
        return Icons.inbox_outlined;
    }
  }
}

enum HabitFilter { all, active, completed }

extension HabitFilterLabel on HabitFilter {
  String get label {
    switch (this) {
      case HabitFilter.all:
        return 'All';
      case HabitFilter.active:
        return 'Active';
      case HabitFilter.completed:
        return 'Done';
    }
  }

  IconData get icon {
    switch (this) {
      case HabitFilter.all:
        return Icons.list_alt_outlined;
      case HabitFilter.active:
        return Icons.flag_outlined;
      case HabitFilter.completed:
        return Icons.check_circle_outline;
    }
  }
}

class TaskFilterState {
  final TaskFilter status;
  final String? categoryId;
  final DateRangeFilter dateFilter;

  const TaskFilterState({
    required this.status,
    required this.categoryId,
    required this.dateFilter,
  });

  factory TaskFilterState.defaults() => TaskFilterState(
        status: TaskFilter.active,
        categoryId: null,
        dateFilter: DateRangeFilter.defaults(),
      );

  bool get isDefault => this == TaskFilterState.defaults();

  TaskFilterState copyWith({
    TaskFilter? status,
    Object? categoryId = _unset,
    DateRangeFilter? dateFilter,
  }) {
    return TaskFilterState(
      status: status ?? this.status,
      categoryId: identical(categoryId, _unset) ? this.categoryId : categoryId as String?,
      dateFilter: dateFilter ?? this.dateFilter,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TaskFilterState &&
        other.status == status &&
        other.categoryId == categoryId &&
        other.dateFilter == dateFilter;
  }

  @override
  int get hashCode => Object.hash(status, categoryId, dateFilter);
}

class GoalFilterState {
  final GoalFilter status;
  final String? categoryId;
  final DateRangeFilter dateFilter;

  const GoalFilterState({
    required this.status,
    required this.categoryId,
    required this.dateFilter,
  });

  factory GoalFilterState.defaults() => GoalFilterState(
        status: GoalFilter.active,
        categoryId: null,
        dateFilter: DateRangeFilter.defaults(),
      );

  bool get isDefault => this == GoalFilterState.defaults();

  GoalFilterState copyWith({
    GoalFilter? status,
    Object? categoryId = _unset,
    DateRangeFilter? dateFilter,
  }) {
    return GoalFilterState(
      status: status ?? this.status,
      categoryId: identical(categoryId, _unset) ? this.categoryId : categoryId as String?,
      dateFilter: dateFilter ?? this.dateFilter,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is GoalFilterState &&
        other.status == status &&
        other.categoryId == categoryId &&
        other.dateFilter == dateFilter;
  }

  @override
  int get hashCode => Object.hash(status, categoryId, dateFilter);
}

class HabitFilterState {
  final HabitFilter status;
  final String? categoryId;
  final DateRangeFilter dateFilter;

  const HabitFilterState({
    required this.status,
    required this.categoryId,
    required this.dateFilter,
  });

  factory HabitFilterState.defaults() => HabitFilterState(
        status: HabitFilter.all,
        categoryId: null,
        dateFilter: DateRangeFilter.defaults(),
      );

  bool get isDefault => this == HabitFilterState.defaults();

  HabitFilterState copyWith({
    HabitFilter? status,
    Object? categoryId = _unset,
    DateRangeFilter? dateFilter,
  }) {
    return HabitFilterState(
      status: status ?? this.status,
      categoryId: identical(categoryId, _unset) ? this.categoryId : categoryId as String?,
      dateFilter: dateFilter ?? this.dateFilter,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is HabitFilterState &&
        other.status == status &&
        other.categoryId == categoryId &&
        other.dateFilter == dateFilter;
  }

  @override
  int get hashCode => Object.hash(status, categoryId, dateFilter);
}

const _unset = Object();
