import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ฟังก์ชันสมัครสมาชิก (Register)
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

  // ฟังก์ชันเข้าสู่ระบบ (Sign In)
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

  // ฟังก์ชันออกจากระบบ
  Future<void> signOut() async {
    await _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }
}