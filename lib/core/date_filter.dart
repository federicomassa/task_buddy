import '../models/goal.dart';
import 'date_utils.dart';

enum DatePreset { today, tomorrow, thisWeek, custom }

/// The time dimension of a filter: an optional preset bucket (or a custom
/// range), plus an independent "include overdue" toggle. Overdue is additive
/// (OR'd) with the preset rather than exclusive, so switching to e.g. "Today"
/// doesn't hide items that are already overdue unless the user explicitly
/// turns the toggle off.
class DateRangeFilter {
  final DatePreset? preset;
  final DateTime? customStart;
  final DateTime? customEnd;
  final bool showOverdue;

  const DateRangeFilter({
    this.preset,
    this.customStart,
    this.customEnd,
    this.showOverdue = true,
  });

  factory DateRangeFilter.defaults() => const DateRangeFilter();

  DateRangeFilter copyWith({
    Object? preset = _unset,
    Object? customStart = _unset,
    Object? customEnd = _unset,
    bool? showOverdue,
  }) {
    return DateRangeFilter(
      preset: identical(preset, _unset) ? this.preset : preset as DatePreset?,
      customStart: identical(customStart, _unset) ? this.customStart : customStart as DateTime?,
      customEnd: identical(customEnd, _unset) ? this.customEnd : customEnd as DateTime?,
      showOverdue: showOverdue ?? this.showOverdue,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DateRangeFilter &&
        other.preset == preset &&
        other.customStart == customStart &&
        other.customEnd == customEnd &&
        other.showOverdue == showOverdue;
  }

  @override
  int get hashCode => Object.hash(preset, customStart, customEnd, showOverdue);
}

const _unset = Object();

/// Whether [dueDate] falls into the bucket described by [preset]. A null
/// preset means "no constraint" (always matches). A null [dueDate] never
/// matches a concrete preset.
bool matchesDatePreset(
  DateTime? dueDate,
  DatePreset? preset, {
  required DateTime today,
  DateTime? customStart,
  DateTime? customEnd,
}) {
  if (preset == null) return true;
  if (dueDate == null) return false;
  final due = dateOnly(dueDate);
  switch (preset) {
    case DatePreset.today:
      return due == today;
    case DatePreset.tomorrow:
      return due == today.add(const Duration(days: 1));
    case DatePreset.thisWeek:
      final weekEnd = today.add(const Duration(days: 6));
      return !due.isBefore(today) && !due.isAfter(weekEnd);
    case DatePreset.custom:
      if (customStart != null && due.isBefore(dateOnly(customStart))) return false;
      if (customEnd != null && due.isAfter(dateOnly(customEnd))) return false;
      return true;
  }
}

bool isGoalOverdue(Goal goal, {required DateTime today}) {
  if (goal.isCompleted) return false;
  final due = goal.dueDate;
  if (due == null) return false;
  return dateOnly(due).isBefore(today);
}

/// Single entry point used by [filterTasks]/[filterGoals]: an item passes
/// the time filter if its due date matches the selected preset, or if it's
/// overdue and the overdue toggle is on.
bool matchesTimeFilter({
  required DateTime? dueDate,
  required bool isOverdue,
  required DateRangeFilter filter,
  required DateTime today,
}) {
  if (filter.showOverdue && isOverdue) return true;
  return matchesDatePreset(
    dueDate,
    filter.preset,
    today: today,
    customStart: filter.customStart,
    customEnd: filter.customEnd,
  );
}
