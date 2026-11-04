// บทบาทไฟล์: ปุ่มกระดิ่งพร้อม badge จำนวนแจ้งเตือนที่ยังไม่อ่าน (lib/widgets/notification_bell.dart).

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/core/theme/app_theme.dart';
import '/providers/auth_provider.dart';
import '/services/notification_service.dart';
import '/screens/auth/notifications/notifications_screen.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<int>(
      stream: NotificationService.unreadCount(uid),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 99 ? '99+' : '$count'),
            backgroundColor: Colors.redAccent,
            child: const Icon(
              Icons.notifications_outlined,
              color: AppColors.goldPrimary,
            ),
          ),
        );
      },
    );
  }
}
