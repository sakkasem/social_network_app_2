/// SIGMA888: แทนโพสต์ ฟิลด์ผู้เขียน รูปภาพ ไลก์ และเวลา

import 'package:cloud_firestore/cloud_firestore.dart';

/// โมเดลโพสต์ที่เก็บผู้เขียน เนื้อหา รูปภาพ ไลก์ และเวลา รวมถึงแปลงข้อมูล Firestore.
class PostModel {
  final String postId;
  final String uid;
  final String username;
  final String displayName;
  final String userPhotoUrl;
  final String content;
  final String imageUrl;
  final String videoUrl;
  final Timestamp createdAt;
  final List<String> likes;
  final List<String> dislikes;
  final Map<String, String> reactions;

  PostModel({
    required this.postId,
    required this.uid,
    required this.username,
    required this.displayName,
    this.userPhotoUrl = '',
    required this.content,
    required this.imageUrl,
    this.videoUrl = '',
    required this.createdAt,
    required this.likes,
    this.dislikes = const [],
    this.reactions = const {},
  });

  /// สร้างโมเดลจากข้อมูล Firestore และใช้ document id เป็น postId.
  factory PostModel.fromMap(Map<String, dynamic> map, String docId) {
    return PostModel(
      postId: docId,
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? '',
      userPhotoUrl: (map['userPhotoUrl'] ?? '').toString(),
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      videoUrl: (map['videoUrl'] ?? '').toString(),
      createdAt: map['createdAt'] ?? Timestamp.now(),
      likes: List<String>.from(map['likes'] ?? []),
      dislikes: List<String>.from(map['dislikes'] ?? []),
      reactions: Map<String, String>.from(map['reactions'] ?? const <String, String>{}),
    );
  }

  /// แปลงฟิลด์ของโมเดลเป็น Map สำหรับบันทึกใน Firestore.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'displayName': displayName,
      'userPhotoUrl': userPhotoUrl,
      'content': content,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'createdAt': createdAt,
      'likes': likes,
      'dislikes': dislikes,
      'reactions': reactions,
    };
  }
}
