/// SIGMA888: อัปโหลดรูปภาพแบบ unsigned ไป Cloudinary และคืน URL ที่ใช้แสดงผล

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// CloudinaryService รวมการเรียกใช้บริการภายนอกและซ่อนรายละเอียดการเชื่อมต่อไว้จากหน้าจอ.
class CloudinaryService {
  // ชื่อ Cloudinary Cloud ที่รับไฟล์อัปโหลดของแอป
  static const _cloudName = 'dn2ukurwr';
  // Preset สำหรับอัปโหลดแบบ unsigned ที่ตั้งค่าไว้ใน Cloudinary
  static const _uploadPreset = 'sigma888_preset';

  /// อัปโหลดไบต์รูปภาพไป Cloudinary และคืน URL แบบ HTTPS สำหรับบันทึกใน Firestore.
  /// หากอัปโหลดหรืออ่าน URL ไม่สำเร็จ เมธอดจะโยน Exception ให้หน้าจอจัดการ.
  static Future<String> uploadImage(
    Uint8List imageBytes, {
    required String filenamePrefix,
  }) async {
    // สร้าง endpoint สำหรับอัปโหลดรูปภาพของ Cloudinary cloud นี้
    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload',
    );
    // ใช้ multipart request เพื่อส่งทั้ง preset และไฟล์ไบนารี
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = _uploadPreset
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: '${filenamePrefix}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ));

    // ส่งไฟล์และแปลง streamed response ให้สามารถอ่าน body ได้
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    // สถานะที่ไม่ใช่ 2xx ถือว่าล้มเหลว ให้หน้าจอจัดการแสดงข้อความได้
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Cloudinary upload failed (${response.statusCode}).');
    }
    // แปลง JSON และตรวจว่ามี secure_url ที่เป็นสตริงก่อนส่งกลับ
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final secureUrl = data['secure_url'];
    if (secureUrl is! String || secureUrl.isEmpty) {
      throw const FormatException('Cloudinary response has no secure_url.');
    }
    return secureUrl;
  }
}
