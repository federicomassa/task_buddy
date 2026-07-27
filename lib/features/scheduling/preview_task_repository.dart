import '../../models/task.dart';
import '../../services/task_repository.dart';
import 'scheduling_preview_state.dart';

/// Wraps a real [TaskRepository] and redirects schedule-changing writes into
/// a [SchedulingPreviewNotifier] instead of Firestore, so the scheduling-preview
/// screen's calendar/unscheduled-list widgets (unmodified) can be dragged
/// around freely with nothing persisted until the user confirms.
class PreviewTaskRepository implements TaskRepository {
  final TaskRepository _real;
  final SchedulingPreviewNotifier _preview;

  PreviewTaskRepository(this._real, this._preview);

  @override
  Stream<List<Task>> streamTasks(String userId) => _real.streamTasks(userId);

  @override
  Future<void> addTask(Task draft) => _real.addTask(draft);

  @override
  Future<void> updateTask(Task task) => _real.updateTask(task);

  @override
  Future<void> deleteTask(String taskId) {
    if (isSyntheticFreeTimeId(taskId)) {
      _preview.deleteSynthetic(taskId);
      return Future.value();
    }
    return _real.deleteTask(taskId);
  }

  @override
  Future<void> toggleComplete(Task task) => _real.toggleComplete(task);

  @override
  Future<void> setContributesToCount(Task task, bool contributesToCount) =>
      _real.setContributesToCount(task, contributesToCount);

  @override
  Future<void> scheduleTaskRanges(Task task, List<TaskTimeRange> ranges, {bool? constrainedToWorkingHours}) async {
    _preview.scheduleRanges(task, ranges, constrainedToWorkingHours: constrainedToWorkingHours);
  }

  @override
  Future<void> unscheduleTask(Task task) async {
    _preview.unschedule(task);
  }

  @override
  Future<void> setFamilyTask(Task task, {required bool isFamilyTask, String? familyId}) =>
      _real.setFamilyTask(task, isFamilyTask: isFamilyTask, familyId: familyId);

  @override
  Future<void> claimOwnership(Task task, String uid) => _real.claimOwnership(task, uid);

  @override
  Future<void> releaseOwnership(Task task, String uid) => _real.releaseOwnership(task, uid);

  @override
  Stream<List<Task>> streamFamilyTasks(String familyId) => _real.streamFamilyTasks(familyId);
}
