// Fakes below implement CollectionReference/DocumentReference (sealed in
// cloud_firestore) purely for test doubles, following the same hand-rolled
// noSuchMethod-fallback pattern used in goal_repository_adjust_progress_test.dart.
// createFamily/redeemInvite/leaveFamily use WriteBatch/Transaction, whose
// generic Firestore SDK signatures aren't worth hand-faking here — those
// paths are covered by the Firestore emulator rules tests instead.
// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_buddy/core/clock.dart';
import 'package:task_buddy/services/family_repository.dart';

class _FakeDocRef implements DocumentReference<Map<String, dynamic>> {
  final List<Map<String, dynamic>> updateCalls = [];

  @override
  String get id => 'code123';

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
  ({FirestoreFamilyRepository repo, _FakeCollection collection}) buildRepo() {
    final docRef = _FakeDocRef();
    final collection = _FakeCollection(docRef);
    final firestore = _FakeFirestore(collection);
    final repo = FirestoreFamilyRepository(firestore, const SystemClock());
    return (repo: repo, collection: collection);
  }

  group('createInvite', () {
    test('creates an active, unredeemed, non-expiring invite', () async {
      final built = buildRepo();
      await built.repo.createInvite('f1', 'u1');
      final data = built.collection.addCalls.single;
      expect(data['familyId'], 'f1');
      expect(data['createdBy'], 'u1');
      expect(data['status'], 'active');
      expect(data['expiresAt'], isNull);
      expect(data['redeemedBy'], isEmpty);
    });
  });

  group('revokeInvite', () {
    test('flips status to revoked and nothing else', () async {
      final built = buildRepo();
      await built.repo.revokeInvite('code123');
      expect(built.collection.docRef.updateCalls.single, {'status': 'revoked'});
    });
  });
}
