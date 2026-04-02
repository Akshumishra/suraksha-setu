import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'sos_local_cache_service.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get currentUserId => _auth.currentUser?.uid;

  static Future<void> saveUserProfile({
    String? name,
    String? email,
    String? phone,
    String? gender,
    int? age,
    String? city,
    bool clearMissingOptionalFields = false,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently logged in');
      }

      final storedProfile = await _loadStoredProfile(user);
      final storedRole = _asString(storedProfile['role']);
      final resolvedName = _firstNonEmpty(
            name,
            user.displayName,
            _asString(storedProfile['name']),
          ) ??
          'Unknown User';
      final resolvedEmail = _normalizedEmail(
            _firstNonEmpty(email, user.email, _asString(storedProfile['email'])),
          ) ??
          '';
      final resolvedPhone = _firstNonEmpty(
            phone,
            user.phoneNumber,
            _asString(storedProfile['phone']),
          ) ??
          '';
      final resolvedGender = clearMissingOptionalFields
          ? _asString(gender)
          : _firstNonEmpty(gender, _asString(storedProfile['gender']));
      final resolvedCity = clearMissingOptionalFields
          ? _asString(city)
          : _firstNonEmpty(city, _asString(storedProfile['city']));
      final resolvedAge =
          clearMissingOptionalFields ? age : age ?? _asInt(storedProfile['age']);
      final resolvedPhotoUrl =
          _firstNonEmpty(user.photoURL, _asString(storedProfile['photoUrl'])) ??
              '';
      final resolvedRole = storedRole ?? 'user';

      final userData = <String, dynamic>{
        'uid': user.uid,
        'name': resolvedName,
        'email': resolvedEmail,
        'phone': resolvedPhone,
        'role': resolvedRole,
        'photoUrl': resolvedPhotoUrl,
        'lastLogin': FieldValue.serverTimestamp(),
      };

      if (clearMissingOptionalFields) {
        userData['gender'] = resolvedGender ?? FieldValue.delete();
        userData['age'] = resolvedAge ?? FieldValue.delete();
        userData['city'] = resolvedCity ?? FieldValue.delete();
      } else {
        if (resolvedGender != null) {
          userData['gender'] = resolvedGender;
        }
        if (resolvedAge != null) {
          userData['age'] = resolvedAge;
        }
        if (resolvedCity != null) {
          userData['city'] = resolvedCity;
        }
      }

      await _firestore.collection('users').doc(user.uid).set(
            userData,
            SetOptions(merge: true),
          );
      await _updateDisplayNameBestEffort(user, resolvedName);
      await SosLocalCacheService.instance.cacheUserProfile(
        userId: user.uid,
        name: resolvedName,
        phone: resolvedPhone,
        email: resolvedEmail,
        gender: resolvedGender,
        age: resolvedAge,
        city: resolvedCity,
        role: resolvedRole,
        photoUrl: resolvedPhotoUrl,
      );
    } catch (e) {
      debugPrint('Error saving user profile: $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }

    final storedProfile = await _loadStoredProfile(user);
    final resolvedProfile = <String, dynamic>{
      ...storedProfile,
      'uid':
          _firstNonEmpty(_asString(storedProfile['uid']), user.uid) ?? user.uid,
      'name': _firstNonEmpty(
            _asString(storedProfile['name']),
            user.displayName,
          ) ??
          '',
      'email': _normalizedEmail(
            _firstNonEmpty(_asString(storedProfile['email']), user.email),
          ) ??
          '',
      'phone': _firstNonEmpty(
            _asString(storedProfile['phone']),
            user.phoneNumber,
          ) ??
          '',
      'gender': _asString(storedProfile['gender']),
      'age': _asInt(storedProfile['age']),
      'city': _asString(storedProfile['city']),
      'role': _asString(storedProfile['role']) ?? 'user',
      'photoUrl': _firstNonEmpty(
            _asString(storedProfile['photoUrl']),
            user.photoURL,
          ) ??
          '',
    };
    await SosLocalCacheService.instance.cacheUserProfile(
      userId: user.uid,
      name: resolvedProfile['name'] as String,
      phone: resolvedProfile['phone'] as String,
      email: resolvedProfile['email'] as String,
      gender: resolvedProfile['gender'] as String?,
      age: resolvedProfile['age'] as int?,
      city: resolvedProfile['city'] as String?,
      role: resolvedProfile['role'] as String?,
      photoUrl: resolvedProfile['photoUrl'] as String?,
    );
    return resolvedProfile;
  }

  static Future<void> refreshLocalProfileCache() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }
    final profile = await getCurrentUserProfile();
    if (profile == null) {
      return;
    }
    await SosLocalCacheService.instance.cacheUserProfile(
      userId: user.uid,
      name: (profile['name'] as String?) ?? '',
      phone: (profile['phone'] as String?) ?? '',
      email: (profile['email'] as String?) ?? '',
      gender: profile['gender'] as String?,
      age: profile['age'] as int?,
      city: profile['city'] as String?,
      role: profile['role'] as String?,
      photoUrl: profile['photoUrl'] as String?,
    );
  }

  static Future<Map<String, dynamic>> _loadStoredProfile(User user) async {
    final remoteProfile = await getUserProfile(user.uid) ?? <String, dynamic>{};
    final cachedProfile = await SosLocalCacheService.instance.readUserProfile(
      userId: user.uid,
    );
    return <String, dynamic>{
      if (cachedProfile != null) ...cachedProfile.toProfileMap(),
      ...remoteProfile,
    };
  }

  static Future<void> _updateDisplayNameBestEffort(
    User user,
    String resolvedName,
  ) async {
    if (resolvedName.trim().isEmpty ||
        user.displayName?.trim() == resolvedName) {
      return;
    }
    try {
      await user.updateDisplayName(resolvedName);
    } catch (e) {
      debugPrint('Display name update failed while saving profile: $e');
    }
  }

  static String? _firstNonEmpty(String? first,
      [String? second, String? third]) {
    for (final value in <String?>[first, second, third]) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  static int? _asInt(dynamic value) {
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

  static String? _asString(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static String? _normalizedEmail(String? value) {
    final trimmed = _asString(value);
    return trimmed?.toLowerCase();
  }
}
