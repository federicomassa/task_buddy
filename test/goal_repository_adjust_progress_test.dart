// Fakes below implement CollectionReference/DocumentReference (sealed in
// cloud_firestore) purely for test doubles, following the same hand-rolled
// noSuchMethod-fallback pattern already used elsewhere in this test suite.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/clock.dart';
import 'package:task_buddy/models/goal.dart';
import 'package:task_buddy/models/task.dart';
import 'package:task_buddy/services/goal_repository.dart';
import 'package:task_buddy/services/task_repository.dart';

/// Records adjustProgress calls instead of touching Firestore, so we can
/// verify FirestoreTaskRepository.toggleComplete/setContributesToCount call
/// through to GoalRepository with the right goalId/delta under the right
/// conditions — proving the consolidation of what used to be two separate
/// copies of this logic didn't change behavior.
class FakeGoalRepository implements GoalRepository {
  final List<(String, int)> adjustProgressCalls = [];

  @override
  Future<void> adjustProgress(String goalId, int delta) async {
    adjustProgressCalls.add((goalId, delta));
  }

  @override
  Stream<List<Goal>> streamStandaloneGoals(String userId) => const Stream.empty();
  @override
  Stream<List<Goal>> streamHabitInstances(String userId) => const Stream.empty();
  @override
  Stream<List<Goal>> streamAllGoals(String userId) => const Stream.empty();
  @override
  Future<List<Goal>> fetchHabitInstances(String userId, String habitId) async => const [];
  @override
  Future<void> addStandaloneGoal({
    required String userId,
    required String title,
    required String description,
    String? categoryId,
    DateTime? dueDate,
    int? targetCount,
  }) async {}
  @override
  Future<void> addHabitInstance({
    required String userId,
    required String habitId,
    required String title,
    required String description,
    String? categoryId,
    required int targetCount,
    required DateTime startDate,
    required DateTime endDate,
    DateTime? dueDate,
  }) async {}
  @override
  Future<void> updateGoal(Goal goal) async {}
  @override
  Future<void> setCompleted(String goalId, bool isCompleted) async {}
  @override
  Future<void> deleteGoal(String goalId) async {}
}

/// Just enough of the Firestore SDK surface for FirestoreTaskRepository's
/// task-document writes (`_collection.doc(id).update(...)`) to work without
/// a real backend — everything else falls through noSuchMethod.
class _FakeDocRef implements DocumentReference<Map<String, dynamic>> {
  final List<Map<String, dynamic>> updateCalls = [];

  @override
  Future<void> update(Map<Object, dynamic> data) async {
    updateCalls.add(Map<String, dynamic>.from(data));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCollection implements CollectionReference<Map<String, dynamic>> {
  final _FakeDocRef docRef;

  _FakeCollection(this.docRef);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => docRef;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirestore implements FirebaseFirestore {
  final _FakeCollection collectionRef;

  _FakeFirestore(this.collectionRef);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) => collectionRef;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Task task({
    required bool isCompleted,
    required bool contributesToCount,
    String? linkedGoalId,
  }) {
    return Task(
      id: 't1',
      userId: 'u1',
      title: 'Task',
      isRecurrent: false,
      categoryIds: const [],
      linkedGoalId: linkedGoalId,
      contributesToCount: contributesToCount,
      isCompleted: isCompleted,
      createdAt: DateTime(2026, 1, 1),
    );
  }

  ({FirestoreTaskRepository repo, FakeGoalRepository goalRepo}) buildRepo() {
    final docRef = _FakeDocRef();
    final firestore = _FakeFirestore(_FakeCollection(docRef));
    final goalRepo = FakeGoalRepository();
    final repo = FirestoreTaskRepository(firestore, const SystemClock(), goalRepo);
    return (repo: repo, goalRepo: goalRepo);
  }

  group('toggleComplete', () {
    test('no linked goal -> no adjustment', () async {
      final built = buildRepo();
      await built.repo.toggleComplete(task(isCompleted: false, contributesToCount: true));
      expect(built.goalRepo.adjustProgressCalls, isEmpty);
    });

    test('linked goal but not contributing -> no adjustment', () async {
      final built = buildRepo();
      await built.repo.toggleComplete(
        task(isCompleted: false, contributesToCount: false, linkedGoalId: 'g1'),
      );
      expect(built.goalRepo.adjustProgressCalls, isEmpty);
    });

    test('completing a linked, contributing task adjusts by +1', () async {
      final built = buildRepo();
      await built.repo.toggleComplete(
        task(isCompleted: false, contributesToCount: true, linkedGoalId: 'g1'),
      );
      expect(built.goalRepo.adjustProgressCalls, [('g1', 1)]);
    });

    test('uncompleting a linked, contributing task adjusts by -1', () async {
      final built = buildRepo();
      await built.repo.toggleComplete(
        task(isCompleted: true, contributesToCount: true, linkedGoalId: 'g1'),
      );
      expect(built.goalRepo.adjustProgressCalls, [('g1', -1)]);
    });
  });

  group('setContributesToCount', () {
    test('no-op when the flag is already at that value', () async {
      final built = buildRepo();
      await built.repo.setContributesToCount(
        task(isCompleted: true, contributesToCount: true, linkedGoalId: 'g1'),
        true,
      );
      expect(built.goalRepo.adjustProgressCalls, isEmpty);
    });

    test('flag flips but task incomplete -> no adjustment', () async {
      final built = buildRepo();
      await built.repo.setContributesToCount(
        task(isCompleted: false, contributesToCount: false, linkedGoalId: 'g1'),
        true,
      );
      expect(built.goalRepo.adjustProgressCalls, isEmpty);
    });

    test('flipping to true on a completed task adjusts by +1', () async {
      final built = buildRepo();
      await built.repo.setContributesToCount(
        task(isCompleted: true, contributesToCount: false, linkedGoalId: 'g1'),
        true,
      );
      expect(built.goalRepo.adjustProgressCalls, [('g1', 1)]);
    });

    test('flipping to false on a completed task adjusts by -1', () async {
      final built = buildRepo();
      await built.repo.setContributesToCount(
        task(isCompleted: true, contributesToCount: true, linkedGoalId: 'g1'),
        false,
      );
      expect(built.goalRepo.adjustProgressCalls, [('g1', -1)]);
    });
  });
}
