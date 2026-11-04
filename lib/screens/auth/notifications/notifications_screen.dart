// บทบาทไฟล์: หน้ารายการแจ้งเตือน (lib/screens/auth/notifications/notifications_screen.dart).
/// SIGMA888: แสดงแจ้งเตือน Like/Comment และทำเครื่องหมายว่าอ่านแล้ว

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '/core/theme/app_theme.dart';
import '/providers/auth_provider.dart';
import '/services/notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m';
    if (diff.inDays < 1) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: AppColors.goldPrimary, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: AppColors.goldPrimary),
        actions: [
          if (uid != null)
            TextButton(
              onPressed: () => NotificationService.markAllRead(uid),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: uid == null
          ? const SizedBox.shrink()
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: NotificationService.latest(uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Could not load notifications.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No notifications yet',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, i) {
                    final doc = docs[i];
                    final data = doc.data();
                    final isRead = data['read'] == true;
                    return ListTile(
                      tileColor: isRead
                          ? Colors.transparent
                          : AppColors.goldPrimary.withOpacity(0.08),
                      leading: Icon(
                        data['type'] == 'comment'
                            ? Icons.mode_comment
                            : Icons.favorite,
                        color: AppColors.goldPrimary,
                      ),
                      title: Text(
                        NotificationService.describe(data),
                        style: TextStyle(
                          color: AppColors.textMain,
                          fontWeight:
                              isRead ? FontWeight.normal : FontWeight.bold,
                        ),
                      ),
                      trailing: Text(
                        _timeAgo(data['createdAt'] as Timestamp?),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      onTap: () {
                        if (!isRead) NotificationService.markRead(uid, doc.id);
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
