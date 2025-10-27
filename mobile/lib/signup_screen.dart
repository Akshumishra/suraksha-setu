import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'permission_screen.dart';
import 'services/user_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(); // FIX 1: Correct instantiation

  bool isLoading = false;

  // Helper to safely call setState across async gaps
  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  Future<void> signupWithEmail() async {
    try {
      _safeSetState(() => isLoading = true);
      
      final userCred = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Save name and email to Firestore user profile
      await UserService.saveUserProfile(
        name: nameController.text,
        email: emailController.text,
      );

      _goToNext();
    } catch (e) {
      if (mounted) { // FIX 2: use_build_context_synchronously check
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Signup failed: $e')),
        );
      }
    } finally {
      _safeSetState(() => isLoading = false);
    }
  }
  
  Future<void> signupWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, 
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);

      // Save profile after successful Google sign-in
      await UserService.saveUserProfile(); 

      _goToNext();
    } catch (e) {
      if (mounted) { // FIX 2: use_build_context_synchronously check
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google signup failed: $e')),
        );
      }
    }
  }

  void _goToNext() {
    // Navigates to the Permission Screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PermissionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account'), backgroundColor: Colors.red),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
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
    );
  }
}