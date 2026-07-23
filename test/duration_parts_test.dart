import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/duration_parts.dart';

void main() {
  test('decomposes a duration into days/hours/minutes', () {
    final parts = DurationParts.fromDuration(const Duration(days: 2, hours: 3, minutes: 45));
    expect(parts.days, 2);
    expect(parts.hours, 3);
    expect(parts.minutes, 45);
  });

  test('exactly 24 hours becomes 1 day, 0 hours', () {
    final parts = DurationParts.fromDuration(const Duration(hours: 24));
    expect(parts.days, 1);
    expect(parts.hours, 0);
    expect(parts.minutes, 0);
  });

  test('round-trips through toDuration', () {
    const original = Duration(days: 1, hours: 2, minutes: 30);
    final parts = DurationParts.fromDuration(original);
    expect(parts.toDuration(), original);
  });

  test('all-zero parts produce a null duration', () {
    const parts = DurationParts(days: 0, hours: 0, minutes: 0);
    expect(parts.toDuration(), isNull);
  });

  test('non-zero minutes alone still produce a duration', () {
    const parts = DurationParts(days: 0, hours: 0, minutes: 5);
    expect(parts.toDuration(), const Duration(minutes: 5));
  });
}
