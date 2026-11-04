// บทบาทไฟล์: สร้างหน้าจอและการโต้ตอบในส่วนที่ระบุในพาธ (lib/screens/main_navigation_screen.dart).
/// SIGMA888: ประกอบแท็บหลักของแอปและควบคุมหน้าที่เลือกอยู่

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import 'auth/notifications/notifications_screen.dart';
import 'auth/feed/home_feed_screen.dart';
import 'auth/feed/create_post_screen.dart';
import 'auth/profile/profile_screen.dart';
import 'auth/chat/chat_list_screen.dart';
import 'auth/chat/chat_room_screen.dart';
import 'auth/groups/groups_list_screen.dart';

/// MainNavigationScreen เป็นหน้าจอของฟีเจอร์ที่ระบุด้วยชื่อคลาสนี้.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

/// _MainNavigationScreenState จัดการ state, lifecycle และการตอบสนองต่อเหตุการณ์ของหน้าจอที่เกี่ยวข้อง.
class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notifSub;
  bool _initialNotifLoad = true;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatSub;
  final Map<String, int> _lastUnreadByRoom = {};
  bool _initialChatLoad = true;
  int _chatUnreadTotal = 0;

  @override
  void initState() {
    super.initState();
    _listenForNewNotifications();
    _listenForChatMessages();
  }

  /// ฟังห้องแชททั้งหมดของผู้ใช้ เพื่อนับข้อความยังไม่อ่านและเด้งแจ้งเตือนข้อความใหม่
  void _listenForChatMessages() {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    _chatSub = FirebaseFirestore.instance
        .collection('chat_rooms')
        .where('participants', arrayContains: uid)
        .snapshots()
        .listen(
      (snapshot) {
        var total = 0;
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final counts = Map<String, dynamic>.from(data['unreadCounts'] ?? const {});
          final unread = ((counts[uid] as num?) ?? 0).toInt();
          total += unread;

          final previous = _lastUnreadByRoom[doc.id] ?? 0;
          _lastUnreadByRoom[doc.id] = unread;

          final isNewIncoming = !_initialChatLoad &&
              unread > previous &&
              data['lastSenderId'] != uid &&
              ChatRoomScreen.activeRoomId != doc.id;
          if (isNewIncoming && mounted) {
            final names = Map<String, dynamic>.from(data['participantNames'] ?? const {});
            final senderId = data['lastSenderId'] as String?;
            final senderName = (names[senderId] ?? 'Someone').toString();
            _showChatPopup(
              senderId: senderId,
              senderName: senderName,
              preview: (data['lastMessage'] ?? '').toString(),
            );
          }
        }
        _initialChatLoad = false;
        if (mounted) setState(() => _chatUnreadTotal = total);
      },
      onError: (e) => debugPrint('Chat listener error: $e'),
    );
  }

  void _showChatPopup({
    required String? senderId,
    required String senderName,
    required String preview,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.cardBg,
        content: Row(
          children: [
            const Icon(Icons.chat_bubble, color: AppColors.goldPrimary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$senderName: $preview',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textMain),
              ),
            ),
          ],
        ),
        action: senderId == null
            ? null
            : SnackBarAction(
                label: 'Open',
                textColor: AppColors.goldPrimary,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatRoomScreen(
                      receiverId: senderId,
                      receiverName: senderName,
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// ฟังแจ้งเตือนใหม่แบบเรียลไทม์ แล้วเด้ง SnackBar เมื่อมีรายการเข้ามาใหม่
  void _listenForNewNotifications() {
    final uid = context.read<AuthProvider>().currentUser?.uid;
    if (uid == null) return;
    _notifSub = NotificationService.latest(uid).listen(
      (snapshot) {
        // snapshot แรกคือของเก่าที่มีอยู่แล้ว ไม่ต้องเด้ง
        if (_initialNotifLoad) {
          _initialNotifLoad = false;
          return;
        }
        for (final change in snapshot.docChanges) {
          if (change.type != DocumentChangeType.added) continue;
          final data = change.doc.data();
          if (data == null || data['read'] == true || !mounted) continue;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.cardBg,
              content: Row(
                children: [
                  const Icon(Icons.notifications, color: AppColors.goldPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      NotificationService.describe(data),
                      style: const TextStyle(color: AppColors.textMain),
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'View',
                textColor: AppColors.goldPrimary,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
              ),
            ),
          );
        }
      },
      onError: (e) => debugPrint('Notification listener error: $e'),
    );
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _chatSub?.cancel();
    super.dispose();
  }

  final List<Widget> _pages = const [
    HomeFeedScreen(),
    GroupsListScreen(),
    SizedBox.shrink(), // Placeholder สำหรับปุ่ม '+' ตรงกลาง
    ChatListScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      // เมื่อกดปุ่ม '+' ตรงกลาง สามารถเปิดหน้า Create Post ได้ที่นี่
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CreatePostScreen()),
      );
      debugPrint('Open Create Post Screen');
    } else {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      // ปุ่ม '+' สีทองตรงกลาง
      floatingActionButton: Container(
        height: 56,
        width: 56,
        decoration: const BoxDecoration(
          color: AppColors.goldPrimary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x66E3B836),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: FloatingActionButton(
          elevation: 0,
          backgroundColor: Colors.transparent,
          shape: const CircleBorder(),
          onPressed: () => _onItemTapped(2),
          child: const Icon(Icons.add, color: Colors.black, size: 30),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // แถบ Bottom Navigation Bar ด้านล่าง
      bottomNavigationBar: BottomAppBar(
        color: AppColors.cardBg,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(index: 0, icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
            _buildNavItem(index: 1, icon: Icons.group_outlined, activeIcon: Icons.group, label: 'Groups'),
            const SizedBox(width: 48), // เว้นพื้นที่ให้ปุ่ม '+' ตรงกลาง
            _buildNavItem(index: 3, icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Chat', badgeCount: _chatUnreadTotal),
            _buildNavItem(index: 4, icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    int badgeCount = 0,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.goldPrimary : AppColors.textMuted;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Badge(
              isLabelVisible: badgeCount > 0,
              label: Text(badgeCount > 99 ? '99+' : '$badgeCount'),
              backgroundColor: Colors.redAccent,
              child: Icon(isSelected ? activeIcon : icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}