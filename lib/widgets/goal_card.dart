import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/color_utils.dart';
import '../features/tasks/task_form.dart';
import '../models/category.dart';
import '../models/goal.dart';
import '../providers/app_providers.dart';
import 'category_pickers.dart';
import 'task_tile.dart';

class GoalCard extends ConsumerWidget {
  final Goal goal;
  final List<Category> categories;
  final ValueChanged<bool?>? onToggleCompleted;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const GoalCard({
    super.key,
    required this.goal,
    required this.categories,
    this.onToggleCompleted,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final category = categoryById(categories, goal.categoryId);
    final target = goal.targetCount;
    final progress = target != null && target > 0
        ? (goal.currentProgress / target).clamp(0.0, 1.0)
        : null;
    final linkedTasks = (ref.watch(tasksStreamProvider).value ?? const [])
        .where((t) => t.linkedGoalId == goal.id)
        .toList();
    final taskRepo = ref.read(taskRepositoryProvider);

    return Card(
      child: Column(
        children: [
          ListTile(
            onTap: onTap,
            leading: Checkbox(value: goal.isCompleted, onChanged: onToggleCompleted),
            title: Text(
              goal.title,
              style: goal.isCompleted ? const TextStyle(decoration: TextDecoration.lineThrough) : null,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (goal.description.isNotEmpty) Text(goal.description),
                if (goal.dueDate != null)
                  Text('Due ${DateFormat.yMMMd().add_Hm().format(goal.dueDate!)}'),
                if (progress != null) ...[
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 2),
                  Text('${goal.currentProgress} / $target'),
                ],
                if (category != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Chip(
                      label: Text(category.name, style: const TextStyle(fontSize: 11)),
                      avatar: CircleAvatar(backgroundColor: colorFromHex(category.colorHex)),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
            trailing: onDelete != null
                ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete)
                : null,
          ),
          if (linkedTasks.isNotEmpty)
            ExpansionTile(
              title: Text('Linked tasks (${linkedTasks.length})'),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                for (final task in linkedTasks)
                  TaskTile(
                    task: task,
                    categories: categories,
                    onToggle: (_) => taskRepo.toggleComplete(task),
                    onTap: () => showTaskFormDialog(context, task: task),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
