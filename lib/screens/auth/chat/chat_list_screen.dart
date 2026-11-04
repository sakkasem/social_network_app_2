// บทบาทไฟล์: สร้างหน้าจอและการโต้ตอบในส่วนที่ระบุในพาธ (lib/screens/auth/chat/chat_list_screen.dart).
/// SIGMA888: แสดง Inbox ของห้องสนทนาส่วนตัวที่มีข้อความล่าสุด

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/theme/app_theme.dart';
import '/providers/auth_provider.dart';
import '/screens/auth/profile/search_users_screen.dart';
import 'chat_room_screen.dart';

/// ChatListScreen เป็นหน้าจอของฟีเจอร์ที่ระบุด้วยชื่อคลาสนี้.
// หน้า Inbox แสดงบทสนทนาล่าสุดและเปิดห้องที่ผู้ใช้เลือก
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

/// _ChatListScreenState จัดการ state, lifecycle และการตอบสนองต่อเหตุการณ์ของหน้าจอที่เกี่ยวข้อง.
class _ChatListScreenState extends State<ChatListScreen> {
  @override
  // แสดงรายการสนทนาจากสตรีม รวมสถานะโหลด ว่าง และผิดพลาดตามผล query
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthProvider>(context).currentUser?.uid;
    if (currentUserId == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Please sign in to view messages.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'INBOX',
          style: TextStyle(
            color: AppColors.goldPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Find people',
            icon: const Icon(Icons.person_search, color: AppColors.goldPrimary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchUsersScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('chat_rooms')
            .where('participants', arrayContains: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton.icon(
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh, color: AppColors.goldPrimary),
                label: const Text('Could not load inbox. Retry', style: TextStyle(color: AppColors.goldPrimary)),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary));
          }

          final rooms = snapshot.data?.docs.toList() ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          rooms.sort((a, b) {
            final aTime = a.data()['lastMessageAt'] as Timestamp?;
            final bTime = b.data()['lastMessageAt'] as Timestamp?;
            return (bTime?.millisecondsSinceEpoch ?? 0)
                .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
          });

          if (rooms.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.chat_bubble_outline, color: AppColors.textMuted, size: 44),
                  const SizedBox(height: 12),
                  const Text('No conversations yet.', style: TextStyle(color: AppColors.textMuted)),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SearchUsersScreen()),
                    ),
                    icon: const Icon(Icons.person_search),
                    label: const Text('Find people'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            itemCount: rooms.length,
            separatorBuilder: (_, __) => const Divider(color: AppColors.border, height: 1),
            itemBuilder: (context, index) {
              final data = rooms[index].data();
              final participants = List<String>.from(data['participants'] ?? const []);
              final otherParticipants = participants.where((uid) => uid != currentUserId).toList();
              final otherUid = otherParticipants.isEmpty ? null : otherParticipants.first;
              if (otherUid == null) return const SizedBox.shrink();

              final names = Map<String, dynamic>.from(data['participantNames'] ?? const {});
              final otherName = (names[otherUid] ?? 'User').toString();
              final lastSenderId = data['lastSenderId'] as String?;
              final preview = (data['lastMessage'] ?? '').toString();
              final subtitle = lastSenderId == currentUserId ? 'You: $preview' : preview;
              final lastMessageAt = data['lastMessageAt'] as Timestamp?;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.goldPrimary,
                  child: Text(
                    otherName.isNotEmpty ? otherName[0].toUpperCase() : 'U',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(otherName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                trailing: Text(
                  _formatTime(lastMessageAt),
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatRoomScreen(receiverId: otherUid, receiverName: otherName),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// แปลงเวลาของข้อความล่าสุดเป็นข้อความสั้นที่เหมาะกับรายการ Inbox.
  // แปลง Timestamp ให้เป็นข้อความเวลาสั้นสำหรับแถว Inbox
  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'now';
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    if (difference.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}';
  }
}
