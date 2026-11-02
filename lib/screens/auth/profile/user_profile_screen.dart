/// SIGMA888: แสดงโปรไฟล์ผู้ใช้อื่น พร้อมติดตาม เป็นเพื่อน บล็อก และรายงาน

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/theme/app_theme.dart';
import '/providers/auth_provider.dart';
import '/screens/auth/chat/chat_room_screen.dart';
import '/screens/auth/profile/profile_layout.dart';

/// UserProfileScreen เป็นหน้าจอของฟีเจอร์ที่ระบุด้วยชื่อคลาสนี้.
class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

/// _UserProfileScreenState จัดการ state, lifecycle และการตอบสนองต่อเหตุการณ์ของหน้าจอที่เกี่ยวข้อง.
class _UserProfileScreenState extends State<UserProfileScreen> {
  final _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isBusy = false;
  bool _isFollowing = false;
  bool _areFriends = false;
  bool _outgoingRequest = false;
  bool _incomingRequest = false;
  bool _blockedByMe = false;
  bool _blockedMe = false;
  int _profileRefreshKey = 0;
  String? _loadError;

  String? get _currentUid =>
      Provider.of<AuthProvider>(context, listen: false).currentUser?.uid;

  /// คืน document id แบบคงที่เพื่อให้ทั้งสองคนอ้าง friendship document เดียวกัน.
  String _friendshipId(String first, String second) {
    final pair = [first, second]..sort((a, b) => b.compareTo(a));
    return '${pair[0]}_${pair[1]}';
  }

  @override
  void initState() {
    super.initState();
    _loadProfileAndRelationships();
  }

