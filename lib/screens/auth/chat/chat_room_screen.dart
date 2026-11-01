import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '/core/theme/app_theme.dart';
import '/providers/auth_provider.dart';
import '/models/message_model.dart';

class ChatRoomScreen extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatRoomScreen({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // สร้าง ChatRoom ID ที่ไม่ซ้ำกันโดยเรียงตาม UID ของทั้งสองคน
  String getChatRoomId(String currentUserId, String targetUserId) {
    if (currentUserId.compareTo(targetUserId) > 0) {
      return '${currentUserId}_$targetUserId';
    } else {
      return '${targetUserId}_$currentUserId';
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (currentUser == null || currentUser.uid == widget.receiverId) return;
    final currentUserId = currentUser.uid;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    final chatRoomId = getChatRoomId(currentUserId, widget.receiverId);

    final participants = [currentUserId, widget.receiverId]
      ..sort((a, b) => b.compareTo(a));
    final roomRef = _firestore.collection('chat_rooms').doc(chatRoomId);
    final messageRef = roomRef.collection('messages').doc();
    try {
      await _firestore.runTransaction((transaction) async {
        final room = await transaction.get(roomRef);
        final latestMessage = {
          'lastMessage': messageText,
          'lastMessageAt': FieldValue.serverTimestamp(),
          'lastSenderId': currentUserId,
        };
        if (room.exists) {
          transaction.update(roomRef, latestMessage);
        } else {
          transaction.set(roomRef, {
            ...latestMessage,
            'participants': participants,
            'participantNames': {
              currentUserId: currentUser.displayName,
              widget.receiverId: widget.receiverName,
            },
          });
        }
        transaction.set(messageRef, {
          'senderId': currentUserId,
          'receiverId': widget.receiverId,
          'message': messageText,
          'timestamp': FieldValue.serverTimestamp(),
        });
      });
    } catch (error) {
      if (mounted) {
        _messageController.text = messageText;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send message. Please try again.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthProvider>(context).currentUser?.uid ?? '';
    final chatRoomId = getChatRoomId(currentUserId, widget.receiverId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          widget.receiverName,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // ส่วนแสดงรายการข้อความแบบเรียลไทม์
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chat_rooms')
                  .doc(chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh, color: AppColors.goldPrimary),
                      label: const Text('Could not load messages. Retry', style: TextStyle(color: AppColors.goldPrimary)),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No messages yet. Say hello!',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final message = MessageModel.fromMap(data, docs[index].id);
                    final isMe = message.senderId == currentUserId;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? AppColors.goldPrimary : AppColors.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: isMe ? null : Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          message.message,
                          style: TextStyle(
                            color: isMe ? Colors.black : Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // ส่วนพิมพ์ข้อความด้านล่าง
          Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.cardBg,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: AppColors.textMuted),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppColors.goldPrimary),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
