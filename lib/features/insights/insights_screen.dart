import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/color_utils.dart';
import '../../core/insights_calculations.dart';
import '../../models/category.dart';
import '../../models/goal.dart';
import '../../models/habit.dart';
import '../../models/task.dart';
import '../../providers/app_providers.dart';
import '../../widgets/sign_out_button.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsStreamProvider).value ?? const <Habit>[];
    final instances = ref.watch(habitInstancesStreamProvider).value ?? const <Goal>[];
    final tasks = ref.watch(tasksStreamProvider).value ?? const <Task>[];
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];
    final now = ref.watch(clockProvider).now();

    return Scaffold(
      appBar: AppBar(title: const Text('Insights'), actions: const [SignOutButton()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Habit Consistency Rate', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (habits.isEmpty)
            const Text('No habits yet.')
          else
            SizedBox(
              height: 220,
              child: _HabitConsistencyChart(habits: habits, instances: instances, now: now),
            ),
          const SizedBox(height: 32),
          Text('Category Distribution (last 30 days)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: _CategoryDistributionChart(tasks: tasks, categories: categories, now: now),
          ),
        ],
      ),
    );
  }
}

class _HabitConsistencyChart extends StatelessWidget {
  final List<Habit> habits;
  final List<Goal> instances;
  final DateTime now;

  const _HabitConsistencyChart({required this.habits, required this.instances, required this.now});

  @override
  Widget build(BuildContext context) {
    final rates = computeHabitConsistencyRates(habits, instances, now);
    final entries = rates.entries.toList();

    return BarChart(
      BarChartData(
        maxY: 100,
        barGroups: [
          for (var i = 0; i < entries.length; i++)
            BarChartGroupData(x: i, barRods: [
              BarChartRodData(toY: entries[i].value, width: 20, color: Theme.of(context).colorScheme.primary),
            ]),
        ],
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= entries.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(entries[i].key, style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
      ),
    );
  }
}

class _CategoryDistributionChart extends StatelessWidget {
  final List<Task> tasks;
  final List<Category> categories;
  final DateTime now;

  const _CategoryDistributionChart({required this.tasks, required this.categories, required this.now});

  @override
  Widget build(BuildContext context) {
    final counts = computeCategoryDistribution(tasks, categories, now);

    if (counts.isEmpty) {
      return const Center(child: Text('No completed tasks in the last 30 days.'));
    }

    final total = counts.values.fold<int>(0, (a, b) => a + b);
    final entries = counts.entries.toList();

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    title: '${(entries[i].value / total * 100).round()}%',
                    color: categoryColorPalette[i % categoryColorPalette.length],
                    radius: 80,
                    titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < entries.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 6, backgroundColor: categoryColorPalette[i % categoryColorPalette.length]),
                      const SizedBox(width: 6),
                      Expanded(child: Text(entries[i].key, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
