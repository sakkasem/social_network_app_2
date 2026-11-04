// บทบาทไฟล์: อ่านและจัดการแจ้งเตือนของผู้ใช้จาก Firestore (lib/services/notification_service.dart).
/// SIGMA888: ฟังแจ้งเตือนใหม่ นับจำนวนที่ยังไม่อ่าน และทำเครื่องหมายว่าอ่านแล้ว

import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static CollectionReference<Map<String, dynamic>> _ref(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('notifications');

  /// รายการแจ้งเตือนล่าสุด (ใหม่สุดก่อน)
  static Stream<QuerySnapshot<Map<String, dynamic>>> latest(String uid) =>
      _ref(uid).orderBy('createdAt', descending: true).limit(50).snapshots();

  /// จำนวนแจ้งเตือนที่ยังไม่อ่าน (ใช้ทำ badge)
  static Stream<int> unreadCount(String uid) => _ref(uid)
      .where('read', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.length);

  static Future<void> markRead(String uid, String notificationId) =>
      _ref(uid).doc(notificationId).update({'read': true});

  static Future<void> markAllRead(String uid) async {
    final unread = await _ref(uid).where('read', isEqualTo: false).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  /// แปลงข้อมูลแจ้งเตือนเป็นข้อความที่อ่านง่าย
  static String describe(Map<String, dynamic> data) {
    final name = (data['actorName'] as String?)?.trim();
    final who = (name == null || name.isEmpty) ? 'Someone' : name;
    switch (data['type']) {
      case 'like':
        return '$who liked your post';
      case 'comment':
        return '$who commented on your post';
      default:
        return '$who interacted with your post';
    }
  }
}
