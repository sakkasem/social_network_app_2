import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '/core/theme/app_theme.dart';
import '/providers/auth_provider.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;

    final text = _messageController.text.trim();
    _messageController.clear();

    await FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .add({
      'senderId': user.uid,
      'senderName': user.displayName,
      'message': text,
      'timestamp': Timestamp.now(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthProvider>(context).currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(widget.groupName, style: const TextStyle(color: Colors.white, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('groups')
                  .doc(widget.groupId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No messages in this group yet.', style: TextStyle(color: AppColors.textMuted)),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == currentUserId;

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
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Text(
                                data['senderName'] ?? 'Member',
                                style: const TextStyle(
                                  color: AppColors.goldPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            Text(
                              data['message'] ?? '',
                              style: TextStyle(
                                color: isMe ? Colors.black : Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
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
                      hintText: 'Type a group message...',
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