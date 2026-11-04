// บทบาทไฟล์: เรียกใช้บริการภายนอกและงานข้อมูลส่วนกลาง (lib/services/post_engagement_service.dart).
/// SIGMA888: จัดการ atomic การโหวตและ emoji reaction ของโพสต์ใน Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';

/// รวมการเขียนปฏิกิริยาของโพสต์โดยแก้เฉพาะ uid ของผู้ใช้ปัจจุบัน.
class PostEngagementService {
  /// สลับ Like/Dislike โดยถอดสถานะตรงข้ามพร้อมกันในคำขอเดียว.
  static Future<void> toggleVote({
    required DocumentReference<Map<String, dynamic>> postRef,
    required String userId,
    required bool currentlySelected,
    required bool isLike,
  }) {
    final selectedField = isLike ? 'likes' : 'dislikes';
    final oppositeField = isLike ? 'dislikes' : 'likes';
    return postRef.update({
      selectedField: currentlySelected
          ? FieldValue.arrayRemove([userId])
          : FieldValue.arrayUnion([userId]),
      oppositeField: FieldValue.arrayRemove([userId]),
    });
  }

  /// กำหนดหรือลบ reaction ของ uid ใน map โดยไม่เขียนทับ reaction ของคนอื่น.
  static Future<void> setReaction({
    required DocumentReference<Map<String, dynamic>> postRef,
    required String userId,
    required String? emoji,
  }) {
    return postRef.update({
      'reactions.$userId': emoji == null ? FieldValue.delete() : emoji,
    });
  }
}
