import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/category.dart';
import '../models/task.dart';
import 'category_pickers.dart';
import 'format_utils.dart';

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

    final tile = ListTile(
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
          if (task.scheduledDate != null)
            Text('Scheduled ${DateFormat.yMMMd().add_Hm().format(task.scheduledDate!)}'),
          if (task.timeEstimate != null)
            Text('~${formatEstimate(task.timeEstimate!)}'),
          if (task.isRecurrent)
            Icon(Icons.repeat, size: 16, color: Theme.of(context).colorScheme.primary),
          for (final c in linkedCategories) CategoryChip(category: c),
        ],
      ),
      trailing: onDelete != null
          ? IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete)
          : null,
    );

    if (onTap == null) return tile;

    // A single GestureDetector handles both taps so the arena can tell a
    // single tap from the first half of a double tap; without onDoubleTap
    // here, each click of a double click fired its own onTap.
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: () {},
      child: tile,
    );
  }
}
