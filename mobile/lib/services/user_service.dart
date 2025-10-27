import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A centralized helper service to manage user data in Firestore.
/// This ensures that every time someone signs in or signs up,
/// their user info (name, email, etc.) is saved or updated properly.
class UserService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Saves or updates a user’s profile in Firestore.
  ///
  /// - If [name] or [email] is not provided, they will be fetched from the
  ///   currently logged-in Firebase user object.
  /// - The user is identified by their `uid` from Firebase Auth.
  static Future<void> saveUserProfile({
    String? name,
    String? email,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception("No user is currently logged in");

      // Prepare user data map
      final userData = {
        'uid': user.uid,
        'name': name ?? user.displayName ?? 'Unknown User',
        'email': email ?? user.email ?? '',
        'photoUrl': user.photoURL ?? '',
        'lastLogin': FieldValue.serverTimestamp(),
      };

      // Store or update document in "users" collection
      await _firestore.collection('users').doc(user.uid).set(
            userData,
            SetOptions(merge: true),
          );
    } catch (e) {
      print("🔥 Error saving user profile: $e");
      rethrow;
    }
  }

  /// Fetch user profile data by UID.
  static Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      print("⚠️ Error fetching user profile: $e");
      return null;
    }
  }
}
