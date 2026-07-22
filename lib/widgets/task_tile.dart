import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/color_utils.dart';
import '../models/category.dart';
import '../models/task.dart';
import 'category_pickers.dart';

class TaskTile extends StatelessWidget {
  final Task task;
  final List<Category> categories;
  final ValueChanged<bool?> onToggle;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TaskTile({
    super.key,
    required this.task,
    required this.categories,
    required this.onToggle,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final linkedCategories = task.categoryIds
        .map((id) => categoryById(categories, id))
        .whereType<Category>()
        .toList();

    return ListTile(
      onTap: onTap,
      leading: Checkbox(value: task.isCompleted, onChanged: onToggle),
      title: Text(
        task.title,
        style: task.isCompleted
            ? const TextStyle(decoration: TextDecoration.lineThrough)
            : null,
      ),
      subtitle: Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (task.dueDate != null)
            Text(DateFormat.yMMMd().add_Hm().format(task.dueDate!)),
          if (task.timeEstimate != null)
            Text('~${_formatEstimate(task.timeEstimate!)}'),
          if (task.isRecurrent)
            Icon(Icons.repeat, size: 16, color: Theme.of(context).colorScheme.primary),
          for (final c in linkedCategories)
            Chip(
              label: Text(c.name, style: const TextStyle(fontSize: 11)),
              avatar: CircleAvatar(backgroundColor: colorFromHex(c.colorHex)),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
        ],
      ),
      trailing: onDelete != null
          ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete)
          : null,
    );
  }

  String _formatEstimate(Duration estimate) {
    final days = estimate.inDays;
    final hours = estimate.inHours % 24;
    final minutes = estimate.inMinutes % 60;
    final parts = <String>[
      if (days > 0) '${days}d',
      if (hours > 0) '${hours}h',
      if (minutes > 0) '${minutes}m',
    ];
    return parts.isEmpty ? '0m' : parts.join(' ');
  }
}
