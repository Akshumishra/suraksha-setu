import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class FirebaseStorageUploadException implements Exception {
  FirebaseStorageUploadException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() =>
      'FirebaseStorageUploadException(code: $code, message: $message)';
}

class FirebaseStorageService {
  FirebaseStorageService._();

  static final FirebaseStorageService instance = FirebaseStorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _folder = 'sos_media';

  /// Uploads a media file to Firebase Storage under the authenticated user's
  /// folder. Returns the Storage path (not a public URL).
  /// Path format: sos_media/{userId}/{timestamp}_{filename}
  Future<String> uploadMedia({required File file}) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseStorageUploadException(
        'You must be logged in to upload media.',
        code: 'unauthenticated',
      );
    }

    if (!await file.exists()) {
      throw FirebaseStorageUploadException(
        'Media file does not exist: ${file.path}',
        code: 'file-not-found',
      );
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(file.path);
    final baseName = path
        .basenameWithoutExtension(file.path)
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final fileName = '${timestamp}_$baseName$extension';
    final storagePath = '$_folder/${user.uid}/$fileName';

    final ref = _storage.ref(storagePath);

    try {
      final metadata = SettableMetadata(
        contentType: _mimeTypeForExtension(extension),
        customMetadata: {
          'uploadedBy': user.uid,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );
      await ref.putFile(file, metadata);
      // Return path, not URL — access is controlled via Cloud Function.
      return storagePath;
    } on FirebaseException catch (e) {
      throw FirebaseStorageUploadException(
        e.message ?? 'Firebase Storage upload failed.',
        code: e.code,
      );
    }
  }

  /// Returns a download URL for a storage path. Only call this for the
  /// current authenticated user's own media. For police/admin, use the
  /// Cloud Function to get a short-lived signed URL.
  Future<String> getDownloadUrl(String storagePath) async {
    try {
      return await _storage.ref(storagePath).getDownloadURL();
    } on FirebaseException catch (e) {
      throw FirebaseStorageUploadException(
        e.message ?? 'Could not retrieve media URL.',
        code: e.code,
      );
    }
  }

  String _mimeTypeForExtension(String ext) {
    switch (ext.toLowerCase()) {
      case '.mp4':
        return 'video/mp4';
      case '.mov':
        return 'video/quicktime';
      case '.avi':
        return 'video/x-msvideo';
      case '.m4v':
        return 'video/x-m4v';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.mp3':
        return 'audio/mpeg';
      case '.aac':
        return 'audio/aac';
      default:
        return 'application/octet-stream';
    }
  }
}
