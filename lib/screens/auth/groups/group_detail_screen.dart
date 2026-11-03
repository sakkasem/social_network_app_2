/// SIGMA888: แสดงรายละเอียดกลุ่ม Feed สมาชิก และสร้างโพสต์ในกลุ่ม

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '/core/theme/app_theme.dart';
import '/models/post_model.dart';
import '/providers/auth_provider.dart';
import '/services/cloudinary_service.dart';
import '/widgets/post_author_avatar.dart';
import '/widgets/network_video_player.dart';
import '/widgets/hashtag_text.dart';
import '/widgets/post_engagement_bar.dart';
import '/services/post_engagement_service.dart';
import 'group_chat_screen.dart';
import 'group_management_screen.dart';

/// GroupDetailScreen เป็นหน้าจอของฟีเจอร์ที่ระบุด้วยชื่อคลาสนี้.
class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupDetailScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

/// _GroupDetailScreenState จัดการ state, lifecycle และการตอบสนองต่อเหตุการณ์ของหน้าจอที่เกี่ยวข้อง.
class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _updatingCover = false;

  /// เลือกภาพปก อัปโหลด Cloudinary และอัปเดต URL ของกลุ่ม.
  Future<void> _changeCoverPhoto() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image == null) return;
      setState(() => _updatingCover = true);
      final bytes = await image.readAsBytes();
      final url = await CloudinaryService.uploadImage(bytes, filenamePrefix: 'group_cover');
      await _firestore.collection('groups').doc(widget.groupId).update({'coverPhotoUrl': url});
      if (mounted) _showMessage('Group cover photo updated.');
    } catch (_) {
      if (mounted) _showMessage('Could not update the cover photo. Please try again.');
    } finally {
      if (mounted) setState(() => _updatingCover = false);
    }
  }

  /// เข้าร่วมหรือออกจากกลุ่มด้วย atomic array transform บนฟิลด์ members.
  Future<void> _toggleMembership(List<String> members, String uid) async {
    final ref = _firestore.collection('groups').doc(widget.groupId);
    final isMember = members.contains(uid);
    try {
      await ref.update({
        'members': isMember ? FieldValue.arrayRemove([uid]) : FieldValue.arrayUnion([uid]),
      });
    } catch (_) {
      if (mounted) _showMessage('Could not update your group membership. Please try again.');
    }
  }

  /// เปิดตัวสร้างโพสต์กลุ่มสำหรับสมาชิก.
  Future<void> _createPost() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateGroupPostDialog(groupId: widget.groupId),
    );
    if (created == true && mounted) _showMessage('Your group post was published.');
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatScreen(groupId: widget.groupId, groupName: widget.groupName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().currentUser?.uid ?? '';
    final groupRef = _firestore.collection('groups').doc(widget.groupId);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          title: Text(widget.groupName, style: const TextStyle(color: AppColors.goldPrimary, fontSize: 16)),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              tooltip: 'Group chat',
              onPressed: _openChat,
              icon: const Icon(Icons.forum_outlined, color: AppColors.goldPrimary),
            ),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: groupRef.snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: TextButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh, color: AppColors.goldPrimary),
                  label: const Text('Could not load this group. Retry', style: TextStyle(color: AppColors.goldPrimary)),
                ),
              );
            }
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary));
            final group = snapshot.data!.data();
            if (group == null) return const Center(child: Text('This group no longer exists.', style: TextStyle(color: AppColors.textMuted)));

            final members = List<String>.from(group['members'] ?? const []);
            final isMember = members.contains(uid);
            final isCreator = group['createdBy'] == uid;
            final coverUrl = (group['coverPhotoUrl'] ?? '').toString();
            final groupName = (group['name'] ?? widget.groupName).toString();
            final description = (group['description'] ?? '').toString();

            return Column(
              children: [
                _GroupCover(
                  coverUrl: coverUrl,
                  memberCount: members.length,
                  onEdit: isCreator ? _changeCoverPhoto : null,
                  isUpdating: _updatingCover,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(groupName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(description, style: const TextStyle(color: AppColors.textMuted, height: 1.35)),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (!isCreator)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: uid.isEmpty ? null : () => _toggleMembership(members, uid),
                                icon: Icon(isMember ? Icons.check : Icons.group_add),
                                label: Text(isMember ? 'Leave group' : 'Join group'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isMember ? Colors.white : AppColors.goldPrimary,
                                  side: BorderSide(color: isMember ? AppColors.border : AppColors.goldPrimary),
                                ),
                              ),
                            ),
                          if (isCreator)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => GroupManagementScreen(groupId: widget.groupId, groupName: groupName)),
                                ),
                                icon: const Icon(Icons.manage_accounts),
                                label: const Text('Manage members'),
                                style: OutlinedButton.styleFrom(foregroundColor: AppColors.goldPrimary),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isMember ? _openChat : null,
                              icon: const Icon(Icons.forum_outlined),
                              label: const Text('Group chat'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.goldPrimary,
                                foregroundColor: Colors.black,
                                disabledBackgroundColor: AppColors.cardBg,
                                disabledForegroundColor: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  indicatorColor: AppColors.goldPrimary,
                  labelColor: AppColors.goldPrimary,
                  unselectedLabelColor: AppColors.textMuted,
                  tabs: [Tab(text: 'Feed'), Tab(text: 'Members')],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _GroupFeedTab(
                        groupId: widget.groupId,
                        isMember: isMember,
                        creatorUid: (group['createdBy'] ?? '').toString(),
                        onCreatePost: _createPost,
                      ),
                      _GroupMembersTab(members: members, creatorUid: (group['createdBy'] ?? '').toString()),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// _GroupCover รวมหน้าที่เฉพาะของส่วนประกอบนี้ไว้ในตำแหน่งเดียว.
class _GroupCover extends StatelessWidget {
  final String coverUrl;
  final int memberCount;
  final VoidCallback? onEdit;
  final bool isUpdating;

  const _GroupCover({required this.coverUrl, required this.memberCount, required this.onEdit, required this.isUpdating});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 190,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (coverUrl.isNotEmpty)
              Image.network(coverUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback())
            else
              _fallback(),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 16,
              child: Text('$memberCount members', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
            if (onEdit != null)
              Positioned(
                right: 12,
                top: 12,
                child: IconButton.filledTonal(
                  tooltip: 'Change cover photo',
                  onPressed: isUpdating ? null : onEdit,
                  icon: isUpdating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.photo_camera_outlined),
                  style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: AppColors.goldPrimary),
                ),
              ),
          ],
        ),
      );

  Widget _fallback() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Color(0xff3d3217), Color(0xff111111)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: const Center(child: Icon(Icons.groups_rounded, color: AppColors.goldPrimary, size: 68)),
      );
}

