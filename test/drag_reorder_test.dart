import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/drag_reorder.dart';

void main() {
  group('resolveOverlapFreeDrop', () {
    test('no collision leaves other tasks untouched', () {
      final result = resolveOverlapFreeDrop(
        draggedTaskId: 'a',
        droppedStart: 9 * 60,
        durationMinutes: 30,
        otherBlocks: [
          const ReorderedBlock(taskId: 'b', startMinutes: 10 * 60, endMinutes: 11 * 60),
        ],
      );

      expect(result, hasLength(1));
      expect(result.single.taskId, 'a');
      expect(result.single.startMinutes, 9 * 60);
      expect(result.single.endMinutes, 9 * 60 + 30);
    });

    test('single push: dropped task overlaps one task, which is pushed forward', () {
      final result = resolveOverlapFreeDrop(
        draggedTaskId: 'a',
        droppedStart: 10 * 60 + 15,
        durationMinutes: 60,
        otherBlocks: [
          const ReorderedBlock(taskId: 'b', startMinutes: 10 * 60 + 30, endMinutes: 11 * 60),
        ],
      );

      expect(result, hasLength(2));
      final a = result.firstWhere((b) => b.taskId == 'a');
      final b = result.firstWhere((b) => b.taskId == 'b');
      expect(a.startMinutes, 10 * 60 + 15);
      expect(a.endMinutes, 11 * 60 + 15);
      expect(b.startMinutes, 11 * 60 + 15);
      expect(b.endMinutes, 11 * 60 + 45);
    });

    test('multi-task cascade: pushing one task causes a further push', () {
      // A 9-10, B 10:30-11, C 11-12. Drag A to 10:15-11:15.
      final result = resolveOverlapFreeDrop(
        draggedTaskId: 'a',
        droppedStart: 10 * 60 + 15,
        durationMinutes: 60,
        otherBlocks: [
          const ReorderedBlock(taskId: 'b', startMinutes: 10 * 60 + 30, endMinutes: 11 * 60),
          const ReorderedBlock(taskId: 'c', startMinutes: 11 * 60, endMinutes: 12 * 60),
        ],
      );

      expect(result, hasLength(3));
      final a = result.firstWhere((b) => b.taskId == 'a');
      final b = result.firstWhere((b) => b.taskId == 'b');
      final c = result.firstWhere((b) => b.taskId == 'c');
      expect(a.startMinutes, 10 * 60 + 15);
      expect(a.endMinutes, 11 * 60 + 15);
      expect(b.startMinutes, 11 * 60 + 15);
      expect(b.endMinutes, 11 * 60 + 45);
      expect(c.startMinutes, 11 * 60 + 45);
      expect(c.endMinutes, 12 * 60 + 45);
    });

    test('back-to-back is not a collision at the exact boundary', () {
      final result = resolveOverlapFreeDrop(
        draggedTaskId: 'a',
        droppedStart: 9 * 60,
        durationMinutes: 60,
        otherBlocks: [
          const ReorderedBlock(taskId: 'b', startMinutes: 10 * 60, endMinutes: 11 * 60),
        ],
      );

      expect(result, hasLength(1));
      expect(result.single.taskId, 'a');
    });

    test('dragged task inserted before all others, at exact tie, sorts first', () {
      final result = resolveOverlapFreeDrop(
        draggedTaskId: 'a',
        droppedStart: 9 * 60,
        durationMinutes: 30,
        otherBlocks: [
          const ReorderedBlock(taskId: 'b', startMinutes: 9 * 60, endMinutes: 10 * 60),
        ],
      );

      expect(result, hasLength(2));
      final a = result.firstWhere((b) => b.taskId == 'a');
      final b = result.firstWhere((b) => b.taskId == 'b');
      expect(a.startMinutes, 9 * 60);
      expect(a.endMinutes, 9 * 60 + 30);
      expect(b.startMinutes, 9 * 60 + 30);
      expect(b.endMinutes, 10 * 60 + 30);
    });

    test('an earlier-starting task whose end reaches into the drop zone cascades forward, '
        'while the dragged task keeps its exact dropped position', () {
      // B is 9:00-10:30. Drag A into 10:00-10:30, landing inside B.
      final result = resolveOverlapFreeDrop(
        draggedTaskId: 'a',
        droppedStart: 10 * 60,
        durationMinutes: 30,
        otherBlocks: [
          const ReorderedBlock(taskId: 'b', startMinutes: 9 * 60, endMinutes: 10 * 60 + 30),
        ],
      );

      expect(result, hasLength(2));
      final a = result.firstWhere((b) => b.taskId == 'a');
      final b = result.firstWhere((b) => b.taskId == 'b');
      expect(a.startMinutes, 10 * 60);
      expect(a.endMinutes, 10 * 60 + 30);
      expect(b.startMinutes, 10 * 60 + 30);
      expect(b.endMinutes, 12 * 60);
    });

    test('dragged task inserted after all others', () {
      final result = resolveOverlapFreeDrop(
        draggedTaskId: 'a',
        droppedStart: 15 * 60,
        durationMinutes: 30,
        otherBlocks: [
          const ReorderedBlock(taskId: 'b', startMinutes: 9 * 60, endMinutes: 10 * 60),
          const ReorderedBlock(taskId: 'c', startMinutes: 11 * 60, endMinutes: 12 * 60),
        ],
      );

      expect(result, hasLength(1));
      expect(result.single.taskId, 'a');
      expect(result.single.startMinutes, 15 * 60);
      expect(result.single.endMinutes, 15 * 60 + 30);
    });
  });
}
