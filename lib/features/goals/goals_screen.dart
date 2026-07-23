import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/habit_instance_utils.dart';
import '../../models/category.dart';
import '../../models/goal.dart';
import '../../models/task.dart';
import '../../providers/app_providers.dart';
import '../../widgets/category_pickers.dart';
import '../../widgets/goal_card.dart';
import '../../widgets/habit_progress_card.dart';
import '../../widgets/sign_out_button.dart';
import '../tasks/task_form.dart';
import 'goal_form.dart';
import 'habit_form.dart';

List<Goal> filterGoals(List<Goal> goals, GoalFilter filter, String? categoryId) {
  var result = switch (filter) {
    GoalFilter.active => goals.where((g) => !g.isCompleted).toList(),
    GoalFilter.completed => goals.where((g) => g.isCompleted).toList(),
  };
  if (categoryId != null) {
    result = result.where((g) => g.categoryId == categoryId).toList();
  }
  return result;
}

enum GoalFilter { active, completed }

extension on GoalFilter {
  String get label {
    switch (this) {
      case GoalFilter.active:
        return 'Active';
      case GoalFilter.completed:
        return 'Done';
    }
  }

  IconData get icon {
    switch (this) {
      case GoalFilter.active:
        return Icons.flag_outlined;
      case GoalFilter.completed:
        return Icons.check_circle_outline;
    }
  }
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
          actions: const [SignOutButton()],
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
  GoalFilter _filter = GoalFilter.active;
  String? _categoryFilter;

  String _emptyMessage() {
    switch (_filter) {
      case GoalFilter.active:
        return 'No active goals. Tap + to add one.';
      case GoalFilter.completed:
        return 'No completed goals yet.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(standaloneGoalsStreamProvider);
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];
    final tasks = ref.watch(tasksStreamProvider).value ?? const <Task>[];
    final goalRepo = ref.read(goalRepositoryProvider);
    final taskRepo = ref.read(taskRepositoryProvider);

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
            child: SegmentedButton<GoalFilter>(
              segments: GoalFilter.values
                  .map(
                    (f) => ButtonSegment(
                      value: f,
                      label: Text(f.label),
                      icon: Icon(f.icon, size: 18),
                    ),
                  )
                  .toList(),
              selected: {_filter},
              onSelectionChanged: (selection) => setState(() => _filter = selection.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: CategoryFilterBar(
              categories: categories,
              selectedId: _categoryFilter,
              onChanged: (id) => setState(() => _categoryFilter = id),
            ),
          ),
          Expanded(
            child: goalsAsync.when(
              data: (goals) {
                final filtered = filterGoals(goals, _filter, _categoryFilter);
                if (filtered.isEmpty) {
                  return Center(child: Text(_emptyMessage()));
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
  String? _categoryFilter;

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(habitsStreamProvider);
    final instancesAsync = ref.watch(habitInstancesStreamProvider);
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];
    final tasks = ref.watch(tasksStreamProvider).value ?? const <Task>[];
    final habitRepo = ref.read(habitRepositoryProvider);
    final taskRepo = ref.read(taskRepositoryProvider);

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
            child: CategoryFilterBar(
              categories: categories,
              selectedId: _categoryFilter,
              onChanged: (id) => setState(() => _categoryFilter = id),
            ),
          ),
          Expanded(
            child: habitsAsync.when(
              data: (habits) {
                final filtered = _categoryFilter == null
                    ? habits
                    : habits.where((h) => h.categoryId == _categoryFilter).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No habits yet. Tap + to add one.'));
                }
                final instances = instancesAsync.value ?? const <Goal>[];
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
