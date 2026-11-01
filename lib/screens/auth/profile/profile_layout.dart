/// SIGMA888: ใช้เลย์เอาต์โปรไฟล์แบบ Instagram ร่วมกัน รวมสถิติ ไฮไลต์ และ Grid โพสต์

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '/core/theme/app_theme.dart';
import '/models/post_model.dart';

/// เลย์เอาต์โปรไฟล์ร่วมที่แสดงข้อมูล สถิติ ไฮไลต์ และโพสต์ของผู้ใช้ทั้งตนเองและผู้อื่น.
class InstagramProfileLayout extends StatefulWidget {
  final String userId;
  final String displayName;
  final String username;
  final String photoUrl;
  final String bio;
  final bool isOwnProfile;
  final Widget actionButtons;

  const InstagramProfileLayout({
    super.key,
    required this.userId,
    required this.displayName,
    required this.username,
    required this.photoUrl,
    required this.bio,
    required this.isOwnProfile,
    required this.actionButtons,
  });

  @override
  State<InstagramProfileLayout> createState() => _InstagramProfileLayoutState();
}

/// _InstagramProfileLayoutState จัดการ state, lifecycle และการตอบสนองต่อเหตุการณ์ของหน้าจอที่เกี่ยวข้อง.
class _InstagramProfileLayoutState extends State<InstagramProfileLayout> {
  late Future<_ProfileStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadStats();
  }

  @override
  void didUpdateWidget(covariant InstagramProfileLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _statsFuture = _loadStats();
  }

  /// ดึงจำนวนโพสต์ ผู้ติดตาม และกำลังติดตามจาก Firestore เพื่อแสดงใน header.
  Future<_ProfileStats> _loadStats() async {
    final firestore = FirebaseFirestore.instance;
    final results = await Future.wait([
      firestore.collection('posts').where('uid', isEqualTo: widget.userId).count().get(),
      firestore.collectionGroup('following').where('targetUid', isEqualTo: widget.userId).count().get(),
      firestore.collection('users').doc(widget.userId).collection('following').count().get(),
    ]);
    return _ProfileStats(
      posts: results[0].count ?? 0,
      followers: results[1].count ?? 0,
      following: results[2].count ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text('@${widget.username}', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverToBoxAdapter(child: _profileHeader()),
              SliverPersistentHeader(
                pinned: true,
                delegate: _TabHeaderDelegate(
                  const TabBar(
                    indicatorColor: AppColors.goldPrimary,
                    indicatorWeight: 2,
                    labelColor: AppColors.goldPrimary,
                    unselectedLabelColor: AppColors.textMuted,
                    tabs: [
                      Tab(icon: Icon(Icons.grid_on_rounded)),
                      Tab(icon: Icon(Icons.alternate_email_rounded)),
                      Tab(icon: Icon(Icons.bookmark_border_rounded)),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              children: [
                _ProfilePostGrid(userId: widget.userId),
                const _ProfilePlaceholder(icon: Icons.alternate_email_rounded, title: 'No tagged posts yet'),
                const _ProfilePlaceholder(icon: Icons.bookmark_border_rounded, title: 'No saved posts yet'),
              ],
            ),
          ),
        ),
      );

  Widget _profileHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _ProfileAvatar(name: widget.displayName, photoUrl: widget.photoUrl),
                const SizedBox(width: 18),
                Expanded(
                  child: FutureBuilder<_ProfileStats>(
                    future: _statsFuture,
                    builder: (context, snapshot) {
                      final stats = snapshot.data;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(value: snapshot.hasError ? '—' : stats?.posts.toString() ?? '…', label: 'Posts'),
                          _StatItem(value: snapshot.hasError ? '—' : stats?.followers.toString() ?? '…', label: 'Followers'),
                          _StatItem(value: snapshot.hasError ? '—' : stats?.following.toString() ?? '…', label: 'Following'),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(widget.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            Text('@${widget.username}', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
            if (widget.bio.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(widget.bio, style: const TextStyle(color: Colors.white, height: 1.35)),
            ],
            const SizedBox(height: 14),
            widget.actionButtons,
            const SizedBox(height: 14),
            _StoryHighlights(isOwnProfile: widget.isOwnProfile),
          ],
        ),
      );
}

/// เก็บจำนวนโพสต์ ผู้ติดตาม และกำลังติดตามที่โหลดจาก Firestore.
class _ProfileStats {
  final int posts;
  final int followers;
  final int following;

  const _ProfileStats({required this.posts, required this.followers, required this.following});
}

/// แสดงตัวเลขสถิติหนึ่งค่าและชื่อกำกับในแถวสถิติโปรไฟล์.
class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ],
      );
}

/// แสดงรูปโปรไฟล์วงกลม และภาพสำรองเมื่อไม่มี URL หรือโหลดรูปไม่ได้.
class _ProfileAvatar extends StatelessWidget {
  final String name;
  final String photoUrl;

  const _ProfileAvatar({required this.name, required this.photoUrl});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: AppColors.goldPrimary, width: 2))),
        child: CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.cardBg,
          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: photoUrl.isEmpty
              ? Text(name.isEmpty ? 'U' : name[0].toUpperCase(), style: const TextStyle(color: AppColors.goldPrimary, fontSize: 28, fontWeight: FontWeight.bold))
              : null,
        ),
      );
}

/// แสดงแถววงกลมสำหรับ Story Highlights และปุ่มสร้างไฮไลต์ใหม่.
class _StoryHighlights extends StatelessWidget {
  final bool isOwnProfile;

