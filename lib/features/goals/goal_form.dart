import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../models/goal.dart';
import '../../providers/app_providers.dart';
import '../../widgets/category_pickers.dart';

Future<void> showGoalFormDialog(BuildContext context, {Goal? goal}) {
  return showDialog(context: context, builder: (_) => GoalFormDialog(goal: goal));
}

class GoalFormDialog extends ConsumerStatefulWidget {
  final Goal? goal;

  const GoalFormDialog({super.key, this.goal});

  @override
  ConsumerState<GoalFormDialog> createState() => _GoalFormDialogState();
}

class _GoalFormDialogState extends ConsumerState<GoalFormDialog> {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.goal?.title ?? '');
  late final TextEditingController _descriptionController =
      TextEditingController(text: widget.goal?.description ?? '');
  late final TextEditingController _targetController =
      TextEditingController(text: widget.goal?.targetCount?.toString() ?? '');
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.goal?.categoryId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final target = int.tryParse(_targetController.text.trim());

    final repo = ref.read(goalRepositoryProvider);
    final existing = widget.goal;

    if (existing == null) {
      await repo.addStandaloneGoal(
        userId: ref.read(currentUserIdProvider),
        title: title,
        description: _descriptionController.text.trim(),
        categoryId: _categoryId,
        targetCount: target,
      );
    } else {
      await repo.updateGoal(existing.copyWith(
        title: title,
        description: _descriptionController.text.trim(),
        categoryId: _categoryId,
        targetCount: target,
      ));
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];

    return AlertDialog(
      title: Text(widget.goal == null ? 'New Goal' : 'Edit Goal'),
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
              decoration: const InputDecoration(labelText: 'Target count (optional)'),
              keyboardType: TextInputType.number,
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
