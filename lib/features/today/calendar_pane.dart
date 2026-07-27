import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/active_hours.dart';
import '../../core/calendar_math.dart';
import '../../core/date_utils.dart';
import '../../core/drag_reorder.dart';
import '../../core/drop_resolution.dart';
import '../../core/task_card_style.dart';
import '../../models/task.dart';
import '../../models/user_settings.dart';
import '../../providers/app_providers.dart';
import '../tasks/task_form.dart';

const double _dayHeight = 24 * pxPerHour;
const double _leftGutter = 52;
const double _rightMargin = 4;
// How far each successive overlapping column is pushed right, as a fraction
// of the available width — the first (non-overlapping) column is always at
// offset 0, i.e. unaffected and full width, per the cascading design.
const double _columnOffsetFraction = 0.18;
const double _minColumnWidth = 40.0;
// Tiny-chip collision packing: the max width a chip's title text is measured
// and rendered at (longer titles are clipped with an ellipsis), the gap kept
// between two colliding chips, and the padding added on top of the measured
// text width to get the chip's full footprint.
const double _tinyChipMaxTextWidth = 110.0;
const double _tinyChipGap = 4.0;
const double _tinyChipHorizontalPadding = 8.0; // matches chip's horizontal:4 padding * 2

/// Real rendered width of a tiny chip's title, for width-aware collision
/// packing (see [packChipsAvoidingOverlap]) — capped to [_tinyChipMaxTextWidth]
/// (the same cap applied when actually rendering the chip's [Text], via a
/// [ConstrainedBox] in [_buildTinyChip]) and respecting the device's text
/// scale, so measurement and rendering can't drift apart.
double _measureTinyChipTextWidth(BuildContext context, String text) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: const TextStyle(fontSize: 10)),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  return painter.width;
}

/// The floating title chip for a tiny (< [tinyThresholdMinutes]-minute) task's
/// block — darker than the bar so it also reads against a plain page
/// background, shifted left by [chipRightInset] (see
/// [packChipsAvoidingOverlap]) so it clears whatever tiny task's chip it's
/// closest to in time. Shared between [_TinyChipLabel] (the real, always-on-
/// top rendering) and [_ScheduledBlock]'s drag-feedback ghost.
Widget _buildTinyChip({
  required Task task,
  required bool isPrimary,
  required Color barColor,
  required double chipRightInset,
}) {
  final chipColor = Color.alphaBlend(Colors.black.withValues(alpha: 0.25), barColor);
  return Container(
    margin: EdgeInsets.only(right: 2 + chipRightInset),
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    decoration: BoxDecoration(
      color: chipColor,
      borderRadius: BorderRadius.circular(6),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _tinyChipMaxTextWidth),
      child: Text(
        isPrimary ? task.title : '↳ ${task.title}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
    ),
  );
}

/// Left/width for a segment's rendering column, per the Google-Calendar-style
/// cascade: the first column (no overlap) keeps its full natural width
/// untouched; each later, overlapping column is pushed further right by a
/// fraction of the available width and shares the same right edge as the
/// rest, so it overlaps (rather than shrinks) everything under it. Shared by
/// [_ScheduledBlock] and [_TinyChipLabel] so a tiny task's floating chip
/// lines up with its own bar's column.
({double left, double width}) _cascadeColumnGeometry({
  required int columnIndex,
  required double availableWidth,
}) {
  final columnOffset = availableWidth * _columnOffsetFraction;
  final rightEdge = _leftGutter + availableWidth;
  final left = (_leftGutter + columnIndex * columnOffset).clamp(_leftGutter, rightEdge - _minColumnWidth);
  final width = (rightEdge - left).clamp(_minColumnWidth, availableWidth);
  return (left: left, width: width);
}

/// The floating title chip for one tiny task's block, rendered as its own
/// top-level layer (see _DayCalendarViewState._buildBlocks) so it always
/// paints on top of every task bar, regardless of which overlap column the
/// bar itself is in. Purely visual — [IgnorePointer]'d, since the tap/drag
/// target for a tiny task is the envelope-sized hit area on its
/// [_ScheduledBlock], which already covers the area the chip visually
/// occupies.
class _TinyChipLabel extends StatelessWidget {
  final Task task;
  final DateTime today;
  final TimeRange segment;
  final bool isPrimary;
  final int columnIndex;
  final double availableWidth;
  final double chipRightInset;

  const _TinyChipLabel({
    required this.task,
    required this.today,
    required this.segment,
    required this.isPrimary,
    required this.columnIndex,
    required this.availableWidth,
    required this.chipRightInset,
  });