  const _StoryHighlights({required this.isOwnProfile});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 92,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            SizedBox(
              width: 76,
              child: Column(
                children: [
                  InkWell(
                    borderRadius: BorderRadius.circular(40),
                    onTap: isOwnProfile
                        ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Story Highlights are ready for a future update.')))
                        : null,
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.goldPrimary, width: 1.5), color: AppColors.cardBg),
                      child: Icon(isOwnProfile ? Icons.add : Icons.auto_awesome_outlined, color: AppColors.goldPrimary, size: 27),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(isOwnProfile ? 'New' : 'Highlights', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            if (!isOwnProfile)
              const Padding(
                padding: EdgeInsets.only(top: 23),
                child: Text('No highlights yet', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
          ],
        ),
      );
}

/// กำหนดขนาดและการวาด TabBar ที่ตรึงอยู่ในส่วนหัวของ NestedScrollView.
class _TabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  const _TabHeaderDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => Container(
        decoration: const BoxDecoration(color: AppColors.background, border: Border(top: BorderSide(color: AppColors.border))),
        child: tabBar,
      );

  @override
  bool shouldRebuild(covariant _TabHeaderDelegate oldDelegate) => oldDelegate.tabBar != tabBar;
}

/// ดึงโพสต์ของผู้ใช้และแสดงภาพหรือข้อความในตารางสามคอลัมน์.
class _ProfilePostGrid extends StatefulWidget {
  final String userId;

  const _ProfilePostGrid({required this.userId});

  @override
  State<_ProfilePostGrid> createState() => _ProfilePostGridState();
}

/// _ProfilePostGridState จัดการ state, lifecycle และการตอบสนองต่อเหตุการณ์ของหน้าจอที่เกี่ยวข้อง.
class _ProfilePostGridState extends State<_ProfilePostGrid> {
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('posts').where('uid', isEqualTo: widget.userId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton.icon(
                onPressed: () => setState(() {}),
                icon: const Icon(Icons.refresh, color: AppColors.goldPrimary),
                label: const Text('Could not load posts. Retry', style: TextStyle(color: AppColors.goldPrimary)),
              ),
            );
          }
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary));
          final docs = [...snapshot.data!.docs]
            ..sort((a, b) {
              final aTime = a.data()['createdAt'] as Timestamp?;
              final bTime = b.data()['createdAt'] as Timestamp?;
              return (bTime?.millisecondsSinceEpoch ?? 0).compareTo(aTime?.millisecondsSinceEpoch ?? 0);
            });
          if (docs.isEmpty) return const _ProfilePlaceholder(icon: Icons.camera_alt_outlined, title: 'No posts yet', subtitle: 'Share photos with your community.');

          return GridView.builder(
            padding: const EdgeInsets.all(2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final post = PostModel.fromMap(docs[index].data(), docs[index].id);
              return InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _PostDetailScreen(post: post))),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (post.imageUrl.isNotEmpty)
                      Image.network(post.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _textPostTile(post.content))
                    else
                      _textPostTile(post.content),
                    if (post.likes.isNotEmpty)
                      Positioned(
                        right: 5,
                        bottom: 5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.favorite, color: Colors.white, size: 12),
                                const SizedBox(width: 3),
                                Text('${post.likes.length}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      );

  Widget _textPostTile(String text) => Container(
        color: AppColors.cardBg,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notes_rounded, color: AppColors.goldPrimary, size: 24),
            const SizedBox(height: 5),
            Text(text, maxLines: 4, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 10)),
          ],
        ),
      );
}

/// แสดงสถานะว่างหรือสถานะผิดพลาดของส่วน Grid โปรไฟล์.
class _ProfilePlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  const _ProfilePlaceholder({required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppColors.goldPrimary, size: 52),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              if (subtitle != null) ...[
                const SizedBox(height: 5),
                Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
              ],
            ],
          ),
        ),
      );
}

/// แสดงรายละเอียดโพสต์ที่เลือกจาก Grid พร้อมคอมเมนต์ที่เกี่ยวข้อง.
class _PostDetailScreen extends StatelessWidget {
  final PostModel post;

  const _PostDetailScreen({required this.post});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('POST', style: TextStyle(color: AppColors.goldPrimary, fontSize: 16)),
        ),
        body: ListView(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.cardBg,
                child: Text(post.displayName.isEmpty ? 'U' : post.displayName[0].toUpperCase(), style: const TextStyle(color: AppColors.goldPrimary)),
              ),
              title: Text(post.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text('@${post.username}', style: const TextStyle(color: AppColors.textMuted)),
            ),
            if (post.imageUrl.isNotEmpty) Image.network(post.imageUrl, fit: BoxFit.contain),
            if (post.content.isNotEmpty)
              Padding(padding: const EdgeInsets.all(16), child: Text(post.content, style: const TextStyle(color: Colors.white, height: 1.4))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('${post.likes.length} likes', style: const TextStyle(color: AppColors.goldPrimary, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('posts').doc(post.postId).collection('comments').orderBy('createdAt').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Padding(padding: EdgeInsets.all(16), child: Text('Could not load comments.', style: TextStyle(color: AppColors.textMuted)));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary));
                if (snapshot.data!.docs.isEmpty) return const Padding(padding: EdgeInsets.all(16), child: Text('No comments yet.', style: TextStyle(color: AppColors.textMuted)));
                return Column(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data();
                    return ListTile(
                      dense: true,
                      title: Text((data['displayName'] ?? 'User').toString(), style: const TextStyle(color: AppColors.goldPrimary, fontSize: 13)),
                      subtitle: Text((data['text'] ?? '').toString(), style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      );
}
