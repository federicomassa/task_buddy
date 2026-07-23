import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/models/user_settings.dart';

void main() {
  test('defaults to reminder disabled at 20:00', () {
    const settings = UserSettings();
    expect(settings.reminderEnabled, isFalse);
    expect(settings.reminderMinutes, 20 * 60);
  });

  test('toFirestore serializes both fields', () {
    const settings = UserSettings(reminderEnabled: true, reminderMinutes: 7 * 60 + 30);
    expect(settings.toFirestore(), {'reminderEnabled': true, 'reminderMinutes': 450});
  });
}
