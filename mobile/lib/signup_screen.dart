import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'permission_screen.dart';
import 'services/user_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const String _googleWebClientId =
      String.fromEnvironment(
        'GOOGLE_WEB_CLIENT_ID',
        defaultValue:
            '179434683012-pub4jlck9oljt5g9dr3iojtihcs8m8c8.apps.googleusercontent.com',
      );

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email'],
    serverClientId: _googleWebClientId,
  );

  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveProfileBestEffort({String? name, String? email}) async {
    try {
      await UserService.saveUserProfile(name: name, email: email);
    } catch (e, stackTrace) {
      debugPrint('Profile save failed after auth success: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _firebaseAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'operation-not-allowed':
        return 'Google Sign-In is not enabled in Firebase Authentication.';
      case 'account-exists-with-different-credential':
        return 'This email is linked to another sign-in method.';
      case 'invalid-credential':
        return 'Google Sign-In credentials are invalid. Check Firebase setup.';
      default:
        return e.message ?? 'Signup failed. Please try again.';
    }
  }

  String _googlePlatformMessage(PlatformException e) {
    final message = (e.message ?? '').toLowerCase();
    if (e.code == 'sign_in_failed' &&
        (message.contains('10') || message.contains('12500'))) {
      return 'Google Sign-In config error. Add the app SHA keys in Firebase and use the latest google-services.json.';
    }
    if (e.code == 'network_error') {
      return 'No internet connection. Please try again.';
    }
    return e.message ?? 'Google Sign-In failed. Please try again.';
  }

  Future<void> signupWithEmail() async {
    try {
      _safeSetState(() => isLoading = true);
      final name = nameController.text.trim();
      final email = emailController.text.trim();

      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: passwordController.text.trim(),
      );

      await _saveProfileBestEffort(name: name, email: email);

      await _goToNext();
    } on FirebaseAuthException catch (e) {
      _showSnackBar(_firebaseAuthMessage(e));
    } catch (e) {
      _showSnackBar('Signup failed: $e');
    } finally {
      _safeSetState(() => isLoading = false);
    }
  }
  
  Future<void> signupWithGoogle() async {
    try {
      _safeSetState(() => isLoading = true);
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _showSnackBar('Google Sign-In cancelled.');
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final hasIdToken =
          googleAuth.idToken != null && googleAuth.idToken!.isNotEmpty;
      final hasAccessToken =
          googleAuth.accessToken != null && googleAuth.accessToken!.isNotEmpty;
      if (!hasIdToken && !hasAccessToken) {
        throw FirebaseAuthException(
          code: 'invalid-credential',
          message: 'Google Sign-In returned no tokens.',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, 
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);

      await _saveProfileBestEffort(); 

      await _goToNext();
    } on FirebaseAuthException catch (e) {
      _showSnackBar(_firebaseAuthMessage(e));
    } on PlatformException catch (e) {
      _showSnackBar(_googlePlatformMessage(e));
    } catch (e) {
      _showSnackBar('Google signup failed: $e');
    } finally {
      _safeSetState(() => isLoading = false);
    }
  }

  Future<void> _goToNext() async {
    final prefs = await SharedPreferences.getInstance();
    final permissionsGranted = prefs.getBool('permissions_granted') ?? false;
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            permissionsGranted ? const HomePage() : const PermissionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account'), backgroundColor: Colors.red),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_add, size: 70, color: Colors.red),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password (min 6 characters)', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 30),
                isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15)),
                        onPressed: signupWithEmail,
                        child: const Text('Create Account', style: TextStyle(fontSize: 16)),
                      ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  icon: const Icon(Icons.login),
                  label: const Text('Sign up with Google'),
                  onPressed: signupWithGoogle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
