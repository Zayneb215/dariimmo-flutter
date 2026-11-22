import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static const cloudName = 'qqs1qnzj';
  static const uploadPreset = 'dariimmo_unsigned';

  static Future<String> upload(XFile file) async {
    final uri =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = uploadPreset
      ..fields['folder'] = 'dariimmo/listings'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final res = await request.send().timeout(const Duration(seconds: 60));
    final body = await res.stream.bytesToString();
    if (res.statusCode != 200) {
      throw Exception('Upload photo échoué ($body)');
    }
    return (jsonDecode(body) as Map<String, dynamic>)['secure_url'] as String;
  }
}