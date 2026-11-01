/// SIGMA888: ค้นหาบัญชีผู้ใช้และเปิดหน้าโปรไฟล์

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '/core/theme/app_theme.dart';
import '/providers/auth_provider.dart';
import 'user_profile_screen.dart';

/// SearchUsersScreen เป็นหน้าจอของฟีเจอร์ที่ระบุด้วยชื่อคลาสนี้.
class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

/// _SearchUsersScreenState จัดการ state, lifecycle และการตอบสนองต่อเหตุการณ์ของหน้าจอที่เกี่ยวข้อง.
class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Provider.of<AuthProvider>(context).currentUser?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('FIND PEOPLE', style: TextStyle(color: AppColors.goldPrimary, fontSize: 16)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name or username...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.goldPrimary),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.clear, color: AppColors.textMuted),
                      ),
                filled: true,
                fillColor: AppColors.cardBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: TextButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh, color: AppColors.goldPrimary),
                      label: const Text('Could not load users. Retry', style: TextStyle(color: AppColors.goldPrimary)),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.goldPrimary));
                }

                final users = (snapshot.data?.docs ?? []).where((doc) {
                  if (doc.id == currentUserId) return false;
                  final data = doc.data();
                  if (_query.isEmpty) return true;
                  final displayName = (data['displayName'] ?? '').toString().toLowerCase();
                  final username = (data['username'] ?? '').toString().toLowerCase();
                  return displayName.contains(_query) || username.contains(_query);
                }).toList();

                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      _query.isEmpty ? 'No users found.' : 'No matching users.',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final doc = users[index];
                    final data = doc.data();
                    final name = (data['displayName'] ?? 'User').toString();
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.goldPrimary,
                        child: Text(name.isEmpty ? 'U' : name[0].toUpperCase(), style: const TextStyle(color: Colors.black)),
                      ),
                      title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text('@${data['username'] ?? ''}', style: const TextStyle(color: AppColors.textMuted)),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => UserProfileScreen(userId: doc.id)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