  @override
  Widget build(BuildContext context) {
    final geometry = segmentGeometry(segment: segment, dayHeightPx: _dayHeight, pxPerHour: pxPerHour);
    final style = taskCardStyle(task, today: today);
    final column = _cascadeColumnGeometry(columnIndex: columnIndex, availableWidth: availableWidth);
    final envelope = tinyBlockEnvelope(barHeight: geometry.height, labelAllocation: tinyChipLabelAllocation);

    return Positioned(
      top: geometry.top - envelope.topOffset,
      left: column.left,
      width: column.width,
      height: envelope.envelopeHeight,
      child: IgnorePointer(
        child: Align(
          alignment: Alignment.centerRight,
          child: _buildTinyChip(
            task: task,
            isPrimary: isPrimary,
            barColor: style.color,
            chipRightInset: chipRightInset,
          ),
        ),
      ),
    );
  }
}

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
  /// a global drag offset — then magnetically re-snapped to the end time of
  /// another task scheduled today (excluding [excludeTaskId], the task being
  /// dragged) if one is close by, so the drop lines its start up flush with
  /// that task's end (see [snapToNeighborEnd]). Null if the calendar isn't
  /// laid out yet.
  int? _snappedMinutesForOffset(Offset globalOffset, {String? excludeTaskId}) {
    final renderBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final local = renderBox.globalToLocal(globalOffset);
    final gridSnapped = snappedMinutesForLocalY(local.dy, dayHeightPx: _dayHeight, pxPerHour: pxPerHour);

    final neighborEndMinutes = [
      for (final t in ref.read(todayScheduledTasksProvider))
        if (t.id != excludeTaskId)
          for (final r in t.estimatedExecutionTimeRanges)
            if (dateOnly(r.start) == widget.today) r.end.hour * 60 + r.end.minute,
    ];
    return snapToNeighborEnd(gridSnapped, neighborEndMinutes).clamp(0, 24 * 60 - 15);
  }

  Future<void> _handleDrop(Task task, Offset globalOffset) async {
    final snapped = _snappedMinutesForOffset(globalOffset, excludeTaskId: task.id);
    if (snapped == null) return;

    final activeHours =
        ref.read(userSettingsStreamProvider).value?.activeHourRanges ?? defaultActiveHourRanges;
    final durationMinutes = task.estimatedDuration?.inMinutes ?? 0;

    if (!dropNeedsConfirmation(droppedMinutes: snapped, durationMinutes: durationMinutes, activeHours: activeHours)) {
      final segments = directDropPlacement(droppedMinutes: snapped, durationMinutes: durationMinutes);
      await _persistPlacement(task, segments);
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
    await ref.read(taskRepositoryProvider).scheduleTaskRanges(
          task,
          taskTimeRangesForDay(widget.today, placement.segments),
          constrainedToWorkingHours: placement.constrainedToWorkingHours,
        );
    await _cascadeOthersIfNeeded(task, placement.segments);
  }

  /// Persists [task]'s new placement at [segments] (a direct, unconfirmed
  /// drop — see [directDropPlacement]), then, unless [allowOverlapProvider]
  /// is on, cascades any other tasks scheduled today that now overlap it.
  Future<void> _persistPlacement(Task task, List<TimeRange> segments) async {
    await ref.read(taskRepositoryProvider).scheduleTaskRanges(task, taskTimeRangesForDay(widget.today, segments));
    await _cascadeOthersIfNeeded(task, segments);
  }

  /// If overlaps aren't allowed, pushes forward any other task scheduled
  /// today whose time now collides with [task]'s freshly-placed [segments],
  /// cascading further pushes as needed (see [resolveOverlapFreeDrop]).
  /// [task]'s own placement is never altered here — it already landed
  /// exactly where dropped.
  Future<void> _cascadeOthersIfNeeded(Task task, List<TimeRange> segments) async {
    if (ref.read(allowOverlapProvider)) return;
    if (segments.isEmpty) return;

    final droppedStart = segments.first.startMinutes;
    final droppedEnd = segments.last.endMinutes;

    final otherTasks = ref.read(todayScheduledTasksProvider).where((t) => t.id != task.id).toList();
    final otherBlocks = [
      for (final t in otherTasks)
        if (_todayBlockMinutes(t) case (final start, final end))
          ReorderedBlock(taskId: t.id, startMinutes: start, endMinutes: end),
    ];

    final resolved = resolveOverlapFreeDrop(
      draggedTaskId: task.id,
      droppedStart: droppedStart,
      durationMinutes: droppedEnd - droppedStart,
      otherBlocks: otherBlocks,
    );

    final otherTasksById = {for (final t in otherTasks) t.id: t};
    final repo = ref.read(taskRepositoryProvider);
    await Future.wait([
      for (final block in resolved)
        if (otherTasksById[block.taskId] case final other?)
          repo.scheduleTaskRanges(
            other,
            taskTimeRangesForDay(widget.today, [TimeRange(startMinutes: block.startMinutes, endMinutes: block.endMinutes)]),
          ),
    ]);
  }

  /// The minutes-since-midnight span [task] occupies on [widget.today],
  /// spanning from the earliest to the latest of its ranges for that day
  /// (collapsing any break-split segments into one contiguous block, the
  /// same simplification [directDropPlacement] already makes for a single
  /// drop).
  (int, int) _todayBlockMinutes(Task task) {
    final ranges = task.estimatedExecutionTimeRanges.where((r) => dateOnly(r.start) == widget.today);
    var start = 24 * 60;
    var end = 0;
    for (final r in ranges) {
      final s = r.start.hour * 60 + r.start.minute;
      final e = r.end.hour * 60 + r.end.minute;
      if (s < start) start = s;
      if (e > end) end = e;
    }
    return (start, end);
  }

  List<_RenderSegment> _flattenSegments(List<Task> tasks) {
    return [
      for (final task in tasks)
        for (var i = 0; i < task.estimatedExecutionTimeRanges.length; i++)
          _RenderSegment(
            task: task,
            range: TimeRange(
              startMinutes: task.estimatedExecutionTimeRanges[i].start.hour * 60 +
                  task.estimatedExecutionTimeRanges[i].start.minute,
              endMinutes: task.estimatedExecutionTimeRanges[i].end.hour * 60 +
                  task.estimatedExecutionTimeRanges[i].end.minute,
            ),
            isPrimary: i == 0,
            segmentIndex: i,
          ),
    ];
  }

  List<Widget> _buildBlocks(BuildContext context, List<_RenderSegment> renderSegments, double maxWidth) {
    final availableWidth = (maxWidth - _leftGutter - _rightMargin).clamp(0.0, double.infinity);

    final columnsById = {
      for (final c in assignColumns([
        for (final s in renderSegments)
          LayoutInterval(id: s.layoutId, startMinutes: s.range.startMinutes, endMinutes: s.range.endMinutes),
      ]))
        c.id: c,
    };

    final geometries = {
      for (final s in renderSegments)
        s.layoutId: segmentGeometry(segment: s.range, dayHeightPx: _dayHeight, pxPerHour: pxPerHour),
    };

    // Every rendering column's box shares the same right edge (see
    // _ScheduledBlock's cascade layout), so every tiny chip's Align(centerRight)
    // anchors to the same absolute pixel position regardless of columnIndex —
    // collision packing therefore has to consider ALL tiny chips together in
    // one global pass, not grouped by column.
    final tinyChipBoxes = <ChipBox>[];
    for (final s in renderSegments) {
      final geometry = geometries[s.layoutId]!;
      if (!geometry.isTiny) continue;
      final envelope = tinyBlockEnvelope(barHeight: geometry.height, labelAllocation: tinyChipLabelAllocation);
      final label = s.isPrimary ? s.task.title : '↳ ${s.task.title}';
      final textWidth = _measureTinyChipTextWidth(context, label).clamp(0.0, _tinyChipMaxTextWidth);
      tinyChipBoxes.add(ChipBox(
        id: s.layoutId,
        top: geometry.top - envelope.topOffset,
        bottom: geometry.top - envelope.topOffset + envelope.envelopeHeight,
        width: textWidth + _tinyChipHorizontalPadding,
      ));
    }
    final chipPlacementById = {
      for (final p in packChipsAvoidingOverlap(tinyChipBoxes, gap: _tinyChipGap)) p.id: p,
    };

    // Paint later (further-right-offset) columns on top, Google-Calendar
    // style, so an offset task reads as sitting above the ones it overlaps
    // rather than being hidden underneath them.
    final ordered = [...renderSegments]
      ..sort((a, b) => columnsById[a.layoutId]!.columnIndex.compareTo(columnsById[b.layoutId]!.columnIndex));

    final bars = [
      for (final s in ordered)
        _ScheduledBlock(
          task: s.task,
          today: widget.today,
          segment: s.range,
          isPrimary: s.isPrimary,
          columnIndex: columnsById[s.layoutId]!.columnIndex,
          availableWidth: availableWidth,
          chipRightInset: chipPlacementById[s.layoutId]?.rightInset ?? 0.0,
        ),
    ];

    // Tiny-task title chips are their own layer, appended after every bar, so
    // a chip always paints on top of every task box — including bars from
    // later, higher-cascade-column tasks that would otherwise paint over it —
    // rather than z-order being tied to each block's own bar-vs-chip stack.
    final labels = [
      for (final s in renderSegments)
        if (geometries[s.layoutId]!.isTiny)
          _TinyChipLabel(
            task: s.task,
            today: widget.today,
            segment: s.range,
            isPrimary: s.isPrimary,
            columnIndex: columnsById[s.layoutId]!.columnIndex,
            availableWidth: availableWidth,
            chipRightInset: chipPlacementById[s.layoutId]?.rightInset ?? 0.0,
          ),
    ];

    return [...bars, ...labels];
  }

  @override
  Widget build(BuildContext context) {
    final scheduledTasks = ref.watch(todayScheduledTasksProvider);
    final activeHours = ref.watch(userSettingsStreamProvider).value?.activeHourRanges ?? defaultActiveHourRanges;
    final dragPreview = ref.watch(dragPreviewProvider);
    final previewMinutes =
        dragPreview == null
            ? null
            : _snappedMinutesForOffset(dragPreview.globalPosition, excludeTaskId: dragPreview.task.id);
    final renderSegments = _flattenSegments(scheduledTasks);

    return DragTarget<Task>(
      onAcceptWithDetails: (details) => _handleDrop(details.data, details.offset),
      builder: (context, candidateData, rejectedData) {
        return SingleChildScrollView(
          child: SizedBox(
            key: _stackKey,
            height: _dayHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    _HourGrid(),
                    _OffHoursShading(activeHours: activeHours),
                    ..._buildBlocks(context, renderSegments, constraints.maxWidth),
                    const _NowLine(),
                    if (previewMinutes != null)
                      _DropPreview(
                        minutes: previewMinutes,
                        height: taskBlockHeight(dragPreview!.task),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// One real-time segment to render, carrying enough identity to map back
/// through [assignColumns]'s [ColumnAssignment.id].
class _RenderSegment {
  final Task task;
  final TimeRange range;
  final bool isPrimary;
  final int segmentIndex;

  const _RenderSegment({
    required this.task,
    required this.range,
    required this.isPrimary,
    required this.segmentIndex,
  });

  Object get layoutId => (task.id, segmentIndex);
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

/// A thin horizontal line marking the current time (now) on the calendar.
class _NowLine extends ConsumerWidget {
  const _NowLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider).now();
    final nowMinutes = now.hour * 60 + now.minute;
    final top = nowMinutes / 60 * pxPerHour;

    // Only show the line if the current time is within the visible day (0-24h)
    if (nowMinutes < 0 || nowMinutes >= 24 * 60) {
      return const SizedBox.shrink();
    }

    // Bright green — stands out against both light/dark themes and task colors.
    const color = Color(0xFF00E676);

    // Extend from the task panel left edge (_leftGutter) plus ~30% of the
    // hour gutter width into the hour labels, so it "infringes a little bit".
    const double leftInset = _leftGutter - (_leftGutter * 0.3);

    return Positioned(
      top: top,
      left: leftInset,
      right: _rightMargin,
      child: IgnorePointer(
        child: Container(
          height: 2,
          color: color,
        ),
      ),
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
/// break) via [_DayCalendarViewState._flattenSegments]; only the first
/// ([isPrimary]) segment is draggable, so dragging always has a single,
/// unambiguous handle.
class _ScheduledBlock extends ConsumerWidget {
  final Task task;
  final DateTime today;
  final TimeRange segment;
  final bool isPrimary;
  final int columnIndex;
  final double availableWidth;
  final double chipRightInset;

  const _ScheduledBlock({
    required this.task,
    required this.today,
    required this.segment,
    required this.isPrimary,
    required this.columnIndex,
    required this.availableWidth,
    required this.chipRightInset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final geometry = segmentGeometry(segment: segment, dayHeightPx: _dayHeight, pxPerHour: pxPerHour);
    final top = geometry.top;
    final height = geometry.height;
    final isTiny = geometry.isTiny;
    final style = taskCardStyle(task, today: today);
    final column = _cascadeColumnGeometry(columnIndex: columnIndex, availableWidth: availableWidth);
    final left = column.left;
    final renderedWidth = column.width;

    final bar = Container(
      // A hard height (not just a minimum) so the block's on-screen size
      // always matches the task's real duration exactly — otherwise a short
      // task's title would force the box to grow past its slot and overlap
      // whatever's positioned right after it.
      height: height,
      clipBehavior: isTiny ? Clip.none : Clip.hardEdge,
      decoration: BoxDecoration(
        color: style.color,
        borderRadius: BorderRadius.circular(4),
        // A visibly dark seam (rather than a page-background-colored one, or
        // no border at all) so back-to-back blocks (one ending exactly when
        // the next begins) show a clear boundary instead of reading as one
        // continuous slab or looking like there's whitespace between them.
        border: Border.all(color: Colors.black.withValues(alpha: 0.35), width: 1.5),
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

    // The bar-only interactive content. For tiny tasks, the title itself is
    // NOT rendered here — it renders as a separate _TinyChipLabel layer, added
    // after every task's bar in _DayCalendarViewState._buildBlocks, so a tiny
    // task's floating label always paints on top of every bar (including ones
    // from later, higher-cascade-column tasks) rather than being tucked
    // underneath them. This box is still sized to the label's full envelope
    // (below), so tapping/dragging anywhere the (separately-painted) chip
    // visually appears still hits this same interactive area.
    Widget content = SizedBox(height: height, child: bar);
    // How far above the segment's real start time this block's wrapping box
    // (and therefore its tap/drag hit-test area) needs to begin, to fully
    // cover a floating label that pokes out past the bar. Zero for
    // normal-sized tasks.
    var topOffset = 0.0;
    // Only used for the drag-feedback ghost (see LongPressDraggable.feedback
    // below): since that ghost floats alone above everything else during a
    // drag, there's no cross-task z-order concern for it, so it can just
    // recombine the bar and chip visually, the way `content` used to before
    // tiny chips became their own top-level layer.
    Widget feedbackContent = content;

    if (isTiny) {
      // Below the `tinyThresholdMinutes` bar is too short to hold any
      // legible text at all (down to a couple of px for a 5-minute task), so
      // its title is rendered by a separate _TinyChipLabel widget instead of
      // here — see that class and the comment on `content` above.
      //
      // Pinning this box to the segment's own height via `top: 0, bottom: 0`
      // (as a previous version did) constrains the label's *available*
      // height to match — for a 5-minute task that's a handful of px, and
      // once the chip's padding is subtracted from that the child is left
      // with ~0 (or negative, clamped to 0) height to render into, which is
      // why the text disappeared entirely rather than just spilling over a
      // bit. Giving it real headroom (anchored to the segment's vertical
      // midpoint, not its height) fixes that.
      //
      // The chip is centered on the bar's midpoint and (for a genuinely tiny
      // task) is taller than the bar itself, so it pokes out above and below
      // by this much. Rather than let it visually overflow past the wrapping
      // box (which would make it unclickable — a widget's hit testing
      // rejects taps outside its own laid-out size, before it ever asks its
      // children), the wrapping box is grown to this full envelope and
      // shifted up to compensate, so the tap/drag target actually covers the
      // whole visible chip.
      final envelope = tinyBlockEnvelope(barHeight: height, labelAllocation: tinyChipLabelAllocation);
      final overflow = envelope.topOffset;
      final envelopeHeight = envelope.envelopeHeight;
      topOffset = overflow;

      content = SizedBox(
        height: envelopeHeight,
        child: Stack(
          children: [
            Positioned(top: overflow, left: 0, right: 0, height: height, child: bar),
          ],
        ),
      );

      final chip = _buildTinyChip(
        task: task,
        isPrimary: isPrimary,
        barColor: style.color,
        chipRightInset: chipRightInset,
      );
      feedbackContent = SizedBox(
        height: envelopeHeight,
        child: Stack(
          children: [
            Positioned(top: overflow, left: 0, right: 0, height: height, child: bar),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: envelopeHeight,
              child: Align(alignment: Alignment.centerRight, child: chip),
            ),
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
      left: left,
      width: renderedWidth,
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
                child: SizedBox(width: 220, child: feedbackContent),
              ),
              childWhenDragging: Opacity(opacity: 0.3, child: tappable),
              onDragUpdate: ref.onTaskDragUpdate(task),
              onDragEnd: ref.onTaskDragEnd(),
              child: tappable,
            ),
    );
  }
}
