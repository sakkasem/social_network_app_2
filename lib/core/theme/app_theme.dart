// บทบาทไฟล์: กำหนดค่าพื้นฐานและรูปแบบร่วมของแอป (lib/core/theme/app_theme.dart).
/// SIGMA888: รวมค่าสีและธีมหลักสำหรับหน้าตาดำ-ทองของ SIGMA888

import 'package:flutter/material.dart';

/// AppColors รวมค่าสีมาตรฐานที่หน้าจอต่าง ๆ ใช้ร่วมกัน.
class AppColors {
  static const Color background = Color(0xFF0D0D0D); // ดำสนิท
  static const Color cardBg = Color(0xFF171717);     // สีพื้นหลังการ์ด
  static const Color inputBg = Color(0xFF1F1F1F);    // สีช่องกรอกข้อมูล
  static const Color goldPrimary = Color(0xFFE3B836); // สีทองหลัก
  static const Color textMain = Color(0xFFFFFFFF);    // สีข้อความหลัก
  static const Color textMuted = Color(0xFF9E9E9E);   // สีข้อความรอง/เทา
  static const Color border = Color(0xFF262626);      // สีเส้นขอบ
}

/// AppTheme สร้าง ThemeData หลักของแอป.
class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.goldPrimary,
        surface: AppColors.cardBg,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}