import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_filter.dart';
import '../../core/filter_state.dart';
import '../../core/task_card_style.dart';
import '../../models/category.dart';
import '../../models/task.dart';
import '../../providers/app_providers.dart';
import '../../widgets/filter_bottom_sheet.dart';
import '../../widgets/settings_button.dart';
import '../../widgets/sign_out_button.dart';
import '../../widgets/task_tile.dart';
import 'task_form.dart';

export '../../core/filter_state.dart' show TaskFilter;

List<Task> filterTasks(
  List<Task> tasks,
  TaskFilter filter,
  String? categoryId,
  DateRangeFilter dateFilter, {
  required DateTime today,
}) {
  List<Task> result;
  switch (filter) {
    case TaskFilter.all:
      result = List.of(tasks);
      break;
    case TaskFilter.active:
      final active = tasks.where((t) => !t.isCompleted && t.dueDate != null).toList();
      active.sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
      result = active;
      break;
    case TaskFilter.completed:
      result = tasks.where((t) => t.isCompleted).toList();
      break;
    case TaskFilter.backlog:
      result = tasks.where((t) => !t.isCompleted && t.dueDate == null).toList();
      break;
  }
  if (categoryId != null) {
    result = result.where((t) => t.categoryIds.contains(categoryId)).toList();
  }
  result = result
      .where(
        (t) => matchesTimeFilter(
          dueDate: t.dueDate,
          isOverdue: isTaskOverdue(t, today: today),
          filter: dateFilter,
          today: today,
        ),
      )
      .toList();
  return result;
}

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String _emptyMessage(TaskFilter filter) {
    switch (filter) {
      case TaskFilter.all:
        return 'No tasks yet.';
      case TaskFilter.active:
        return 'No active tasks with a due date.';
      case TaskFilter.completed:
        return 'No completed tasks yet.';
      case TaskFilter.backlog:
        return 'Backlog is empty.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksStreamProvider);
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];
    final taskRepo = ref.read(taskRepositoryProvider);
    final filterState = ref.watch(taskFilterProvider);
    final today = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: !filterState.isDefault,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: () => showTaskFilterSheet(context, ref),
          ),
          const SettingsButton(),
          const SignOutButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showTaskFormDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                final filtered = filterTasks(
                  tasks,
                  filterState.status,
                  filterState.categoryId,
                  filterState.dateFilter,
                  today: today,
                );
                if (filtered.isEmpty) {
                  return Center(child: Text(_emptyMessage(filterState.status)));
                }
                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final task = filtered[index];
                    return TaskTile(
                      task: task,
                      categories: categories,
                      onToggle: (_) => taskRepo.toggleComplete(task),
                      onTap: () => showTaskFormDialog(context, task: task),
                      onDelete: () => taskRepo.deleteTask(task.id),
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
