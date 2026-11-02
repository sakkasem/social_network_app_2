/// SIGMA888: จุดแดงแจ้งเตือนคำขอเป็นเพื่อนและข้อความแชตที่ยังไม่ได้อ่าน

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// จุดแดงขนาดเล็กสำหรับซ้อนบนไอคอนหรือแถวรายการ.
class RedDot extends StatelessWidget {
  final double size;
  const RedDot({super.key, this.size = 10});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
      );
}

/// ซ้อนจุดแดงที่มุมขวาบนของ [child] เมื่อ [show] เป็นจริง.
class DotBadge extends StatelessWidget {
  final bool show;
  final Widget child;
  const DotBadge({super.key, required this.show, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (show) const Positioned(right: -2, top: -2, child: RedDot()),
        ],
      );
}

/// ห้องแชตนี้มีข้อความจากคู่สนทนาที่ใหม่กว่าเวลาอ่านล่าสุดของผู้ใช้หรือไม่.
bool isChatRoomUnread(Map<String, dynamic> room, String uid) {
  final lastSender = room['lastSenderId'] as String?;
  final lastAt = room['lastMessageAt'] as Timestamp?;
  if (lastSender == null || lastSender == uid || lastAt == null) return false;
  final readAt = (room['readAt'] as Map?)?[uid] as Timestamp?;
  return readAt == null || lastAt.compareTo(readAt) > 0;
}

/// สตรีมจำนวนห้องแชตที่ยังไม่ได้อ่านของผู้ใช้.
Stream<int> unreadChatCountStream(String uid) => FirebaseFirestore.instance
    .collection('chat_rooms')
    .where('participants', arrayContains: uid)
    .snapshots()
    .map((s) => s.docs
        .where((d) => isChatRoomUnread(d.data(), uid))
        .length);

/// สตรีมจำนวนคำขอเป็นเพื่อนที่รอการตอบรับ (เอกสารที่ยังไม่ถูกลบคือ pending).
Stream<int> pendingFriendRequestCountStream(String uid) => FirebaseFirestore.instance
    .collection('users')
    .doc(uid)
    .collection('friendRequests')
    .snapshots()
    .map((s) => s.docs.length);
