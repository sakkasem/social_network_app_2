/// SIGMA888: แทนข้อมูลบัญชีผู้ใช้ที่แอปใช้หลังเข้าสู่ระบบ

/// โมเดลบัญชีผู้ใช้ที่แอปใช้แสดงโปรไฟล์และระบุตัวตน.
class UserModel {
  final String uid;
  final String email;
  final String username;
  final String displayName;
  final String? photoUrl;
  final String bio;
  final bool isPrivate;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.displayName,
    this.photoUrl,
    this.bio = '',
    this.isPrivate = false,
  });

  /// แปลงข้อมูลจากเอกสาร Firestore เป็น UserModel โดยใช้ document id เป็น uid.
  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      uid: docId,
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'],
      bio: map['bio'] ?? '',
      isPrivate: map['isPrivate'] == true,
    );
  }

  /// แปลง UserModel เป็น Map สำหรับบันทึกใน Firestore.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'isPrivate': isPrivate,
    };
  }
}
