import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_settings.dart';

abstract class UserSettingsRepository {
  Stream<UserSettings> streamSettings(String userId);

  Future<void> updateReminder({
    required String userId,
    required bool enabled,
    required int minutes,
  });
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
  Future<void> updateReminder({
    required String userId,
    required bool enabled,
    required int minutes,
  }) {
    return _collection.doc(userId).set(
      UserSettings(reminderEnabled: enabled, reminderMinutes: minutes).toFirestore(),
      SetOptions(merge: true),
    );
  }
}
