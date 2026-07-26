import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_settings.dart';

abstract class UserSettingsRepository {
  Stream<UserSettings> streamSettings(String userId);

  Future<void> updateSettings({required String userId, required UserSettings settings});
}

class FirestoreUserSettingsRepository implements UserSettingsRepository {
  final FirebaseFirestore _db;

  FirestoreUserSettingsRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _collection => _db.collection('userSettings');

  @override
  Stream<UserSettings> streamSettings(String userId) {
    return _collection.doc(userId).snapshots().map(UserSettings.fromFirestore);
  }

  @override
  Future<void> updateSettings({required String userId, required UserSettings settings}) {
    return _collection.doc(userId).set(settings.toFirestore(), SetOptions(merge: true));
  }
}
