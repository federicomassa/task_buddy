import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;
  final String userId;
  final String name;
  final String colorHex;
  final DateTime createdAt;

  Category({
    required this.id,
    required this.userId,
    required this.name,
    required this.colorHex,
    required this.createdAt,
  });

  factory Category.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Category(
      id: doc.id,
      userId: data['userId'] as String,
      name: data['name'] as String,
      colorHex: data['colorHex'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'colorHex': colorHex,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
