/// SIGMA888: ให้ผู้สร้างกลุ่มดูและนำสมาชิกออกจากกลุ่ม

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/theme/app_theme.dart';
import '/providers/auth_provider.dart';

/// GroupManagementScreen เป็นหน้าจอของฟีเจอร์ที่ระบุด้วยชื่อคลาสนี้.
class GroupManagementScreen extends StatelessWidget {
  final String groupId;
  final String groupName;

  const GroupManagementScreen({super.key, required this.groupId, required this.groupName});

  Future<void> _removeMember(BuildContext context, String memberUid) async {
    final currentUid = context.read<AuthProvider>().currentUser?.uid;
    if (currentUid == null || memberUid == currentUid) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Remove member?', style: TextStyle(color: Colors.white)),
        content: const Text('This person will lose access to the group chat.', style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Remove', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await FirebaseFirestore.instance.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayRemove([memberUid]),
      });
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not remove this member.')));
      }
    }
  }

  Future<void> _editGroup(BuildContext context) async {
    final nameController = TextEditingController(text: groupName);
    final descriptionController = TextEditingController();
    final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
    try {
      final snapshot = await groupRef.get();
      if (!context.mounted || !snapshot.exists) return;
      descriptionController.text = (snapshot.data()?['description'] ?? '').toString();
      final save = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text('Edit group', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, maxLength: 80, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Group name')),
              TextField(controller: descriptionController, maxLength: 500, maxLines: 3, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Description')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
          ],
        ),
      );
      if (save != true || !context.mounted) return;
      final name = nameController.text.trim();
      final description = descriptionController.text.trim();
      if (name.isEmpty || name.length > 80 || description.length > 500) return;
      final currentUid = context.read<AuthProvider>().currentUser?.uid;
      if (snapshot.data()?['createdBy'] != currentUid) return;
      await groupRef.update({'name': name, 'description': description});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group details updated.')));
        Navigator.pop(context, name);
      }
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update group details.')));
    } finally {
      nameController.dispose();
      descriptionController.dispose();
    }
  }

  Future<void> _deleteGroup(BuildContext context) async {
    final currentUid = context.read<AuthProvider>().currentUser?.uid;
    final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
    if (currentUid == null) return;
    final group = await groupRef.get();
    if (!group.exists || group.data()?['createdBy'] != currentUid || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Delete group?', style: TextStyle(color: Colors.white)),
        content: const Text('This permanently removes the group, its posts, comments, and messages.', style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await _deleteCollection(groupRef.collection('messages'));
      final posts = await groupRef.collection('posts').get();
      for (final post in posts.docs) {
        await _deleteCollection(post.reference.collection('comments'));
      }
      for (var start = 0; start < posts.docs.length; start += 450) {
        final batch = FirebaseFirestore.instance.batch();
        for (final post in posts.docs.skip(start).take(450)) {
          batch.delete(post.reference);
        }
        await batch.commit();
      }
      await groupRef.delete();
      if (context.mounted) Navigator.pop(context, 'deleted');
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete group data. Please try again.')));
    }
  }

  Future<void> _deleteCollection(Query<Map<String, dynamic>> query) async {
    while (true) {
      final docs = await query.limit(450).get();
      if (docs.docs.isEmpty) break;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in docs.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = context.watch<AuthProvider>().currentUser?.uid;
    final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('$groupName members', style: const TextStyle(color: AppColors.goldPrimary, fontSize: 16)),
        actions: [
          IconButton(tooltip: 'Edit group', onPressed: () => _editGroup(context), icon: const Icon(Icons.edit_outlined, color: AppColors.goldPrimary)),
          IconButton(tooltip: 'Delete group', onPressed: () => _deleteGroup(context), icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: groupRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text('Could not load members.', style: TextStyle(color: AppColors.textMuted)),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary));
          final data = snapshot.data!.data();
          if (data == null || data['createdBy'] != currentUid) {
            return const Center(child: Text('Only the group creator can manage members.', style: TextStyle(color: AppColors.textMuted)));
          }
          final members = List<String>.from(data['members'] ?? const []);
          if (members.isEmpty) return const Center(child: Text('No members found.', style: TextStyle(color: AppColors.textMuted)));
          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final uid = members[index];
              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance.collection('user_directory').doc(uid).get(),
                builder: (context, userSnapshot) {
                  final user = userSnapshot.data?.data();
                  final name = (user?['displayName'] ?? 'Member').toString();
                  final isCreator = uid == data['createdBy'];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.goldPrimary,
                      backgroundImage: ((user?['photoUrl'] ?? '') as String).isNotEmpty ? NetworkImage(user!['photoUrl'] as String) : null,
                      child: ((user?['photoUrl'] ?? '') as String).isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U') : null,
                    ),
                    title: Text(name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(isCreator ? 'Group creator' : '@${user?['username'] ?? uid}', style: const TextStyle(color: AppColors.textMuted)),
                    trailing: isCreator ? const Icon(Icons.shield, color: AppColors.goldPrimary) : IconButton(
                      tooltip: 'Remove member',
                      onPressed: () => _removeMember(context, uid),
                      icon: const Icon(Icons.person_remove_alt_1, color: Colors.redAccent),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
