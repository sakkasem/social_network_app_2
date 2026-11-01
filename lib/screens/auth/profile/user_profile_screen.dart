import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/theme/app_theme.dart';
import '/providers/auth_provider.dart';
import '/screens/auth/chat/chat_room_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

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
  String? _loadError;

  String? get _currentUid =>
      Provider.of<AuthProvider>(context, listen: false).currentUser?.uid;

  String _friendshipId(String first, String second) {
    final pair = [first, second]..sort((a, b) => b.compareTo(a));
    return '${pair[0]}_${pair[1]}';
  }

  @override
  void initState() {
    super.initState();
    _loadProfileAndRelationships();
  }

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

  Future<void> _runAction(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await action();
      await _loadProfileAndRelationships();
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

  Future<void> _unfriend() async {
    final currentUid = _currentUid;
    if (currentUid == null) return;
    await _firestore
        .collection('friendships')
        .doc(_friendshipId(currentUid, widget.userId))
        .delete();
  }

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('PROFILE', style: TextStyle(color: AppColors.goldPrimary, fontSize: 16)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary))
          : _loadError != null
              ? Center(
                  child: TextButton.icon(
                    onPressed: _loadProfileAndRelationships,
                    icon: const Icon(Icons.refresh),
                    label: Text(_loadError!),
                  ),
                )
              : _blockedMe
                  ? const Center(child: Text('This profile is unavailable.', style: TextStyle(color: AppColors.textMuted)))
                  : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 52,
                        backgroundColor: AppColors.goldPrimary,
                        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isEmpty
                            ? Text(name.isEmpty ? 'U' : name[0].toUpperCase(),
                                style: const TextStyle(fontSize: 38, color: Colors.black, fontWeight: FontWeight.bold))
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('@$username', style: const TextStyle(color: AppColors.textMuted)),
                      if ((profile?['bio'] ?? '').toString().isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(profile!['bio'].toString(), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                      ],
                      const SizedBox(height: 28),
                      if (currentUid != widget.userId) ...[
                        if (!_blockedByMe) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _isBusy ? null : () => _runAction(_toggleFollow),
                                child: Text(_isFollowing ? 'Following' : 'Follow'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: _buildFriendButton()),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatRoomScreen(receiverId: widget.userId, receiverName: name),
                              ),
                            ),
                            icon: const Icon(Icons.chat_bubble_outline),
                            label: const Text('Message'),
                          ),
                        ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: _isBusy ? null : () => _runAction(_toggleBlock),
                              icon: Icon(_blockedByMe ? Icons.lock_open : Icons.block, color: Colors.redAccent),
                              label: Text(_blockedByMe ? 'Unblock user' : 'Block user', style: const TextStyle(color: Colors.redAccent)),
                            ),
                            TextButton.icon(
                              onPressed: _isBusy ? null : _reportUser,
                              icon: const Icon(Icons.flag_outlined, color: AppColors.textMuted),
                              label: const Text('Report', style: TextStyle(color: AppColors.textMuted)),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildFriendButton() {
    if (_areFriends) {
      return OutlinedButton(
        onPressed: _isBusy ? null : () => _runAction(_unfriend),
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