/// _GroupFeedTab รวมหน้าที่เฉพาะของส่วนประกอบนี้ไว้ในตำแหน่งเดียว.
class _GroupFeedTab extends StatelessWidget {
  final String groupId;
  final bool isMember;
  final String creatorUid;
  final VoidCallback onCreatePost;

  const _GroupFeedTab({required this.groupId, required this.isMember, required this.creatorUid, required this.onCreatePost});

  @override
  Widget build(BuildContext context) {
    if (!isMember) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text('Join this group to view its posts and share with members.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
        ),
      );
    }
    final postsRef = FirebaseFirestore.instance.collection('groups').doc(groupId).collection('posts');
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCreatePost,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Write a post'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.goldPrimary, alignment: Alignment.centerLeft),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: postsRef.orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Could not load group posts.', style: TextStyle(color: AppColors.textMuted)));
              }
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary));
              if (snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No posts yet. Start the conversation!', style: TextStyle(color: AppColors.textMuted)));
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  return _GroupPostCard(
                    groupId: groupId,
                    creatorUid: creatorUid,
                    post: PostModel.fromMap(doc.data(), doc.id),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// _GroupPostCard รวมหน้าที่เฉพาะของส่วนประกอบนี้ไว้ในตำแหน่งเดียว.
class _GroupPostCard extends StatelessWidget {
  final String groupId;
  final String creatorUid;
  final PostModel post;

  const _GroupPostCard({required this.groupId, required this.creatorUid, required this.post});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final userId = user?.uid ?? '';
    final postRef = FirebaseFirestore.instance.collection('groups').doc(groupId).collection('posts').doc(post.postId);
    return Card(
      color: AppColors.cardBg,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: AppColors.border)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PostAuthorAvatar(
                  uid: post.uid,
                  displayName: post.displayName,
                  photoUrl: post.userPhotoUrl,
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(post.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text('@${post.username}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                Text(_timeLabel(post.createdAt), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                if (user != null && (user.uid == post.uid || user.uid == creatorUid))
                  PopupMenuButton<String>(
                    color: AppColors.cardBg,
                    onSelected: (action) {
                      if (action == 'edit' && user.uid == post.uid) _editPost(context, postRef, post);
                      if (action == 'delete') _deletePost(context, postRef);
                    },
                    itemBuilder: (_) => [
                      if (user.uid == post.uid) const PopupMenuItem(value: 'edit', child: Text('Edit post')),
                      const PopupMenuItem(value: 'delete', child: Text('Delete post')),
                    ],
                  ),
              ],
            ),
            if (post.content.isNotEmpty) ...[
              const SizedBox(height: 12),
              HashtagText(text: post.content, style: const TextStyle(color: Colors.white, height: 1.4)),
            ],
            if (post.videoUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: NetworkVideoPlayer(url: post.videoUrl, height: 220),
              ),
            ] else if (post.imageUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  post.imageUrl,
                  width: double.infinity,
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(height: 100, child: Center(child: Icon(Icons.broken_image, color: AppColors.textMuted))),
                ),
              ),
            ],
            const Divider(color: AppColors.border, height: 22),
            Row(
              children: [
                Expanded(
                  child: PostEngagementBar(
                    post: post,
                    userId: userId,
                    onLike: user == null ? () {} : () => _toggleVote(context, postRef, post, user.uid, isLike: true),
                    onDislike: user == null ? () {} : () => _toggleVote(context, postRef, post, user.uid, isLike: false),
                    onReaction: user == null ? (_) {} : (emoji) => _setReaction(context, postRef, user.uid, emoji),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _showComments(context, groupId, post.postId),
                  icon: const Icon(Icons.mode_comment_outlined, color: AppColors.textMuted),
                  label: const Text('Comment', style: TextStyle(color: AppColors.textMuted)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPost(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> postRef,
    PostModel post,
  ) async {
    final controller = TextEditingController(text: post.content);
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Edit group post', style: TextStyle(color: Colors.white)),
        content: TextField(controller: controller, maxLength: 1000, maxLines: 4, style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
        ],
      ),
    );
    final content = controller.text.trim();
    controller.dispose();
    if (save != true || (content.isEmpty && post.imageUrl.isEmpty && post.videoUrl.isEmpty) || !context.mounted) return;
    try {
      await postRef.update({'content': content, 'hashtags': HashtagText.extract(content)});
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update group post.')));
    }
  }

  Future<void> _deletePost(BuildContext context, DocumentReference<Map<String, dynamic>> postRef) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Delete group post?', style: TextStyle(color: Colors.white)),
        content: const Text('This also removes its comments.', style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
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
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete group post.')));
    }
  }

  Future<void> _toggleVote(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> postRef,
    PostModel post,
    String uid, {
    required bool isLike,
  }) async {
    try {
      await PostEngagementService.toggleVote(
        postRef: postRef,
        userId: uid,
        currentlySelected: (isLike ? post.likes : post.dislikes).contains(uid),
        isLike: isLike,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update reaction.')));
      }
    }
  }

  Future<void> _setReaction(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> postRef,
    String uid,
    String? emoji,
  ) async {
    try {
      await PostEngagementService.setReaction(postRef: postRef, userId: uid, emoji: emoji);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save reaction.')));
      }
    }
  }

  static String _timeLabel(Timestamp timestamp) {
    final date = timestamp.toDate();
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    return '${date.day}/${date.month}/${date.year}';
  }

  /// แสดงคอมเมนต์ของโพสต์ในกลุ่ม และรองรับการเพิ่มคอมเมนต์จากหน้าต่างนี้.
  static Future<void> _showComments(BuildContext context, String groupId, String postId) async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;
    final controller = TextEditingController();
    final commentsRef = FirebaseFirestore.instance.collection('groups').doc(groupId).collection('posts').doc(postId).collection('comments');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(sheetContext).viewInsets.bottom + 12),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.62,
            child: Column(
              children: [
                const Text('Comments', style: TextStyle(color: AppColors.goldPrimary, fontWeight: FontWeight.bold)),
                const Divider(color: AppColors.border),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: commentsRef.orderBy('createdAt', descending: true).snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return const Center(child: Text('Could not load comments.', style: TextStyle(color: AppColors.textMuted)));
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary));
                      if (snapshot.data!.docs.isEmpty) return const Center(child: Text('No comments yet.', style: TextStyle(color: AppColors.textMuted)));
                      return ListView(
                        children: snapshot.data!.docs.map((doc) {
                          final data = doc.data();
                          return ListTile(
                            dense: true,
                            title: Text((data['displayName'] ?? 'Member').toString(), style: const TextStyle(color: AppColors.goldPrimary, fontSize: 13)),
                            subtitle: Text((data['text'] ?? '').toString(), style: const TextStyle(color: Colors.white)),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
                Row(
                  children: [
                    Expanded(child: TextField(controller: controller, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Write a comment...'))),
                    IconButton(
                      icon: const Icon(Icons.send, color: AppColors.goldPrimary),
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        try {
                          await commentsRef.add({
                            'uid': user.uid,
                            'displayName': user.displayName,
                            'text': text,
                            'createdAt': FieldValue.serverTimestamp(),
                          });
                          controller.clear();
                        } catch (_) {
                          if (sheetContext.mounted) ScaffoldMessenger.of(sheetContext).showSnackBar(const SnackBar(content: Text('Could not send comment.')));
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    controller.dispose();
  }
}

/// _GroupMembersTab รวมหน้าที่เฉพาะของส่วนประกอบนี้ไว้ในตำแหน่งเดียว.
class _GroupMembersTab extends StatelessWidget {
  final List<String> members;
  final String creatorUid;

  const _GroupMembersTab({required this.members, required this.creatorUid});

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) return const Center(child: Text('No members yet.', style: TextStyle(color: AppColors.textMuted)));
    return ListView.builder(
      itemCount: members.length,
      itemBuilder: (context, index) {
        final uid = members[index];
        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance.collection('user_directory').doc(uid).get(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final name = (data?['displayName'] ?? 'Member').toString();
            final photo = (data?['photoUrl'] ?? '').toString();
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.goldPrimary,
                backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                child: photo.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.black)) : null,
              ),
              title: Text(name, style: const TextStyle(color: Colors.white)),
              subtitle: Text(uid == creatorUid ? 'Group creator' : '@${data?['username'] ?? uid}', style: const TextStyle(color: AppColors.textMuted)),
              trailing: uid == creatorUid ? const Icon(Icons.shield_outlined, color: AppColors.goldPrimary) : null,
            );
          },
        );
      },
    );
  }
}

/// _CreateGroupPostDialog แสดงกล่องโต้ตอบสำหรับรับข้อมูลหรือยืนยันการทำงาน.
class _CreateGroupPostDialog extends StatefulWidget {
  final String groupId;
  const _CreateGroupPostDialog({required this.groupId});

  @override
  State<_CreateGroupPostDialog> createState() => _CreateGroupPostDialogState();
}

/// _CreateGroupPostDialogState จัดการ state, lifecycle และการตอบสนองต่อเหตุการณ์ของหน้าจอที่เกี่ยวข้อง.
class _CreateGroupPostDialogState extends State<_CreateGroupPostDialog> {
  final _contentController = TextEditingController();
  Uint8List? _imageBytes;
  Uint8List? _videoBytes;
  String? _videoFilename;
  bool _saving = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  /// เลือกรูปเพื่อแนบกับโพสต์กลุ่มและเก็บไบต์ไว้ใน state ของ dialog.
  Future<void> _pickImage() async {
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _videoBytes = null;
          _videoFilename = null;
        });
      }
    } catch (_) {
      if (mounted) _showMessage('Could not select image. Please try again.');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final video = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );
      if (video == null) return;
      final bytes = await video.readAsBytes();
      if (mounted) {
        setState(() {
          _videoBytes = bytes;
          _videoFilename = video.name;
          _imageBytes = null;
        });
      }
    } catch (_) {
      if (mounted) _showMessage('Could not select video. Please try again.');
    }
  }

  /// อัปโหลดรูปถ้ามี แล้วสร้างโพสต์ใน subcollection ของกลุ่ม.
  Future<void> _publish() async {
    final user = context.read<AuthProvider>().currentUser;
    final content = _contentController.text.trim();
    if (user == null || (content.isEmpty && _imageBytes == null && _videoBytes == null)) return;
    setState(() => _saving = true);
    try {
      var imageUrl = '';
      var videoUrl = '';
      if (_imageBytes != null) {
        imageUrl = await CloudinaryService.uploadImage(_imageBytes!, filenamePrefix: 'group_post');
      }
      if (_videoBytes != null) {
        videoUrl = await CloudinaryService.uploadVideo(
          _videoBytes!,
          filenamePrefix: 'group_post_${user.uid}',
          filename: _videoFilename ?? 'video.mp4',
        );
      }
      final profileSnapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final profile = profileSnapshot.data();
      final latestDisplayName = (profile?['displayName'] ?? user.displayName).toString();
      final latestUsername = (profile?['username'] ?? user.username).toString();
      final latestPhotoUrl = (profile?['photoUrl'] ?? user.photoUrl ?? '').toString();

      await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).collection('posts').add({
        'groupId': widget.groupId,
        'uid': user.uid,
        'username': latestUsername,
        'displayName': latestDisplayName,
        'userPhotoUrl': latestPhotoUrl,
        'content': content,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'mediaType': videoUrl.isNotEmpty ? 'video' : (imageUrl.isNotEmpty ? 'image' : 'text'),
        'hashtags': HashtagText.extract(content),
        'likes': <String>[],
        'dislikes': <String>[],
        'reactions': <String, String>{},
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        _showMessage(_imageBytes == null && _videoBytes == null ? 'Could not publish this post.' : 'Media upload or post creation failed. Please try again.');
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Post to group', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _contentController,
                maxLength: 1000,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: 'Share something with the group...'),
              ),
              if (_imageBytes != null) ...[
                ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(_imageBytes!, height: 160, fit: BoxFit.cover)),
                TextButton.icon(onPressed: _saving ? null : () => setState(() => _imageBytes = null), icon: const Icon(Icons.close), label: const Text('Remove image')),
              ],
              if (_videoBytes != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.video_file_outlined, color: AppColors.goldPrimary),
                  title: Text(_videoFilename ?? 'Selected video', style: const TextStyle(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    onPressed: _saving ? null : () => setState(() {
                      _videoBytes = null;
                      _videoFilename = null;
                    }),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _pickImage,
                  icon: const Icon(Icons.image_outlined, color: AppColors.goldPrimary),
                  label: const Text('Add photo', style: TextStyle(color: AppColors.goldPrimary)),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _pickVideo,
                  icon: const Icon(Icons.video_library_outlined, color: AppColors.goldPrimary),
                  label: const Text('Add video', style: TextStyle(color: AppColors.goldPrimary)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _saving ? null : _publish,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.goldPrimary, foregroundColor: Colors.black),
            child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator()) : const Text('Post'),
          ),
        ],
      );
}
