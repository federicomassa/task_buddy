import '../models/task.dart';
import '../models/user_settings.dart';

List<TimeRange> _sorted(List<TimeRange> ranges) {
  final copy = [...ranges]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
  return copy;
}

int _clampInt(int value, int lower, int upper) {
  if (value < lower) return lower;
  if (value > upper) return upper;
  return value;
}

/// Sum of every active-hours range's length — the length of the continuous
/// "virtual" working timeline (see [realMinutesFromVirtual]).
int totalActiveMinutes(List<TimeRange> activeHours) {
  return activeHours.fold(0, (sum, r) => sum + (r.endMinutes - r.startMinutes));
}

/// Maps a point on the continuous virtual working timeline — 0 at the start
/// of the first active-hours range, ticking upward through each range in
/// chronological order and skipping every break entirely — to real
/// wall-clock minutes since midnight. Returns null once [virtualMinutes]
/// reaches or exceeds the total active time ([totalActiveMinutes]).
int? realMinutesFromVirtual(int virtualMinutes, List<TimeRange> activeHours) {
  var remaining = virtualMinutes;
  for (final r in _sorted(activeHours)) {
    final length = r.endMinutes - r.startMinutes;
    if (remaining < length) return r.startMinutes + remaining;
    remaining -= length;
  }
  return null;
}

/// The inverse of [realMinutesFromVirtual]: maps a real wall-clock minute
/// to its position on the virtual timeline, or null if it falls outside
/// every active-hours range (e.g. during a break, or before/after the work
/// day).
int? virtualMinutesFromReal(int realMinutes, List<TimeRange> activeHours) {
  var cursor = 0;
  for (final r in _sorted(activeHours)) {
    if (realMinutes >= r.startMinutes && realMinutes < r.endMinutes) {
      return cursor + (realMinutes - r.startMinutes);
    }
    cursor += r.endMinutes - r.startMinutes;
  }
  return null;
}

/// Splits a virtual `[virtualStart, virtualEnd)` interval into one
/// real-time [TimeRange] per active-hours range it touches. A block that
/// starts before a break and runs past it comes back as two (or more)
/// segments, one per side of the break — this is what lets a single task
/// render as "before lunch" and "after lunch" pieces on the calendar.
List<TimeRange> realSegmentsFromVirtualRange(
  int virtualStart,
  int virtualEnd,
  List<TimeRange> activeHours,
) {
  final segments = <TimeRange>[];
  var cursor = 0;
  for (final r in _sorted(activeHours)) {
    final length = r.endMinutes - r.startMinutes;
    final rangeStart = cursor;
    final rangeEnd = cursor + length;
    final segStart = _clampInt(virtualStart, rangeStart, rangeEnd);
    final segEnd = _clampInt(virtualEnd, rangeStart, rangeEnd);
    if (segEnd > segStart) {
      segments.add(TimeRange(
        startMinutes: r.startMinutes + (segStart - rangeStart),
        endMinutes: r.startMinutes + (segEnd - rangeStart),
      ));
    }
    cursor = rangeEnd;
  }
  return segments;
}

/// Real-time segments for placing a [durationMinutes]-long block starting at
/// [startMinutes], splitting it across any break it spans — unless
/// [constrainedToWorkingHours] is false, in which case it always renders as
/// a single literal segment from [startMinutes], breaks or not (the user
/// explicitly chose to place it there as-is). Also falls back to a single,
/// unsplit segment if [startMinutes] doesn't fall inside any active-hours
/// range at all (e.g. an ordinary evening task) — splitting only makes sense
/// relative to a window the placement actually started inside.
List<TimeRange> realSegmentsForPlacement({
  required int startMinutes,
  required int durationMinutes,
  required List<TimeRange> activeHours,
  required bool constrainedToWorkingHours,
}) {
  final literal = [TimeRange(startMinutes: startMinutes, endMinutes: startMinutes + durationMinutes)];
  if (!constrainedToWorkingHours) return literal;

  final virtualStart = virtualMinutesFromReal(startMinutes, activeHours);
  if (virtualStart == null) return literal;
  return realSegmentsFromVirtualRange(virtualStart, virtualStart + durationMinutes, activeHours);
}

/// Whether a task with [durationMinutes] starting at [startMinutes]
/// (minutes since midnight) would touch any break at all — i.e. it doesn't
/// fit entirely within a single active-hours range. This covers starting
/// inside a break, starting inside a range but running past its end into
/// the next break, and needing more time than remains in the day.
bool violatesActiveHours(int startMinutes, int durationMinutes, List<TimeRange> activeHours) {
  final endMinutes = startMinutes + durationMinutes;
  for (final r in activeHours) {
    if (startMinutes >= r.startMinutes && endMinutes <= r.endMinutes) return false;
  }
  return true;
}

/// The nearest real-time minute at or after [startMinutes] that falls
/// inside an active-hours range: [startMinutes] itself if it's already in
/// one, otherwise the start of the next range. If no range remains later
/// that day, returns [startMinutes] unchanged (there's nothing to snap to).
/// Used to resolve "schedule, but respect breaks" when a task is dropped
/// directly on top of a break — [realSegmentsForPlacement] already handles a
/// task that starts inside a range but runs past it into a break, but
/// there's no range to anchor the splitting logic to if the drop itself lands outside
/// every range.
int resolveActiveStart(int startMinutes, List<TimeRange> activeHours) {
  final sorted = _sorted(activeHours);
  for (final r in sorted) {
    if (startMinutes < r.startMinutes) return r.startMinutes;
    if (startMinutes < r.endMinutes) return startMinutes;
  }
  return startMinutes;
}

/// Materializes minutes-since-midnight [segments] into concrete wall-clock
/// [TaskTimeRange]s on [day]. Shared by every call site that turns a
/// virtual/real minutes-based placement (from [realSegmentsFromVirtualRange]
/// or [realSegmentsForPlacement]) into the ranges actually stored on a task.
List<TaskTimeRange> taskTimeRangesForDay(DateTime day, List<TimeRange> segments) {
  return segments
      .map((s) => TaskTimeRange(
            start: DateTime(day.year, day.month, day.day, s.startMinutes ~/ 60, s.startMinutes % 60),
            end: DateTime(day.year, day.month, day.day, s.endMinutes ~/ 60, s.endMinutes % 60),
          ))
      .toList();
}
