import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '/core/theme/app_theme.dart';
import '/providers/auth_provider.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  // เพิ่มบรรทัดประกาศตัวแปรเหล่านี้ครับ
  Uint8List? _imageBytes;
  bool _isLoading = false;

  Future<void> _pickImage() async {
  try {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  } catch (e) {
    debugPrint('=== ERROR PICKING IMAGE: $e ===');
  }
}

  // ฟังก์ชันอัปโหลดรูปไป Firebase Storage แล้วส่งโพสต์
  Future<void> _submitPost() async {
    if (_contentController.text.trim().isEmpty && _imageBytes == null) return;
    setState(() => _isLoading = true);
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user == null) return;
      String imageUrl = '';

      // ถ้ามีการเลือกรูป ให้ทำการอัปโหลดขึ้น Firebase Storage
      if (_imageBytes != null) {
        final ref = FirebaseStorage.instance
        .ref()
        .child('post_images')
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putData(_imageBytes!);
        imageUrl = await ref.getDownloadURL();
      }

      // บันทึกข้อมูลโพสต์ลง Firestore (รวม imageUrl)
      await FirebaseFirestore.instance.collection('posts').add({
        'uid': user.uid,
        'displayName': user.displayName,
        'username': user.username,
        'content': _contentController.text.trim(),
        'imageUrl': imageUrl,
        'likes': [],
        'createdAt': Timestamp.now(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error creating post: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('CREATE POST', style: TextStyle(color: AppColors.goldPrimary, fontSize: 16)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child: _isLoading
               ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.goldPrimary))
                : const Text('Post', style: TextStyle(color: AppColors.goldPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              style: const TextStyle(color: Colors.white),
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'What is happening in SIGMA888...?',
                hintStyle: TextStyle(color: AppColors.textMuted),
                border: InputBorder.none,
              ),
            ),
            if (_imageBytes != null) ...[
              const SizedBox(height: 12),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_imageBytes!, height: 200, width: double.infinity, fit: BoxFit.cover),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    onPressed: () => setState(() => _imageBytes = null),
                  ),
                ],
              ),
            ],
            const Spacer(),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image, color: AppColors.goldPrimary, size: 28),
                  onPressed: _pickImage,
                ),
                const Text('Add Image', style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}