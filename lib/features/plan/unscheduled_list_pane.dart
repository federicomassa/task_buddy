import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../models/task.dart';
import '../../providers/app_providers.dart';
import '../../widgets/task_schedule_card.dart';

/// The Today screen's right-hand pane: tasks due today or overdue that
/// haven't been dragged onto the calendar yet. Also accepts drops from the
/// calendar pane to un-schedule a task.
class UnscheduledTaskList extends ConsumerWidget {
  final DateTime today;

  const UnscheduledTaskList({super.key, required this.today});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(unscheduledTodayTasksProvider);
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];

    return DragTarget<Task>(
      onAcceptWithDetails: (details) {
        ref.read(taskRepositoryProvider).unscheduleTask(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        if (tasks.isEmpty) {
          return const Center(child: Text('Nothing to schedule.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: tasks.length,
          itemBuilder: (context, index) => TaskScheduleCard(
            task: tasks[index],
            categories: categories,
            today: today,
          ),
        );
      },
    );
  }
}
