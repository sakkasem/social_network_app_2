import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '/core/theme/app_theme.dart';
import '/providers/auth_provider.dart';
import '/services/cloudinary_service.dart';
import '/widgets/chat_input_bar.dart';
import '/widgets/chat_message_bubble.dart';

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
  bool _isSending = false;

  Future<void> _sendMessage() async {
    final user = context.read<AuthProvider>().currentUser;
    final text = _messageController.text.trim();
    if (text.isEmpty || user == null || _isSending) return;
    _messageController.clear();
    setState(() => _isSending = true);
    try {
      await _persistMessage(senderId: user.uid, senderName: user.displayName, text: text);
    } catch (_) {
      if (mounted) {
        _messageController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send message. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final user = context.read<AuthProvider>().currentUser;
    if (user == null || _isSending) return;
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null || !mounted) return;
      setState(() => _isSending = true);
      final bytes = await picked.readAsBytes();
      final imageUrl = await CloudinaryService.uploadImage(bytes, filenamePrefix: 'group_chat_${widget.groupId}');
      await _persistMessage(senderId: user.uid, senderName: user.displayName, text: '📷 Photo', imageUrl: imageUrl);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not upload or send the photo. Please try again.')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _persistMessage({
    required String senderId,
    required String senderName,
    required String text,
    String imageUrl = '',
  }) async {
    await FirebaseFirestore.instance.collection('groups').doc(widget.groupId).collection('messages').add({
      'senderId': senderId,
      'senderName': senderName,
      'message': text,
      'imageUrl': imageUrl,
      'type': imageUrl.isEmpty ? 'text' : 'image',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AuthProvider>().currentUser?.uid ?? '';
    final messages = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('messages')
        .orderBy('timestamp', descending: true);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            const CircleAvatar(radius: 17, backgroundColor: AppColors.cardBg, child: Icon(Icons.groups_outlined, color: AppColors.goldPrimary, size: 19)),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.groupName, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16))),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messages.snapshots(),
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
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary));
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('No messages in this group yet.', style: TextStyle(color: AppColors.textMuted)));

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final senderId = (data['senderId'] ?? '').toString();
                    final isMe = senderId == currentUserId;
                    return ChatMessageBubble(
                      senderId: senderId,
                      senderName: (data['senderName'] ?? 'Member').toString(),
                      isMe: isMe,
                      message: (data['message'] ?? '').toString(),
                      imageUrl: (data['imageUrl'] ?? '').toString(),
                      timestamp: data['timestamp'] is Timestamp ? data['timestamp'] as Timestamp : null,
                    );
                  },
                );
              },
            ),
          ),
          ChatInputBar(
            controller: _messageController,
            hintText: 'Message the group…',
            isBusy: _isSending,
            onSend: _sendMessage,
            onPickImage: _pickAndSendImage,
          ),
        ],
      ),
    );
  }
}
