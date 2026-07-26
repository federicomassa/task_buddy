import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/active_hours.dart';
import '../../core/calendar_math.dart';
import '../../core/drop_resolution.dart';
import '../../core/task_card_style.dart';
import '../../models/task.dart';
import '../../models/user_settings.dart';
import '../../providers/app_providers.dart';
import '../tasks/task_form.dart';

const double _dayHeight = 24 * pxPerHour;

enum _DropDialogResult { cancel, scheduleAnyway, respectBreaks }

/// The Today screen's left-hand pane: a scrollable midnight-to-midnight
/// timeline showing today's scheduled tasks as positioned blocks, and
/// accepting drag-and-drop from the unscheduled task list. Active-hours
/// breaks (e.g. lunch) are shaded, and a task whose duration spans a break
/// renders as multiple blocks — one per side of the break — rather than
/// overlapping it.
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

  Future<void> _handleDrop(Task task, Offset globalOffset) async {
    final snapped = _snappedMinutesForOffset(globalOffset);
    if (snapped == null) return;

    final activeHours =
        ref.read(userSettingsStreamProvider).value?.activeHourRanges ?? defaultActiveHourRanges;
    final durationMinutes = task.estimatedDuration?.inMinutes ?? 0;

    if (!dropNeedsConfirmation(droppedMinutes: snapped, durationMinutes: durationMinutes, activeHours: activeHours)) {
      final segments = directDropPlacement(droppedMinutes: snapped, durationMinutes: durationMinutes);
      ref.read(taskRepositoryProvider).scheduleTaskRanges(task, taskTimeRangesForDay(widget.today, segments));
      return;
    }

    final choice = await showDialog<_DropDialogResult>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Outside active hours'),
        content: const Text(
          'This time falls during a break or outside your active hours. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_DropDialogResult.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(_DropDialogResult.respectBreaks),
            child: const Text('Schedule, but respect breaks'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(_DropDialogResult.scheduleAnyway),
            child: const Text('Schedule anyway'),
          ),
        ],
      ),
    );

    final dropChoice = switch (choice) {
      _DropDialogResult.scheduleAnyway => DropChoice.scheduleAnyway,
      _DropDialogResult.respectBreaks => DropChoice.respectBreaks,
      _DropDialogResult.cancel || null => null,
    };
    if (dropChoice == null) return;

    final placement = resolveConfirmedDrop(
      choice: dropChoice,
      droppedMinutes: snapped,
      durationMinutes: durationMinutes,
      activeHours: activeHours,
    );
    await ref.read(taskRepositoryProvider).updateTask(task.copyWith(
          estimatedExecutionTimeRanges: taskTimeRangesForDay(widget.today, placement.segments),
          constrainedToWorkingHours: placement.constrainedToWorkingHours,
        ));
  }

  List<Widget> _blocksForTask(Task task) {
    final segments = task.estimatedExecutionTimeRanges
        .map((r) => TimeRange(
              startMinutes: r.start.hour * 60 + r.start.minute,
              endMinutes: r.end.hour * 60 + r.end.minute,
            ))
        .toList();
    return [
      for (var i = 0; i < segments.length; i++)
        _ScheduledBlock(
          task: task,
          today: widget.today,
          segment: segments[i],
          isPrimary: i == 0,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final scheduledTasks = ref.watch(todayScheduledTasksProvider);
    final activeHours = ref.watch(userSettingsStreamProvider).value?.activeHourRanges ?? defaultActiveHourRanges;
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
                _OffHoursShading(activeHours: activeHours),
                for (final task in scheduledTasks) ..._blocksForTask(task),
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

/// Shades the parts of the day outside every active-hours range (before the
/// work day starts, breaks like lunch between ranges, and after it ends),
/// so it's visually clear why a task's blocks might be split.
class _OffHoursShading extends StatelessWidget {
  final List<TimeRange> activeHours;

  const _OffHoursShading({required this.activeHours});

  @override
  Widget build(BuildContext context) {
    final ranges = [...activeHours]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    final gaps = <TimeRange>[];
    var cursor = 0;
    for (final r in ranges) {
      if (r.startMinutes > cursor) {
        gaps.add(TimeRange(startMinutes: cursor, endMinutes: r.startMinutes));
      }
      if (r.endMinutes > cursor) cursor = r.endMinutes;
    }
    if (cursor < 24 * 60) {
      gaps.add(TimeRange(startMinutes: cursor, endMinutes: 24 * 60));
    }

    return IgnorePointer(
      child: Stack(
        children: [
          for (final gap in gaps)
            Positioned(
              top: gap.startMinutes / 60 * pxPerHour,
              left: 0,
              right: 0,
              height: (gap.endMinutes - gap.startMinutes) / 60 * pxPerHour,
              child: Container(color: Colors.black.withValues(alpha: 0.12)),
            ),
        ],
      ),
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

/// One block for one real-time segment of a scheduled task. A task whose
/// duration spans a break renders as multiple of these (one per side of the
/// break) via [_DayCalendarViewState._blocksForTask]; only the first
/// ([isPrimary]) segment is draggable, so dragging always has a single,
/// unambiguous handle.
class _ScheduledBlock extends ConsumerWidget {
  final Task task;
  final DateTime today;
  final TimeRange segment;
  final bool isPrimary;

  const _ScheduledBlock({
    required this.task,
    required this.today,
    required this.segment,
    required this.isPrimary,
  });

  // Below this, the bar is too short to fit even one line of text.
  static const double _tinyThresholdMinutes = 15;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = segment.startMinutes / 60 * pxPerHour;
    final rawHeight = (segment.endMinutes - segment.startMinutes) / 60 * pxPerHour;
    final height = rawHeight < 1.0 ? 1.0 : (rawHeight > _dayHeight - top ? _dayHeight - top : rawHeight);
    final isTiny = segment.endMinutes - segment.startMinutes < _tinyThresholdMinutes;
    final style = taskCardStyle(task, today: today);

    final bar = Container(
      // A hard height (not just a minimum) so the block's on-screen size
      // always matches the task's real duration exactly — otherwise a short
      // task's title would force the box to grow past its slot and overlap
      // whatever's positioned right after it.
      height: height,
      clipBehavior: isTiny ? Clip.none : Clip.hardEdge,
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
        // A border in the page background color, rather than no border at
        // all, so back-to-back blocks (one ending exactly when the next
        // begins) still show a visible seam instead of reading as one
        // continuous slab.
        border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
      ),
      padding: isTiny ? null : const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      alignment: isTiny ? null : Alignment.topLeft,
      child: isTiny
          ? null
          : Text(
              isPrimary ? task.title : '↳ ${task.title}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
    );

    Widget content = SizedBox(height: height, child: bar);
    // How far above the segment's real start time this block's wrapping box
    // (and therefore its tap/drag hit-test area) needs to begin, to fully
    // cover a floating label that pokes out past the bar. Zero for
    // normal-sized tasks.
    var topOffset = 0.0;

    if (isTiny) {
      // Below the `_tinyThresholdMinutes` bar is too short to hold any
      // legible text at all (down to a couple of px for a 5-minute task),
      // so instead of cramming/clipping the title inside it, the title is a
      // separate chip floating on top — darker than the bar so it also
      // reads against a plain white page background — vertically centered
      // on the bar and pushed to its right edge, so it's less likely to
      // land exactly on top of the same floating label for whatever task is
      // stacked immediately above or below it.
      //
      // The chip has no fixed height: its size comes entirely from padding
      // around the text, so it grows automatically with the user's system
      // text-scale/accessibility settings instead of being tuned for one
      // assumed font size and clipping (or looking oddly empty) on a device
      // with different settings.
      final chipColor = Color.alphaBlend(Colors.black.withValues(alpha: 0.25), style.color);
      final chip = Container(
        margin: const EdgeInsets.only(right: 2),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
        decoration: BoxDecoration(
          color: chipColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isPrimary ? task.title : '↳ ${task.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      );

      // Pinning this to the segment's own height via `top: 0, bottom: 0`
      // (as a previous version did) constrains the label's *available*
      // height to match — for a 5-minute task that's a handful of px, and
      // once the chip's padding is subtracted from that the child is left
      // with ~0 (or negative, clamped to 0) height to render into, which is
      // why the text disappeared entirely rather than just spilling over a
      // bit. Giving it real headroom (anchored to the segment's vertical
      // midpoint, not its height) fixes that; `Align` still only makes the
      // *visible* chip as big as its own text needs (see the note on
      // Container above), so this headroom doesn't force the chip to look
      // stretched or oversized — it's just room to lay out in.
      const labelAllocation = 32.0;

      // The chip is centered on the bar's midpoint and (for a genuinely
      // tiny task) is taller than the bar itself, so it pokes out above and
      // below by this much. Rather than let it visually overflow past the
      // wrapping box (which would make it unclickable — a widget's hit
      // testing rejects taps outside its own laid-out size, before it ever
      // asks its children), the wrapping box is grown to this full envelope
      // and shifted up to compensate, so the tap/drag target actually
      // covers the whole visible chip.
      final envelope = tinyBlockEnvelope(barHeight: height, labelAllocation: labelAllocation);
      final overflow = envelope.topOffset;
      final envelopeHeight = envelope.envelopeHeight;
      topOffset = overflow;

      final label = Positioned(
        top: (envelopeHeight - labelAllocation) / 2,
        height: labelAllocation,
        left: 0,
        right: 0,
        child: Align(alignment: Alignment.centerRight, child: chip),
      );

      content = SizedBox(
        height: envelopeHeight,
        child: Stack(
          children: [
            Positioned(top: overflow, left: 0, right: 0, height: height, child: bar),
            label,
          ],
        ),
      );
    }

    final tappable = GestureDetector(
      onTap: () => showTaskFormDialog(context, task: task),
      onDoubleTap: () {},
      child: content,
    );

    return Positioned(
      top: top - topOffset,
      left: 52,
      right: 4,
      child: (!isPrimary || task.estimatedDuration == null)
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
