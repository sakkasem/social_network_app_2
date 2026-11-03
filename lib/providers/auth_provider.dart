/// SIGMA888: จัดการสถานะผู้ใช้ การสมัคร เข้าสู่ระบบ ออกจากระบบ และโหลดโปรไฟล์

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// Provider สถานะยืนยันตัวตน: เก็บโปรไฟล์ปัจจุบันและประสาน Firebase Auth กับ Firestore.
class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> _syncUserDirectory(UserModel user) {
    return _firestore.collection('user_directory').doc(user.uid).set({
      'uid': user.uid,
      'username': user.username,
      'displayName': user.displayName,
      'photoUrl': user.photoUrl ?? '',
      'isPrivate': user.isPrivate,
    });
  }

  Future<void> _backfillOwnPostFields(UserModel user) async {
    final snapshot = await _firestore.collection('posts').where('uid', isEqualTo: user.uid).get();
    final legacyPosts = snapshot.docs.where((doc) => !doc.data().containsKey('visibility')).toList();
    for (var start = 0; start < legacyPosts.length; start += 450) {
      final batch = _firestore.batch();
      for (final doc in legacyPosts.skip(start).take(450)) {
        batch.update(doc.reference, {
          'visibility': user.isPrivate ? 'followers' : 'public',
        });
      }
      await batch.commit();
    }
  }

  /// สร้างบัญชี Firebase Auth และเอกสารโปรไฟล์ Firestore; คืน true เมื่อสำเร็จ.
  Future<bool> signUp({
    required String email,
    required String password,
    required String username,
    required String displayName,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // 1. สร้าง User ใน Firebase Authentication
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 2. สร้างข้อมูลโปรไฟล์เก็บไว้ใน Cloud Firestore (collection 'users')
      UserModel newUser = UserModel(
        uid: credential.user!.uid,
        email: email,
        username: username,
        displayName: displayName,
      );

      await _firestore.collection('users').doc(newUser.uid).set(newUser.toMap());
      await _syncUserDirectory(newUser);
      _currentUser = newUser;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Sign Up Error: $e');
      return false;
    }
  }

  /// เข้าสู่ระบบด้วยอีเมล/รหัสผ่านและโหลดโปรไฟล์ Firestore; คืน false เมื่อผิดพลาด.
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ดึงข้อมูลโปรไฟล์จาก Firestore มาเก็บไว้
      DocumentSnapshot doc = await _firestore.collection('users').doc(credential.user!.uid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        await _syncUserDirectory(_currentUser!);
        await _backfillOwnPostFields(_currentUser!);
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Sign In Error: $e');
      return false;
    }
  }

  /// ออกจาก Firebase Auth ล้างผู้ใช้ปัจจุบัน และแจ้งผู้ฟังให้วาดหน้าจอใหม่.
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }
  
  /// โหลดเอกสารผู้ใช้ที่ล็อกอินอยู่ซ้ำและแจ้งผู้ฟังเมื่อข้อมูลโปรไฟล์เปลี่ยน.
  Future<void> reloadUserData() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return;
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(firebaseUser!.uid).get();
      if (doc.exists) {
        _currentUser = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
        await _syncUserDirectory(_currentUser!);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error reloading user data: $e');
    }
  }
  
}
