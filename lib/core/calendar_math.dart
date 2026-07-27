import '../models/user_settings.dart';

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

/// How close (in minutes) a grid-snapped drop position must be to another
/// task's end time to magnetically snap to it instead — so a dragged task's
/// start lines up flush with the end of an adjacent task rather than landing
/// a grid tick or two off.
const int neighborSnapThresholdMinutes = 20;

/// Snaps [minutes] to the closest value in [neighborEndMinutes] that lies
/// within [neighborSnapThresholdMinutes] of it, if any — otherwise returns
/// [minutes] unchanged. On a distance tie, the earliest-listed neighbor end
/// wins.
int snapToNeighborEnd(int minutes, List<int> neighborEndMinutes) {
  int? closest;
  var closestDistance = neighborSnapThresholdMinutes + 1;
  for (final end in neighborEndMinutes) {
    final distance = (end - minutes).abs();
    if (distance <= neighborSnapThresholdMinutes && distance < closestDistance) {
      closest = end;
      closestDistance = distance;
    }
  }
  return closest ?? minutes;
}

/// Below this real duration, a scheduled block is too short to hold text
/// inside its own bar, and instead gets a floating label chip (see
/// [tinyBlockEnvelope]).
const double tinyThresholdMinutes = 15;

/// Vertical room a tiny block's floating title chip is given to lay out in,
/// regardless of how short the bar itself is (see [tinyBlockEnvelope]). Sized
/// for the chip's actual font size (10) plus its vertical padding (2+2), with
/// a little slack — keep in sync with the chip's real styling in
/// `calendar_pane.dart` if that changes.
const double tinyChipLabelAllocation = 20.0;

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

/// Pixel top/height for a segment's bar (clamped to fit within the day), and
/// whether it's short enough to need the floating-chip tiny-block treatment.
/// Pulled out of the block widget itself so overlap/stagger layout (which
/// needs this same geometry for every segment before any block is built)
/// isn't stuck re-deriving it.
class SegmentGeometry {
  final double top;
  final double height;
  final bool isTiny;

  const SegmentGeometry({required this.top, required this.height, required this.isTiny});
}

SegmentGeometry segmentGeometry({
  required TimeRange segment,
  required double dayHeightPx,
  required double pxPerHour,
}) {
  final top = segment.startMinutes / 60 * pxPerHour;
  final rawHeight = (segment.endMinutes - segment.startMinutes) / 60 * pxPerHour;
  final height =
      rawHeight < 1.0 ? 1.0 : (rawHeight > dayHeightPx - top ? dayHeightPx - top : rawHeight);
  final isTiny = segment.endMinutes - segment.startMinutes < tinyThresholdMinutes;
  return SegmentGeometry(top: top, height: height, isTiny: isTiny);
}

/// One time interval to lay out in a horizontal overlap grid, carrying an
/// opaque [id] the caller uses to map the result back to its own block.
class LayoutInterval {
  final Object id;
  final int startMinutes;
  final int endMinutes;

  const LayoutInterval({required this.id, required this.startMinutes, required this.endMinutes});
}

/// An interval's assigned column, and the shared column count for the whole
/// connected overlap cluster it belongs to (see [assignColumns]).
class ColumnAssignment {
  final Object id;
  final int columnIndex;
  final int columnCount;

  const ColumnAssignment({required this.id, required this.columnIndex, required this.columnCount});
}

