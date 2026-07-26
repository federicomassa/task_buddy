import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date_filter.dart';
import '../core/filter_state.dart';
import '../models/category.dart';
import '../providers/app_providers.dart';
import 'category_pickers.dart';

Future<void> showTaskFilterSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _TaskFilterSheetContent(),
  );
}

Future<void> showGoalFilterSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _GoalFilterSheetContent(),
  );
}

Future<void> showHabitFilterSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _HabitFilterSheetContent(),
  );
}

class _TaskFilterSheetContent extends ConsumerWidget {
  const _TaskFilterSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(taskFilterProvider);
    final notifier = ref.read(taskFilterProvider.notifier);
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];

    return _FilterSheetBody<TaskFilter>(
      statusValues: TaskFilter.values,
      selectedStatus: state.status,
      statusLabel: (f) => f.label,
      categories: categories,
      selectedCategoryId: state.categoryId,
      dateFilter: state.dateFilter,
      onStatusChanged: (f) => notifier.update((s) => s.copyWith(status: f)),
      onCategoryChanged: (id) => notifier.update((s) => s.copyWith(categoryId: id)),
      onDateFilterChanged: (d) => notifier.update((s) => s.copyWith(dateFilter: d)),
      onReset: () => notifier.update((_) => TaskFilterState.defaults()),
    );
  }
}

class _GoalFilterSheetContent extends ConsumerWidget {
  const _GoalFilterSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(goalFilterProvider);
    final notifier = ref.read(goalFilterProvider.notifier);
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];

    return _FilterSheetBody<GoalFilter>(
      statusValues: GoalFilter.values,
      selectedStatus: state.status,
      statusLabel: (f) => f.label,
      categories: categories,
      selectedCategoryId: state.categoryId,
      dateFilter: state.dateFilter,
      onStatusChanged: (f) => notifier.update((s) => s.copyWith(status: f)),
      onCategoryChanged: (id) => notifier.update((s) => s.copyWith(categoryId: id)),
      onDateFilterChanged: (d) => notifier.update((s) => s.copyWith(dateFilter: d)),
      onReset: () => notifier.update((_) => GoalFilterState.defaults()),
    );
  }
}

class _HabitFilterSheetContent extends ConsumerWidget {
  const _HabitFilterSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitFilterProvider);
    final notifier = ref.read(habitFilterProvider.notifier);
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];

    return _FilterSheetBody<HabitFilter>(
      statusValues: HabitFilter.values,
      selectedStatus: state.status,
      statusLabel: (f) => f.label,
      categories: categories,
      selectedCategoryId: state.categoryId,
      dateFilter: state.dateFilter,
      onStatusChanged: (f) => notifier.update((s) => s.copyWith(status: f)),
      onCategoryChanged: (id) => notifier.update((s) => s.copyWith(categoryId: id)),
      onDateFilterChanged: (d) => notifier.update((s) => s.copyWith(dateFilter: d)),
      onReset: () => notifier.update((_) => HabitFilterState.defaults()),
    );
  }
}

/// The three-section body (State / Category / Time range) shared by the
/// Tasks, Goals, and Habits filter sheets. Each tab's [ConsumerWidget]
/// wraps this with its own provider wiring, since `TaskFilter`/`GoalFilter`/
/// `HabitFilter` are distinct enums with no common supertype.
class _FilterSheetBody<TStatus extends Enum> extends StatelessWidget {
  final List<TStatus> statusValues;
  final TStatus selectedStatus;
  final String Function(TStatus) statusLabel;
  final List<Category> categories;
  final String? selectedCategoryId;
  final DateRangeFilter dateFilter;
  final ValueChanged<TStatus> onStatusChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<DateRangeFilter> onDateFilterChanged;
  final VoidCallback onReset;

