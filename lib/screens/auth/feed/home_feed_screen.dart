import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/core/theme/app_theme.dart';
import '/models/post_model.dart';

class HomeFeedScreen extends StatelessWidget {
  const HomeFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'SIGMA888 FEED',
          style: TextStyle(color: AppColors.goldPrimary, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // ดึงข้อมูลโพสต์เรียงจากล่าสุด
        stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No posts yet. Be the first to share!',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final post = PostModel.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ส่วนหัว: ชื่อผู้ใช้
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.goldPrimary,
                          radius: 18,
                          child: Text(
                            post.displayName.isNotEmpty ? post.displayName[0].toUpperCase() : 'U',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.displayName,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              '@${post.username}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // เนื้อหาโพสต์
                    Text(
                      post.content,
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    // ไอคอนปุ่มไลก์ / คอมเมนต์
                    const Row(
                      children: [
                        Icon(Icons.favorite_border, color: AppColors.textMuted, size: 20),
                        SizedBox(width: 6),
                        Text('Like', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        SizedBox(width: 20),
                        Icon(Icons.chat_bubble_outline, color: AppColors.textMuted, size: 20),
                        SizedBox(width: 6),
                        Text('Comment', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}