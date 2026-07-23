import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/goal.dart';
import '../models/task.dart';
import 'category_pickers.dart';
import 'task_tile.dart';

class GoalCard extends StatelessWidget {
  final Goal goal;
  final List<Category> categories;
  final List<Task> linkedTasks;
  final int contributingCount;
  final ValueChanged<bool?>? onToggleCompleted;
  final ValueChanged<Task>? onToggleTask;
  final ValueChanged<Task>? onToggleContributesToCount;
  final ValueChanged<Task>? onTapTask;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const GoalCard({
    super.key,
    required this.goal,
    required this.categories,
    this.linkedTasks = const [],
    this.contributingCount = 0,
    this.onToggleCompleted,
    this.onToggleTask,
    this.onToggleContributesToCount,
    this.onTapTask,
    this.onDelete,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final category = categoryById(categories, goal.categoryId);
    final target = goal.targetCount;
    final progress = target != null && target > 0
        ? (goal.currentProgress / target).clamp(0.0, 1.0)
        : null;

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
                    child: CategoryChip(category: category),
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
                  Row(
                    children: [
                      Expanded(
                        child: TaskTile(
                          task: task,
                          categories: categories,
                          onToggle: (_) => onToggleTask?.call(task),
                          onTap: () => onTapTask?.call(task),
                        ),
                      ),
                      if (target != null && target > 0)
                        IconButton(
                          icon: Icon(
                            task.contributesToCount ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: task.contributesToCount
                                ? Colors.green
                                : Theme.of(context).disabledColor,
                          ),
                          tooltip: task.contributesToCount
                              ? 'Counts toward goal'
                              : contributingCount >= target
                                  ? 'Limit of $target contributing tasks reached'
                                  : 'Mark as counting toward goal',
                          onPressed: !task.contributesToCount && contributingCount >= target
                              ? null
                              : () => onToggleContributesToCount?.call(task),
                        ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
