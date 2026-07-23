/// Minutes from midnight, snapped to the nearest 15-minute increment, for
/// a local Y offset within a calendar of [dayHeightPx] at [pxPerHour] scale.
int snappedMinutesForLocalY(
  double localY, {
  required double dayHeightPx,
  required double pxPerHour,
}) {
  final clampedY = localY.clamp(0.0, dayHeightPx - 1);
  final totalMinutes = clampedY / pxPerHour * 60;
  final snapped = (totalMinutes / 15).round() * 15;
  return snapped.clamp(0, 24 * 60 - 15);
}
