/// SIGMA888: แสดงแฮชแท็กที่กดได้และเปิดหน้าค้นหาโพสต์ตามแท็ก.

import 'package:flutter/material.dart';

import '/screens/auth/profile/hashtag_search_screen.dart';

/// แยกข้อความเป็น spans เพื่อให้เฉพาะคำที่ขึ้นต้นด้วย # เป็นลิงก์.
class HashtagText extends StatelessWidget {
  final String text;
  final TextStyle? style;

  const HashtagText({super.key, required this.text, this.style});

  static final RegExp _pattern = RegExp(r'#([A-Za-z0-9_ก-๙]+)');

  static List<String> extract(String text) => _pattern
      .allMatches(text)
      .map((match) => match.group(1)!.toLowerCase())
      .toSet()
      .toList();

  @override
  Widget build(BuildContext context) {
    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final match in _pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      final tag = match.group(1)!.toLowerCase();
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => HashtagSearchScreen(tag: tag)),
          ),
          child: Text(
            match.group(0)!,
            style: (style ?? DefaultTextStyle.of(context).style).copyWith(
              color: const Color(0xffe0b84f),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) spans.add(TextSpan(text: text.substring(lastEnd)));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
