import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform_support.dart';
import '../../models/user_settings.dart';
import '../../providers/app_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _apply({required bool enabled, required int minutes}) async {
    final userId = ref.read(currentUserIdProvider);
    await ref.read(userSettingsRepositoryProvider).updateReminder(
          userId: userId,
          enabled: enabled,
          minutes: minutes,
        );
    if (!isAndroidPlatform) return;
    final notifications = ref.read(notificationServiceProvider);
    if (enabled) {
      await notifications.requestPermission();
      await notifications.scheduleDailyReminder(minutes);
    } else {
      await notifications.cancelDailyReminder();
    }
  }

  Future<void> _pickTime(UserSettings settings) async {
    final current = TimeOfDay(
      hour: settings.reminderMinutes ~/ 60,
      minute: settings.reminderMinutes % 60,
    );
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    await _apply(enabled: settings.reminderEnabled, minutes: minutes);
  }

  Future<void> _runTest(String label, Future<void> Function() action) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(notificationServiceProvider).requestPermission();
      await action();
      messenger.showSnackBar(SnackBar(content: Text(label)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Test notification failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(userSettingsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load settings: $error')),
        data: (settings) {
          final time = TimeOfDay(
            hour: settings.reminderMinutes ~/ 60,
            minute: settings.reminderMinutes % 60,
          );
          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Daily planning reminder'),
                subtitle: const Text('Get notified each day to plan tomorrow'),
                value: settings.reminderEnabled,
                onChanged: (value) => _apply(enabled: value, minutes: settings.reminderMinutes),
              ),
              ListTile(
                enabled: settings.reminderEnabled,
                title: const Text('Reminder time'),
                subtitle: Text(time.format(context)),
                trailing: const Icon(Icons.chevron_right),
                onTap: settings.reminderEnabled ? () => _pickTime(settings) : null,
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Troubleshooting',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                title: const Text('Send test notification now'),
                subtitle: const Text('Fires immediately — checks permission & delivery'),
                trailing: const Icon(Icons.notifications_active_outlined),
                onTap: () => _runTest(
                  'Test notification sent',
                  () => ref.read(notificationServiceProvider).showTestNotificationNow(),
                ),
              ),
              ListTile(
                title: const Text('Schedule test notification in 1 minute'),
                subtitle: const Text('Uses the same scheduling path as the daily reminder'),
                trailing: const Icon(Icons.schedule),
                onTap: () => _runTest(
                  'Scheduled — should arrive in about a minute',
                  () => ref.read(notificationServiceProvider).scheduleTestNotificationInOneMinute(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
