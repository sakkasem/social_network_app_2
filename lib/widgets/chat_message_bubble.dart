/// SIGMA888: แสดง bubble ข้อความหรือภาพ พร้อมผู้ส่งและเวลา

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';
import '/widgets/post_author_avatar.dart';

/// Bubble สำหรับแสดงข้อความหรือภาพ พร้อมแยกสีตามผู้ส่งและแสดงเวลา.
class ChatMessageBubble extends StatelessWidget {
  final String senderId;
  final String senderName;
  final bool isMe;
  final String message;
  final String imageUrl;
  final Timestamp? timestamp;

  const ChatMessageBubble({
    super.key,
    required this.senderId,
    required this.senderName,
    required this.isMe,
    required this.message,
    this.imageUrl = '',
    this.timestamp,
  });

  String _timeText() {
    if (timestamp == null) return '';
    final date = timestamp!.toDate().toLocal();
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe ? AppColors.goldPrimary : Colors.grey[850]!;
    final textColor = isMe ? Colors.black : Colors.white;
    final showText = message.isNotEmpty && !(imageUrl.isNotEmpty && message == '📷 Photo');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            PostAuthorAvatar(uid: senderId, displayName: senderName, radius: 15),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe && senderName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 3),
                    child: Text(senderName, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ),
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.76),
                  padding: EdgeInsets.all(imageUrl.isNotEmpty ? 5 : 11),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMe ? 18 : 5),
                      bottomRight: Radius.circular(isMe ? 5 : 18),
                    ),
                    border: isMe ? null : Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (imageUrl.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            imageUrl,
                            width: 230,
                            height: 220,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox(
                              width: 230,
                              height: 120,
                              child: Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textMuted, size: 36)),
                            ),
                          ),
                        ),
                      if (showText)
                        Padding(
                          padding: EdgeInsets.only(left: imageUrl.isNotEmpty ? 7 : 0, right: imageUrl.isNotEmpty ? 7 : 0, top: imageUrl.isNotEmpty ? 7 : 0),
                          child: Text(message, style: TextStyle(color: textColor, fontSize: 15, height: 1.25)),
                        ),
                    ],
                  ),
                ),
                if (_timeText().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    child: Text(_timeText(), style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  ),
              ],
            ),
          ),
          if (isMe) const SizedBox(width: 2),
        ],
      ),
    );
  }
}
