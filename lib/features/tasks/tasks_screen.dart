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
import '../../widgets/task_tile.dart';
import '../family/family_management_screen.dart';
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

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tasks'),
          bottom: const TabBar(tabs: [Tab(text: 'Tasks'), Tab(text: 'Family')]),
          actions: const [SettingsButton()],
        ),
        body: const TabBarView(
          children: [_TasksTab(), _FamilyTab()],
        ),
      ),
    );
  }
}

class _TasksTab extends ConsumerStatefulWidget {
  const _TasksTab();

  @override
  ConsumerState<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends ConsumerState<_TasksTab> {
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'add-task',
        onPressed: () => showTaskFormDialog(context),
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
                onPressed: () => showTaskFilterSheet(context, ref),
              ),
            ),
          ),
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

/// Shows every Family-tagged task belonging to the user's family, both
/// unclaimed (surfaced first, with a "Claim" action, per the requirement
/// that unclaimed work be clearly visible) and already-claimed (read-only
/// unless the current user is one of the owners), so a claimed task's edits
/// stay visible to the rest of the family, not just to its owners.
class _FamilyTab extends ConsumerWidget {
  const _FamilyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyId = ref.watch(myFamilyIdStreamProvider).value;
    final userId = ref.watch(currentUserIdProvider);
    final categories = ref.watch(categoriesStreamProvider).value ?? const <Category>[];
    final taskRepo = ref.read(taskRepositoryProvider);

    if (familyId == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("You're not part of a family yet."),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FamilyManagementScreen()),
                ),
                child: const Text('Set up Family'),
              ),
            ],
          ),
        ),
      );
    }

    final tasksAsync = ref.watch(familyTasksStreamProvider);

    return Scaffold(
      body: tasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return const Center(child: Text('No family tasks yet.'));
          }
          final unclaimed = tasks.where((t) => t.ownerIds.isEmpty).toList();
          final claimed = tasks.where((t) => t.ownerIds.isNotEmpty).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (unclaimed.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Unclaimed — someone should take these!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                for (final task in unclaimed)
                  _FamilyTaskRow(
                    task: task,
                    categories: categories,
                    isOwner: false,
                    onClaim: () => taskRepo.claimOwnership(task, userId),
                    onRelease: null,
                    onTap: null,
                  ),
              ],
              if (claimed.isNotEmpty) ...[
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('Claimed', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                for (final task in claimed)
                  _FamilyTaskRow(
                    task: task,
                    categories: categories,
                    isOwner: task.ownerIds.contains(userId),
                    onClaim: task.ownerIds.contains(userId) ? null : () => taskRepo.claimOwnership(task, userId),
                    onRelease: task.ownerIds.contains(userId) ? () => taskRepo.releaseOwnership(task, userId) : null,
                    onTap: task.ownerIds.contains(userId) ? () => showTaskFormDialog(context, task: task) : null,
                  ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _FamilyTaskRow extends ConsumerWidget {
  final Task task;
  final List<Category> categories;
  final bool isOwner;
  final VoidCallback? onClaim;
  final VoidCallback? onRelease;
  final VoidCallback? onTap;

  const _FamilyTaskRow({
    required this.task,
    required this.categories,
    required this.isOwner,
    required this.onClaim,
    required this.onRelease,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskRepo = ref.read(taskRepositoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskTile(
          task: task,
          categories: categories,
          onToggle: isOwner ? (_) => taskRepo.toggleComplete(task) : (_) {},
          onTap: onTap,
        ),
        if (onClaim != null || onRelease != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Row(
              children: [
                if (onClaim != null)
                  TextButton(onPressed: onClaim, child: const Text('Claim')),
                if (onRelease != null)
                  TextButton(onPressed: onRelease, child: const Text('Release')),
              ],
            ),
          ),
        const Divider(height: 1),
      ],
    );
  }
}
