import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../models/goal.dart';
import '../../providers/app_providers.dart';
import '../../widgets/goal_card.dart';
import '../../widgets/habit_progress_card.dart';
import '../../widgets/task_tile.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksStreamProvider);
    final habitsAsync = ref.watch(habitsStreamProvider);
    final instancesAsync = ref.watch(habitInstancesStreamProvider);
    final goalsAsync = ref.watch(standaloneGoalsStreamProvider);
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];
    final taskRepo = ref.read(taskRepositoryProvider);
    final goalRepo = ref.read(goalRepositoryProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final todayTasks = (tasksAsync.value ?? [])
        .where((t) => !t.isCompleted && t.dueDate != null &&
            DateTime(t.dueDate!.year, t.dueDate!.month, t.dueDate!.day) == today)
        .toList();

    final habits = habitsAsync.value ?? [];
    final instances = instancesAsync.value ?? const <Goal>[];

    final activeGoals = (goalsAsync.value ?? [])
        .where((g) => !g.isCompleted)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _SectionHeader('Due Today'),
          if (todayTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Nothing due today.'),
            )
          else
            ...todayTasks.map((task) => TaskTile(
                  task: task,
                  categories: categories,
                  onToggle: (_) => taskRepo.toggleComplete(task),
                )),
          const SizedBox(height: 16),
          _SectionHeader('Active Habits'),
          if (habits.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No habits set up yet.'),
            )
          else
            ...habits.map((habit) {
              final now = DateTime.now();
              final matches = instances.where((g) => g.habitId == habit.id);
              Goal? current;
              for (final g in matches) {
                if (g.startDate != null && g.endDate != null && !now.isBefore(g.startDate!) && now.isBefore(g.endDate!)) {
                  current = g;
                  break;
                }
              }
              return HabitProgressCard(habit: habit, currentInstance: current);
            }),
          const SizedBox(height: 16),
          _SectionHeader('Goals'),
          if (activeGoals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No active goals.'),
            )
          else
            ...activeGoals.map((goal) => GoalCard(
                  goal: goal,
                  categories: categories,
                  onToggleCompleted: (v) => goalRepo.setCompleted(goal.id, v ?? false),
                )),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
