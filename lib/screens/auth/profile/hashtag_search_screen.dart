/// SIGMA888: ค้นหาโพสต์ที่มีแฮชแท็กตรงกับคำค้น.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';
import '/widgets/hashtag_text.dart';
import '/widgets/network_video_player.dart';

/// แสดงผลโพสต์ที่บันทึก hashtag เดียวกับ tag ที่ผู้ใช้เลือก.
class HashtagSearchScreen extends StatelessWidget {
  final String tag;

  const HashtagSearchScreen({super.key, required this.tag});

  @override
  Widget build(BuildContext context) {
    final posts = FirebaseFirestore.instance
        .collection('posts')
        .where('visibility', isEqualTo: 'public')
        .where('hashtags', arrayContains: tag)
        .snapshots();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('#$tag', style: const TextStyle(color: AppColors.goldPrimary)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: posts,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Could not load hashtag posts.', style: TextStyle(color: AppColors.textMuted)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary));
          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final at = a.data()['createdAt'] as Timestamp?;
              final bt = b.data()['createdAt'] as Timestamp?;
              return (bt?.millisecondsSinceEpoch ?? 0).compareTo(at?.millisecondsSinceEpoch ?? 0);
            });
          if (docs.isEmpty) return const Center(child: Text('No posts with this hashtag yet.', style: TextStyle(color: AppColors.textMuted)));
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final content = (data['content'] ?? '').toString();
              final imageUrl = (data['imageUrl'] ?? '').toString();
              final videoUrl = (data['videoUrl'] ?? '').toString();
              return Card(
                color: AppColors.cardBg,
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text((data['displayName'] ?? data['username'] ?? 'Member').toString(), style: const TextStyle(color: AppColors.goldPrimary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      HashtagText(text: content, style: const TextStyle(color: Colors.white)),
                      if (videoUrl.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        NetworkVideoPlayer(url: videoUrl, height: 220),
                      ] else if (imageUrl.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(imageUrl, width: double.infinity, height: 220, fit: BoxFit.cover)),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
