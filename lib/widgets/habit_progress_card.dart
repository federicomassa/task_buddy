import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/goal.dart';
import '../models/habit.dart';

class HabitProgressCard extends StatelessWidget {
  final Habit habit;
  final Goal? currentInstance;
  final VoidCallback? onDelete;

  const HabitProgressCard({
    super.key,
    required this.habit,
    required this.currentInstance,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final instance = currentInstance;
    final progress = instance != null && habit.targetCount > 0
        ? (instance.currentProgress / habit.targetCount).clamp(0.0, 1.0)
        : 0.0;

    return Card(
      child: Padding(
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
    );
  }

  String _formatDeadline(Goal instance) {
    final dueDate = instance.dueDate;
    if (dueDate != null) return DateFormat.MMMd().add_Hm().format(dueDate);
    return DateFormat.MMMd().format(instance.endDate!);
  }
}
