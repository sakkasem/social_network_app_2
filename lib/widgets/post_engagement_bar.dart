/// SIGMA888: ปุ่ม Like, Dislike และ Emoji Reaction สำหรับโพสต์.

import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';
import '/models/post_model.dart';

/// แถบปฏิกิริยาที่รับ callbacks จาก Feed เพื่อให้แต่ละหน้าคงลอจิกแจ้งเตือนของตน.
class PostEngagementBar extends StatelessWidget {
  final PostModel post;
  final String userId;
  final VoidCallback onLike;
  final VoidCallback onDislike;
  final ValueChanged<String?> onReaction;

  const PostEngagementBar({
    super.key,
    required this.post,
    required this.userId,
    required this.onLike,
    required this.onDislike,
    required this.onReaction,
  });

  @override
  Widget build(BuildContext context) {
    final liked = post.likes.contains(userId);
    final disliked = post.dislikes.contains(userId);
    final selectedReaction = post.reactions[userId];
    final reactionCounts = <String, int>{};
    for (final emoji in post.reactions.values) {
      reactionCounts.update(emoji, (count) => count + 1, ifAbsent: () => 1);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        TextButton.icon(
          onPressed: onLike,
          icon: Icon(liked ? Icons.thumb_up : Icons.thumb_up_outlined, color: liked ? AppColors.goldPrimary : AppColors.textMuted),
          label: Text('${post.likes.length}', style: TextStyle(color: liked ? AppColors.goldPrimary : AppColors.textMuted)),
        ),
        TextButton.icon(
          onPressed: onDislike,
          icon: Icon(disliked ? Icons.thumb_down : Icons.thumb_down_outlined, color: disliked ? Colors.redAccent : AppColors.textMuted),
          label: Text('${post.dislikes.length}', style: TextStyle(color: disliked ? Colors.redAccent : AppColors.textMuted)),
        ),
        PopupMenuButton<String>(
          tooltip: 'React to post',
          color: AppColors.cardBg,
          onSelected: (value) => onReaction(value == '__remove__' ? null : value),
          itemBuilder: (_) => [
            for (final emoji in const ['❤️', '😆', '😮', '😢'])
              PopupMenuItem(value: emoji, child: Text('$emoji  ${reactionCounts[emoji] ?? 0}', style: const TextStyle(color: Colors.white))),
            if (selectedReaction != null)
              const PopupMenuItem(value: '__remove__', child: Text('Remove reaction', style: TextStyle(color: AppColors.textMuted))),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Text(selectedReaction ?? '😊', style: const TextStyle(fontSize: 19)),
          ),
        ),
      ],
    );
  }
}
