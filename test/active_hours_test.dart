import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/active_hours.dart';
import 'package:task_buddy/models/user_settings.dart';

void main() {
  const ranges = [
    TimeRange(startMinutes: 9 * 60, endMinutes: 12 * 60), // 180 min
    TimeRange(startMinutes: 13 * 60, endMinutes: 18 * 60), // 300 min
  ];

  group('totalActiveMinutes', () {
    test('sums every range', () {
      expect(totalActiveMinutes(ranges), 480);
    });
  });

  group('realMinutesFromVirtual', () {
    test('virtual 0 maps to the first range start', () {
      expect(realMinutesFromVirtual(0, ranges), 9 * 60);
    });

    test('virtual position within the first range stays in it', () {
      expect(realMinutesFromVirtual(150, ranges), 11 * 60 + 30);
    });

    test('crossing the boundary skips straight to the next range start', () {
      expect(realMinutesFromVirtual(180, ranges), 13 * 60);
    });

    test('position within the second range', () {
      expect(realMinutesFromVirtual(210, ranges), 13 * 60 + 30);
    });

    test('null once beyond total active time', () {
      expect(realMinutesFromVirtual(480, ranges), isNull);
      expect(realMinutesFromVirtual(1000, ranges), isNull);
    });

    test('unsorted input ranges are still handled in chronological order', () {
      final unsorted = [ranges[1], ranges[0]];
      expect(realMinutesFromVirtual(0, unsorted), 9 * 60);
    });
  });

  group('virtualMinutesFromReal', () {
    test('start of first range is virtual 0', () {
      expect(virtualMinutesFromReal(9 * 60, ranges), 0);
    });

    test('inside the second range', () {
      expect(virtualMinutesFromReal(14 * 60, ranges), 180 + 60);
    });

    test('null during a break', () {
      expect(virtualMinutesFromReal(12 * 60 + 30, ranges), isNull);
    });

    test('null outside every range', () {
      expect(virtualMinutesFromReal(22 * 60, ranges), isNull);
    });
  });

  group('realSegmentsFromVirtualRange', () {
    test('interval fully inside one range stays a single segment', () {
      final segments = realSegmentsFromVirtualRange(30, 90, ranges);
      expect(segments, [const TimeRange(startMinutes: 9 * 60 + 30, endMinutes: 10 * 60 + 30)]);
    });

    test('interval spanning the break splits into two segments', () {
      // virtual 150 (11:30) to 270 (i.e. 90 min into the afternoon range).
      final segments = realSegmentsFromVirtualRange(150, 270, ranges);
      expect(segments, [
        const TimeRange(startMinutes: 11 * 60 + 30, endMinutes: 12 * 60),
        const TimeRange(startMinutes: 13 * 60, endMinutes: 14 * 60 + 30),
      ]);
    });

    test('interval beyond total capacity is clipped', () {
      final segments = realSegmentsFromVirtualRange(450, 600, ranges);
      expect(segments, [const TimeRange(startMinutes: 17 * 60 + 30, endMinutes: 18 * 60)]);
    });
  });

  group('realSegmentsForPlacement', () {
    test('empty duration produces a zero-length literal when unconstrained', () {
      expect(
        realSegmentsForPlacement(
          startMinutes: 9 * 60,
          durationMinutes: 0,
          activeHours: ranges,
          constrainedToWorkingHours: false,
        ),
        [const TimeRange(startMinutes: 9 * 60, endMinutes: 9 * 60)],
      );
    });

    test('a placement starting before lunch and running 2h splits across it', () {
      final segments = realSegmentsForPlacement(
        startMinutes: 11 * 60 + 30,
        durationMinutes: 120,
        activeHours: ranges,
        constrainedToWorkingHours: true,
      );
      expect(segments, [
        const TimeRange(startMinutes: 11 * 60 + 30, endMinutes: 12 * 60),
        const TimeRange(startMinutes: 13 * 60, endMinutes: 14 * 60 + 30),
      ]);
    });

    test('a placement outside any active-hours range renders unsplit', () {
      final segments = realSegmentsForPlacement(
        startMinutes: 20 * 60,
        durationMinutes: 60,
        activeHours: ranges,
        constrainedToWorkingHours: true,
      );
      expect(segments, [
        const TimeRange(startMinutes: 20 * 60, endMinutes: 21 * 60),
      ]);
    });

    test('constrainedToWorkingHours false always renders as one literal block', () {
      final segments = realSegmentsForPlacement(
        startMinutes: 11 * 60 + 30,
        durationMinutes: 120,
        activeHours: ranges,
        constrainedToWorkingHours: false,
      );
      expect(segments, [
        const TimeRange(startMinutes: 11 * 60 + 30, endMinutes: 13 * 60 + 30),
      ]);
    });
  });

  group('violatesActiveHours', () {
    test('false when the task starts and fits comfortably inside a range', () {
      expect(violatesActiveHours(10 * 60, 30, ranges), isFalse);
    });

    test('true when the start itself falls in a break', () {
      expect(violatesActiveHours(12 * 60 + 30, 15, ranges), isTrue);
    });

    test('true when the start is before the work day begins', () {
      expect(violatesActiveHours(7 * 60, 30, ranges), isTrue);
    });

    test('true when the start is after the work day ends', () {
      expect(violatesActiveHours(20 * 60, 30, ranges), isTrue);
    });

    test('true when a task starts inside a range but runs past its end into a break', () {
      // Starts at 11:30, runs 2h — well within total active time (480 min)
      // once split across the break, but it does touch the break, so this
      // should prompt rather than silently succeed.
      expect(violatesActiveHours(11 * 60 + 30, 120, ranges), isTrue);
    });

    test('false when a task starts and ends exactly at a range boundary', () {
      expect(violatesActiveHours(9 * 60, 180, ranges), isFalse);
    });

    test('true when the task would run past the end of the last range', () {
      // Starts at 17:45 (within the last range) but needs 30 more minutes
      // than are left before 18:00, and there's no range after it.
      expect(violatesActiveHours(17 * 60 + 45, 30, ranges), isTrue);
    });
  });

  group('virtualDeadlineFromReal', () {
    test('deadline inside the first range', () {
      expect(virtualDeadlineFromReal(10 * 60, ranges), 60);
    });

    test('deadline inside the break snaps down to the end of the preceding range', () {
      expect(virtualDeadlineFromReal(12 * 60 + 30, ranges), 180);
    });

    test('deadline before the work day starts is 0', () {
      expect(virtualDeadlineFromReal(7 * 60, ranges), 0);
    });

    test('deadline at the end of the day is full capacity', () {
      expect(virtualDeadlineFromReal(18 * 60, ranges), 480);
    });

    test('deadline after the end of the day is full capacity', () {
      expect(virtualDeadlineFromReal(19 * 60, ranges), 480);
    });

    test('deadline exactly at a range start boundary', () {
      expect(virtualDeadlineFromReal(13 * 60, ranges), 180);
    });
  });

  group('resolveActiveStart', () {
    test('a start already inside a range is returned unchanged', () {
      expect(resolveActiveStart(10 * 60, ranges), 10 * 60);
    });

    test('a start during a break snaps forward to the next range', () {
      expect(resolveActiveStart(12 * 60 + 30, ranges), 13 * 60);
    });

    test('a start before the work day snaps forward to the first range', () {
      expect(resolveActiveStart(7 * 60, ranges), 9 * 60);
    });

    test('a start after the last range is left unchanged (nothing to snap to)', () {
      expect(resolveActiveStart(20 * 60, ranges), 20 * 60);
    });
  });
}
