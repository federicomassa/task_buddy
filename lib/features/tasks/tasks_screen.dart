import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../models/task.dart';
import '../../providers/app_providers.dart';
import '../../widgets/category_pickers.dart';
import '../../widgets/settings_button.dart';
import '../../widgets/sign_out_button.dart';
import '../../widgets/task_tile.dart';
import 'task_form.dart';

List<Task> filterTasks(List<Task> tasks, TaskFilter filter, String? categoryId) {
  List<Task> result;
  switch (filter) {
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
  return result;
}

enum TaskFilter { active, completed, backlog }

extension on TaskFilter {
  String get label {
    switch (this) {
      case TaskFilter.active:
        return 'Active';
      case TaskFilter.completed:
        return 'Done';
      case TaskFilter.backlog:
        return 'Backlog';
    }
  }

  IconData get icon {
    switch (this) {
      case TaskFilter.active:
        return Icons.flag_outlined;
      case TaskFilter.completed:
        return Icons.check_circle_outline;
      case TaskFilter.backlog:
        return Icons.inbox_outlined;
    }
  }
}

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  TaskFilter _filter = TaskFilter.active;
  String? _categoryFilter;

  String _emptyMessage() {
    switch (_filter) {
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        actions: const [SettingsButton(), SignOutButton()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showTaskFormDialog(context),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SegmentedButton<TaskFilter>(
              segments: TaskFilter.values
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
            child: tasksAsync.when(
              data: (tasks) {
                final filtered = filterTasks(tasks, _filter, _categoryFilter);
                if (filtered.isEmpty) {
                  return Center(child: Text(_emptyMessage()));
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
