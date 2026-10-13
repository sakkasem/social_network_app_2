class UserModel {
  final String uid;
  final String email;
  final String username;
  final String displayName;
  final String? photoUrl;

  UserModel({
    required this.uid,
    required this.email,
    required this.username,
    required this.displayName,
    this.photoUrl,
  });

  // แปลงข้อมูลจาก Map (เช่น ดึงมาจาก Firestore/Database) เป็น UserModel
  factory UserModel.fromMap(Map<String, dynamic> map, String docId) {
    return UserModel(
      uid: docId,
      email: map['email'] ?? '',
      username: map['username'] ?? '',
      displayName: map['displayName'] ?? '',
      photoUrl: map['photoUrl'],
    );
  }

  // แปลงจาก UserModel เป็น Map สำหรับเตรียมเซฟลง Database
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'username': username,
      'displayName': displayName,
      'photoUrl': photoUrl,
    };
  }
}