  const _FilterSheetBody({
    required this.statusValues,
    required this.selectedStatus,
    required this.statusLabel,
    required this.categories,
    required this.selectedCategoryId,
    required this.dateFilter,
    required this.onStatusChanged,
    required this.onCategoryChanged,
    required this.onDateFilterChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return _FilterSheetScaffold(
      onReset: onReset,
      children: [
        _FilterSection(
          title: 'State',
          child: _ChoiceChipRow<TStatus>(
            values: statusValues,
            selected: selectedStatus,
            labelOf: statusLabel,
            onChanged: onStatusChanged,
          ),
        ),
        _FilterSection(
          title: 'Category',
          child: _CategorySection(
            categories: categories,
            selectedId: selectedCategoryId,
            onChanged: onCategoryChanged,
          ),
        ),
        _FilterSection(
          title: 'Time range',
          child: _TimeFilterSection(
            dateFilter: dateFilter,
            onChanged: onDateFilterChanged,
          ),
        ),
      ],
    );
  }
}

class _FilterSheetScaffold extends StatelessWidget {
  final List<Widget> children;
  final VoidCallback onReset;

  const _FilterSheetScaffold({required this.children, required this.onReset});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton(onPressed: onReset, child: const Text('Reset')),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// A row of `ChoiceChip`s for a single-select enum value — the same visual
/// style as [CategoryFilterBar], so every filter dimension in the sheet
/// (state, category, time preset) reads consistently.
class _ChoiceChipRow<T extends Enum> extends StatelessWidget {
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  const _ChoiceChipRow({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: values.map((v) {
        return ChoiceChip(
          label: Text(labelOf(v)),
          selected: v == selected,
          onSelected: (_) => onChanged(v),
        );
      }).toList(),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final List<Category> categories;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  const _CategorySection({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return CategoryFilterBar(
      categories: categories,
      selectedId: selectedId,
      onChanged: onChanged,
    );
  }
}

class _TimeFilterSection extends StatelessWidget {
  final DateRangeFilter dateFilter;
  final ValueChanged<DateRangeFilter> onChanged;

  const _TimeFilterSection({required this.dateFilter, required this.onChanged});

  Future<void> _pickCustomRange(BuildContext context) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDateRange: dateFilter.customStart != null && dateFilter.customEnd != null
          ? DateTimeRange(start: dateFilter.customStart!, end: dateFilter.customEnd!)
          : null,
    );
    if (range == null) return;
    onChanged(
      dateFilter.copyWith(
        preset: DatePreset.custom,
        customStart: range.start,
        customEnd: range.end,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('Any date'),
              selected: dateFilter.preset == null,
              onSelected: (_) => onChanged(
                dateFilter.copyWith(preset: null, customStart: null, customEnd: null),
              ),
            ),
            ChoiceChip(
              label: const Text('Today'),
              selected: dateFilter.preset == DatePreset.today,
              onSelected: (_) => onChanged(
                dateFilter.copyWith(preset: DatePreset.today, customStart: null, customEnd: null),
              ),
            ),
            ChoiceChip(
              label: const Text('Tomorrow'),
              selected: dateFilter.preset == DatePreset.tomorrow,
              onSelected: (_) => onChanged(
                dateFilter.copyWith(
                  preset: DatePreset.tomorrow,
                  customStart: null,
                  customEnd: null,
                ),
              ),
            ),
            ChoiceChip(
              label: const Text('This week'),
              selected: dateFilter.preset == DatePreset.thisWeek,
              onSelected: (_) => onChanged(
                dateFilter.copyWith(
                  preset: DatePreset.thisWeek,
                  customStart: null,
                  customEnd: null,
                ),
              ),
            ),
            ChoiceChip(
              label: const Text('Custom range'),
              selected: dateFilter.preset == DatePreset.custom,
              onSelected: (_) => _pickCustomRange(context),
            ),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Include overdue'),
          value: dateFilter.showOverdue,
          onChanged: (v) => onChanged(dateFilter.copyWith(showOverdue: v)),
        ),
      ],
    );
  }
}
