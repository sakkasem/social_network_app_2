import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '/providers/auth_provider.dart';
import '/core/theme/app_theme.dart';
import '/models/post_model.dart';
import '/models/comment_model.dart';
import '/widgets/post_author_avatar.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _blockedSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _blockedBySubscription;
  String? _blockListUid;
  final Set<String> _blockedUsers = {};
  Set<String> _blockedByMe = {};
  Set<String> _blockedMe = {};
  bool _gotBlocked = false;
  bool _gotBlockedBy = false;
  String? _blockListError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid != _blockListUid) _listenToBlockLists(uid);
  }

  void _listenToBlockLists(String? uid) {
    _blockedSubscription?.cancel();
    _blockedBySubscription?.cancel();
    _blockListUid = uid;
    _blockedByMe = {};
    _blockedMe = {};
    _blockedUsers.clear();
    _gotBlocked = uid == null;
    _gotBlockedBy = uid == null;
    _blockListError = null;
    if (uid == null) return;

    void update() {
      if (!mounted) return;
      setState(() {
        _blockedUsers
          ..clear()
          ..addAll(_blockedByMe)
          ..addAll(_blockedMe);
      });
    }

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    _blockedSubscription = userRef.collection('blocked').snapshots().listen((snapshot) {
      _blockedByMe = snapshot.docs.map((doc) => doc.id).toSet();
      _gotBlocked = true;
      update();
    }, onError: (_) {
      if (mounted) setState(() => _blockListError = 'Could not load blocked users.');
    });
    _blockedBySubscription = userRef.collection('blockedBy').snapshots().listen((snapshot) {
      _blockedMe = snapshot.docs.map((doc) => doc.id).toSet();
      _gotBlockedBy = true;
      update();
    }, onError: (_) {
      if (mounted) setState(() => _blockListError = 'Could not load blocked users.');
    });
  }

  @override
  void dispose() {
    _blockedSubscription?.cancel();
    _blockedBySubscription?.cancel();
    super.dispose();
  }

  Future<void> _reportPost(PostModel post) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Report post', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: reasonController,
          maxLength: 500,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Tell us why this post should be reviewed'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, reasonController.text.trim()), child: const Text('Submit')),
        ],
      ),
    );
    reasonController.dispose();
    final reporterUid = context.read<AuthProvider>().currentUser?.uid;
    if (reason == null || reason.isEmpty || reporterUid == null || !mounted) return;
    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'reporterUid': reporterUid,
        'targetType': 'post',
        'targetId': post.postId,
        'reason': reason,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) _showMessage('Report submitted.');
    } catch (_) {
      if (mounted) _showMessage('Could not submit report. Please try again.');
    }
  }

  Future<void> _createNotification({
    required String recipientUid,
    required String postId,
    required String type,
    String? sourceId,
  }) async {
    final actor = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (actor == null || recipientUid == actor.uid) return;

    final data = <String, dynamic>{
      'actorUid': actor.uid,
      'actorName': actor.displayName,
      'postId': postId,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    };
    if (sourceId != null) data['sourceId'] = sourceId;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(recipientUid)
        .collection('notifications')
        .add(data);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ฟังก์ชันสำหรับกด Like หรือ Unlike โพสต์
  Future<void> _toggleLike(BuildContext context, PostModel post) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    final currentUserId = user?.uid;

    if (currentUserId == null) return;

    final isRemovingLike = post.likes.contains(currentUserId);
    try {
      await FirebaseFirestore.instance.collection('posts').doc(post.postId).update({
        'likes': isRemovingLike
            ? FieldValue.arrayRemove([currentUserId])
            : FieldValue.arrayUnion([currentUserId]),
      });
      if (!isRemovingLike) {
        try {
          await _createNotification(
            recipientUid: post.uid,
            postId: post.postId,
            type: 'like',
          );
        } catch (e) {
          debugPrint('Could not create like notification: $e');
        }
      }
    } catch (e) {
      debugPrint('Error updating like: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update like. Please try again.')),
        );
      }
    }
  }

  // ฟังก์ชันแสดง Modal Bottom Sheet สำหรับคอมเมนต์
  Future<void> _editPost(PostModel post) async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null || user.uid != post.uid) return;

    final controller = TextEditingController(text: post.content);
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Edit post', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          maxLength: 1000,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Write something...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
        ],
      ),
    );
    final updatedContent = controller.text.trim();
    controller.dispose();
    if (shouldSave != true || (updatedContent.isEmpty && post.imageUrl.isEmpty) || !mounted) return;

    try {
      final postRef = FirebaseFirestore.instance.collection('posts').doc(post.postId);
      final latestPost = await postRef.get();
      if (!mounted) return;
      if (!latestPost.exists || latestPost.data()?['uid'] != user.uid) {
        _showMessage('You can only edit your own posts.');
        return;
      }
      await postRef.update({'content': updatedContent});
      if (mounted) _showMessage('Post updated.');
    } catch (e) {
      debugPrint('Error editing post: $e');
      if (mounted) _showMessage('Could not update post. Please try again.');
    }
  }

  Future<void> _confirmDeletePost(PostModel post) async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null || user.uid != post.uid) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Delete post?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will permanently delete your post and its comments.',
          style: TextStyle(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final postRef = FirebaseFirestore.instance.collection('posts').doc(post.postId);
      final latestPost = await postRef.get();
      if (!mounted) return;
      if (!latestPost.exists || latestPost.data()?['uid'] != user.uid) {
        _showMessage('You can only delete your own posts.');
        return;
      }

      // Firestore does not automatically delete subcollection documents.
      while (true) {
        final comments = await postRef.collection('comments').limit(450).get();
        if (comments.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final comment in comments.docs) {
          batch.delete(comment.reference);
        }
        await batch.commit();
      }
      await postRef.delete();
      if (mounted) _showMessage('Post deleted.');
    } catch (e) {
      debugPrint('Error deleting post: $e');
      if (mounted) _showMessage('Could not delete post. Please try again.');
    }
  }

  void _showCommentsModal(BuildContext context, String postId) {
    final parentContext = context;
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
                      if (snapshot.hasError) {
                        return Center(
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Future<void>.delayed(Duration.zero, () {
                                if (parentContext.mounted) {
                                  _showCommentsModal(parentContext, postId);
                                }
                              });
                            },
                            icon: const Icon(Icons.refresh, color: AppColors.goldPrimary),
                            label: const Text('Could not load comments. Retry', style: TextStyle(color: AppColors.goldPrimary)),
                          ),
                        );
                      }
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
                          final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);
                          final commentRef = await postRef.collection('comments').add({
                            'uid': user.uid,
                            'displayName': user.displayName,
                            'text': text,
                            'createdAt': Timestamp.now(),
                          });
                          try {
                            final postSnapshot = await postRef.get();
                            final ownerUid = postSnapshot.data()?['uid'] as String?;
                            if (postSnapshot.exists && ownerUid != null) {
                              await _createNotification(
                                recipientUid: ownerUid,
                                postId: postId,
                                type: 'comment',
                                sourceId: commentRef.id,
                              );
                            }
                          } catch (e) {
                            debugPrint('Could not create comment notification: $e');
                          }
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
    final currentUserId = Provider.of<AuthProvider>(context).currentUser?.uid;
    final signedInUid = currentUserId ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'SIGMA888 FEED',
          style: TextStyle(color: AppColors.goldPrimary, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1),
        ),
      ),
      body: _blockListError != null
          ? Center(child: TextButton.icon(onPressed: () => _listenToBlockLists(currentUserId), icon: const Icon(Icons.refresh), label: Text("$_blockListError Retry")))
          : (!_gotBlocked || !_gotBlockedBy)
              ? const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary))
              : StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('posts').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton.icon(
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh, color: AppColors.goldPrimary),
                label: const Text('Could not load feed. Retry', style: TextStyle(color: AppColors.goldPrimary)),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary));
          }

          final docs = (snapshot.data?.docs ?? []).where((doc) {
            final post = PostModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
            return !_blockedUsers.contains(post.uid);
          }).toList();

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'No posts yet. Be the first to share!',
                style: TextStyle(color: AppColors.textMuted),
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final post = PostModel.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
              final bool isLiked = post.likes.contains(signedInUid);

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
                        PostAuthorAvatar(
                          uid: post.uid,
                          displayName: post.displayName,
                          photoUrl: post.userPhotoUrl,
                          radius: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
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
                        )),
                        PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
                            color: AppColors.cardBg,
                            onSelected: (action) {
                              if (action == 'edit') _editPost(post);
                              if (action == 'delete') _confirmDeletePost(post);
                              if (action == 'report') _reportPost(post);
                            },
                            itemBuilder: (context) => post.uid == currentUserId
                                ? const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit post')),
                                    PopupMenuItem(value: 'delete', child: Text('Delete post', style: TextStyle(color: Colors.redAccent))),
                                  ]
                                : const [PopupMenuItem(value: 'report', child: Text('Report post'))],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      post.content,
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                    ),
                    if (post.imageUrl.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          post.imageUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          // ใส่ Loading ตอนรูปกำลังโหลด
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 200,
                              color: AppColors.cardBg,
                              child: const Center(
                                child: CircularProgressIndicator(color: AppColors.goldPrimary),
                              ),
                            );
                          },
                          // จัดการกรณีโหลดรูปไม่สำเร็จ
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 200,
                            color: AppColors.cardBg,
                            child: const Center(
                              child: Icon(Icons.broken_image, color: AppColors.textMuted, size: 40),
                            ),
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        // ปุ่ม Like
                        InkWell(
                          onTap: () => _toggleLike(context, post),
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
