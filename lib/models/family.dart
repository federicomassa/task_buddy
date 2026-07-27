import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMemberInfo {
  final String email;
  final DateTime joinedAt;

  const FamilyMemberInfo({required this.email, required this.joinedAt});

  factory FamilyMemberInfo.fromMap(Map<String, dynamic> map) {
    return FamilyMemberInfo(
      email: map['email'] as String,
      joinedAt: (map['joinedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email,
        'joinedAt': Timestamp.fromDate(joinedAt),
      };
}

class Family {
  final String id;
  final String createdBy;
  final List<String> memberIds;
  final Map<String, FamilyMemberInfo> members;
  final DateTime createdAt;

  const Family({
    required this.id,
    required this.createdBy,
    required this.memberIds,
    required this.members,
    required this.createdAt,
  });

  factory Family.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final membersMap = (data['members'] as Map<String, dynamic>?) ?? const {};
    return Family(
      id: doc.id,
      createdBy: data['createdBy'] as String,
      memberIds: (data['memberIds'] as List<dynamic>?)?.cast<String>() ?? [],
      members: membersMap.map(
        (uid, info) => MapEntry(uid, FamilyMemberInfo.fromMap(Map<String, dynamic>.from(info as Map))),
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
