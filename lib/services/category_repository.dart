import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category.dart';

class CategoryRepository {
  final FirebaseFirestore _db;

  CategoryRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db.collection('categories');

  Stream<List<Category>> streamCategories(String userId) {
    return _collection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(Category.fromFirestore).toList());
  }

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

  Future<void> updateCategory(Category category) {
    return _collection.doc(category.id).update({
      'name': category.name,
      'colorHex': category.colorHex,
    });
  }

  Future<void> deleteCategory(String categoryId) {
    return _collection.doc(categoryId).delete();
  }
}
