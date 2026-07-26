import 'active_hours.dart';
import '../models/user_settings.dart';

/// What to do with a task dropped somewhere that violates active hours (see
/// [dropNeedsConfirmation]) — mirrors the two non-cancel choices offered by
/// the "Outside active hours" dialog.
enum DropChoice { scheduleAnyway, respectBreaks }

/// Minutes-based placement to apply to a dropped task: the segments to
/// materialize into [TaskTimeRange]s (via [taskTimeRangesForDay]), and the
/// `constrainedToWorkingHours` flag to store alongside them.
class DropPlacement {
  final List<TimeRange> segments;
  final bool constrainedToWorkingHours;

  const DropPlacement({required this.segments, required this.constrainedToWorkingHours});
}

/// Whether dropping a [durationMinutes]-long task at [droppedMinutes] should
/// prompt the user before placing it, rather than placing it directly via
/// [directDropPlacement]. Re-evaluated against every drop, independent of the
/// task's current `constrainedToWorkingHours` — that flag only describes how
/// the task's *existing* placement renders, not a standing "never ask this
/// task again" preference.
bool dropNeedsConfirmation({
  required int droppedMinutes,
  required int durationMinutes,
  required List<TimeRange> activeHours,
}) {
  return violatesActiveHours(droppedMinutes, durationMinutes, activeHours);
}

/// The placement for a drop that landed entirely inside a single
/// active-hours range (i.e. [dropNeedsConfirmation] returned false) — always
/// exactly one segment, matching the dropped time and duration verbatim, and
/// leaving `constrainedToWorkingHours` unchanged from whatever the task had.
List<TimeRange> directDropPlacement({required int droppedMinutes, required int durationMinutes}) {
  return [TimeRange(startMinutes: droppedMinutes, endMinutes: droppedMinutes + durationMinutes)];
}

/// The placement to apply once the user has picked how to handle a drop that
/// [dropNeedsConfirmation] flagged.
DropPlacement resolveConfirmedDrop({
  required DropChoice choice,
  required int droppedMinutes,
  required int durationMinutes,
  required List<TimeRange> activeHours,
}) {
  switch (choice) {
    case DropChoice.scheduleAnyway:
      // A single literal block straight through the break instead of
      // splitting. Doesn't suppress future prompts for this task — see
      // dropNeedsConfirmation.
      return DropPlacement(
        segments: [TimeRange(startMinutes: droppedMinutes, endMinutes: droppedMinutes + durationMinutes)],
        constrainedToWorkingHours: false,
      );
    case DropChoice.respectBreaks:
      // If the drop landed inside a break (or before/after the work day),
      // there's no range for the splitting logic to anchor to, so push the
      // start forward to when work resumes; otherwise keep the dropped time
      // as-is and let it split across whatever break it runs into.
      final resolved = resolveActiveStart(droppedMinutes, activeHours);
      final segments = realSegmentsForPlacement(
        startMinutes: resolved,
        durationMinutes: durationMinutes,
        activeHours: activeHours,
        constrainedToWorkingHours: true,
      );
      return DropPlacement(segments: segments, constrainedToWorkingHours: true);
  }
}
