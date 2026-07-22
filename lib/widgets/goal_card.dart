import 'package:flutter/material.dart';

import '../core/color_utils.dart';
import '../models/category.dart';
import '../models/goal.dart';
import 'category_pickers.dart';

class GoalCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final category = categoryById(categories, goal.categoryId);
    final target = goal.targetCount;
    final progress = target != null && target > 0
        ? (goal.currentProgress / target).clamp(0.0, 1.0)
        : null;

    return Card(
      child: ListTile(
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
    );
  }
}
