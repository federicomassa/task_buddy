import '../models/habit.dart';

class PeriodRange {
  final DateTime start;
  final DateTime end;

  const PeriodRange(this.start, this.end);
}

/// Returns the [start, end) range for the period containing [date].
/// Weekly periods run Monday..Sunday; monthly periods run calendar months.
PeriodRange currentPeriodRange(HabitPeriod period, DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  if (period == HabitPeriod.weekly) {
    final start = day.subtract(Duration(days: day.weekday - DateTime.monday));
    final end = start.add(const Duration(days: 7));
    return PeriodRange(start, end);
  }
  final start = DateTime(day.year, day.month, 1);
  final end = DateTime(day.year, day.month + 1, 1);
  return PeriodRange(start, end);
}
