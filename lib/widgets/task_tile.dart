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
            Text(DateFormat.yMMMd().format(task.dueDate!)),
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
}
