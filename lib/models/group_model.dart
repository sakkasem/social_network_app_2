// บทบาทไฟล์: ประกาศ Model และการแปลงข้อมูลของโดเมนแอป (lib/models/group_model.dart).
/// SIGMA888: แทนข้อมูลกลุ่มและจัดการแปลงข้อมูล Firestore

import 'package:cloud_firestore/cloud_firestore.dart';

/// GroupModel เก็บโครงสร้างข้อมูลและช่วยแปลงข้อมูลระหว่างแอปกับ Firestore.
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