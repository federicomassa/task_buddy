import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/category.dart';
import '../../models/goal.dart';
import '../../models/task.dart';
import '../../providers/app_providers.dart';
import '../../widgets/category_pickers.dart';

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
  DateTime? _dueDate;
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
      _isRecurrent = task.isRecurrent;
      _recurrenceRule = task.recurrenceRule ?? RecurrenceRule.daily;
      _categoryIds = [...task.categoryIds];
      _linkedGoalId = task.linkedGoalId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final repo = ref.read(taskRepositoryProvider);
    final userId = ref.read(currentUserIdProvider);
    final existing = widget.task;

    if (existing == null) {
      await repo.addTask(
        userId: userId,
        title: title,
        dueDate: _dueDate,
        isRecurrent: _isRecurrent,
        recurrenceRule: _isRecurrent ? _recurrenceRule : null,
        categoryIds: _categoryIds,
        linkedGoalId: _linkedGoalId,
      );
    } else {
      await repo.updateTask(existing.copyWith(
        title: title,
        dueDate: _dueDate,
        isRecurrent: _isRecurrent,
        recurrenceRule: _isRecurrent ? _recurrenceRule : null,
        categoryIds: _categoryIds,
        linkedGoalId: _linkedGoalId,
      ));
    }

    if (mounted) Navigator.of(context).pop();
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
                      : 'Due ${DateFormat.yMMMd().format(_dueDate!)}'),
                ),
                TextButton(onPressed: _pickDueDate, child: const Text('Pick date')),
                if (_dueDate != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _dueDate = null),
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
