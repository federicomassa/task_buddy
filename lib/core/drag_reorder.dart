/// A task's placement in minutes-since-midnight, used by
/// [resolveOverlapFreeDrop].
class ReorderedBlock {
  final String taskId;
  final int startMinutes;
  final int endMinutes;

  const ReorderedBlock({required this.taskId, required this.startMinutes, required this.endMinutes});
}

/// Places [draggedTaskId] at `[droppedStart, droppedStart + durationMinutes)`
/// among [otherBlocks] (each one other task scheduled today, unsorted) with
/// no overlaps, by cascading affected tasks forward the minimum amount
/// necessary. The dragged task always lands exactly at the dropped position —
/// it is never itself pushed, even if an earlier-starting task's end reaches
/// into the drop zone; in that case the earlier task is the one that
/// cascades forward, past the dragged task.
///
/// Any other block that ends at or before [droppedStart] doesn't interact
/// with the drop and is left untouched. Every block that ends after
/// [droppedStart] (whether it starts before, during, or after the dragged
/// block) is sorted by its original start time and walked forward, pushing
/// each one's start to `max(its own start, the previous block's end)` —
/// starting from the dragged block's own end. This guarantees no overlaps by
/// construction: a block's end is always `<=` the following block's start.
///
/// Returns only the blocks whose start changed from [otherBlocks]' original
/// position, always including the dragged task (it's always newly placed).
/// Unaffected tasks — and any existing gaps between them — are left out and
/// untouched.
List<ReorderedBlock> resolveOverlapFreeDrop({
  required String draggedTaskId,
  required int droppedStart,
  required int durationMinutes,
  required List<ReorderedBlock> otherBlocks,
}) {
  final draggedEnd = droppedStart + durationMinutes;

  final toCascade = otherBlocks.where((b) => b.endMinutes > droppedStart).toList()
    ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  final result = [
    ReorderedBlock(taskId: draggedTaskId, startMinutes: droppedStart, endMinutes: draggedEnd),
  ];

  var prevEnd = draggedEnd;
  for (final block in toCascade) {
    final duration = block.endMinutes - block.startMinutes;
    final actualStart = block.startMinutes < prevEnd ? prevEnd : block.startMinutes;
    final actualEnd = actualStart + duration;
    prevEnd = actualEnd;

    if (actualStart != block.startMinutes) {
      result.add(ReorderedBlock(taskId: block.taskId, startMinutes: actualStart, endMinutes: actualEnd));
    }
  }
  return result;
}
