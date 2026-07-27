import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform_support.dart';
import '../../models/user_settings.dart';
import '../../providers/app_providers.dart';
import '../family/family_management_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _save(UserSettings settings) async {
    final userId = ref.read(currentUserIdProvider);
    await ref.read(userSettingsRepositoryProvider).updateSettings(
          userId: userId,
          settings: settings,
        );
  }

  Future<void> _applyReminder(UserSettings settings, {required bool enabled, required int minutes}) async {
    await _save(settings.copyWith(reminderEnabled: enabled, reminderMinutes: minutes));
    if (!isAndroidPlatform) return;
    final notifications = ref.read(notificationServiceProvider);
    if (enabled) {
      await notifications.requestPermission();
      await notifications.scheduleDailyReminder(minutes);
    } else {
      await notifications.cancelDailyReminder();
    }
  }

  Future<void> _pickReminderTime(UserSettings settings) async {
    final current = TimeOfDay(
      hour: settings.reminderMinutes ~/ 60,
      minute: settings.reminderMinutes % 60,
    );
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    await _applyReminder(settings, enabled: settings.reminderEnabled, minutes: minutes);
  }

  Future<void> _addActiveHourRange(UserSettings settings) async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: 'Start time',
    );
    if (start == null) return;
    if (!mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      helpText: 'End time',
    );
    if (end == null) return;

    final range = TimeRange(
      startMinutes: start.hour * 60 + start.minute,
      endMinutes: end.hour * 60 + end.minute,
    );
    await _save(settings.copyWith(activeHourRanges: [...settings.activeHourRanges, range]));
  }

  Future<void> _editActiveHourRange(UserSettings settings, int index) async {
    final current = settings.activeHourRanges[index];
    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.startMinutes ~/ 60, minute: current.startMinutes % 60),
      helpText: 'Start time',
    );
    if (start == null) return;
    if (!mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.endMinutes ~/ 60, minute: current.endMinutes % 60),
      helpText: 'End time',
    );
    if (end == null) return;

    final updated = [...settings.activeHourRanges];
    updated[index] = TimeRange(
      startMinutes: start.hour * 60 + start.minute,
      endMinutes: end.hour * 60 + end.minute,
    );
    await _save(settings.copyWith(activeHourRanges: updated));
  }

  Future<void> _removeActiveHourRange(UserSettings settings, int index) async {
    final updated = [...settings.activeHourRanges]..removeAt(index);
    await _save(settings.copyWith(activeHourRanges: updated));
  }

  Future<void> _editWsjfWeight(
    UserSettings settings, {
    required String label,
    required int currentValue,
    required WsjfWeights Function(int) apply,
  }) async {
    final controller = TextEditingController(text: currentValue.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(label),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Weight'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(int.tryParse(controller.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null) return;
    await _save(settings.copyWith(wsjfWeights: apply(result)));
  }

  String _formatMinutes(int minutes) {
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return time.format(context);
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
          final weights = settings.wsjfWeights;

          return ListView(
            children: [
              SwitchListTile(
                title: const Text('Daily planning reminder'),
                subtitle: const Text('Get notified each day to plan tomorrow'),
                value: settings.reminderEnabled,
                onChanged: (value) =>
                    _applyReminder(settings, enabled: value, minutes: settings.reminderMinutes),
              ),
              ListTile(
                enabled: settings.reminderEnabled,
                title: const Text('Reminder time'),
                subtitle: Text(time.format(context)),
                trailing: const Icon(Icons.chevron_right),
                onTap: settings.reminderEnabled ? () => _pickReminderTime(settings) : null,
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Family',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.family_restroom),
                title: const Text('Manage family'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FamilyManagementScreen()),
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Planning',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text(
                  'Active hours',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              for (var i = 0; i < settings.activeHourRanges.length; i++)
                ListTile(
                  title: Text(
                    '${_formatMinutes(settings.activeHourRanges[i].startMinutes)} - '
                    '${_formatMinutes(settings.activeHourRanges[i].endMinutes)}',
                  ),
                  onTap: () => _editActiveHourRange(settings, i),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Remove range',
                    onPressed: () => _removeActiveHourRange(settings, i),
                  ),
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add active hours range'),
                onTap: () => _addActiveHourRange(settings),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  'WSJF priority weights',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text(
                  'Used to score tasks in "Help me plan" (weight ÷ duration). '
                  'Keep P3 low so unimportant, non-urgent tasks are scheduled last.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              ListTile(
                title: const Text('P0 — Important & Urgent'),
                trailing: Text('${weights.importantUrgent}'),
                onTap: () => _editWsjfWeight(
                  settings,
                  label: 'P0 — Important & Urgent',
                  currentValue: weights.importantUrgent,
                  apply: (v) => WsjfWeights(
                    importantUrgent: v,
                    urgentOnly: weights.urgentOnly,
                    importantOnly: weights.importantOnly,
                    neither: weights.neither,
                  ),
                ),
              ),
              ListTile(
                title: const Text('P1 — Urgent, not Important'),
                trailing: Text('${weights.urgentOnly}'),
                onTap: () => _editWsjfWeight(
                  settings,
                  label: 'P1 — Urgent, not Important',
                  currentValue: weights.urgentOnly,
                  apply: (v) => WsjfWeights(
                    importantUrgent: weights.importantUrgent,
                    urgentOnly: v,
                    importantOnly: weights.importantOnly,
                    neither: weights.neither,
                  ),
                ),
              ),
              ListTile(
                title: const Text('P2 — Important, not Urgent'),
                trailing: Text('${weights.importantOnly}'),
                onTap: () => _editWsjfWeight(
                  settings,
                  label: 'P2 — Important, not Urgent',
                  currentValue: weights.importantOnly,
                  apply: (v) => WsjfWeights(
                    importantUrgent: weights.importantUrgent,
                    urgentOnly: weights.urgentOnly,
                    importantOnly: v,
                    neither: weights.neither,
                  ),
                ),
              ),
              ListTile(
                title: const Text('P3 — Neither'),
                trailing: Text('${weights.neither}'),
                onTap: () => _editWsjfWeight(
                  settings,
                  label: 'P3 — Neither',
                  currentValue: weights.neither,
                  apply: (v) => WsjfWeights(
                    importantUrgent: weights.importantUrgent,
                    urgentOnly: weights.urgentOnly,
                    importantOnly: weights.importantOnly,
                    neither: v,
                  ),
                ),
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
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () => ref.read(authServiceProvider).signOut(),
              ),
            ],
          );
        },
      ),
    );
  }
}
