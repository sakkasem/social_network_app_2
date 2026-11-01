import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '/core/theme/app_theme.dart';
import '/models/user_model.dart';
import '/providers/auth_provider.dart';
import '/screens/auth/login_screen.dart';
import '/services/cloudinary_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('PROFILE', style: TextStyle(color: AppColors.goldPrimary, fontSize: 16)),
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'Edit profile',
              icon: const Icon(Icons.edit, color: AppColors.goldPrimary),
              onPressed: () => _editProfile(context, user),
            ),
        ],
      ),
      body: user == null
          ? const Center(child: Text('Please sign in.', style: TextStyle(color: Colors.white)))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.goldPrimary,
                      backgroundImage: (user.photoUrl?.isNotEmpty ?? false)
                          ? NetworkImage(user.photoUrl!)
                          : null,
                      child: user.photoUrl?.isNotEmpty == true
                          ? null
                          : Text(
                              user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U',
                              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Text(user.displayName, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('@${user.username}', style: const TextStyle(color: AppColors.textMuted)),
                    if (user.bio.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(user.bio, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                    ],
                    const SizedBox(height: 32),
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
                          _infoTile(Icons.email_outlined, 'Email', user.email),
                          const Divider(color: AppColors.border, height: 24),
                          _infoTile(Icons.fingerprint, 'User ID', user.uid),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                        ),
                        onPressed: () async {
                          await auth.signOut();
                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (_) => false,
                            );
                          }
                        },
                        icon: const Icon(Icons.logout),
                        label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  static Widget _infoTile(IconData icon, String title, String value) => Row(
        children: [
          Icon(icon, color: AppColors.goldPrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
        ],
      );
}

class _EditProfileDialog extends StatefulWidget {
  final UserModel user;
  const _EditProfileDialog({required this.user});

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

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
