import 'package:cloud_firestore/cloud_firestore.dart';

class CommentModel {
  final String commentId;
  final String uid;
  final String displayName;
  final String text;
  final Timestamp createdAt;

  CommentModel({
    required this.commentId,
    required this.uid,
    required this.displayName,
    required this.text,
    required this.createdAt,
  });

  factory CommentModel.fromMap(Map<String, dynamic> map, String docId) {
    return CommentModel(
      commentId: docId,
      uid: map['uid'] ?? '',
      displayName: map['displayName'] ?? '',
      text: map['text'] ?? '',
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'displayName': displayName,
      'text': text,
      'createdAt': createdAt,
    };
  }
}