import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/clock.dart';
import '../models/category.dart';

abstract class CategoryRepository {
  Stream<List<Category>> streamCategories(String userId);

  Future<void> addCategory({
    required String userId,
    required String name,
    required String colorHex,
  });

  Future<void> updateCategory(Category category);

  Future<void> deleteCategory(String categoryId);
}

class FirestoreCategoryRepository implements CategoryRepository {
  final FirebaseFirestore _db;
  final Clock _clock;

  FirestoreCategoryRepository(this._db, this._clock);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('categories');

  @override
  Stream<List<Category>> streamCategories(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Category.fromFirestore(d, now: _clock.now())).toList());
  }

  @override
  Future<void> addCategory({
    required String userId,
    required String name,
    required String colorHex,
  }) {
    return _collection.add({
      'userId': userId,
      'name': name,
      'colorHex': colorHex,
      'createdAt': Timestamp.now(),
    });
  }

  @override
  Future<void> updateCategory(Category category) {
    return _collection.doc(category.id).update({
      'name': category.name,
      'colorHex': category.colorHex,
    });
  }

  @override
  Future<void> deleteCategory(String categoryId) {
    return _collection.doc(categoryId).delete();
  }
}
