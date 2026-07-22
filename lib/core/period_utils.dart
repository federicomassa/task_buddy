import '../models/habit.dart';

class PeriodRange {
  final DateTime start;
  final DateTime end;

  const PeriodRange(this.start, this.end);
}

/// Returns the [start, end) range for the period containing [date].
/// Daily periods run midnight..midnight; weekly periods run Monday..Sunday;
/// monthly periods run calendar months.
PeriodRange currentPeriodRange(HabitPeriod period, DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  switch (period) {
    case HabitPeriod.daily:
      return PeriodRange(day, day.add(const Duration(days: 1)));
    case HabitPeriod.weekly:
      final start = day.subtract(Duration(days: day.weekday - DateTime.monday));
      final end = start.add(const Duration(days: 7));
      return PeriodRange(start, end);
    case HabitPeriod.monthly:
      final start = DateTime(day.year, day.month, 1);
      final end = DateTime(day.year, day.month + 1, 1);
      return PeriodRange(start, end);
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
