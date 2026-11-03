/// SIGMA888: แสดงและส่งข้อความหรือรูปภาพในการสนทนาส่วนตัว

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '/core/theme/app_theme.dart';
import '/models/message_model.dart';
import '/providers/auth_provider.dart';
import '/services/cloudinary_service.dart';
import '/widgets/chat_input_bar.dart';
import '/widgets/chat_message_bubble.dart';
import '/widgets/post_author_avatar.dart';

/// ChatRoomScreen เป็นหน้าจอของฟีเจอร์ที่ระบุด้วยชื่อคลาสนี้.
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

/// _ChatRoomScreenState จัดการ state, lifecycle และการตอบสนองต่อเหตุการณ์ของหน้าจอที่เกี่ยวข้อง.
class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isSending = false;

  /// สร้าง room id แบบคงที่จาก uid ทั้งคู่ เพื่อให้คู่สนทนาได้ห้องเดียวกัน.
  String _chatRoomId(String currentUserId, String targetUserId) =>
      currentUserId.compareTo(targetUserId) > 0
          ? '${currentUserId}_$targetUserId'
          : '${targetUserId}_$currentUserId';

  /// ตรวจข้อความและผู้ใช้ก่อนส่งข้อความตัวอักษร พร้อมแจ้งเมื่อส่งไม่สำเร็จ.
  Future<void> _sendMessage() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    final text = _messageController.text.trim();
    if (text.isEmpty || currentUser == null || currentUser.uid == widget.receiverId || _isSending) return;

    _messageController.clear();
    setState(() => _isSending = true);
    try {
      await _persistMessage(senderId: currentUser.uid, senderName: currentUser.displayName, text: text);
    } catch (_) {
      if (mounted) {
        _messageController.text = text;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send message. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// เลือกรูปจากแกลเลอรี อัปโหลด Cloudinary แล้วส่ง URL เป็นข้อความรูปภาพ.
  Future<void> _pickAndSendImage() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null || currentUser.uid == widget.receiverId || _isSending) return;
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (picked == null || !mounted) return;
      setState(() => _isSending = true);
      final bytes = await picked.readAsBytes();
      final imageUrl = await CloudinaryService.uploadImage(bytes, filenamePrefix: 'chat_${currentUser.uid}');
      await _persistMessage(
        senderId: currentUser.uid,
        senderName: currentUser.displayName,
        text: '📷 Photo',
        imageUrl: imageUrl,
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not upload or send the photo. Please try again.')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendVideo() async {
    final currentUser = context.read<AuthProvider>().currentUser;
    if (currentUser == null || currentUser.uid == widget.receiverId || _isSending) return;
    try {
      final picked = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );
      if (picked == null || !mounted) return;
      setState(() => _isSending = true);
      final videoUrl = await CloudinaryService.uploadVideo(
        await picked.readAsBytes(),
        filenamePrefix: 'chat_${currentUser.uid}',
        filename: picked.name,
      );
      await _persistMessage(
        senderId: currentUser.uid,
        senderName: currentUser.displayName,
        text: '🎬 Video',
        videoUrl: videoUrl,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อัปโหลดหรือส่งวิดีโอไม่สำเร็จ กรุณาลองใหม่')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  /// บันทึกข้อความและปรับ metadata ห้องแชตใน transaction เดียวกัน.
  /// รับผู้ส่ง ข้อความ และ URL รูปที่อาจไม่มี; ไม่คืนค่าเมื่อเขียนสำเร็จ.
  Future<void> _persistMessage({
    required String senderId,
    required String senderName,
    required String text,
    String imageUrl = '',
    String videoUrl = '',
  }) async {
    final roomId = _chatRoomId(senderId, widget.receiverId);
    final participants = [senderId, widget.receiverId]..sort((a, b) => b.compareTo(a));
    final roomRef = _firestore.collection('chat_rooms').doc(roomId);
    final messageRef = roomRef.collection('messages').doc();
    final lastMessage = videoUrl.isNotEmpty ? '🎬 Video' : (imageUrl.isEmpty ? text : '📷 Photo');

    // อ่านห้องก่อน: สร้าง metadata เมื่อเป็นการคุยครั้งแรก หรืออัปเดตข้อความล่าสุด
    await _firestore.runTransaction((transaction) async {
      final room = await transaction.get(roomRef);
      final roomUpdate = {
        'lastMessage': lastMessage,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastSenderId': senderId,
      };
      if (room.exists) {
        transaction.update(roomRef, roomUpdate);
      } else {
        transaction.set(roomRef, {
          ...roomUpdate,
          'participants': participants,
          'participantNames': {
            senderId: senderName,
            widget.receiverId: widget.receiverName,
          },
        });
      }
      // เขียนเอกสารข้อความพร้อมชนิดและ server timestamp ใน transaction เดียวกัน
      transaction.set(messageRef, {
        'senderId': senderId,
        'receiverId': widget.receiverId,
        'message': text,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'type': videoUrl.isNotEmpty ? 'video' : (imageUrl.isEmpty ? 'text' : 'image'),
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthProvider>().currentUser;
    final currentUserId = currentUser?.uid ?? '';
    final roomId = _chatRoomId(currentUserId, widget.receiverId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        iconTheme: const IconThemeData(color: Colors.white),
        titleSpacing: 0,
        title: Row(
          children: [
            PostAuthorAvatar(uid: widget.receiverId, displayName: widget.receiverName, radius: 17),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.receiverName, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16))),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore.collection('chat_rooms').doc(roomId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
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
                if (docs.isEmpty) return const Center(child: Text('No messages yet. Say hello!', style: TextStyle(color: AppColors.textMuted)));

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final message = MessageModel.fromMap(data, docs[index].id);
                    final isMe = message.senderId == currentUserId;
                    return ChatMessageBubble(
                      senderId: message.senderId,
                      senderName: isMe ? '' : widget.receiverName,
                      isMe: isMe,
                      message: message.message,
                      imageUrl: message.imageUrl,
                      videoUrl: message.videoUrl,
                      timestamp: message.timestamp,
                    );
                  },
                );
              },
            ),
          ),
          ChatInputBar(
            controller: _messageController,
            hintText: 'Message…',
            isBusy: _isSending,
            onSend: _sendMessage,
            onPickImage: _pickAndSendImage,
            onPickVideo: _pickAndSendVideo,
          ),
        ],
      ),
    );
  }
}
