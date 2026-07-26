import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/drop_resolution.dart';
import 'package:task_buddy/models/user_settings.dart';

void main() {
  const ranges = [
    TimeRange(startMinutes: 9 * 60, endMinutes: 12 * 60), // 180 min
    TimeRange(startMinutes: 13 * 60, endMinutes: 18 * 60), // 300 min
  ];

  group('dropNeedsConfirmation', () {
    test('false when the drop fits comfortably inside a range', () {
      expect(
        dropNeedsConfirmation(droppedMinutes: 10 * 60, durationMinutes: 30, activeHours: ranges),
        isFalse,
      );
    });

    test('true when the drop lands in a break', () {
      expect(
        dropNeedsConfirmation(droppedMinutes: 12 * 60 + 30, durationMinutes: 15, activeHours: ranges),
        isTrue,
      );
    });
  });

  group('directDropPlacement', () {
    test('a single literal segment matching the dropped time and duration', () {
      final segments = directDropPlacement(droppedMinutes: 10 * 60, durationMinutes: 30);
      expect(segments, [const TimeRange(startMinutes: 10 * 60, endMinutes: 10 * 60 + 30)]);
    });
  });

  group('resolveConfirmedDrop', () {
    test('scheduleAnyway produces one literal block straight through the break', () {
      final placement = resolveConfirmedDrop(
        choice: DropChoice.scheduleAnyway,
        droppedMinutes: 11 * 60 + 30,
        durationMinutes: 120,
        activeHours: ranges,
      );
      expect(placement.constrainedToWorkingHours, isFalse);
      expect(placement.segments, [const TimeRange(startMinutes: 11 * 60 + 30, endMinutes: 13 * 60 + 30)]);
    });

    test('respectBreaks splits across the break it spans', () {
      final placement = resolveConfirmedDrop(
        choice: DropChoice.respectBreaks,
        droppedMinutes: 11 * 60 + 30,
        durationMinutes: 120,
        activeHours: ranges,
      );
      expect(placement.constrainedToWorkingHours, isTrue);
      expect(placement.segments, [
        const TimeRange(startMinutes: 11 * 60 + 30, endMinutes: 12 * 60),
        const TimeRange(startMinutes: 13 * 60, endMinutes: 14 * 60 + 30),
      ]);
    });

    test('respectBreaks on a drop inside a break snaps forward to the next range', () {
      final placement = resolveConfirmedDrop(
        choice: DropChoice.respectBreaks,
        droppedMinutes: 12 * 60 + 30,
        durationMinutes: 30,
        activeHours: ranges,
      );
      expect(placement.segments, [const TimeRange(startMinutes: 13 * 60, endMinutes: 13 * 60 + 30)]);
    });
  });
}
