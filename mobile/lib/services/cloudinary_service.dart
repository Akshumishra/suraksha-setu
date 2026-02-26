import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class CloudinaryUploadException implements Exception {
  CloudinaryUploadException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'CloudinaryUploadException(statusCode: $statusCode, message: $message)';
}

class CloudinaryService {
  // Cloudinary configuration for unsigned upload.
  static const String _cloudName = 'dkryeldxv';
  static const String _uploadPreset = 'Suraksha_Media';
  static const String _uploadUrl =
      'https://api.cloudinary.com/v1_1/$_cloudName/auto/upload';
  static const String _folder = 'sos_media';

  static Future<String> uploadMedia({
    required File file,
  }) async {
    // Validate the local file before network upload.
    if (!await file.exists()) {
      throw CloudinaryUploadException(
        'Media file does not exist: ${file.path}',
      );
    }

    // Generate a unique public ID using current timestamp.
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final baseName = path
        .basenameWithoutExtension(file.path)
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final extension = path.extension(file.path);
    final publicId = 'sos_${timestamp}_$baseName';

    final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl))
      ..fields['upload_preset'] = _uploadPreset
      ..fields['folder'] = _folder
      ..fields['public_id'] = publicId
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path,
          filename: '$publicId$extension',
        ),
      );

    try {
      // Perform multipart upload and parse response JSON.
      final response = await request.send().timeout(
            const Duration(seconds: 45),
          );
      final responseBody = await response.stream.bytesToString();
      final decoded = responseBody.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(responseBody) as Map<String, dynamic>;

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final serverMessage =
            (decoded['error'] as Map<String, dynamic>?)?['message']?.toString();
        throw CloudinaryUploadException(
          serverMessage ?? 'Cloudinary upload failed.',
          statusCode: response.statusCode,
        );
      }

      // Extract secure_url that will be stored in Firestore mediaUrl.
      final secureUrl = decoded['secure_url']?.toString();
      if (secureUrl == null || secureUrl.isEmpty) {
        throw CloudinaryUploadException(
          'Upload succeeded but secure_url was missing.',
          statusCode: response.statusCode,
        );
      }

      return secureUrl;
    } on TimeoutException {
      throw CloudinaryUploadException('Cloudinary upload timed out.');
    } on SocketException catch (e) {
      throw CloudinaryUploadException('Network error during upload: $e');
    } on FormatException catch (e) {
      throw CloudinaryUploadException('Invalid Cloudinary JSON response: $e');
    }
  }
}
