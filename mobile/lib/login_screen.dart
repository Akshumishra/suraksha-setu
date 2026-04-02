import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'screens/email_verification_screen.dart';
import 'signup_screen.dart';
import 'permission_screen.dart';
import 'services/auth_account_service.dart';
import 'services/user_service.dart';
import 'widgets/suraksha_setu_brand_logo.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '179434683012-pub4jlck9oljt5g9dr3iojtihcs8m8c8.apps.googleusercontent.com',
  );

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email'],
    serverClientId: _googleWebClientId,
  );
  bool isLoading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _goToEmailVerification() async {
    if (!mounted) {
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const EmailVerificationScreen()),
    );
  }

  Future<void> _saveProfileBestEffort({String? email}) async {
    try {
      await UserService.saveUserProfile(email: email);
    } catch (e, stackTrace) {
      debugPrint('Profile save failed after auth success: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  String _firebaseAuthMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'user-disabled':
        return 'This account is disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'operation-not-allowed':
        return 'Google Sign-In is not enabled in Firebase Authentication.';
      case 'account-exists-with-different-credential':
        return 'This email is linked to another sign-in method.';
      default:
        return e.message ?? 'Authentication failed. Please try again.';
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

  Future<void> _goToNextScreen() async {
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

  Future<void> signInWithEmail() async {
    setState(() => isLoading = true);
    try {
      final email = emailController.text.trim();
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: passwordController.text.trim(),
      );
      await _saveProfileBestEffort(email: email);
      if (AuthAccountService.requiresEmailVerification(credential.user)) {
        try {
          await AuthAccountService.sendEmailVerification(user: credential.user);
        } catch (_) {
          // The verification screen still lets the user resend if needed.
        }
        _showSnackBar('Verify your email before continuing.');
        await _goToEmailVerification();
        return;
      }
      await _goToNextScreen();
    } on FirebaseAuthException catch (e) {
      _showSnackBar(_firebaseAuthMessage(e));
    } catch (_) {
      _showSnackBar('Login failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final controller = TextEditingController(text: emailController.text.trim());
    final formKey = GlobalKey<FormState>();

    final shouldSend = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Forgot Password'),
            content: Form(
              key: formKey,
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Account email',
                  hintText: 'name@example.com',
                ),
                validator: (value) {
                  final trimmed = (value ?? '').trim();
                  if (trimmed.isEmpty) {
                    return 'Enter your email';
                  }
                  final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                  if (!emailPattern.hasMatch(trimmed)) {
                    return 'Enter a valid email';
                  }
                  return null;
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (!(formKey.currentState?.validate() ?? false)) {
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('Send reset link'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldSend) {
      controller.dispose();
      return;
    }

    try {
      await AuthAccountService.sendPasswordResetEmail(email: controller.text);
      _showSnackBar('Password reset email sent.');
    } on FirebaseAuthException catch (error) {
      _showSnackBar(error.message ?? 'Could not send password reset email.');
    } catch (error) {
      _showSnackBar('Could not send password reset email: $error');
    } finally {
      controller.dispose();
    }
  }

  Future<void> signInWithGoogle() async {
    setState(() => isLoading = true);
    try {
      await _googleSignIn.signOut();
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _showSnackBar('Google Sign-In cancelled.');
        return;
      }

      final googleAuth = await googleUser.authentication;
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
      await _goToNextScreen();
    } on FirebaseAuthException catch (e) {
      _showSnackBar(_firebaseAuthMessage(e));
    } on PlatformException catch (e) {
      _showSnackBar(_googlePlatformMessage(e));
    } catch (e) {
      _showSnackBar('Google Sign-In failed: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        backgroundColor: Colors.red,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SurakshaSetuBrandLogo(width: 220),
                const SizedBox(height: 20),
                const Text(
                  'Rapid Response & Safety Alerts',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isLoading ? null : _showForgotPasswordDialog,
                    child: const Text('Forgot password?'),
                  ),
                ),
                const SizedBox(height: 20),
                isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          minimumSize: const Size.fromHeight(50),
                        ),
                        onPressed: signInWithEmail,
                        child: const Text('Login'),
                      ),
                const SizedBox(height: 20),
                const Text('OR'),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  onPressed: signInWithGoogle,
                  child: const Text('Login with Google'),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    );
                  },
                  child: const Text("Don't have an account? Sign Up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
