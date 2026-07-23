import '../models/habit.dart';

class PeriodRange {
  final DateTime start;
  final DateTime end;

  const PeriodRange(this.start, this.end);
}

/// Returns the [start, end) range for a cycle of [interval] [unit]s
/// starting at [date] (floored to midnight). E.g. interval=2, unit=weeks
/// yields a 14-day range starting today.
PeriodRange currentPeriodRange(int interval, RecurrenceUnit unit, DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  switch (unit) {
    case RecurrenceUnit.days:
      return PeriodRange(day, day.add(Duration(days: interval)));
    case RecurrenceUnit.weeks:
      return PeriodRange(day, day.add(Duration(days: interval * 7)));
    case RecurrenceUnit.months:
      return PeriodRange(day, DateTime(day.year, day.month + interval, day.day));
  }
}

/// Returns the next moment on or after [from] whose time of day matches
/// [minutesSinceMidnight] (0-1439) — today if that time hasn't passed yet,
/// otherwise tomorrow.
DateTime nextOccurrenceOfTimeOfDay(int minutesSinceMidnight, DateTime from) {
  final candidate = DateTime(
    from.year,
    from.month,
    from.day,
    minutesSinceMidnight ~/ 60,
    minutesSinceMidnight % 60,
  );
  return candidate.isAfter(from) ? candidate : candidate.add(const Duration(days: 1));
}
