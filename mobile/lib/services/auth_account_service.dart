import 'package:firebase_auth/firebase_auth.dart';

class AuthAccountService {
  AuthAccountService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static bool requiresEmailVerification(User? user) {
    if (user == null) {
      return false;
    }
    final hasPasswordProvider = user.providerData.any(
      (provider) => provider.providerId == EmailAuthProvider.PROVIDER_ID,
    );
    final hasEmail = (user.email ?? '').trim().isNotEmpty;
    return hasEmail && hasPasswordProvider && !user.emailVerified;
  }

  static Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw const FormatException('Enter your email first.');
    }
    await _auth.sendPasswordResetEmail(email: normalizedEmail);
  }

  static Future<void> sendEmailVerification({
    User? user,
  }) async {
    final targetUser = user ?? _auth.currentUser;
    if (targetUser == null) {
      throw StateError('No authenticated user is available for verification.');
    }
    await targetUser.sendEmailVerification();
  }

  static Future<bool> reloadAndCheckVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      return false;
    }
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }
}
