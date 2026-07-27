import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/eisenhower.dart';
import '../../models/category.dart';
import '../../models/task.dart';
import '../../providers/app_providers.dart';
import '../../widgets/task_schedule_card.dart';
import '../tasks/task_form.dart';
import 'scheduling_summary_dialog.dart';

const _quadrants = [
  (EisenhowerQuadrant.importantUrgent, 'P0 — Important & Urgent'),
  (EisenhowerQuadrant.urgentOnly, 'P1 — Urgent'),
  (EisenhowerQuadrant.importantOnly, 'P2 — Important'),
  (EisenhowerQuadrant.neither, 'P3 — Neither'),
];

/// Full-screen Eisenhower matrix: the user drags today's active tasks into
/// importance/urgency quadrants, then "Schedule my day" auto-places them on
/// the Plan calendar in WSJF priority order.
class HelpMePlanScreen extends ConsumerWidget {
  const HelpMePlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(scheduleEligibleTasksProvider);
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];
    final settingsAsync = ref.watch(userSettingsStreamProvider);
    final today = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Help me plan')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load settings: $error')),
        data: (settings) {
          final totalActiveMinutes =
              settings.activeHourRanges.fold<int>(0, (sum, r) => sum + (r.endMinutes - r.startMinutes));

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Active hours today: ${(totalActiveMinutes / 60).toStringAsFixed(1)}h. '
                  'Drag tasks into a quadrant, then schedule your day.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              Expanded(
                child: GridView.count(
                  padding: const EdgeInsets.all(8),
                  crossAxisCount: 2,
                  childAspectRatio: 0.8,
                  children: [
                    for (final (quadrant, label) in _quadrants)
                      _QuadrantPane(
                        quadrant: quadrant,
                        label: label,
                        tasks: tasks.where((t) => quadrantOf(t) == quadrant).toList(),
                        categories: categories,
                        today: today,
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Schedule my day'),
                  onPressed: tasks.isEmpty
                      ? null
                      : () => runScheduleMyDay(
                            context,
                            ref,
                            tasks: tasks,
                            settings: settings,
                            today: today,
                          ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuadrantPane extends ConsumerWidget {
  final EisenhowerQuadrant quadrant;
  final String label;
  final List<Task> tasks;
  final List<Category> categories;
  final DateTime today;

  const _QuadrantPane({
    required this.quadrant,
    required this.label,
    required this.tasks,
    required this.categories,
    required this.today,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.all(4),
      child: DragTarget<Task>(
        onAcceptWithDetails: (details) {
          final task = details.data;
          ref.read(taskRepositoryProvider).updateTask(task.copyWith(
                isImportant: quadrant == EisenhowerQuadrant.importantUrgent ||
                    quadrant == EisenhowerQuadrant.importantOnly,
                isUrgent: quadrant == EisenhowerQuadrant.importantUrgent ||
                    quadrant == EisenhowerQuadrant.urgentOnly,
              ));
        },
        builder: (context, candidateData, rejectedData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(label, style: Theme.of(context).textTheme.titleSmall),
              ),
              const Divider(height: 1),
              Expanded(
                child: tasks.isEmpty
                    ? const Center(child: Text('Drop tasks here', style: TextStyle(fontSize: 11)))
                    : ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, index) => _PlanTaskCard(
                          task: tasks[index],
                          categories: categories,
                          today: today,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanTaskCard extends ConsumerWidget {
  final Task task;
  final List<Category> categories;
  final DateTime today;

  const _PlanTaskCard({required this.task, required this.categories, required this.today});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = TaskEstimateCard(task: task, categories: categories, today: today);

    if (task.estimatedDuration == null) {
      // Tasks without a time estimate can't be scored (WSJF needs a
      // duration), so they aren't draggable — tap to add one instead.
      return InkWell(
        onTap: () => showTaskFormDialog(context, task: task),
        child: content,
      );
    }

    return LongPressDraggable<Task>(
      data: task,
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(width: 220, child: content),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: content),
      child: content,
    );
  }
}
