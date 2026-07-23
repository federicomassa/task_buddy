import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Thin wrapper around `flutter_local_notifications` for the single daily
/// "plan tomorrow" reminder. There's only ever one such reminder, so it's
/// always scheduled/cancelled under this fixed notification id.
const _reminderNotificationId = 1;

/// Separate id for the manual "send test notification" button, so testing
/// never collides with (or cancels) the real daily reminder's alarm.
const _testNotificationId = 999;

const _testNotificationDetails = NotificationDetails(
  android: AndroidNotificationDetails('test_notification', 'Test notification'),
);

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz_data.initializeTimeZones();
    final localTimezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localTimezone.identifier));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );
  }

  Future<bool?> requestPermission() async {
    return await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> scheduleDailyReminder(int minutesSinceMidnight) async {
    await _plugin.zonedSchedule(
      id: _reminderNotificationId,
      title: 'Plan tomorrow',
      body: 'Take a moment to plan your tasks for tomorrow.',
      scheduledDate: _nextInstanceOf(minutesSinceMidnight),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('daily_reminder', 'Daily reminder'),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailyReminder() {
    return _plugin.cancel(id: _reminderNotificationId);
  }

  /// Fires immediately, bypassing AlarmManager entirely — proves permission
  /// + channel + OS delivery all work, independent of scheduling.
  Future<void> showTestNotificationNow() {
    return _plugin.show(
      id: _testNotificationId,
      title: 'Test notification',
      body: 'If you can see this, notifications are working.',
      notificationDetails: _testNotificationDetails,
    );
  }

  /// Schedules through the same `zonedSchedule`/AlarmManager path as the
  /// real daily reminder, but fires ~1 minute out instead of waiting for
  /// tomorrow — lets you verify the *scheduled* delivery path specifically
  /// (inexact alarms, Doze, OEM battery management) without a long wait.
  Future<void> scheduleTestNotificationInOneMinute() {
    return _plugin.zonedSchedule(
      id: _testNotificationId,
      title: 'Scheduled test notification',
      body: 'This fired via the same scheduling path as the daily reminder.',
      scheduledDate: tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1)),
      notificationDetails: _testNotificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  static tz.TZDateTime _nextInstanceOf(int minutesSinceMidnight) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      minutesSinceMidnight ~/ 60,
      minutesSinceMidnight % 60,
    );
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
