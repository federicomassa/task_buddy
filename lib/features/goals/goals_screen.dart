import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_filter.dart';
import '../../core/filter_state.dart';
import '../../core/habit_instance_utils.dart';
import '../../models/category.dart';
import '../../models/goal.dart';
import '../../models/habit.dart';
import '../../models/task.dart';
import '../../providers/app_providers.dart';
import '../../widgets/filter_bottom_sheet.dart';
import '../../widgets/goal_card.dart';
import '../../widgets/habit_progress_card.dart';
import '../../widgets/settings_button.dart';
import '../../widgets/sign_out_button.dart';
import '../tasks/task_form.dart';
import 'goal_form.dart';
import 'habit_form.dart';

export '../../core/filter_state.dart' show GoalFilter, HabitFilter;

List<Goal> filterGoals(
  List<Goal> goals,
  GoalFilter filter,
  String? categoryId,
  DateRangeFilter dateFilter, {
  required DateTime today,
}) {
  List<Goal> result;
  switch (filter) {
    case GoalFilter.all:
      result = List.of(goals);
      break;
    case GoalFilter.active:
      final active = goals.where((g) => !g.isCompleted && g.dueDate != null).toList();
      active.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
      result = active;
      break;
    case GoalFilter.completed:
      result = goals.where((g) => g.isCompleted).toList();
      break;
    case GoalFilter.backlog:
      result = goals.where((g) => !g.isCompleted && g.dueDate == null).toList();
      break;
  }
  if (categoryId != null) {
    result = result.where((g) => g.categoryId == categoryId).toList();
  }
  result = result
      .where(
        (g) => matchesTimeFilter(
          dueDate: g.dueDate,
          isOverdue: isGoalOverdue(g, today: today),
          filter: dateFilter,
          today: today,
        ),
      )
      .toList();
  return result;
}

/// Filters habit templates by their *current cycle instance* — a habit has
/// no isCompleted/dueDate of its own, so status and time filtering both key
/// off `currentHabitInstance(instances, habit.id, now)`. A habit with no
/// current instance yet never matches `active`/`completed` and never
/// matches a time preset (mirrors how tasks/goals with no due date behave).
List<Habit> filterHabits(
  List<Habit> habits,
  List<Goal> instances,
  HabitFilter filter,
  String? categoryId,
  DateRangeFilter dateFilter, {
  required DateTime now,
  required DateTime today,
}) {
  List<Habit> result = List.of(habits);
  if (categoryId != null) {
    result = result.where((h) => h.categoryId == categoryId).toList();
  }
  result = result.where((h) {
    final instance = currentHabitInstance(instances, h.id, now);
    switch (filter) {
      case HabitFilter.all:
        break;
      case HabitFilter.active:
        if (instance == null || instance.isCompleted) return false;
        break;
      case HabitFilter.completed:
        if (instance == null || !instance.isCompleted) return false;
        break;
    }
    return matchesTimeFilter(
      dueDate: instance?.dueDate,
      isOverdue: instance != null && isGoalOverdue(instance, today: today),
      filter: dateFilter,
      today: today,
    );
  }).toList();
  return result;
}

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Goals & Habits'),
          bottom: const TabBar(tabs: [Tab(text: 'Goals'), Tab(text: 'Habits')]),
          actions: const [SettingsButton(), SignOutButton()],
        ),
        body: const TabBarView(
          children: [_GoalsTab(), _HabitsTab()],
        ),
      ),
    );
  }
}

class _GoalsTab extends ConsumerStatefulWidget {
  const _GoalsTab();

  @override
  ConsumerState<_GoalsTab> createState() => _GoalsTabState();
}

