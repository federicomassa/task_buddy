import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/calendar_math.dart';
import 'package:task_buddy/models/user_settings.dart';

void main() {
  const dayHeightPx = 24 * 60.0;
  const pxPerHour = 60.0;

  test('snaps to the nearest 15-minute increment', () {
    // 90px == 1h30m == 90 minutes, already on a 15-minute boundary.
    expect(snappedMinutesForLocalY(90, dayHeightPx: dayHeightPx, pxPerHour: pxPerHour), 90);
  });

  test('rounds down just below a boundary', () {
    // 7 minutes worth of px rounds to 0.
    expect(snappedMinutesForLocalY(7 * pxPerHour / 60, dayHeightPx: dayHeightPx, pxPerHour: pxPerHour), 0);
  });

  test('rounds up at/above the halfway point', () {
    expect(snappedMinutesForLocalY(8 * pxPerHour / 60, dayHeightPx: dayHeightPx, pxPerHour: pxPerHour), 15);
  });

  test('clamps to 0 at the top', () {
    expect(snappedMinutesForLocalY(-10, dayHeightPx: dayHeightPx, pxPerHour: pxPerHour), 0);
  });

  test('clamps to the last 15-minute slot at the bottom', () {
    expect(
      snappedMinutesForLocalY(dayHeightPx + 100, dayHeightPx: dayHeightPx, pxPerHour: pxPerHour),
      24 * 60 - 15,
    );
  });

  group('snapToNeighborEnd', () {
    test('snaps to a neighbor end within the threshold', () {
      expect(snapToNeighborEnd(9 * 60 + 5, [9 * 60]), 9 * 60);
    });

    test('leaves minutes unchanged when no neighbor end is close enough', () {
      expect(snapToNeighborEnd(9 * 60 + 30, [9 * 60]), 9 * 60 + 30);
    });

    test('exactly at the threshold still snaps', () {
      expect(
        snapToNeighborEnd(9 * 60 + neighborSnapThresholdMinutes, [9 * 60]),
        9 * 60,
      );
    });

    test('just past the threshold does not snap', () {
      expect(
        snapToNeighborEnd(9 * 60 + neighborSnapThresholdMinutes + 1, [9 * 60]),
        9 * 60 + neighborSnapThresholdMinutes + 1,
      );
    });

    test('picks the closest neighbor end among several candidates', () {
      expect(snapToNeighborEnd(10 * 60, [9 * 60 + 50, 10 * 60 + 5]), 10 * 60 + 5);
    });

    test('on a distance tie, the earliest-listed neighbor wins', () {
      expect(snapToNeighborEnd(10 * 60, [9 * 60 + 55, 10 * 60 + 5]), 9 * 60 + 55);
    });
  });

  group('tinyBlockEnvelope', () {
    test('no overflow when the bar is already taller than the label', () {
      final envelope = tinyBlockEnvelope(barHeight: 40, labelAllocation: 32);
      expect(envelope.envelopeHeight, 40);
      expect(envelope.topOffset, 0);
    });

    test('no overflow when the bar exactly matches the label allocation', () {
      final envelope = tinyBlockEnvelope(barHeight: 32, labelAllocation: 32);
      expect(envelope.envelopeHeight, 32);
      expect(envelope.topOffset, 0);
    });

    test('grows symmetrically around the bar when the label is taller', () {
      final envelope = tinyBlockEnvelope(barHeight: 2, labelAllocation: 32);
      expect(envelope.topOffset, 15);
      expect(envelope.envelopeHeight, 32);
    });
  });

  group('segmentGeometry', () {
    test('normal segment matches naive minutes-to-px conversion', () {
      final geometry = segmentGeometry(
        segment: const TimeRange(startMinutes: 9 * 60, endMinutes: 10 * 60),
        dayHeightPx: dayHeightPx,
        pxPerHour: pxPerHour,
      );
      expect(geometry.top, 9 * 60.0);
      expect(geometry.height, 60.0);
      expect(geometry.isTiny, false);
    });

    test('clamps height so a block never overruns the end of the day', () {
      final geometry = segmentGeometry(
        segment: const TimeRange(startMinutes: 23 * 60 + 50, endMinutes: 24 * 60 + 30),
        dayHeightPx: dayHeightPx,
        pxPerHour: pxPerHour,
      );
      expect(geometry.height, dayHeightPx - geometry.top);
    });

    test('segment shorter than the tiny threshold is tiny', () {
      final geometry = segmentGeometry(
        segment: const TimeRange(startMinutes: 0, endMinutes: 10),
        dayHeightPx: dayHeightPx,
        pxPerHour: pxPerHour,
      );
      expect(geometry.isTiny, true);
    });

    test('segment exactly at the tiny threshold is not tiny', () {
      final geometry = segmentGeometry(
        segment: TimeRange(startMinutes: 0, endMinutes: tinyThresholdMinutes.round()),
        dayHeightPx: dayHeightPx,
        pxPerHour: pxPerHour,
      );
      expect(geometry.isTiny, false);
    });

    test('degenerate zero-duration segment gets a floor height of 1px', () {
      final geometry = segmentGeometry(
        segment: const TimeRange(startMinutes: 60, endMinutes: 60),
        dayHeightPx: dayHeightPx,
        pxPerHour: pxPerHour,
      );
      expect(geometry.height, 1.0);
    });
  });

  group('assignColumns', () {
    ColumnAssignment resultFor(List<ColumnAssignment> results, Object id) =>
        results.firstWhere((r) => r.id == id);

    test('no overlap: each interval gets its own column of 1', () {
      final results = assignColumns([
        const LayoutInterval(id: 'a', startMinutes: 0, endMinutes: 30),
        const LayoutInterval(id: 'b', startMinutes: 60, endMinutes: 90),
      ]);
      expect(resultFor(results, 'a').columnIndex, 0);
      expect(resultFor(results, 'a').columnCount, 1);
      expect(resultFor(results, 'b').columnIndex, 0);
      expect(resultFor(results, 'b').columnCount, 1);
    });

    test('simple pair overlap gets two columns', () {
      final results = assignColumns([
        const LayoutInterval(id: 'a', startMinutes: 0, endMinutes: 60),
        const LayoutInterval(id: 'b', startMinutes: 30, endMinutes: 90),
      ]);
      expect(resultFor(results, 'a').columnIndex, 0);
      expect(resultFor(results, 'b').columnIndex, 1);
      expect(resultFor(results, 'a').columnCount, 2);
      expect(resultFor(results, 'b').columnCount, 2);
    });

    test('back-to-back intervals do not overlap and get separate columnCounts', () {
      final results = assignColumns([
        const LayoutInterval(id: 'a', startMinutes: 0, endMinutes: 60),
        const LayoutInterval(id: 'b', startMinutes: 60, endMinutes: 120),
      ]);
      expect(resultFor(results, 'a').columnIndex, 0);
      expect(resultFor(results, 'a').columnCount, 1);
      expect(resultFor(results, 'b').columnIndex, 0);
      expect(resultFor(results, 'b').columnCount, 1);
    });

    test('three-way full overlap gets three columns', () {
      final results = assignColumns([
        const LayoutInterval(id: 'a', startMinutes: 0, endMinutes: 90),
        const LayoutInterval(id: 'b', startMinutes: 0, endMinutes: 90),
        const LayoutInterval(id: 'c', startMinutes: 0, endMinutes: 90),
      ]);
      expect({resultFor(results, 'a').columnIndex, resultFor(results, 'b').columnIndex, resultFor(results, 'c').columnIndex},
          {0, 1, 2});
      expect(resultFor(results, 'a').columnCount, 3);
      expect(resultFor(results, 'b').columnCount, 3);
      expect(resultFor(results, 'c').columnCount, 3);
    });

    test('domino chain (A/B overlap, B/C overlap, A/C do not) peaks at 2 columns', () {
      final results = assignColumns([
        const LayoutInterval(id: 'a', startMinutes: 0, endMinutes: 60),
        const LayoutInterval(id: 'b', startMinutes: 30, endMinutes: 90),
        const LayoutInterval(id: 'c', startMinutes: 60, endMinutes: 120),
      ]);
      expect(resultFor(results, 'a').columnCount, 2);
      expect(resultFor(results, 'b').columnCount, 2);
      expect(resultFor(results, 'c').columnCount, 2);
    });

    test('a cluster closing frees columns for a later, disjoint cluster', () {
      final results = assignColumns([
        const LayoutInterval(id: 'a', startMinutes: 0, endMinutes: 30),
        const LayoutInterval(id: 'b', startMinutes: 10, endMinutes: 20),
        const LayoutInterval(id: 'c', startMinutes: 40, endMinutes: 70),
      ]);
      expect(resultFor(results, 'a').columnCount, 2);
      expect(resultFor(results, 'b').columnCount, 2);
      expect(resultFor(results, 'c').columnIndex, 0);
      expect(resultFor(results, 'c').columnCount, 1);
    });

    test('result is independent of input order', () {
      final intervals = [
        const LayoutInterval(id: 'a', startMinutes: 0, endMinutes: 60),
        const LayoutInterval(id: 'b', startMinutes: 30, endMinutes: 90),
      ];
      final forward = assignColumns(intervals);
      final reversed = assignColumns(intervals.reversed.toList());
      expect(resultFor(forward, 'a').columnIndex, resultFor(reversed, 'a').columnIndex);
      expect(resultFor(forward, 'b').columnIndex, resultFor(reversed, 'b').columnIndex);
    });
  });

  group('packChipsAvoidingOverlap', () {
    ChipPlacement resultFor(List<ChipPlacement> results, Object id) =>
        results.firstWhere((r) => r.id == id);

    test('disjoint boxes both stay flush at the shared edge', () {
      final results = packChipsAvoidingOverlap([
        const ChipBox(id: 'a', top: 0, bottom: 20, width: 50),
        const ChipBox(id: 'b', top: 40, bottom: 60, width: 50),
      ]);
      expect(resultFor(results, 'a').rightInset, 0);
      expect(resultFor(results, 'b').rightInset, 0);
    });

    test('overlapping boxes: the shift is driven by the real width, not a fixed step', () {
      final results = packChipsAvoidingOverlap(
        [
          const ChipBox(id: 'a', top: 0, bottom: 40, width: 30),
          const ChipBox(id: 'b', top: 20, bottom: 60, width: 50),
        ],
        gap: 4,
      );
      expect(resultFor(results, 'a').rightInset, 0);
      expect(resultFor(results, 'b').rightInset, 30 + 4);
    });

    test('three mutually overlapping boxes cascade left by cumulative width', () {
      final results = packChipsAvoidingOverlap(
        [
          const ChipBox(id: 'a', top: 0, bottom: 60, width: 20),
          const ChipBox(id: 'b', top: 0, bottom: 60, width: 20),
          const ChipBox(id: 'c', top: 0, bottom: 60, width: 20),
        ],
        gap: 4,
      );
      expect(resultFor(results, 'a').rightInset, 0);
      expect(resultFor(results, 'b').rightInset, 20 + 4);
      expect(resultFor(results, 'c').rightInset, 20 + 4 + 20 + 4);
    });

    test('a narrower first box needs less shift for its neighbor than a wider one would', () {
      final narrow = packChipsAvoidingOverlap(
        [
          const ChipBox(id: 'a', top: 0, bottom: 40, width: 10),
          const ChipBox(id: 'b', top: 20, bottom: 60, width: 50),
        ],
        gap: 4,
      );
      final wide = packChipsAvoidingOverlap(
        [
          const ChipBox(id: 'a', top: 0, bottom: 40, width: 80),
          const ChipBox(id: 'b', top: 20, bottom: 60, width: 50),
        ],
        gap: 4,
      );
      expect(resultFor(narrow, 'b').rightInset, 10 + 4);
      expect(resultFor(wide, 'b').rightInset, 80 + 4);
      expect(resultFor(narrow, 'b').rightInset, lessThan(resultFor(wide, 'b').rightInset));
    });
  });
}
