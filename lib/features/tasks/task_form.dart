import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/duration_parts.dart';
import '../../models/category.dart';
import '../../models/goal.dart';
import '../../models/task.dart';
import '../../providers/app_providers.dart';
import '../../widgets/category_pickers.dart';
import '../../widgets/date_pickers.dart';

Future<void> showTaskFormDialog(BuildContext context, {Task? task}) {
  return showDialog(
    context: context,
    builder: (_) => TaskFormDialog(task: task),
  );
}

class TaskFormDialog extends ConsumerStatefulWidget {
  final Task? task;

  const TaskFormDialog({super.key, this.task});

  @override
  ConsumerState<TaskFormDialog> createState() => _TaskFormDialogState();
}

class _TaskFormDialogState extends ConsumerState<TaskFormDialog> {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.task?.title ?? '');
  late final TextEditingController _estDaysController = TextEditingController();
  late final TextEditingController _estHoursController = TextEditingController();
  late final TextEditingController _estMinutesController = TextEditingController();
  DateTime? _dueDate;
  DateTime? _scheduledDate;
  bool _isRecurrent = false;
  RecurrenceRule _recurrenceRule = RecurrenceRule.daily;
  List<String> _categoryIds = [];
  String? _linkedGoalId;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    if (task != null) {
      _dueDate = task.dueDate;
      _scheduledDate = task.scheduledDate;
      _isRecurrent = task.isRecurrent;
      _recurrenceRule = task.recurrenceRule ?? RecurrenceRule.daily;
      _categoryIds = [...task.categoryIds];
      _linkedGoalId = task.linkedGoalId;
      final estimate = task.timeEstimate;
      if (estimate != null) {
        final parts = DurationParts.fromDuration(estimate);
        _estDaysController.text = parts.days.toString();
        _estHoursController.text = parts.hours.toString();
        _estMinutesController.text = parts.minutes.toString();
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _estDaysController.dispose();
    _estHoursController.dispose();
    _estMinutesController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = ref.read(clockProvider).now();
    final picked = await pickDueDateWithDefaultTime(
      context,
      initialDate: _dueDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
      nowForTimeDefault: now,
    );
    if (picked == null) return;
    setState(() => _dueDate = picked);
  }

  Future<void> _pickScheduledDate() async {
    final now = ref.read(clockProvider).now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (pickedDate == null) return;

    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _scheduledDate != null
          ? TimeOfDay.fromDateTime(_scheduledDate!)
          : TimeOfDay.fromDateTime(now),
    );
    if (pickedTime == null) return;

    setState(() {
      _scheduledDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Duration? get _timeEstimate {
    final days = int.tryParse(_estDaysController.text.trim()) ?? 0;
    final hours = int.tryParse(_estHoursController.text.trim()) ?? 0;
    final minutes = int.tryParse(_estMinutesController.text.trim()) ?? 0;
    return DurationParts(days: days, hours: hours, minutes: minutes).toDuration();
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final repo = ref.read(taskRepositoryProvider);
    final userId = ref.read(currentUserIdProvider);
    final existing = widget.task;

    if (existing == null) {
      repo
          .addTask(
            userId: userId,
            title: title,
            dueDate: _dueDate,
            scheduledDate: _scheduledDate,
            isRecurrent: _isRecurrent,
            recurrenceRule: _isRecurrent ? _recurrenceRule : null,
            categoryIds: _categoryIds,
            linkedGoalId: _linkedGoalId,
            timeEstimate: _timeEstimate,
          )
          .catchError((e) => ref.read(errorReporterProvider).report(e));
    } else {
      final goalChanged = _linkedGoalId != existing.linkedGoalId;
      repo
          .updateTask(existing.copyWith(
            title: title,
            dueDate: _dueDate,
            scheduledDate: _scheduledDate,
            isRecurrent: _isRecurrent,
            recurrenceRule: _isRecurrent ? _recurrenceRule : null,
            categoryIds: _categoryIds,
            linkedGoalId: _linkedGoalId,
            // The contributes-to-count flag is scoped to the previously
            // linked goal's N-task cap; relinking to a different goal must
            // not silently carry it over (and skip that goal's cap).
            contributesToCount: goalChanged ? false : null,
            timeEstimate: _timeEstimate,
          ))
          .catchError((e) => ref.read(errorReporterProvider).report(e));
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];
    final goals = ref.watch(allGoalsStreamProvider).value ?? const <Goal>[];

    return AlertDialog(
      title: Text(widget.task == null ? 'New Task' : 'Edit Task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(_dueDate == null
                      ? 'No due date'
                      : 'Due ${DateFormat.yMMMd().add_Hm().format(_dueDate!)}'),
                ),
                TextButton(onPressed: _pickDueDate, child: const Text('Pick date & time')),
                if (_dueDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(_scheduledDate == null
                      ? 'Not scheduled'
                      : 'Scheduled ${DateFormat.yMMMd().add_Hm().format(_scheduledDate!)}'),
                ),
                TextButton(onPressed: _pickScheduledDate, child: const Text('Pick date & time')),
                if (_scheduledDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _scheduledDate = null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Time estimate', style: Theme.of(context).textTheme.labelLarge),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _estDaysController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Days'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _estHoursController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Hours'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _estMinutesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Minutes'),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Recurrent'),
              value: _isRecurrent,
              onChanged: (v) => setState(() => _isRecurrent = v),
            ),
            if (_isRecurrent)
              DropdownButtonFormField<RecurrenceRule>(
                initialValue: _recurrenceRule,
                decoration: const InputDecoration(labelText: 'Repeats'),
                items: RecurrenceRule.values
                    .map((r) => DropdownMenuItem(value: r, child: Text(r.name)))
                    .toList(),
                onChanged: (v) => setState(() => _recurrenceRule = v ?? RecurrenceRule.daily),
              ),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: Text('Categories', style: Theme.of(context).textTheme.labelLarge)),
            const SizedBox(height: 4),
            CategoryMultiSelect(
              categories: categories,
              selectedIds: _categoryIds,
              onChanged: (v) => setState(() => _categoryIds = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _linkedGoalId,
              decoration: const InputDecoration(labelText: 'Linked goal/habit (optional)'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('None')),
                ...goals.map((g) => DropdownMenuItem<String?>(value: g.id, child: Text(g.title))),
              ],
              onChanged: (v) => setState(() => _linkedGoalId = v),
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
