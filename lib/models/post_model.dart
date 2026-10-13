import 'package:cloud_firestore/cloud_firestore.dart';

class PostModel {
  final String postId;
  final String uid;
  final String username;
  final String displayName;
  final String content;
  final String? mediaUrl;
  final Timestamp createdAt;
  final List<String> likes;

  PostModel({
    required this.postId,
    required this.uid,
    required this.username,
    required this.displayName,
    required this.content,
    this.mediaUrl,
    required this.createdAt,
    required this.likes,
  });

  factory PostModel.fromMap(Map<String, dynamic> map, String docId) {
    return PostModel(
      postId: docId,
      uid: map['uid'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? '',
      content: map['content'] ?? '',
      mediaUrl: map['mediaUrl'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      likes: List<String>.from(map['likes'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'username': username,
      'displayName': displayName,
      'content': content,
      'mediaUrl': mediaUrl,
      'createdAt': createdAt,
      'likes': likes,
    };
  }
}