import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../models/goal.dart';
import '../../models/habit.dart';
import '../../providers/app_providers.dart';
import '../../widgets/goal_card.dart';
import '../../widgets/habit_progress_card.dart';
import '../../widgets/sign_out_button.dart';
import 'goal_form.dart';
import 'habit_form.dart';

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

class _GoalsTab extends ConsumerWidget {
  const _GoalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(standaloneGoalsStreamProvider);
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];
    final goalRepo = ref.read(goalRepositoryProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-goal',
        onPressed: () => showGoalFormDialog(context),
        child: const Icon(Icons.add),
      ),
      body: goalsAsync.when(
        data: (goals) {
          if (goals.isEmpty) {
            return const Center(child: Text('No goals yet. Tap + to add one.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: goals.length,
            itemBuilder: (context, index) {
              final goal = goals[index];
              return GoalCard(
                goal: goal,
                categories: categories,
                onToggleCompleted: (v) => goalRepo.setCompleted(goal.id, v ?? false),
                onTap: () => showGoalFormDialog(context, goal: goal),
                onDelete: () => goalRepo.deleteGoal(goal.id),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _HabitsTab extends ConsumerWidget {
  const _HabitsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsStreamProvider);
    final instancesAsync = ref.watch(habitInstancesStreamProvider);
    final habitRepo = ref.read(habitRepositoryProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-habit',
        onPressed: () => showHabitFormDialog(context),
        child: const Icon(Icons.add),
      ),
      body: habitsAsync.when(
        data: (habits) {
          if (habits.isEmpty) {
            return const Center(child: Text('No habits yet. Tap + to add one.'));
          }
          final instances = instancesAsync.value ?? const <Goal>[];
          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: habits.length,
            itemBuilder: (context, index) {
              final habit = habits[index];
              final currentInstance = _currentInstanceFor(habit, instances);
              return HabitProgressCard(
                habit: habit,
                currentInstance: currentInstance,
                onDelete: () => habitRepo.deleteHabit(habit.id),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Goal? _currentInstanceFor(Habit habit, List<Goal> instances) {
    final now = DateTime.now();
    final matches = instances.where((g) => g.habitId == habit.id).toList();
    for (final g in matches) {
      if (g.startDate != null && g.endDate != null && !now.isBefore(g.startDate!) && now.isBefore(g.endDate!)) {
        return g;
      }
    }
    return matches.isNotEmpty ? matches.first : null;
  }
}
