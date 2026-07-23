import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../models/habit.dart';
import '../../providers/app_providers.dart';
import '../../widgets/category_pickers.dart';

Future<void> showHabitFormDialog(BuildContext context, {Habit? habit}) {
  return showDialog(context: context, builder: (_) => HabitFormDialog(habit: habit));
}

class HabitFormDialog extends ConsumerStatefulWidget {
  final Habit? habit;

  const HabitFormDialog({super.key, this.habit});

  @override
  ConsumerState<HabitFormDialog> createState() => _HabitFormDialogState();
}

class _HabitFormDialogState extends ConsumerState<HabitFormDialog> {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.habit?.title ?? '');
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.habit?.description ?? '');
  late final TextEditingController _targetController =
      TextEditingController(text: (widget.habit?.targetCount ?? 3).toString());
  String? _categoryId;
  HabitPeriod _period = HabitPeriod.weekly;
  TimeOfDay? _dueTime;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.habit?.categoryId;
    _period = widget.habit?.period ?? HabitPeriod.weekly;
    final dueTimeMinutes = widget.habit?.dueTimeMinutes;
    if (dueTimeMinutes != null) {
      _dueTime = TimeOfDay(hour: dueTimeMinutes ~/ 60, minute: dueTimeMinutes % 60);
    }
  }

  Future<void> _pickDueTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? const TimeOfDay(hour: 7, minute: 0),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    final target = int.tryParse(_targetController.text.trim()) ?? 1;
    if (title.isEmpty) return;

    final habitRepo = ref.read(habitRepositoryProvider);
    final existing = widget.habit;
    final userId = ref.read(currentUserIdProvider);
    final dueTimeMinutes = _dueTime != null ? _dueTime!.hour * 60 + _dueTime!.minute : null;

    if (existing == null) {
      // New habits need the created habit's id before the first cycle
      // instance can be added, so this chain has to stay sequential — but it
      // runs in the background rather than gating the dialog's close.
      ref
          .read(habitCycleServiceProvider)
          .createHabitWithFirstInstance(
            userId: userId,
            title: title,
            description: _descriptionController.text.trim(),
            categoryId: _categoryId,
            targetCount: target,
            period: _period,
            dueTimeMinutes: dueTimeMinutes,
          )
          .catchError((e) => ref.read(errorReporterProvider).report(e));
    } else {
      habitRepo
          .updateHabit(Habit(
            id: existing.id,
            userId: existing.userId,
            title: title,
            description: _descriptionController.text.trim(),
            categoryId: _categoryId,
            targetCount: target,
            period: _period,
            dueTimeMinutes: dueTimeMinutes,
            createdAt: existing.createdAt,
          ))
          .catchError((e) => ref.read(errorReporterProvider).report(e));
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];

    return AlertDialog(
      title: Text(widget.habit == null ? 'New Habit' : 'Edit Habit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetController,
              decoration: const InputDecoration(labelText: 'Target count per period'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<HabitPeriod>(
              initialValue: _period,
              decoration: const InputDecoration(labelText: 'Period'),
              items: const [
                DropdownMenuItem(value: HabitPeriod.daily, child: Text('Daily')),
                DropdownMenuItem(value: HabitPeriod.weekly, child: Text('Weekly')),
                DropdownMenuItem(value: HabitPeriod.monthly, child: Text('Monthly')),
              ],
              onChanged: (v) => setState(() => _period = v ?? HabitPeriod.weekly),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(_dueTime == null
                      ? 'No due time'
                      : 'Due by ${_dueTime!.format(context)} each cycle'),
                ),
                TextButton(onPressed: _pickDueTime, child: const Text('Pick time')),
                if (_dueTime != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _dueTime = null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            CategoryDropdown(
              categories: categories,
              value: _categoryId,
              onChanged: (v) => setState(() => _categoryId = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
