import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page.dart';
import 'permission_screen.dart';
import 'screens/email_verification_screen.dart';
import 'services/auth_account_service.dart';
import 'services/user_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  static const String _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '179434683012-pub4jlck9oljt5g9dr3iojtihcs8m8c8.apps.googleusercontent.com',
  );
  static const List<String> _genderOptions = <String>[
    'Female',
    'Male',
    'Non-binary',
    'Prefer not to say',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: const ['email'],
    serverClientId: _googleWebClientId,
  );
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController mobileController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String? _selectedGender;
  bool _requireEmailPassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    cityController.dispose();
    mobileController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveProfileBestEffort({
    String? name,
    String? email,
    String? phone,
    String? gender,
    int? age,
    String? city,
  }) async {
    try {
      await UserService.saveUserProfile(
        name: name,
        email: email,
        phone: phone,
        gender: gender,
        age: age,
        city: city,
      );
    } catch (e, stackTrace) {
      debugPrint('Profile save failed after auth success: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _updateDisplayNameBestEffort(String name) async {
    if (name.trim().isEmpty) return;
    try {
      await _auth.currentUser?.updateDisplayName(name.trim());
    } catch (e, stackTrace) {
      debugPrint('Display name update failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
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

  bool _validateForm({required bool requireEmailPassword}) {
    FocusScope.of(context).unfocus();
    _requireEmailPassword = requireEmailPassword;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      _showSnackBar('Please complete the highlighted fields.');
    }
    return isValid;
  }

  int _parsedAge() => int.parse(ageController.text.trim());

  String _trimmedOrEmpty(TextEditingController controller) {
    return controller.text.trim();
  }

  Future<void> signupWithEmail() async {
    if (!_validateForm(requireEmailPassword: true)) {
      return;
    }

    try {
      _safeSetState(() => isLoading = true);
      final name = _trimmedOrEmpty(nameController);
      final email = _trimmedOrEmpty(emailController);
      final city = _trimmedOrEmpty(cityController);
      final phone = _trimmedOrEmpty(mobileController);
      final age = _parsedAge();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: passwordController.text.trim(),
      );

      await _updateDisplayNameBestEffort(name);
      await _saveProfileBestEffort(
        name: name,
        email: email,
        phone: phone,
        gender: _selectedGender,
        age: age,
        city: city,
      );
      await AuthAccountService.sendEmailVerification(user: credential.user);
      _showSnackBar('Verification email sent. Check your inbox.');

      await _goToEmailVerification();
    } on FirebaseAuthException catch (e) {
      _showSnackBar(_firebaseAuthMessage(e));
    } catch (e) {
      _showSnackBar('Signup failed: $e');
    } finally {
      _safeSetState(() => isLoading = false);
    }
  }

  Future<void> signupWithGoogle() async {
    if (!_validateForm(requireEmailPassword: false)) {
      return;
    }

    try {
      _safeSetState(() => isLoading = true);
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        _showSnackBar('Google Sign-In cancelled.');
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
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

      final name = _trimmedOrEmpty(nameController);
      final city = _trimmedOrEmpty(cityController);
      final phone = _trimmedOrEmpty(mobileController);
      final age = _parsedAge();

      await _updateDisplayNameBestEffort(name);
      await _saveProfileBestEffort(
        name: name,
        phone: phone,
        gender: _selectedGender,
        age: age,
        city: city,
      );

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

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  String? _requiredTextValidator(String? value, String fieldLabel) {
    if ((value ?? '').trim().isEmpty) {
      return 'Enter your $fieldLabel';
    }
    return null;
  }

  String? _genderValidator(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Select your gender';
    }
    return null;
  }

  String? _ageValidator(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Enter your age';
    }
    final age = int.tryParse(trimmed);
    if (age == null || age < 1 || age > 120) {
      return 'Enter a valid age';
    }
    return null;
  }

  String? _mobileValidator(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Enter your mobile number';
    }
    if (trimmed.length < 10 || trimmed.length > 15) {
      return 'Use 10 to 15 digits';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    if (!_requireEmailPassword) {
      return null;
    }
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Enter your email';
    }
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(trimmed)) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    if (!_requireEmailPassword) {
      return null;
    }
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Enter a password';
    }
    if (trimmed.length < 6) {
      return 'Minimum 6 characters';
    }
    return null;
  }

  Widget _sectionTitle(BuildContext context, String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildGenderAndAgeFields() {
    final genderField = DropdownButtonFormField<String>(
      initialValue: _selectedGender,
      isExpanded: true,
      decoration: _inputDecoration(
        label: 'Gender',
        icon: Icons.wc_outlined,
      ),
      items: _genderOptions
          .map(
            (gender) => DropdownMenuItem<String>(
              value: gender,
              child: Text(
                gender,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: isLoading
          ? null
          : (value) {
              setState(() {
                _selectedGender = value;
              });
            },
      validator: _genderValidator,
    );

    final ageField = TextFormField(
      controller: ageController,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      decoration: _inputDecoration(
        label: 'Age',
        icon: Icons.cake_outlined,
        hint: '18',
      ),
      validator: _ageValidator,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackFields = constraints.maxWidth < 360;
        if (stackFields) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              genderField,
              const SizedBox(height: 14),
              ageField,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: genderField),
            const SizedBox(width: 12),
            Expanded(child: ageField),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.primaryContainer.withValues(alpha: 0.9),
                colorScheme.surface,
                colorScheme.secondaryContainer.withValues(alpha: 0.35),
              ],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    colorScheme.primary.withValues(alpha: 0.22),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.person_add_alt_1_rounded,
                            size: 40,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Set up your safety profile',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your personal details so emergency contacts and responders can identify you quickly.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Card(
                        elevation: 1.5,
                        shadowColor: Colors.black12,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _sectionTitle(
                                  context,
                                  'Personal details',
                                  'These help complete the user profile in the app.',
                                ),
                                const SizedBox(height: 18),
                                TextFormField(
                                  controller: nameController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: _inputDecoration(
                                    label: 'Full Name',
                                    icon: Icons.badge_outlined,
                                    hint: 'Enter your full name',
                                  ),
                                  textInputAction: TextInputAction.next,
                                  validator: (value) => _requiredTextValidator(
                                      value, 'full name'),
                                ),
                                const SizedBox(height: 14),
                                _buildGenderAndAgeFields(),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: cityController,
                                  textCapitalization: TextCapitalization.words,
                                  decoration: _inputDecoration(
                                    label: 'City',
                                    icon: Icons.location_city_outlined,
                                    hint: 'Enter your city',
                                  ),
                                  textInputAction: TextInputAction.next,
                                  validator: (value) =>
                                      _requiredTextValidator(value, 'city'),
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: mobileController,
                                  keyboardType: TextInputType.phone,
                                  textInputAction: TextInputAction.next,
                                  inputFormatters: <TextInputFormatter>[
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(15),
                                  ],
                                  decoration: _inputDecoration(
                                    label: 'Mobile Number',
                                    icon: Icons.phone_android_outlined,
                                    hint: '10 to 15 digits',
                                  ),
                                  validator: _mobileValidator,
                                ),
                                const SizedBox(height: 24),
                                _sectionTitle(
                                  context,
                                  'Account details',
                                  'Email and password are only required for email signup.',
                                ),
                                const SizedBox(height: 18),
                                TextFormField(
                                  controller: emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: _inputDecoration(
                                    label: 'Email',
                                    icon: Icons.alternate_email_rounded,
                                    hint: 'name@example.com',
                                  ),
                                  validator: _emailValidator,
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: passwordController,
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  decoration: _inputDecoration(
                                    label: 'Password',
                                    icon: Icons.lock_outline_rounded,
                                    hint: 'Minimum 6 characters',
                                  ),
                                  validator: _passwordValidator,
                                ),
                                const SizedBox(height: 24),
                                if (isLoading)
                                  const Center(
                                      child: CircularProgressIndicator())
                                else ...[
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                    onPressed: signupWithEmail,
                                    child: const Text('Create Account'),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                    onPressed: signupWithGoogle,
                                    icon: const Icon(Icons.login_rounded),
                                    label: const Text('Sign up with Google'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
