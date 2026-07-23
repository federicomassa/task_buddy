import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/calendar_math.dart';
import '../../core/task_card_style.dart';
import '../../models/task.dart';
import '../../providers/app_providers.dart';
import '../tasks/task_form.dart';

const double _dayHeight = 24 * pxPerHour;

/// The Today screen's left-hand pane: a scrollable midnight-to-midnight
/// timeline showing today's scheduled tasks as positioned blocks, and
/// accepting drag-and-drop from the unscheduled task list.
class DayCalendarView extends ConsumerStatefulWidget {
  final DateTime today;

  const DayCalendarView({super.key, required this.today});

  @override
  ConsumerState<DayCalendarView> createState() => _DayCalendarViewState();
}

class _DayCalendarViewState extends ConsumerState<DayCalendarView> {
  final _stackKey = GlobalKey();

  /// Minutes from midnight, snapped to the nearest 15-minute increment, for
  /// a global drag offset. Null if the calendar isn't laid out yet.
  int? _snappedMinutesForOffset(Offset globalOffset) {
    final renderBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final local = renderBox.globalToLocal(globalOffset);
    return snappedMinutesForLocalY(local.dy, dayHeightPx: _dayHeight, pxPerHour: pxPerHour);
  }

  void _handleDrop(Task task, Offset globalOffset) {
    final snapped = _snappedMinutesForOffset(globalOffset);
    if (snapped == null) return;
    final newScheduledDate = DateTime(
      widget.today.year,
      widget.today.month,
      widget.today.day,
      snapped ~/ 60,
      snapped % 60,
    );

    ref.read(taskRepositoryProvider).scheduleTask(task, newScheduledDate);
  }

  @override
  Widget build(BuildContext context) {
    final scheduledTasks = ref.watch(todayScheduledTasksProvider);
    final dragPreview = ref.watch(dragPreviewProvider);
    final previewMinutes =
        dragPreview == null ? null : _snappedMinutesForOffset(dragPreview.globalPosition);

    return DragTarget<Task>(
      onAcceptWithDetails: (details) => _handleDrop(details.data, details.offset),
      builder: (context, candidateData, rejectedData) {
        return SingleChildScrollView(
          child: SizedBox(
            key: _stackKey,
            height: _dayHeight,
            child: Stack(
              children: [
                _HourGrid(),
                for (final task in scheduledTasks)
                  _ScheduledBlock(task: task, today: widget.today),
                if (previewMinutes != null)
                  _DropPreview(
                    minutes: previewMinutes,
                    height: taskBlockHeight(dragPreview!.task),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HourGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(24, (hour) {
        return SizedBox(
          height: pxPerHour,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 48,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    '${hour.toString().padLeft(2, '0')}:00',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
              const Expanded(child: Divider(height: 1)),
            ],
          ),
        );
      }),
    );
  }
}

/// Ghost block shown at the snapped drop time while a task is being
/// dragged over the calendar, so the target time is visible before drop.
class _DropPreview extends StatelessWidget {
  final int minutes;
  final double height;

  const _DropPreview({required this.minutes, required this.height});

  @override
  Widget build(BuildContext context) {
    final top = minutes / 60 * pxPerHour;
    final label = '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
        '${(minutes % 60).toString().padLeft(2, '0')}';
    final color = Theme.of(context).colorScheme.primary;

    return Positioned(
      top: top,
      left: 52,
      right: 4,
      height: height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: color, width: 2),
            borderRadius: BorderRadius.circular(4),
            color: color.withValues(alpha: 0.15),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          alignment: Alignment.topLeft,
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

class _ScheduledBlock extends ConsumerWidget {
  final Task task;
  final DateTime today;

  const _ScheduledBlock({required this.task, required this.today});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sched = task.scheduledDate!;
    final top = (sched.hour * 60 + sched.minute) / 60 * pxPerHour;
    final height = taskBlockHeight(task).clamp(1.0, _dayHeight - top);
    final style = taskCardStyle(task, today: today);

    final content = Container(
      constraints: BoxConstraints(minHeight: height),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      alignment: Alignment.topLeft,
      child: Text(
        task.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );

    final tappable = GestureDetector(
      onTap: () => showTaskFormDialog(context, task: task),
      onDoubleTap: () {},
      child: content,
    );

    return Positioned(
      top: top,
      left: 52,
      right: 4,
      child: task.timeEstimate == null
          ? tappable
          : LongPressDraggable<Task>(
              data: task,
              // Keep the feedback/drop coordinate space anchored to the
              // pointer rather than the grabbed point within the card, so it
              // matches the ghost preview's coordinates exactly.
              dragAnchorStrategy: pointerDragAnchorStrategy,
              feedback: Material(
                color: Colors.transparent,
                child: SizedBox(width: 220, child: content),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: tappable),
              onDragUpdate: ref.onTaskDragUpdate(task),
              onDragEnd: ref.onTaskDragEnd(),
              child: tappable,
            ),
    );
  }
}
