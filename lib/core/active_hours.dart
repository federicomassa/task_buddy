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

/// Real-time segments for a scheduled task, splitting it across any break
/// it spans — unless [Task.constrainedToWorkingHours] is false, in which
/// case it always renders as a single literal segment from its scheduled
/// time, breaks or not (the user explicitly chose to place it there as-is).
/// Also falls back to a single, unsplit segment if the task's start time
/// doesn't fall inside any active-hours range at all (e.g. an ordinary
/// evening task) — splitting only makes sense relative to a window the task
/// actually started inside. Returns an empty list if the task isn't
/// scheduled or has no estimate.
List<TimeRange> taskRealSegments(Task task, List<TimeRange> activeHours) {
  final scheduled = task.scheduledDate;
  final estimate = task.timeEstimate;
  if (scheduled == null || estimate == null) return const [];

  final startMinutes = scheduled.hour * 60 + scheduled.minute;
  final literal = [TimeRange(startMinutes: startMinutes, endMinutes: startMinutes + estimate.inMinutes)];
  if (!task.constrainedToWorkingHours) return literal;

  final virtualStart = virtualMinutesFromReal(startMinutes, activeHours);
  if (virtualStart == null) return literal;
  return realSegmentsFromVirtualRange(virtualStart, virtualStart + estimate.inMinutes, activeHours);
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
/// directly on top of a break — [taskRealSegments] already handles a task
/// that starts inside a range but runs past it into a break, but there's no
/// range to anchor the splitting logic to if the drop itself lands outside
/// every range.
int resolveActiveStart(int startMinutes, List<TimeRange> activeHours) {
  final sorted = _sorted(activeHours);
  for (final r in sorted) {
    if (startMinutes < r.startMinutes) return r.startMinutes;
    if (startMinutes < r.endMinutes) return startMinutes;
  }
  return startMinutes;
}
