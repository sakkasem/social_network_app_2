import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import 'auth/feed/home_feed_screen.dart';
import 'auth/feed/create_post_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeFeedScreen(),
    Center(child: Text('Groups', style: TextStyle(color: Colors.white, fontSize: 18))),
    SizedBox.shrink(), // Placeholder สำหรับปุ่ม '+' ตรงกลาง
    Center(child: Text('Chat Messages', style: TextStyle(color: Colors.white, fontSize: 18))),
    Center(child: Text('User Profile', style: TextStyle(color: Colors.white, fontSize: 18))),
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
            _buildNavItem(index: 3, icon: Icons.chat_bubble_outline, activeIcon: Icons.chat_bubble, label: 'Chat'),
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
            Icon(isSelected ? activeIcon : icon, color: color, size: 22),
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