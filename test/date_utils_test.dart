import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/date_utils.dart';

void main() {
  test('strips time of day', () {
    expect(dateOnly(DateTime(2026, 7, 22, 14, 30, 15)), DateTime(2026, 7, 22));
  });

  test('already date-only value is unchanged', () {
    expect(dateOnly(DateTime(2026, 1, 1)), DateTime(2026, 1, 1));
  });
}
