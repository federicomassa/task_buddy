import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/category.dart';
import '../../providers/app_providers.dart';
import '../../widgets/task_tile.dart';
import 'task_form.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksStreamProvider);
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];
    final taskRepo = ref.read(taskRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showTaskFormDialog(context),
        child: const Icon(Icons.add),
      ),
      body: tasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(child: Text('No tasks yet. Tap + to add one.'));
          }
          return ListView.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
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
    );
  }
}
