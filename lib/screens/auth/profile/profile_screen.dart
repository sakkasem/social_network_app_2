// บทบาทไฟล์: สร้างหน้าจอและการโต้ตอบในส่วนที่ระบุในพาธ (lib/screens/auth/profile/profile_screen.dart).
/// SIGMA888: แสดงโปรไฟล์ตนเองและจัดการข้อมูลบัญชี

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '/core/theme/app_theme.dart';
import '/models/user_model.dart';
import '/providers/auth_provider.dart';
import '/screens/auth/login_screen.dart';
import '/screens/auth/profile/profile_layout.dart';
import '/services/cloudinary_service.dart';

/// ProfileScreen เป็นหน้าจอของฟีเจอร์ที่ระบุด้วยชื่อคลาสนี้.
// หน้าโปรไฟล์ผู้ใช้ปัจจุบัน แสดงข้อมูลส่วนตัวและทางลัดแก้ไข/ตั้งค่า
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// เปิด dialog ให้เจ้าของบัญชีแก้ไขข้อมูลโปรไฟล์ของตนเอง.
  // เปิดฟอร์มแก้ไขโปรไฟล์และส่งค่าที่บันทึกกลับมาใช้แสดงผล
  Future<void> _editProfile(BuildContext context, UserModel user) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => _EditProfileDialog(user: user),
    );
    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    }
  }

  /// แสดงตัวเลือกบัญชีและคำสั่งออกจากระบบ.
  // แสดงเมนูตั้งค่าที่เกี่ยวข้องกับบัญชีและโปรไฟล์
  void _showSettings(BuildContext context, UserModel user) {
    final auth = context.read<AuthProvider>();
    var isPrivate = user.isPrivate;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardBg,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(builder: (sheetContext, setSheetState) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Account settings', style: TextStyle(color: AppColors.goldPrimary, fontWeight: FontWeight.bold))),
            ListTile(leading: const Icon(Icons.email_outlined, color: AppColors.goldPrimary), title: Text(user.email, style: const TextStyle(color: Colors.white))),
            ListTile(leading: const Icon(Icons.fingerprint, color: AppColors.goldPrimary), title: Text(user.uid, style: const TextStyle(color: AppColors.textMuted))),
            SwitchListTile(
              value: isPrivate,
              activeColor: AppColors.goldPrimary,
              title: const Text('Private account', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Only approved followers can view your posts.', style: TextStyle(color: AppColors.textMuted)),
              onChanged: (value) async {
                setSheetState(() => isPrivate = value);
                try {
                  final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
                  await userRef.update({'privacyChanging': true, 'privacyTargetPrivate': value});
                  final posts = FirebaseFirestore.instance.collection('posts').where('uid', isEqualTo: user.uid);
                  final postDocs = await posts.get();
                  for (var start = 0; start < postDocs.docs.length; start += 450) {
                    final batch = FirebaseFirestore.instance.batch();
                    for (final doc in postDocs.docs.skip(start).take(450)) {
                      batch.update(doc.reference, {'visibility': value ? 'followers' : 'public'});
                    }
                    await batch.commit();
                  }
                  await userRef.update({
                    'isPrivate': value,
                    'privacyChanging': false,
                    'privacyTargetPrivate': value,
                  });
                  await FirebaseFirestore.instance.collection('user_directory').doc(user.uid).update({'isPrivate': value});
                  await auth.reloadUserData();
                } catch (_) {
                  try {
                    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'privacyChanging': false});
                  } catch (_) {}
                  if (sheetContext.mounted) {
                    setSheetState(() => isPrivate = !value);
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(content: Text('Could not update account privacy. Please try again.')),
                    );
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(sheetContext);
                await auth.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (_) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      )),
    );
  }

  @override
  // ประกอบส่วนข้อมูลโปรไฟล์และรายการโพสต์ของเจ้าของบัญชี
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('Please sign in.', style: TextStyle(color: Colors.white))),
      );
    }

    return InstagramProfileLayout(
      userId: user.uid,
      displayName: user.displayName,
      username: user.username,
      photoUrl: user.photoUrl ?? '',
      bio: user.bio,
      isOwnProfile: true,
      isPrivateProfile: user.isPrivate,
      actionButtons: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _editProfile(context, user),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit profile'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.goldPrimary, side: const BorderSide(color: AppColors.goldPrimary)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showSettings(context, user),
              icon: const Icon(Icons.settings_outlined, size: 18),
              label: const Text('Settings'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: AppColors.border)),
            ),
          ),
        ],
      ),
    );
  }
}

