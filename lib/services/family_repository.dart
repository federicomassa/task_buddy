import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/clock.dart';
import '../models/family.dart';

abstract class FamilyRepository {
  /// Watches the current user's `userFamily/{uid}` pointer doc, emitting the
  /// familyId they belong to (or null if they're not in one).
  Stream<String?> streamMyFamilyId(String userId);

  Stream<Family?> streamFamily(String familyId);

  /// Creates a new family with [userId] as its sole initial member. Returns
  /// the new familyId.
  Future<String> createFamily(String userId, String userEmail);

  /// Generates a new multi-use invite code for [familyId]. Returns the code.
  Future<String> createInvite(String familyId, String createdBy);

  Future<void> revokeInvite(String code);

  /// Redeems an invite [code], adding [userId] to the invite's family.
  ///
  /// This is deliberately NOT one atomic transaction/batch: the `families`
  /// join rule validates the join by reading back the `userFamily` pointer,
  /// and Firestore rules' get()/exists() calls only see the database as of
  /// the start of the current write -- they never see earlier writes from
  /// the same transaction or batch. So the pointer must be written and
  /// committed first, as its own request, before the `families` update is
  /// sent.
  Future<void> redeemInvite({
    required String code,
    required String userId,
    required String userEmail,
  });

  Future<void> leaveFamily({required String userId, required String familyId});
}

class FirestoreFamilyRepository implements FamilyRepository {
  final FirebaseFirestore _db;
  final Clock _clock;

  FirestoreFamilyRepository(this._db, this._clock);

  CollectionReference<Map<String, dynamic>> get _families => _db.collection('families');

  CollectionReference<Map<String, dynamic>> get _userFamily => _db.collection('userFamily');

  CollectionReference<Map<String, dynamic>> get _invites => _db.collection('familyInvites');

  @override
  Stream<String?> streamMyFamilyId(String userId) {
    return _userFamily.doc(userId).snapshots().map((doc) => doc.data()?['familyId'] as String?);
  }

  @override
  Stream<Family?> streamFamily(String familyId) {
    return _families.doc(familyId).snapshots().map((doc) => doc.exists ? Family.fromFirestore(doc) : null);
  }

  @override
  Future<String> createFamily(String userId, String userEmail) async {
    final familyRef = _families.doc();
    final now = Timestamp.fromDate(_clock.now());

    final batch = _db.batch();
    batch.set(familyRef, {
      'createdBy': userId,
      'memberIds': [userId],
      'members': {
        userId: {'email': userEmail, 'joinedAt': now},
      },
      'createdAt': now,
    });
    batch.set(_userFamily.doc(userId), {'familyId': familyRef.id});
    await batch.commit();

    return familyRef.id;
  }

  @override
  Future<String> createInvite(String familyId, String createdBy) async {
    final inviteRef = await _invites.add({
      'familyId': familyId,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(_clock.now()),
      'expiresAt': null,
      'status': 'active',
      'redeemedBy': <String>[],
    });
    return inviteRef.id;
  }

  @override
  Future<void> revokeInvite(String code) {
    return _invites.doc(code).update({'status': 'revoked'});
  }

  @override
  Future<void> redeemInvite({
    required String code,
    required String userId,
    required String userEmail,
  }) async {
    final inviteRef = _invites.doc(code);
    final inviteSnap = await inviteRef.get();
    final invite = inviteSnap.data();
    if (invite == null || invite['status'] != 'active') {
      throw StateError('Invite code is not valid or has been revoked');
    }
    final expiresAt = invite['expiresAt'] as Timestamp?;
    if (expiresAt != null && expiresAt.toDate().isBefore(_clock.now())) {
      throw StateError('Invite code has expired');
    }
    final familyId = invite['familyId'] as String;
    final now = Timestamp.fromDate(_clock.now());

    // If a previous attempt got this far but failed before the families
    // update below (e.g. the app was killed mid-join), the pointer already
    // exists -- re-`set`ting it would be rejected (the userFamily rule only
    // allows create, never update), so skip straight to the next step
    // instead of erroring out on a safe retry.
    final pointerSnap = await _userFamily.doc(userId).get();
    final existingFamilyId = pointerSnap.data()?['familyId'] as String?;
    if (existingFamilyId != null && existingFamilyId != familyId) {
      throw StateError('You are already part of a different family — leave it before joining another.');
    }
    if (existingFamilyId == null) {
      await _userFamily.doc(userId).set({'familyId': familyId});
    }

    try {
      await _families.doc(familyId).update({
        'memberIds': FieldValue.arrayUnion([userId]),
        'members.$userId': {'email': userEmail, 'joinedAt': now},
      });
    } catch (e) {
      // Roll back the pointer so a retry isn't stuck unable to re-create it.
      if (existingFamilyId == null) {
        await _userFamily.doc(userId).delete();
      }
      rethrow;
    }

    await inviteRef.update({
      'redeemedBy': FieldValue.arrayUnion([userId]),
    });
  }

  @override
  Future<void> leaveFamily({required String userId, required String familyId}) async {
    final batch = _db.batch();
    batch.delete(_userFamily.doc(userId));
    batch.update(_families.doc(familyId), {
      'memberIds': FieldValue.arrayRemove([userId]),
      'members.$userId': FieldValue.delete(),
    });
    await batch.commit();
  }
}
