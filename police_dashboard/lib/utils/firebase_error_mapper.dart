import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class FirebaseErrorMapper {
  const FirebaseErrorMapper._();

  static String toMessage(
    Object error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is FirebaseAuthException) {
      return _authMessage(error);
    }
    if (error is FirebaseFunctionsException) {
      return _functionsMessage(error);
    }
    if (error is FirebaseException) {
      return _firebaseMessage(error);
    }
    if (error is StateError) {
      return error.message;
    }
    return fallback;
  }

  static String _authMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account exists for this email.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect email or password.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is disabled in Firebase Auth.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Authentication failed. Please try again.';
    }
  }

  static String _functionsMessage(FirebaseFunctionsException error) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Please log in to continue.';
      case 'permission-denied':
        return 'You do not have permission to perform this action.';
      case 'invalid-argument':
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Some input fields are invalid.';
      case 'not-found':
        return 'Requested record was not found.';
      case 'already-exists':
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'This record already exists.';
      case 'failed-precondition':
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Request cannot be completed in the current state.';
      case 'internal':
        return 'Server error. Verify the Firebase Cloud Functions are deployed and try again.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Server is unavailable. Please try again in a moment.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Request failed on the server.';
    }
  }

  static String _firebaseMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthorized':
        return 'Permission denied by Firebase rules.';
      case 'unauthenticated':
        return 'Authentication is required to continue.';
      case 'network-request-failed':
      case 'unavailable':
        return 'Network error. Check your internet connection.';
      default:
        return error.message?.trim().isNotEmpty == true
            ? error.message!.trim()
            : 'Firebase request failed. Please try again.';
    }
  }
}