/// Google-Calendar-style column layout for a set of possibly-overlapping
/// time intervals: classic greedy interval-graph coloring, one connected
/// cluster at a time.
///
/// Intervals are sorted by start (ties broken by end, then input order, so
/// the result is deterministic across repeated calls with the same input).
/// Scanning left to right, we track the "active" set of intervals that have
/// started but not yet ended; each interval takes the smallest column index
/// not already used by a still-active interval, then joins the active set.
/// Whenever the active set empties out, the current cluster "closes": every
/// interval seen since it opened shares one columnCount, equal to the max
/// columnIndex+1 reached anywhere in that cluster — this is each cluster's
/// peak concurrent overlap, not its member count. For example A(0-60),
/// B(30-90), C(60-120): A/B overlap and B/C overlap, but A and C never do,
/// so peak concurrency is only 2 (not 3) and all three get columnCount 2,
/// matching real Google Calendar behavior for this kind of domino chain.
///
/// Overlap is strictly time-overlap (`start < otherEnd && otherStart < end`);
/// back-to-back intervals (one's end equals another's start) do NOT count as
/// overlapping, free their column immediately, and never share a cluster.
List<ColumnAssignment> assignColumns(List<LayoutInterval> intervals) {
  if (intervals.isEmpty) return [];

  final sorted = [...intervals]..sort((a, b) {
      final byStart = a.startMinutes.compareTo(b.startMinutes);
      if (byStart != 0) return byStart;
      return a.endMinutes.compareTo(b.endMinutes);
    });

  final results = <ColumnAssignment>[];
  final activeEndByColumn = <int, int>{};
  var clusterMembers = <(Object, int)>[];
  var clusterMaxColumn = 0;

  void closeCluster() {
    final columnCount = clusterMaxColumn + 1;
    for (final (id, columnIndex) in clusterMembers) {
      results.add(ColumnAssignment(id: id, columnIndex: columnIndex, columnCount: columnCount));
    }
    clusterMembers = [];
    clusterMaxColumn = 0;
  }

  for (final interval in sorted) {
    activeEndByColumn.removeWhere((_, end) => end <= interval.startMinutes);

    if (activeEndByColumn.isEmpty && clusterMembers.isNotEmpty) {
      closeCluster();
    }

    var columnIndex = 0;
    while (activeEndByColumn.containsKey(columnIndex)) {
      columnIndex++;
    }
    activeEndByColumn[columnIndex] = interval.endMinutes;
    clusterMembers.add((interval.id, columnIndex));
    if (columnIndex > clusterMaxColumn) clusterMaxColumn = columnIndex;
  }
  closeCluster();

  return results;
}

/// One tiny-block chip's collision footprint: its vertical envelope (see
/// [tinyBlockEnvelope]) plus its actual rendered width, used by
/// [packChipsAvoidingOverlap] to shift it left only as far as its real
/// neighbors require. All chips share one right-anchored coordinate space
/// (x=0), since every rendering column's chip aligns to the same shared
/// right edge (see calendar_pane.dart's overlap-cascade layout).
class ChipBox {
  final Object id;
  final double top;
  final double bottom;
  final double width;

  const ChipBox({required this.id, required this.top, required this.bottom, required this.width});
}

/// A chip's resolved horizontal shift: how far left of the shared right edge
/// (x=0) its own right side must sit so it doesn't overlap any
/// vertically-overlapping chip's box (see [packChipsAvoidingOverlap]).
class ChipPlacement {
  final Object id;
  final double rightInset;

  const ChipPlacement({required this.id, required this.rightInset});
}

/// Greedy left-cascading packer for tiny-block chips that all anchor to the
/// same shared right edge (x=0). Boxes are processed in [top]-ascending
/// order (ties broken by original list position, since sort isn't otherwise
/// deterministic) — this ordering only affects which chip in a colliding
/// pair ends up flush against the edge vs. shifted left (earlier-starting
/// chip keeps the edge), not correctness.
///
/// Each box is pushed exactly [gap] px left of the leftmost edge of every
/// already-placed box whose vertical envelope overlaps it. Taking the single
/// minimum bound across all conflicts (rather than reacting to just the
/// nearest one) is sufficient, not an approximation: if this box's right
/// edge sits at or left of another box's left edge minus [gap], the two
/// spans cannot overlap regardless of either box's other edge — so clearing
/// the leftmost conflicting edge clears all of them at once. Boxes with no
/// vertical conflicts stay flush at the shared edge (`rightInset: 0`).
List<ChipPlacement> packChipsAvoidingOverlap(List<ChipBox> boxes, {double gap = 4.0}) {
  if (boxes.isEmpty) return [];

  final order = List<int>.generate(boxes.length, (i) => i)
    ..sort((i, j) {
      final byTop = boxes[i].top.compareTo(boxes[j].top);
      return byTop != 0 ? byTop : i.compareTo(j);
    });

  final placed = <({double left, double top, double bottom})>[];
  final results = <ChipPlacement>[];

  for (final i in order) {
    final box = boxes[i];
    var right = 0.0;
    for (final p in placed) {
      final overlaps = box.top < p.bottom && p.top < box.bottom;
      if (overlaps) right = right < p.left - gap ? right : p.left - gap;
    }
    placed.add((left: right - box.width, top: box.top, bottom: box.bottom));
    results.add(ChipPlacement(id: box.id, rightInset: -right));
  }
  return results;
}
