import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/models/user_settings.dart';

void main() {
  test('defaults to reminder disabled at 20:00 and standard active hours/weights', () {
    const settings = UserSettings();
    expect(settings.reminderEnabled, isFalse);
    expect(settings.reminderMinutes, 20 * 60);
    expect(settings.activeHourRanges, defaultActiveHourRanges);
    expect(settings.wsjfWeights.importantUrgent, 10);
    expect(settings.wsjfWeights.urgentOnly, 5);
    expect(settings.wsjfWeights.importantOnly, 3);
    expect(settings.wsjfWeights.neither, 1);
  });

  test('toFirestore serializes all fields', () {
    const settings = UserSettings(
      reminderEnabled: true,
      reminderMinutes: 7 * 60 + 30,
      activeHourRanges: [TimeRange(startMinutes: 8 * 60, endMinutes: 10 * 60)],
      wsjfWeights: WsjfWeights(importantUrgent: 20, urgentOnly: 8, importantOnly: 4, neither: 1),
    );
    expect(settings.toFirestore(), {
      'reminderEnabled': true,
      'reminderMinutes': 450,
      'activeHourRanges': [
        {'start': 480, 'end': 600},
      ],
      'wsjfWeights': {'importantUrgent': 20, 'urgentOnly': 8, 'importantOnly': 4, 'neither': 1},
    });
  });

  test('copyWith only overrides passed fields', () {
    const settings = UserSettings(reminderEnabled: true, reminderMinutes: 100);
    final updated = settings.copyWith(reminderMinutes: 200);
    expect(updated.reminderEnabled, isTrue);
    expect(updated.reminderMinutes, 200);
    expect(updated.activeHourRanges, defaultActiveHourRanges);
  });

  test('WsjfWeights.fromMap falls back to defaults for missing fields', () {
    final weights = WsjfWeights.fromMap({'importantUrgent': 99});
    expect(weights.importantUrgent, 99);
    expect(weights.urgentOnly, 5);
    expect(weights.importantOnly, 3);
    expect(weights.neither, 1);
  });

  test('WsjfWeights.fromMap(null) returns defaults', () {
    expect(WsjfWeights.fromMap(null).importantUrgent, 10);
  });
}
