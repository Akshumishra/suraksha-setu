import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import all required screens for routing
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'permission_screen.dart';

// =======================================================
// THE MAIN FUNCTION (ENTRY POINT) - Fixes "No 'main' method found" error
// =======================================================
void main() async {
  // Required for Flutter to initialize bindings before calling native code (like Firebase)
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase connection
  await Firebase.initializeApp();
  
  runApp(const SurakshaSetu());
}

// =======================================================
// MAIN APP WIDGET
// =======================================================
class SurakshaSetu extends StatelessWidget {
  const SurakshaSetu({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Suraksha Setu',
      theme: ThemeData(
        primarySwatch: Colors.red,
        // Using Material 3 color scheme for modern look
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      // The app starts with RootDecider to check login/onboarding status
      home: const RootDecider(),
    );
  }
}

// =======================================================
// ROUTING LOGIC (DECIDES FIRST SCREEN)
// =======================================================
class RootDecider extends StatefulWidget {
  const RootDecider({super.key});

  @override
  State<RootDecider> createState() => _RootDeciderState();
}

class _RootDeciderState extends State<RootDecider> {
  // Null means we are still loading/checking status
  bool? onboardingDone;
  User? user; 

  @override
  void initState() {
    super.initState();
    _checkInitialRoute();
  }

  Future<void> _checkInitialRoute() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Check if onboarding was completed (default: false)
    onboardingDone = prefs.getBool('onboardingDone') ?? false;
    
    // 2. Check if a user is currently logged in via Firebase Auth
    user = FirebaseAuth.instance.currentUser;
    
    // Rebuild the widget based on the new states
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading spinner while checking SharedPreferences
    if (onboardingDone == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // --- DECISION TREE ---
    if (!onboardingDone!) {
      // 1. Onboarding not done -> Show Onboarding Screen (first time launch)
      return const OnboardingScreen();
    } else if (user == null) {
      // 2. Onboarding done, but no user is logged in -> Show Login Screen
      return const LoginScreen();
    } else {
      // 3. Onboarding done AND user is logged in -> Go straight to Permissions
      return const PermissionScreen();
    }
  }
}
