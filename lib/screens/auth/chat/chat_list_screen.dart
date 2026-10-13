import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '/core/theme/app_theme.dart';
import '/providers/auth_provider.dart';
import 'chat_room_screen.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthProvider>(context).currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'MESSAGES',
          style: TextStyle(
            color: AppColors.goldPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No users found.', style: TextStyle(color: AppColors.textMuted)));
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final userData = users[index].data() as Map<String, dynamic>;
              final userId = users[index].id;

              // ไม่แสดงชื่อตัวเองในรายชื่อแชท
              if (userId == currentUserId) {
                return const SizedBox.shrink();
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.goldPrimary,
                  child: Text(
                    userData['displayName'] != null && userData['displayName'].isNotEmpty
                        ? userData['displayName'][0].toUpperCase()
                        : 'U',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  userData['displayName'] ?? 'User',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '@${userData['username'] ?? ''}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatRoomScreen(
                        receiverId: userId,
                        receiverName: userData['displayName'] ?? 'User',
                      ),
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