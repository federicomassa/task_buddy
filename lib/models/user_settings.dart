import 'package:cloud_firestore/cloud_firestore.dart';

class UserSettings {
  static const defaultReminderMinutes = 20 * 60;

  final bool reminderEnabled;
  final int reminderMinutes;

  const UserSettings({
    this.reminderEnabled = false,
    this.reminderMinutes = defaultReminderMinutes,
  });

  factory UserSettings.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return const UserSettings();
    return UserSettings(
      reminderEnabled: data['reminderEnabled'] as bool? ?? false,
      reminderMinutes: data['reminderMinutes'] as int? ?? defaultReminderMinutes,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reminderEnabled': reminderEnabled,
      'reminderMinutes': reminderMinutes,
    };
  }
}
