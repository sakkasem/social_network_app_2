/// SIGMA888: เลือกภาพ อัปโหลด Cloudinary และสร้างโพสต์ใน Feed หลัก

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '/core/theme/app_theme.dart';
import '/providers/auth_provider.dart';
import '/services/cloudinary_service.dart';
import '/widgets/hashtag_text.dart';

/// CreatePostScreen เป็นหน้าจอของฟีเจอร์ที่ระบุด้วยชื่อคลาสนี้.
class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

/// _CreatePostScreenState จัดการ state, lifecycle และการตอบสนองต่อเหตุการณ์ของหน้าจอที่เกี่ยวข้อง.
class _CreatePostScreenState extends State<CreatePostScreen> {
  final _contentController = TextEditingController();
  // เพิ่มบรรทัดประกาศตัวแปรเหล่านี้ครับ
  Uint8List? _imageBytes;
  Uint8List? _videoBytes;
  String? _videoFilename;
  bool _isLoading = false;

  /// เปิดแกลเลอรีและเก็บไบต์รูปที่เลือกไว้ใน state เพื่อแสดงตัวอย่างก่อนโพสต์.
  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        if (mounted) {
          setState(() {
            _imageBytes = bytes;
            _videoBytes = null;
            _videoFilename = null;
          });
        }
      }
    } catch (e) {
      debugPrint('=== ERROR PICKING IMAGE: $e ===');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เลือกรูปไม่สำเร็จ กรุณาลองอีกครั้ง')),
        );
      }
    }
  }

  /// โหลดโปรไฟล์ล่าสุด อัปโหลดรูปถ้ามี และสร้างเอกสารโพสต์ใน Firestore.
  /// แสดงข้อผิดพลาดแก่ผู้ใช้ และคืนสถานะ loading เมื่อทำงานเสร็จ.
  Future<void> _submitPost() async {
    if (_contentController.text.trim().isEmpty &&
        _imageBytes == null &&
        _videoBytes == null)
      return;
    setState(() => _isLoading = true);
    var uploadFailed = false;
    try {
      final user = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentUser;
      if (user == null) throw Exception('กรุณาเข้าสู่ระบบก่อนสร้างโพสต์');
      String imageUrl = '';
      String videoUrl = '';

      // ถ้ามีการเลือกรูป ให้อัปโหลดไป Cloudinary ก่อนเพื่อให้ได้ URL สำหรับโพสต์
      if (_imageBytes != null) {
        try {
          imageUrl = await CloudinaryService.uploadImage(
            _imageBytes!,
            filenamePrefix: 'post',
          );
        } catch (_) {
          uploadFailed = true;
          rethrow;
        }
      }
      if (_videoBytes != null) {
        try {
          videoUrl = await CloudinaryService.uploadVideo(
            _videoBytes!,
            filenamePrefix: 'post_${user.uid}',
            filename: _videoFilename ?? 'video.mp4',
          );
        } catch (_) {
          uploadFailed = true;
          rethrow;
        }
      }

      // อ่านข้อมูลล่าสุดจาก users เพราะข้อมูลรูปใน Firebase Auth อาจยังไม่อัปเดต
      final profileSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final profile = profileSnapshot.data() ?? <String, dynamic>{};
      final latestDisplayName = (profile['displayName'] ?? user.displayName)
          .toString();
      final latestUsername = (profile['username'] ?? user.username).toString();
      final latestPhotoUrl = (profile['photoUrl'] ?? user.photoUrl ?? '')
          .toString();
      final isPrivacyChanging = profile['privacyChanging'] == true;
      final isPrivate = isPrivacyChanging
          ? profile['privacyTargetPrivate'] == true
          : profile['isPrivate'] == true;

      // เก็บ display name และ photo URL ล่าสุดไว้กับโพสต์เพื่อใช้แสดงใน Feed
      await FirebaseFirestore.instance.collection('posts').add({
        'uid': user.uid,
        'displayName': latestDisplayName,
        'username': latestUsername,
        'content': _contentController.text.trim(),
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'mediaType': videoUrl.isNotEmpty
            ? 'video'
            : (imageUrl.isNotEmpty ? 'image' : 'text'),
        'hashtags': HashtagText.extract(_contentController.text.trim()),
        'visibility': isPrivate ? 'followers' : 'public',
        'userPhotoUrl': latestPhotoUrl,
        'likes': [],
        'dislikes': <String>[],
        'reactions': <String, String>{},
        'createdAt': Timestamp.now(),
      });

      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Error creating post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              uploadFailed
                  ? 'อัปโหลดรูปหรือวิดีโอไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'
                  : 'สร้างโพสต์ไม่สำเร็จ กรุณาตรวจสอบการเชื่อมต่อแล้วลองใหม่',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickVideo() async {
    try {
      final file = await ImagePicker().pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (mounted) {
        setState(() {
          _videoBytes = bytes;
          _videoFilename = file.name;
          _imageBytes = null;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เลือกวิดีโอไม่สำเร็จ กรุณาลองอีกครั้ง'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  /// สร้างหน้าจอกรอกเนื้อหา แนบรูปตัวอย่าง และเรียกส่งโพสต์.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'CREATE POST',
          style: TextStyle(color: AppColors.goldPrimary, fontSize: 16),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _submitPost,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.goldPrimary,
                    ),
                  )
                : const Text(
                    'Post',
                    style: TextStyle(
                      color: AppColors.goldPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
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
                    child: Image.memory(
                      _imageBytes!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    onPressed: () => setState(() => _imageBytes = null),
                  ),
                ],
              ),
            ],
            if (_videoBytes != null) ...[
              const SizedBox(height: 12),
              ListTile(
                tileColor: AppColors.cardBg,
                leading: const Icon(
                  Icons.video_file_outlined,
                  color: AppColors.goldPrimary,
                ),
                title: Text(
                  _videoFilename ?? 'Selected video',
                  style: const TextStyle(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => setState(() {
                    _videoBytes = null;
                    _videoFilename = null;
                  }),
                ),
              ),
            ],
            const Spacer(),
            Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.image,
                    color: AppColors.goldPrimary,
                    size: 28,
                  ),
                  onPressed: _pickImage,
                ),
                const Text(
                  'Add Image',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                IconButton(
                  tooltip: 'Add video',
                  icon: const Icon(
                    Icons.video_library_outlined,
                    color: AppColors.goldPrimary,
                    size: 26,
                  ),
                  onPressed: _isLoading ? null : _pickVideo,
                ),
                const Text(
                  'Add Video',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
