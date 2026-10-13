import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '/providers/auth_provider.dart';
import '/core/theme/app_theme.dart';
import '/models/post_model.dart';
import '/models/comment_model.dart';

class HomeFeedScreen extends StatelessWidget {
  const HomeFeedScreen({super.key});

  // ฟังก์ชันสำหรับกด Like หรือ Unlike โพสต์
  void _toggleLike(BuildContext context, String postId, List<String> currentLikes) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.uid;

    if (currentUserId == null) return;

    List<String> updatedLikes = List.from(currentLikes);
    if (updatedLikes.contains(currentUserId)) {
      updatedLikes.remove(currentUserId); // ถ้าเคยไลก์แล้ว ให้เอาออก (Unlike)
    } else {
      updatedLikes.add(currentUserId); // ถ้ายังไม่ไลก์ ให้เพิ่มเข้าไป (Like)
    }

    try {
      await FirebaseFirestore.instance.collection('posts').doc(postId).update({
        'likes': updatedLikes,
      });
    } catch (e) {
      debugPrint('Error updating like: $e');
    }
  }

  // ฟังก์ชันแสดง Modal Bottom Sheet สำหรับคอมเมนต์
  void _showCommentsModal(BuildContext context, String postId) {
    final TextEditingController commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // แถบด้านบน
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Comments',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: AppColors.border, height: 1),

                // รายการคอมเมนต์เรียลไทม์
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(postId)
                        .collection('comments')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppColors.goldPrimary),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'No comments yet. Start the conversation!',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        );
                      }

                      final docs = snapshot.data!.docs;

                      return ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final comment = CommentModel.fromMap(
                            docs[index].data() as Map<String, dynamic>,
                            docs[index].id,
                          );

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.goldPrimary,
                                  child: Text(
                                    comment.displayName.isNotEmpty
                                        ? comment.displayName[0].toUpperCase()
                                        : 'U',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        comment.displayName,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        comment.text,
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                //ช่องพิมพ์ส่งคอมเมนต์
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commentController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'Add a comment...',
                            hintStyle: TextStyle(color: AppColors.textMuted),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.send, color: AppColors.goldPrimary),
                        onPressed: () async {
                          if (commentController.text.trim().isEmpty) return;

                          final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
                          if (user == null) return;

                          final text = commentController.text.trim();
                          commentController.clear();

                          // บันทึกลง Subcollection 'comments' ของโพสต์นั้นๆ
                          await FirebaseFirestore.instance
                              .collection('posts')
                              .doc(postId)
                              .collection('comments')
                              .add({
                            'uid': user.uid,
                            'displayName': user.displayName,
                            'text': text,
                            'createdAt': Timestamp.now(),
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthProvider>(context).currentUser?.uid ?? '';

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
              final bool isLiked = post.likes.contains(currentUserId);

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
                    // ส่วนหัว
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
                    Text(
                      post.content,
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // ปุ่ม Like
                        InkWell(
                          onTap: () => _toggleLike(context, post.postId, post.likes),
                          child: Row(
                            children: [
                              Icon(
                                isLiked ? Icons.favorite : Icons.favorite_border,
                                color: isLiked ? Colors.redAccent : AppColors.textMuted,
                                size: 20,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${post.likes.length}',
                                style: TextStyle(
                                  color: isLiked ? Colors.redAccent : AppColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        // ปุ่ม Comment ที่กดเปิด Modal Sheet ได้แล้ว
                        InkWell(
                          onTap: () => _showCommentsModal(context, post.postId),
                          child: const Row(
                            children: [
                              Icon(Icons.chat_bubble_outline, color: AppColors.textMuted, size: 20),
                              SizedBox(width: 6),
                              Text('Comment', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                            ],
                          ),
                        ),
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