/// _EditProfileDialog แสดงกล่องโต้ตอบสำหรับรับข้อมูลหรือยืนยันการทำงาน.
// Dialog ฟอร์มแก้ไขชื่อ Bio และรูปโปรไฟล์
class _EditProfileDialog extends StatefulWidget {
  final UserModel user;
  const _EditProfileDialog({required this.user});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

/// _EditProfileDialogState จัดการ state, lifecycle และการตอบสนองต่อเหตุการณ์ของหน้าจอที่เกี่ยวข้อง.
// จัดการค่าฟอร์ม การเลือกรูป และสถานะบันทึกโปรไฟล์
class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  Uint8List? _imageBytes;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.displayName);
    _bioController = TextEditingController(text: widget.user.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  /// เปิดแกลเลอรีและเก็บไบต์รูปใหม่ไว้ก่อนบันทึกโปรไฟล์.
  // เลือกรูปใหม่และเตรียมไฟล์สำหรับอัปโหลด
  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (file != null) setState(() => _imageBytes = null);
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (mounted) setState(() => _imageBytes = bytes);
      }
    } catch (_) {
      if (mounted) _message('Could not select that image. Please try again.');
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  /// อัปโหลดรูปถ้ามี แล้วบันทึกชื่อ ประวัติ และ URL ลง Firestore/provider.
  // บันทึกข้อมูลโปรไฟล์ และอัปโหลดรูปผ่านบริการสื่อเมื่อมีไฟล์ใหม่
  Future<void> _save() async {
    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    if (name.isEmpty || name.length > 60 || bio.length > 160) {
      _message('Name is required (up to 60 characters); bio must be 160 characters or fewer.');
      return;
    }
    setState(() => _saving = true);
    try {
      var photoUrl = widget.user.photoUrl ?? '';
      if (_imageBytes != null) {
        photoUrl = await CloudinaryService.uploadImage(_imageBytes!, filenamePrefix: 'profile_${widget.user.uid}');
      }
      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).update({
        'displayName': name,
        'bio': bio,
        'photoUrl': photoUrl,
      });
      await FirebaseFirestore.instance.collection('user_directory').doc(widget.user.uid).set({
        'uid': widget.user.uid,
        'username': widget.user.username,
        'displayName': name,
        'photoUrl': photoUrl,
        'isPrivate': widget.user.isPrivate,
      });
      await context.read<AuthProvider>().reloadUserData();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        _message(_imageBytes != null
            ? 'Could not upload or save the profile photo. Please try again.'
            : 'Could not save your profile. Please try again.');
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _saving ? null : _pickPhoto,
                child: CircleAvatar(
                  radius: 42,
                  backgroundColor: AppColors.goldPrimary,
                  backgroundImage: _imageBytes != null
                      ? MemoryImage(_imageBytes!)
                      : (widget.user.photoUrl?.isNotEmpty ?? false)
                          ? NetworkImage(widget.user.photoUrl!)
                          : null,
                  child: const Align(alignment: Alignment.bottomRight, child: Icon(Icons.camera_alt, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                maxLength: 60,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Display Name', labelStyle: TextStyle(color: AppColors.textMuted)),
              ),
              TextField(
                controller: _bioController,
                maxLength: 160,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Bio', labelStyle: TextStyle(color: AppColors.textMuted)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.goldPrimary, foregroundColor: Colors.black),
            child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator()) : const Text('Save'),
          ),
        ],
      );
}
