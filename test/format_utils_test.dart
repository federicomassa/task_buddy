import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/widgets/format_utils.dart';

void main() {
  test('zero duration formats as 0m', () {
    expect(formatEstimate(Duration.zero), '0m');
  });

  test('minutes only', () {
    expect(formatEstimate(const Duration(minutes: 45)), '45m');
  });

  test('hours only', () {
    expect(formatEstimate(const Duration(hours: 2)), '2h');
  });

  test('days only', () {
    expect(formatEstimate(const Duration(days: 3)), '3d');
  });

  test('combined days, hours, minutes', () {
    expect(formatEstimate(const Duration(days: 1, hours: 2, minutes: 30)), '1d 2h 30m');
  });
}
