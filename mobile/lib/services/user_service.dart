import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class UserService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> saveUserProfile({
    String? name,
    String? email,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user is currently logged in');
      }

      final existingDoc = await _firestore.collection('users').doc(user.uid).get();
      final existingRole = existingDoc.data()?['role'] as String?;

      final userData = <String, dynamic>{
        'uid': user.uid,
        'name': name ?? user.displayName ?? 'Unknown User',
        'email': email ?? user.email ?? '',
        'phone': user.phoneNumber ?? '',
        'role': existingRole ?? 'user',
        'photoUrl': user.photoURL ?? '',
        'lastLogin': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(user.uid).set(
            userData,
            SetOptions(merge: true),
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
}
