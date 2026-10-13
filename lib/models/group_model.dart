import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String groupId;
  final String name;
  final String description;
  final String createdBy;
  final List<String> members;
  final Timestamp createdAt;

  GroupModel({
    required this.groupId,
    required this.name,
    required this.description,
    required this.createdBy,
    required this.members,
    required this.createdAt,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map, String docId) {
    return GroupModel(
      groupId: docId,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      createdBy: map['createdBy'] ?? '',
      members: List<String>.from(map['members'] ?? []),
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'createdBy': createdBy,
      'members': members,
      'createdAt': createdAt,
    };
  }
}