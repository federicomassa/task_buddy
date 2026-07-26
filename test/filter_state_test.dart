import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/date_filter.dart';
import 'package:task_buddy/core/filter_state.dart';

void main() {
  group('TaskFilterState', () {
    test('defaults are active status, no category, no date constraint, overdue on', () {
      final state = TaskFilterState.defaults();
      expect(state.status, TaskFilter.active);
      expect(state.categoryId, null);
      expect(state.dateFilter, DateRangeFilter.defaults());
      expect(state.isDefault, true);
    });

    test('copyWith changes only the given field', () {
      final state = TaskFilterState.defaults();
      final changed = state.copyWith(status: TaskFilter.backlog);
      expect(changed.status, TaskFilter.backlog);
      expect(changed.categoryId, state.categoryId);
      expect(changed.isDefault, false);
    });

    test('copyWith can clear categoryId back to null', () {
      final state = TaskFilterState.defaults().copyWith(categoryId: 'c1');
      final cleared = state.copyWith(categoryId: null);
      expect(cleared.categoryId, null);
    });
  });

  group('GoalFilterState', () {
    test('defaults mirror TaskFilterState', () {
      final state = GoalFilterState.defaults();
      expect(state.status, GoalFilter.active);
      expect(state.categoryId, null);
      expect(state.isDefault, true);
    });
  });

  group('DateRangeFilter', () {
    test('value equality', () {
      const a = DateRangeFilter(preset: DatePreset.today, showOverdue: false);
      const b = DateRangeFilter(preset: DatePreset.today, showOverdue: false);
      expect(a, b);
    });

    test('copyWith can clear preset back to null', () {
      const filter = DateRangeFilter(preset: DatePreset.today);
      final cleared = filter.copyWith(preset: null);
      expect(cleared.preset, null);
    });
  });
}
