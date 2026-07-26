import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/calendar_math.dart';

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
}
