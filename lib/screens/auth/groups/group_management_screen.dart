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

  @override
  Widget build(BuildContext context) {
    final currentUid = context.watch<AuthProvider>().currentUser?.uid;
    final groupRef = FirebaseFirestore.instance.collection('groups').doc(groupId);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('$groupName members', style: const TextStyle(color: AppColors.goldPrimary, fontSize: 16)),
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
                future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
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
