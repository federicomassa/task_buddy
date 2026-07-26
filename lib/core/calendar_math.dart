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

/// The wrapping-box height and upward shift needed to fully contain a "tiny"
/// scheduled block's floating label, when the label (given [labelAllocation]
/// of vertical room) is taller than the block's own [barHeight]. The
/// envelope is grown symmetrically around the bar's vertical midpoint and
/// [topOffset] is how far above the bar's own top the envelope (and
/// therefore its tap/drag hit-test area) needs to start, so the label never
/// pokes out past its wrapping box — a widget's hit testing rejects taps
/// outside its own laid-out size, before it ever asks its children. Zero
/// overflow (and an unchanged envelope) when the bar is already tall enough
/// to hold the label on its own.
({double envelopeHeight, double topOffset}) tinyBlockEnvelope({
  required double barHeight,
  required double labelAllocation,
}) {
  final overflow = ((labelAllocation - barHeight) / 2).clamp(0.0, double.infinity);
  return (envelopeHeight: barHeight + overflow * 2, topOffset: overflow);
}
