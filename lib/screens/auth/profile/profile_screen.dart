import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '/core/theme/app_theme.dart';
import '/providers/auth_provider.dart';
import '/screens/auth/login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // ฟังก์ชันแสดง Dialog สำหรับแก้ไขชื่อโปรไฟล์
  void _showEditProfileDialog(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    final nameController = TextEditingController(text: user.displayName);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.cardBg,
          title: const Text(
            'Edit Profile',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Display Name',
              labelStyle: TextStyle(color: AppColors.textMuted),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.goldPrimary),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.goldPrimary),
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) return;

                try {
                  // อัปเดตข้อมูลใน Firestore
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                    'displayName': newName,
                  });

                  // รีเฟรชข้อมูลใน AuthProvider ทันที
                  await authProvider.reloadUserData();

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated successfully!')),
                    );
                  }
                } catch (e) {
                  debugPrint('Error updating profile: $e');
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text(
          'PROFILE',
          style: TextStyle(
            color: AppColors.goldPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        actions: [
          // ปุ่ม Edit Profile ด้านขวาบน
          IconButton(
            icon: const Icon(Icons.edit, color: AppColors.goldPrimary),
            onPressed: () => _showEditProfileDialog(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // รูปโปรไฟล์ตัวอักษรแรกของชื่อ
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.goldPrimary,
                child: Text(
                  user?.displayName.isNotEmpty == true
                      ? user!.displayName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ชื่อแสดงผล (Display Name)
              Text(
                user?.displayName ?? 'User Name',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),

              // Username
              Text(
                '@${user?.username ?? "username"}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

              // การ์ดแสดงข้อมูลบัญชี
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildInfoTile(
                      icon: Icons.email_outlined,
                      title: 'Email',
                      value: user?.email ?? 'N/A',
                    ),
                    const Divider(color: AppColors.border, height: 24),
                    _buildInfoTile(
                      icon: Icons.fingerprint,
                      title: 'User ID',
                      value: user?.uid ?? 'N/A',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // ปุ่ม Log Out
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.redAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onPressed: () async {
                    await authProvider.signOut();

                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Log Out',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppColors.goldPrimary, size: 20),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}