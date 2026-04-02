import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/emergency_contact.dart';

class CachedUserProfile {
  const CachedUserProfile({
    required this.userId,
    this.name,
    this.phone,
    this.email,
    this.gender,
    this.age,
    this.city,
    this.role,
    this.photoUrl,
  });

  final String userId;
  final String? name;
  final String? phone;
  final String? email;
  final String? gender;
  final int? age;
  final String? city;
  final String? role;
  final String? photoUrl;

  Map<String, dynamic> toProfileMap() {
    return <String, dynamic>{
      'uid': userId,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (gender != null) 'gender': gender,
      if (age != null) 'age': age,
      if (city != null) 'city': city,
      if (role != null) 'role': role,
      if (photoUrl != null) 'photoUrl': photoUrl,
    };
  }
}

class SosLocalCacheService {
  SosLocalCacheService._();

  static final SosLocalCacheService instance = SosLocalCacheService._();

  static const String emergencyContactsCacheFileName =
      'emergency_contacts_cache.json';
  static const String userProfileCacheFileName = 'user_profile_cache.json';

  Future<File> _fileFor(String fileName) async {
    final supportDir = await getApplicationSupportDirectory();
    final file = File('${supportDir.path}${Platform.pathSeparator}$fileName');
    await file.parent.create(recursive: true);
    return file;
  }

  Future<void> cacheEmergencyContacts({
    required String userId,
    required Iterable<EmergencyContact> contacts,
  }) async {
    final file = await _fileFor(emergencyContactsCacheFileName);
    final payload = <String, dynamic>{
      'userId': userId,
      'updatedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
      'contacts': contacts
          .map(
            (contact) => <String, dynamic>{
              'id': contact.id,
              'name': contact.name.trim(),
              'phone': contact.phone.trim(),
              'relation': contact.relation.trim(),
              'contactUserId': contact.contactUserId?.trim(),
              'contactEmail': contact.contactEmail?.trim().toLowerCase(),
            },
          )
          .toList(growable: false),
    };
    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  Future<void> cacheUserProfile({
    required String userId,
    required String name,
    required String phone,
    required String email,
    String? gender,
    int? age,
    String? city,
    String? role,
    String? photoUrl,
  }) async {
    final file = await _fileFor(userProfileCacheFileName);
    final payload = <String, dynamic>{
      'userId': userId,
      'updatedAtEpochMs': DateTime.now().millisecondsSinceEpoch,
      'name': name.trim(),
      'phone': phone.trim(),
      'email': email.trim().toLowerCase(),
      'gender': _trimToNull(gender),
      'age': age,
      'city': _trimToNull(city),
      'role': _trimToNull(role),
      'photoUrl': _trimToNull(photoUrl),
    };
    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  Future<CachedUserProfile?> readUserProfile({
    required String userId,
  }) async {
    final file = await _fileFor(userProfileCacheFileName);
    if (!await file.exists()) {
      return null;
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final cachedUserId = _trimToNull(decoded['userId']);
    if (cachedUserId == null || cachedUserId != userId.trim()) {
      return null;
    }

    return CachedUserProfile(
      userId: cachedUserId,
      name: _trimToNull(decoded['name']),
      phone: _trimToNull(decoded['phone']),
      email: _trimToNull(decoded['email'])?.toLowerCase(),
      gender: _trimToNull(decoded['gender']),
      age: _readInt(decoded['age']),
      city: _trimToNull(decoded['city']),
      role: _trimToNull(decoded['role']),
      photoUrl: _trimToNull(decoded['photoUrl']),
    );
  }

  String? _trimToNull(dynamic value) {
    if (value is! String) {
      return null;
    }
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }
}
