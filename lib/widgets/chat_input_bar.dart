/// SIGMA888: แสดงแถบพิมพ์แชต ปุ่มรูป อีโมจิ และส่งข้อความ

import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';

/// แถบรับข้อความที่รองรับการเลือกภาพ เปิดตัวเลือกอีโมจิ และส่งข้อความ.
class ChatInputBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool isBusy;
  final VoidCallback onSend;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.isBusy,
    required this.onSend,
    required this.onPickImage,
    required this.onPickVideo,
  });

  /// แทนอีโมจิในช่วงข้อความที่เลือก หรือแทรกที่ตำแหน่งเคอร์เซอร์ปัจจุบัน.
  void _insertEmoji(BuildContext context, String emoji) {
    final oldValue = controller.value;
    final selection = oldValue.selection;
    final start = selection.isValid ? selection.start : oldValue.text.length;
    final end = selection.isValid ? selection.end : oldValue.text.length;
    final updatedText = oldValue.text.replaceRange(start, end, emoji);
    controller.value = TextEditingValue(
      text: updatedText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    Navigator.pop(context);
  }

  /// เปิดแผ่นเลือกอีโมจิและเพิ่มตัวเลือกลงในช่องพิมพ์เมื่อถูกแตะ.
  void _showEmojiPicker(BuildContext context) {
    const emojis = [
      '😀', '😁', '😂', '🤣', '😊', '😍', '🥰', '😘',
      '😎', '🤔', '😭', '😡', '👍', '👎', '👏', '🙏',
      '❤️', '🔥', '🎉', '✨', '💯', '🙌', '🤝', '😴',
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBg,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: 220,
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
            itemCount: emojis.length,
            itemBuilder: (_, index) => IconButton(
              onPressed: () => _insertEmoji(sheetContext, emojis[index]),
              icon: Text(emojis[index], style: const TextStyle(fontSize: 24)),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          decoration: const BoxDecoration(
            color: AppColors.cardBg,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Choose photo',
                onPressed: isBusy ? null : onPickImage,
                icon: const Icon(Icons.photo_outlined, color: AppColors.goldPrimary),
              ),
              IconButton(
                tooltip: 'Choose video',
                onPressed: isBusy ? null : onPickVideo,
                icon: const Icon(Icons.video_library_outlined, color: AppColors.goldPrimary),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: AppColors.inputBg, borderRadius: BorderRadius.circular(22)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          enabled: !isBusy,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: const TextStyle(color: AppColors.textMuted),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => onSend(),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Add emoji',
                        visualDensity: VisualDensity.compact,
                        onPressed: isBusy ? null : () => _showEmojiPicker(context),
                        icon: const Icon(Icons.emoji_emotions_outlined, color: AppColors.goldPrimary, size: 21),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) => isBusy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.goldPrimary)),
                      )
                    : IconButton(
                        tooltip: 'Send message',
                        onPressed: value.text.trim().isEmpty ? null : onSend,
                        icon: const Icon(Icons.send_rounded, color: AppColors.goldPrimary),
                      ),
              ),
            ],
          ),
        ),
      );
}
