// Fakes below implement CollectionReference/DocumentReference (sealed in
// cloud_firestore) purely for test doubles, following the same hand-rolled
// noSuchMethod-fallback pattern used in goal_repository_adjust_progress_test.dart.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/clock.dart';
import 'package:task_buddy/models/goal.dart';
import 'package:task_buddy/models/task.dart';
import 'package:task_buddy/services/goal_repository.dart';
import 'package:task_buddy/services/task_repository.dart';

class _FakeGoalRepository implements GoalRepository {
  @override
  Future<void> adjustProgress(String goalId, int delta) async {}
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
  final List<Map<String, dynamic>> addCalls = [];

  _FakeCollection(this.docRef);

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) => docRef;

  @override
  Future<DocumentReference<Map<String, dynamic>>> add(Map<String, dynamic> data) async {
    addCalls.add(data);
    return docRef;
  }

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
    required String userId,
    bool isFamilyTask = false,
    String? familyId,
    List<String>? ownerIds,
  }) {
    return Task(
      id: 't1',
      userId: userId,
      title: 'Task',
      isRecurrent: false,
      categoryIds: const [],
      isCompleted: false,
      createdAt: DateTime(2026, 1, 1),
      isFamilyTask: isFamilyTask,
      familyId: familyId,
      ownerIds: ownerIds,
    );
  }

  ({FirestoreTaskRepository repo, _FakeCollection collection}) buildRepo() {
    final docRef = _FakeDocRef();
    final collection = _FakeCollection(docRef);
    final firestore = _FakeFirestore(collection);
    final repo = FirestoreTaskRepository(firestore, const SystemClock(), _FakeGoalRepository());
    return (repo: repo, collection: collection);
  }

  group('addTask', () {
    test('a personal task owns itself at creation', () async {
      final built = buildRepo();
      await built.repo.addTask(task(userId: 'u1'));
      expect(built.collection.addCalls.single['ownerIds'], ['u1']);
    });

    test('a family task starts unclaimed at creation', () async {
      final built = buildRepo();
      await built.repo.addTask(task(userId: 'u1', isFamilyTask: true, familyId: 'f1'));
      expect(built.collection.addCalls.single['ownerIds'], isEmpty);
    });
  });

  group('setFamilyTask', () {
    test('marking a task Family drops it to unclaimed', () async {
      final built = buildRepo();
      await built.repo.setFamilyTask(task(userId: 'u1'), isFamilyTask: true, familyId: 'f1');
      final update = built.collection.docRef.updateCalls.single;
      expect(update['isFamilyTask'], true);
      expect(update['familyId'], 'f1');
      expect(update['ownerIds'], isEmpty);
    });

    test('unmarking a task returns it to its creator', () async {
      final built = buildRepo();
      await built.repo.setFamilyTask(
        task(userId: 'u1', isFamilyTask: true, familyId: 'f1', ownerIds: const []),
        isFamilyTask: false,
      );
      final update = built.collection.docRef.updateCalls.single;
      expect(update['isFamilyTask'], false);
      expect(update['familyId'], isNull);
      expect(update['ownerIds'], ['u1']);
    });
  });

  group('claimOwnership / releaseOwnership', () {
    test('claim arrayUnions the claiming uid', () async {
      final built = buildRepo();
      await built.repo.claimOwnership(task(userId: 'u1', isFamilyTask: true, ownerIds: const []), 'u2');
      final update = built.collection.docRef.updateCalls.single;
      expect(update['ownerIds'], isA<FieldValue>());
    });

    test('release arrayRemoves the releasing uid', () async {
      final built = buildRepo();
      await built.repo.releaseOwnership(
        task(userId: 'u1', isFamilyTask: true, ownerIds: const ['u1', 'u2']),
        'u2',
      );
      final update = built.collection.docRef.updateCalls.single;
      expect(update['ownerIds'], isA<FieldValue>());
    });
  });
}
