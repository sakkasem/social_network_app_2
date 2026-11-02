/// SIGMA888: แสดง Inbox ของห้องสนทนาส่วนตัวที่มีข้อความล่าสุด

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/theme/app_theme.dart';
import '/providers/auth_provider.dart';
import '/screens/auth/profile/search_users_screen.dart';
import '/widgets/notification_badges.dart';
import 'chat_room_screen.dart';

/// ChatListScreen เป็นหน้าจอของฟีเจอร์ที่ระบุด้วยชื่อคลาสนี้.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

/// _ChatListScreenState จัดการ state, lifecycle และการตอบสนองต่อเหตุการณ์ของหน้าจอที่เกี่ยวข้อง.
class _ChatListScreenState extends State<ChatListScreen> {
  @override
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
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('users').doc(currentUserId).snapshots(),
            builder: (context, snap) {
              final profile = snap.data?.data();
              final name = (profile?['displayName'] ?? '').toString();
              final photoUrl = (profile?['photoUrl'] ?? '').toString();
              final hasPhoto = photoUrl.isNotEmpty;
              return CircleAvatar(
                key: ValueKey('me-$photoUrl'),
                radius: 16,
                backgroundColor: AppColors.goldPrimary,
                backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                child: hasPhoto
                    ? null
                    : Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
              );
            },
          ),
          StreamBuilder<int>(
            stream: pendingFriendRequestCountStream(currentUserId),
            builder: (context, snap) => IconButton(
              tooltip: 'Find people',
              icon: DotBadge(
                show: (snap.data ?? 0) > 0,
                child: const Icon(Icons.person_search, color: AppColors.goldPrimary),
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchUsersScreen()),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('chat_rooms')
            .where('participants', arrayContains: currentUserId)
            .snapshots(includeMetadataChanges: true),
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
              // snapshot ของ FlutterFire ประมาณค่า server timestamp ที่รอเขียน จึงนับเป็นอ่านแล้วทันที
              final data = rooms[index].data();
              final participants = List<String>.from(data['participants'] ?? const []);
              final otherParticipants = participants.where((uid) => uid != currentUserId).toList();
              final otherUid = otherParticipants.isEmpty ? null : otherParticipants.first;
              if (otherUid == null) return const SizedBox.shrink();

              final names = Map<String, dynamic>.from(data['participantNames'] ?? const {});
              final cachedName = (names[otherUid] ?? 'User').toString();
              final lastSenderId = data['lastSenderId'] as String?;
              final preview = (data['lastMessage'] ?? '').toString();
              final subtitle = lastSenderId == currentUserId ? 'You: $preview' : preview;
              final lastMessageAt = data['lastMessageAt'] as Timestamp?;
              final unread = isChatRoomUnread(data, currentUserId);

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance.collection('users').doc(otherUid).snapshots(),
                builder: (context, userSnap) {
                  final profile = userSnap.data?.data();
                  final profileName = (profile?['displayName'] ?? '').toString();
                  final otherName = profileName.isNotEmpty ? profileName : cachedName;
                  final photoUrl = (profile?['photoUrl'] ?? '').toString();
                  final hasPhoto = photoUrl.isNotEmpty;

                  return ListTile(
                    leading: CircleAvatar(
                      key: ValueKey('$otherUid-$photoUrl'),
                      backgroundColor: AppColors.goldPrimary,
                      backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                      child: hasPhoto
                          ? null
                          : Text(
                              otherName.isNotEmpty ? otherName[0].toUpperCase() : 'U',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                    ),
                    title: Text(otherName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: unread ? Colors.white : AppColors.textMuted,
                        fontWeight: unread ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(lastMessageAt),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                        if (unread) ...[
                          const SizedBox(height: 6),
                          const RedDot(),
                        ],
                      ],
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
          );
        },
      ),
    );
  }

  /// แปลงเวลาของข้อความล่าสุดเป็นข้อความสั้นที่เหมาะกับรายการ Inbox.
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
