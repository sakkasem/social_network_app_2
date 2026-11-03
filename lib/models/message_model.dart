/// SIGMA888: แทนข้อความแชต รวมถึงข้อความรูปภาพและเวลา

import 'package:cloud_firestore/cloud_firestore.dart';

/// MessageModel เก็บโครงสร้างข้อมูลและช่วยแปลงข้อมูลระหว่างแอปกับ Firestore.
class MessageModel {
  final String messageId;
  final String senderId;
  final String receiverId;
  final String message;
  final String imageUrl;
  final String videoUrl;
  final Timestamp timestamp;

  MessageModel({
    required this.messageId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.imageUrl = '',
    this.videoUrl = '',
    required this.timestamp,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map, String docId) {
    return MessageModel(
      messageId: docId,
      senderId: map['senderId'] ?? '',
      receiverId: map['receiverId'] ?? '',
      message: map['message'] ?? '',
      imageUrl: (map['imageUrl'] ?? '').toString(),
      videoUrl: (map['videoUrl'] ?? '').toString(),
      timestamp: map['timestamp'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'receiverId': receiverId,
      'message': message,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'timestamp': timestamp,
    };
  }
}
