// บทบาทไฟล์: จุดเริ่มต้นหรือการตั้งค่าระดับแอป (lib/main.dart).
/// SIGMA888: จุดเริ่มต้นแอป ตั้งค่า Firebase, Provider และธีม

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  // 3. ต้องเรียกใช้ WidgetsFlutterBinding ก่อนเรียก async/await ใน main
  WidgetsFlutterBinding.ensureInitialized();

  // เปิด backend ของ video_player สำหรับ Windows และ Linux ที่ plugin ทางการไม่รองรับโดยตรง
  VideoPlayerMediaKit.ensureInitialized(windows: true, linux: true);
  
  // 4. เชื่อมต่อ Firebase เข้ากับแอป
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

/// MyApp รวมหน้าที่เฉพาะของส่วนประกอบนี้ไว้ในตำแหน่งเดียว.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'SIGMA888',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const LoginScreen(),
      ),
    );
  }
}
