// บทบาทไฟล์: คอมโพเนนต์ Widget ที่นำกลับมาใช้ซ้ำ (lib/widgets/post_author_avatar.dart).
/// SIGMA888: แสดงรูปผู้เขียนจากโปรไฟล์ Firestore แบบสด พร้อมภาพสำรอง

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';

/// แสดงรูปโปรไฟล์ล่าสุดจาก Firestore และใช้ URL ที่บันทึกในโพสต์เก่าเป็นภาพสำรอง.
// แสดงภาพผู้เขียนแบบสดจาก user_directory และใช้ข้อมูลโพสต์เป็น fallback
class PostAuthorAvatar extends StatelessWidget {
  final String uid;
  final String displayName;
  final String photoUrl;
  final double radius;

  const PostAuthorAvatar({
    super.key,
    required this.uid,
    required this.displayName,
    this.photoUrl = '',
    this.radius = 18,
  });

  @override
  // StreamBuilder ฟังข้อมูลโปรไฟล์ล่าสุด; เมื่อมี photoUrl ใหม่จะสร้างภาพใหม่ทันที
  Widget build(BuildContext context) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('user_directory').doc(uid).snapshots(),
        builder: (context, snapshot) {
          final profile = snapshot.data?.data();
          final currentName = (profile?['displayName'] ?? displayName).toString();
          // ใช้ URL ในโพสต์เป็นภาพสำรองก่อนข้อมูล directory มา แล้วเลือก photoUrl ล่าสุดจาก Firestore
          final currentPhoto = profile == null
              ? photoUrl
              : (profile['photoUrl'] ?? '').toString();
          final diameter = radius * 2;

          if (currentPhoto.isEmpty) return _fallback(currentName);
          return SizedBox(
            width: diameter,
            height: diameter,
            child: ClipOval(
              child: Image.network(
                currentPhoto,
                width: diameter,
                height: diameter,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(currentName),
              ),
            ),
          );
        },
      );

  // แสดงอักษรย่อเมื่อยังไม่มี URL หรือโหลดภาพจากเครือข่ายไม่สำเร็จ
  Widget _fallback(String name) => CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.goldPrimary,
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      );
}