class _GoalsTabState extends ConsumerState<_GoalsTab> {
  String _emptyMessage(GoalFilter filter) {
    switch (filter) {
      case GoalFilter.all:
        return 'No goals yet.';
      case GoalFilter.active:
        return 'No active goals. Tap + to add one.';
      case GoalFilter.completed:
        return 'No completed goals yet.';
      case GoalFilter.backlog:
        return 'Backlog is empty.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(standaloneGoalsStreamProvider);
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];
    final tasks = ref.watch(tasksStreamProvider).value ?? const <Task>[];
    final goalRepo = ref.read(goalRepositoryProvider);
    final taskRepo = ref.read(taskRepositoryProvider);
    final filterState = ref.watch(goalFilterProvider);
    final today = ref.watch(todayProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-goal',
        onPressed: () => showGoalFormDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Badge(
                  isLabelVisible: !filterState.isDefault,
                  child: const Icon(Icons.filter_list),
                ),
                onPressed: () => showGoalFilterSheet(context, ref),
              ),
            ),
          ),
          Expanded(
            child: goalsAsync.when(
              data: (goals) {
                final filtered = filterGoals(
                  goals,
                  filterState.status,
                  filterState.categoryId,
                  filterState.dateFilter,
                  today: today,
                );
                if (filtered.isEmpty) {
                  return Center(child: Text(_emptyMessage(filterState.status)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final goal = filtered[index];
                    final linkedTasks = tasks.where((t) => t.linkedGoalId == goal.id).toList();
                    final contributingCount = linkedTasks.where((t) => t.contributesToCount).length;
                    return GoalCard(
                      goal: goal,
                      categories: categories,
                      linkedTasks: linkedTasks,
                      contributingCount: contributingCount,
                      onToggleCompleted: (v) => goalRepo.setCompleted(goal.id, v ?? false),
                      onToggleTask: (task) => taskRepo.toggleComplete(task),
                      onToggleContributesToCount: (task) =>
                          taskRepo.setContributesToCount(task, !task.contributesToCount),
                      onTapTask: (task) => showTaskFormDialog(context, task: task),
                      onTap: () => showGoalFormDialog(context, goal: goal),
                      onDelete: () => goalRepo.deleteGoal(goal.id),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitsTab extends ConsumerStatefulWidget {
  const _HabitsTab();

  @override
  ConsumerState<_HabitsTab> createState() => _HabitsTabState();
}

class _HabitsTabState extends ConsumerState<_HabitsTab> {
  String _emptyMessage(HabitFilter filter) {
    switch (filter) {
      case HabitFilter.all:
        return 'No habits yet. Tap + to add one.';
      case HabitFilter.active:
        return 'No active habits.';
      case HabitFilter.completed:
        return 'No completed habits yet.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsStreamProvider);
    final instancesAsync = ref.watch(habitInstancesStreamProvider);
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];
    final tasks = ref.watch(tasksStreamProvider).value ?? const <Task>[];
    final habitRepo = ref.read(habitRepositoryProvider);
    final taskRepo = ref.read(taskRepositoryProvider);
    final filterState = ref.watch(habitFilterProvider);
    final now = ref.watch(clockProvider).now();
    final today = ref.watch(todayProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-habit',
        onPressed: () => showHabitFormDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Badge(
                  isLabelVisible: !filterState.isDefault,
                  child: const Icon(Icons.filter_list),
                ),
                onPressed: () => showHabitFilterSheet(context, ref),
              ),
            ),
          ),
          Expanded(
            child: habitsAsync.when(
              data: (habits) {
                final instances = instancesAsync.value ?? const <Goal>[];
                final filtered = filterHabits(
                  habits,
                  instances,
                  filterState.status,
                  filterState.categoryId,
                  filterState.dateFilter,
                  now: now,
                  today: today,
                );
                if (filtered.isEmpty) {
                  return Center(child: Text(_emptyMessage(filterState.status)));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final habit = filtered[index];
                    final currentInstance = currentHabitInstance(
                      instances,
                      habit.id,
                      ref.watch(clockProvider).now(),
                    );
                    final linkedTasks = currentInstance == null
                        ? const <Task>[]
                        : tasks.where((t) => t.linkedGoalId == currentInstance.id).toList();
                    final contributingCount =
                        linkedTasks.where((t) => t.contributesToCount).length;
                    return HabitProgressCard(
                      habit: habit,
                      currentInstance: currentInstance,
                      categories: categories,
                      linkedTasks: linkedTasks,
                      contributingCount: contributingCount,
                      onToggleTask: (task) => taskRepo.toggleComplete(task),
                      onToggleContributesToCount: (task) =>
                          taskRepo.setContributesToCount(task, !task.contributesToCount),
                      onTapTask: (task) => showTaskFormDialog(context, task: task),
                      onTap: () => showHabitFormDialog(context, habit: habit),
                      onDelete: () => habitRepo.deleteHabit(habit.id),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }
}
