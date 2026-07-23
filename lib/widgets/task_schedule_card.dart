import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/task_card_style.dart';
import '../models/category.dart';
import '../models/task.dart';
import '../providers/app_providers.dart';
import 'category_pickers.dart';
import 'format_utils.dart';

/// A draggable card representing an unscheduled task, used in the Today
/// screen's task list. Long-press to drag onto the calendar and schedule it.
class TaskScheduleCard extends ConsumerWidget {
  final Task task;
  final List<Category> categories;
  final DateTime today;

  const TaskScheduleCard({
    super.key,
    required this.task,
    required this.categories,
    required this.today,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = _CardContent(task: task, categories: categories, today: today);

    if (task.timeEstimate == null) {
      // Tasks without a time estimate can't be scheduled on the calendar,
      // so they aren't draggable at all.
      return content;
    }

    return LongPressDraggable<Task>(
      data: task,
      // The default anchor keeps the feedback offset by wherever within the
      // card you grabbed it, which would make DragTarget's reported drop
      // position (used to compute the scheduled time) diverge from the
      // pointer position (used for the live ghost preview). Anchoring to the
      // pointer keeps both in the same coordinate space.
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 260, child: content),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: content),
      onDragUpdate: ref.onTaskDragUpdate(task),
      onDragEnd: ref.onTaskDragEnd(),
      child: content,
    );
  }
}

class _CardContent extends StatelessWidget {
  final Task task;
  final List<Category> categories;
  final DateTime today;

  const _CardContent({required this.task, required this.categories, required this.today});

  @override
  Widget build(BuildContext context) {
    final style = taskCardStyle(task, today: today);
    final overdue = isTaskOverdue(task, today: today);
    final linkedCategories = task.categoryIds
        .map((id) => categoryById(categories, id))
        .whereType<Category>()
        .toList();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Container(
        constraints: BoxConstraints(minHeight: style.height),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: style.color, width: 6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              task.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (overdue)
                  const Text('Overdue', style: TextStyle(color: Colors.red, fontSize: 11)),
                if (task.timeEstimate != null)
                  Text('~${formatEstimate(task.timeEstimate!)}', style: const TextStyle(fontSize: 11)),
                for (final c in linkedCategories) CategoryChip(category: c, fontSize: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
