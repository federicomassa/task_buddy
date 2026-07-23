import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/goal.dart';
import '../models/habit.dart';
import '../models/task.dart';
import 'task_tile.dart';

class HabitProgressCard extends StatelessWidget {
  final Habit habit;
  final Goal? currentInstance;
  final List<Category> categories;
  final List<Task> linkedTasks;
  final int contributingCount;
  final ValueChanged<Task>? onToggleTask;
  final ValueChanged<Task>? onToggleContributesToCount;
  final ValueChanged<Task>? onTapTask;
  final VoidCallback? onDelete;

  const HabitProgressCard({
    super.key,
    required this.habit,
    required this.currentInstance,
    this.categories = const [],
    this.linkedTasks = const [],
    this.contributingCount = 0,
    this.onToggleTask,
    this.onToggleContributesToCount,
    this.onTapTask,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final instance = currentInstance;
    final progress = instance != null && habit.targetCount > 0
        ? (instance.currentProgress / habit.targetCount).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(habit.title, style: Theme.of(context).textTheme.titleMedium),
                    ),
                    Chip(
                      label: Text(switch (habit.period) {
                        HabitPeriod.daily => 'Daily',
                        HabitPeriod.weekly => 'Weekly',
                        HabitPeriod.monthly => 'Monthly',
                      }),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (onDelete != null)
                      IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete),
                  ],
                ),
                if (habit.description.isNotEmpty) Text(habit.description),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 4),
                Text(
                  instance != null
                      ? '${instance.currentProgress} / ${habit.targetCount} '
                          '· due ${_formatDeadline(instance)}'
                      : 'No active cycle yet',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
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
                      if (habit.targetCount > 0)
                        IconButton(
                          icon: Icon(
                            task.contributesToCount ? Icons.check_circle : Icons.radio_button_unchecked,
                            color: task.contributesToCount
                                ? Colors.green
                                : Theme.of(context).disabledColor,
                          ),
                          tooltip: task.contributesToCount
                              ? 'Counts toward habit'
                              : contributingCount >= habit.targetCount
                                  ? 'Limit of ${habit.targetCount} contributing tasks reached'
                                  : 'Mark as counting toward habit',
                          onPressed: !task.contributesToCount && contributingCount >= habit.targetCount
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

  String _formatDeadline(Goal instance) {
    final dueDate = instance.dueDate;
    if (dueDate != null) return DateFormat.MMMd().add_Hm().format(dueDate);
    return DateFormat.MMMd().format(instance.endDate!);
  }
}
