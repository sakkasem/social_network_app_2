import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '/core/theme/app_theme.dart';
import '/models/group_model.dart';
import '/providers/auth_provider.dart';
import 'group_chat_screen.dart';

class GroupsListScreen extends StatelessWidget {
  const GroupsListScreen({super.key});

  // Dialog สำหรับสร้างกลุ่มใหม่
  void _showCreateGroupDialog(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text('Create New Group', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.goldPrimary),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
                if (user == null) return;

                await FirebaseFirestore.instance.collection('groups').add({
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                  'createdBy': user.uid,
                  'members': [user.uid], // ผู้สร้างเข้าร่วมโดยอัตโนมัติ
                  'createdAt': Timestamp.now(),
                });

                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Create', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // ฟังก์ชันเข้าร่วม / ออกจากกลุ่ม
  void _toggleJoinGroup(String groupId, List<String> members, String currentUserId) async {
    List<String> updatedMembers = List.from(members);
    if (updatedMembers.contains(currentUserId)) {
      updatedMembers.remove(currentUserId);
    } else {
      updatedMembers.add(currentUserId);
    }

    await FirebaseFirestore.instance.collection('groups').doc(groupId).update({
      'members': updatedMembers,
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthProvider>(context).currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'GROUPS',
          style: TextStyle(
            color: AppColors.goldPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.goldPrimary),
            onPressed: () => _showCreateGroupDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('groups').orderBy('createdAt', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No groups found. Tap + to create one!', style: TextStyle(color: AppColors.textMuted)),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final group = GroupModel.fromMap(docs[index].data() as Map<String, dynamic>, docs[index].id);
              final isMember = group.members.contains(currentUserId);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.goldPrimary,
                    child: Text(
                      group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    group.name,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${group.description}\n${group.members.length} members',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  isThreeLine: true,
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMember ? Colors.grey[800] : AppColors.goldPrimary,
                    ),
                    onPressed: () => _toggleJoinGroup(group.groupId, group.members, currentUserId),
                    child: Text(
                      isMember ? 'Joined' : 'Join',
                      style: TextStyle(
                        color: isMember ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () {
                    if (isMember) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GroupChatScreen(
                            groupId: group.groupId,
                            groupName: group.name,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please join the group first to chat.')),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}