  /// โหลดโปรไฟล์และสถานะติดตาม/เพื่อน/บล็อกที่เกี่ยวข้องกับผู้ใช้เป้าหมาย.
  Future<void> _loadProfileAndRelationships() async {
    final currentUid = _currentUid;
    if (currentUid == null) {
      setState(() {
        _loadError = 'Please sign in to view this profile.';
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final profileFuture = _firestore.collection('users').doc(widget.userId).get();
      final relationshipFutures = await Future.wait([
        _firestore.collection('users').doc(currentUid).collection('following').doc(widget.userId).get(),
        _firestore.collection('users').doc(widget.userId).collection('friendRequests').doc(currentUid).get(),
        _firestore.collection('users').doc(currentUid).collection('friendRequests').doc(widget.userId).get(),
        _firestore.collection('friendships').doc(_friendshipId(currentUid, widget.userId)).get(),
        _firestore.collection('users').doc(currentUid).collection('blocked').doc(widget.userId).get(),
        _firestore.collection('users').doc(currentUid).collection('blockedBy').doc(widget.userId).get(),
      ]);
      final profileSnapshot = await profileFuture;
      if (!mounted) return;

      setState(() {
        _profile = profileSnapshot.data();
        _isFollowing = relationshipFutures[0].exists;
        _outgoingRequest = relationshipFutures[1].exists;
        _incomingRequest = relationshipFutures[2].exists;
        _areFriends = relationshipFutures[3].exists;
        _blockedByMe = relationshipFutures[4].exists;
        _blockedMe = relationshipFutures[5].exists;
        _isLoading = false;
        if (!profileSnapshot.exists) _loadError = 'This user could not be found.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Could not load this profile. Please try again.';
      });
    }
  }

  /// ครอบการกระทำ async ด้วยสถานะ busy และจัดการข้อผิดพลาดเพื่อแสดงแก่ผู้ใช้.
  Future<void> _runAction(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
      await _loadProfileAndRelationships();
      if (mounted) setState(() => _profileRefreshKey++);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// เพิ่มหรือลบเอกสาร following เพื่อเปลี่ยนสถานะติดตาม.
  Future<void> _toggleFollow() async {
    final currentUid = _currentUid;
    if (currentUid == null) return;
    final followingRef = _firestore
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(widget.userId);
    if (_isFollowing) {
      await followingRef.delete();
    } else {
      await followingRef.set({
        'targetUid': widget.userId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// สร้างคำขอเป็นเพื่อนไปยังผู้ใช้เป้าหมาย.
  Future<void> _sendFriendRequest() async {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (currentUser == null) return;
    await _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('friendRequests')
        .doc(currentUser.uid)
        .set({
      'fromUid': currentUser.uid,
      'fromName': currentUser.displayName,
      'toUid': widget.userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// ยกเลิกคำขอเป็นเพื่อนที่ผู้ใช้ปัจจุบันส่งออกไป.
  Future<void> _cancelFriendRequest() async {
    final currentUid = _currentUid;
    if (currentUid == null) return;
    await _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('friendRequests')
        .doc(currentUid)
        .delete();
  }

  /// ยอมรับคำขอและสร้าง friendship จากนั้นลบคำขอที่รอดำเนินการ.
  Future<void> _acceptFriendRequest() async {
    final currentUid = _currentUid;
    if (currentUid == null) return;
    final pair = [currentUid, widget.userId]..sort((a, b) => b.compareTo(a));
    final batch = _firestore.batch();
    batch.set(_firestore.collection('friendships').doc('${pair[0]}_${pair[1]}'), {
      'participants': pair,
      'acceptedByUid': currentUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.delete(_firestore
        .collection('users')
        .doc(currentUid)
        .collection('friendRequests')
        .doc(widget.userId));
    await batch.commit();
  }

  /// ปฏิเสธคำขอเป็นเพื่อนที่เข้ามาและลบเอกสารคำขอนั้น.
  Future<void> _rejectFriendRequest() async {
    final currentUid = _currentUid;
    if (currentUid == null) return;
    await _firestore
        .collection('users')
        .doc(currentUid)
        .collection('friendRequests')
        .doc(widget.userId)
        .delete();
  }

  /// ขอให้ผู้ใช้ยืนยันก่อนลบเพื่อน แล้วจึงลบ friendship จริง.
  Future<void> _confirmUnfriend() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('ลบเพื่อน', style: TextStyle(color: Colors.white)),
        content: const Text('คุณต้องการลบเพื่อนคนนี้ใช่หรือไม่?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('ยกเลิก')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('ยืนยันการลบ', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _runAction(_unfriend);
  }

  /// ยุติความสัมพันธ์เพื่อนโดยลบเอกสาร friendship ที่ใช้ร่วมกัน.
  Future<void> _unfriend() async {
    final currentUid = _currentUid;
    if (currentUid == null) return;
    await _firestore
        .collection('friendships')
        .doc(_friendshipId(currentUid, widget.userId))
        .delete();
  }

  /// เพิ่ม/ลบรายการบล็อกและเอกสาร mirror ด้วย batch ให้การเปลี่ยนแปลงเป็นชุดเดียว.
  Future<void> _toggleBlock() async {
    final currentUid = _currentUid;
    if (currentUid == null || currentUid == widget.userId) return;
    final blockedRef = _firestore.collection('users').doc(currentUid).collection('blocked').doc(widget.userId);
    final mirrorRef = _firestore.collection('users').doc(widget.userId).collection('blockedBy').doc(currentUid);
    final batch = _firestore.batch();
    if (_blockedByMe) {
      batch.delete(blockedRef);
      batch.delete(mirrorRef);
    } else {
      final data = {'blockerUid': currentUid, 'blockedUid': widget.userId, 'createdAt': FieldValue.serverTimestamp()};
      batch.set(blockedRef, data);
      batch.set(mirrorRef, data);
      batch.delete(_firestore.collection('users').doc(currentUid).collection('following').doc(widget.userId));
      batch.delete(_firestore.collection('friendships').doc(_friendshipId(currentUid, widget.userId)));
    }
    await batch.commit();
  }

  /// ส่งรายงานผู้ใช้ไปยังคอลเลกชัน reports เพื่อให้ตรวจสอบภายหลัง.
  Future<void> _reportUser() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Report user', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: reasonController,
          maxLength: 500,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: 'Tell us why you are reporting this user'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, reasonController.text.trim()), child: const Text('Submit')),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || reason.isEmpty || !mounted) return;
    try {
      final currentUid = _currentUid;
      if (currentUid == null) return;
      await _firestore.collection('reports').add({
        'reporterUid': currentUid,
        'targetType': 'user',
        'targetId': widget.userId,
        'reason': reason,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted.')));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not submit report.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _currentUid;
    final profile = _profile;
    final name = (profile?['displayName'] ?? 'User').toString();
    final username = (profile?['username'] ?? '').toString();
    final photoUrl = (profile?['photoUrl'] ?? '').toString();
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.goldPrimary)),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: TextButton.icon(
            onPressed: _loadProfileAndRelationships,
            icon: const Icon(Icons.refresh, color: AppColors.goldPrimary),
            label: Text(_loadError!, style: const TextStyle(color: AppColors.goldPrimary)),
          ),
        ),
      );
    }
    if (_blockedMe) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('This profile is unavailable.', style: TextStyle(color: AppColors.textMuted))),
      );
    }

    final isOwnProfile = currentUid == widget.userId;
    return InstagramProfileLayout(
      key: ValueKey('${widget.userId}-$_profileRefreshKey'),
      userId: widget.userId,
      displayName: name,
      username: username,
      photoUrl: photoUrl,
      bio: (profile?['bio'] ?? '').toString(),
      isOwnProfile: isOwnProfile,
      actionButtons: isOwnProfile ? const SizedBox.shrink() : _buildProfileActions(name),
    );
  }

  Widget _buildProfileActions(String name) {
    if (_blockedByMe) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isBusy ? null : () => _runAction(_toggleBlock),
              icon: const Icon(Icons.lock_open_outlined),
              label: const Text('Unblock'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.goldPrimary, side: const BorderSide(color: AppColors.goldPrimary)),
            ),
          ),
          const SizedBox(width: 8),
          _profileMoreMenu(),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _isBusy ? null : () => _runAction(_toggleFollow),
                style: FilledButton.styleFrom(
                  backgroundColor: _isFollowing ? AppColors.cardBg : AppColors.goldPrimary,
                  foregroundColor: _isFollowing ? Colors.white : Colors.black,
                  side: _isFollowing ? const BorderSide(color: AppColors.border) : null,
                ),
                child: Text(_isFollowing ? 'Following' : 'Follow'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChatRoomScreen(receiverId: widget.userId, receiverName: name)),
                ),
                icon: const Icon(Icons.chat_bubble_outline, size: 18),
                label: const Text('Message'),
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.goldPrimary, side: const BorderSide(color: AppColors.goldPrimary)),
              ),
            ),
            const SizedBox(width: 4),
            _profileMoreMenu(),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(width: double.infinity, child: _buildFriendButton()),
      ],
    );
  }

  Widget _profileMoreMenu() => PopupMenuButton<String>(
        icon: const Icon(Icons.more_horiz, color: AppColors.textMuted),
        color: AppColors.cardBg,
        onSelected: (value) {
          if (value == 'block') _runAction(_toggleBlock);
          if (value == 'report') _reportUser();
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'block', child: Text(_blockedByMe ? 'Unblock user' : 'Block user')),
          const PopupMenuItem(value: 'report', child: Text('Report user')),
        ],
      );

  Widget _buildFriendButton() {
    if (_areFriends) {
      return OutlinedButton(
        onPressed: _isBusy ? null : _confirmUnfriend,
        child: const Text('Friends'),
      );
    }
    if (_incomingRequest) {
      return PopupMenuButton<String>(
        enabled: !_isBusy,
        onSelected: (action) => _runAction(action == 'accept' ? _acceptFriendRequest : _rejectFriendRequest),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'accept', child: Text('Accept request')),
          PopupMenuItem(value: 'reject', child: Text('Decline request')),
        ],
        child: OutlinedButton(onPressed: null, child: const Text('Request received')),
      );
    }
    if (_outgoingRequest) {
      return OutlinedButton(
        onPressed: _isBusy ? null : () => _runAction(_cancelFriendRequest),
        child: const Text('Pending'),
      );
    }
    return ElevatedButton(
      onPressed: _isBusy ? null : () => _runAction(_sendFriendRequest),
      style: ElevatedButton.styleFrom(backgroundColor: AppColors.goldPrimary, foregroundColor: Colors.black),
      child: const Text('Add friend'),
    );
  }
}
