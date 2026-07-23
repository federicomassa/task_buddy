class DurationParts {
  final int days;
  final int hours;
  final int minutes;

  const DurationParts({required this.days, required this.hours, required this.minutes});

  factory DurationParts.fromDuration(Duration d) {
    final totalMinutes = d.inMinutes;
    return DurationParts(
      days: totalMinutes ~/ (24 * 60),
      hours: (totalMinutes % (24 * 60)) ~/ 60,
      minutes: totalMinutes % 60,
    );
  }

  /// Null when all parts are zero, matching the "no estimate" semantics of
  /// the days/hours/minutes fields it's built from.
  Duration? toDuration() {
    if (days == 0 && hours == 0 && minutes == 0) return null;
    return Duration(days: days, hours: hours, minutes: minutes);
  }
}
