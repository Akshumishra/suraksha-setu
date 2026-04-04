import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'permission_screen.dart';
import 'screens/email_verification_screen.dart';
import 'services/auth_account_service.dart';
import 'services/sos_background_task_handler.dart';
import 'services/emergency_contact_service.dart';
import 'services/sos_alert_notification_service.dart';
import 'services/sos_sync_service.dart';
import 'services/user_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load secrets from .env before initializing anything else.
  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp();

  try {
    await SosBackgroundTaskHandler.instance.initialize();
  } catch (e, stackTrace) {
    debugPrint('Failed to initialize SOS background task handler: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  try {
    await SosAlertNotificationService.instance.initialize();
  } catch (e, stackTrace) {
    debugPrint('Failed to initialize SOS alert notifications: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  // Start periodic offline evidence sync in background.
  unawaited(
    SosSyncService.instance.startAutoSync().catchError((error, stackTrace) {
      debugPrint('Failed to start SOS auto-sync: $error');
      debugPrintStack(stackTrace: stackTrace);
    }),
  );

  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user == null) {
      unawaited(
        SosAlertNotificationService.instance.stop().catchError((error, stackTrace) {
          debugPrint('Failed to stop SOS alert notifications: $error');
          debugPrintStack(stackTrace: stackTrace);
        }),
      );
      return;
    }
    unawaited(
      EmergencyContactService.instance.refreshLocalCache().catchError((
        error,
        stackTrace,
      ) {
        debugPrint('Failed to warm emergency contact cache: $error');
        debugPrintStack(stackTrace: stackTrace);
      }),
    );
    unawaited(
      UserService.refreshLocalProfileCache().catchError((error, stackTrace) {
        debugPrint('Failed to warm user profile cache: $error');
        debugPrintStack(stackTrace: stackTrace);
      }),
    );
    unawaited(
      SosAlertNotificationService.instance.startForCurrentUser().catchError((
        error,
        stackTrace,
      ) {
        debugPrint('Failed to start SOS alert notifications: $error');
        debugPrintStack(stackTrace: stackTrace);
      }),
    );
  });

  runApp(const SurakshaSetu());
}

class SurakshaSetu extends StatelessWidget {
  const SurakshaSetu({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Suraksha Setu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const RootDecider(),
    );
  }
}

class RootDecider extends StatefulWidget {
  const RootDecider({super.key});

  @override
  State<RootDecider> createState() => _RootDeciderState();
}

class _RootDeciderState extends State<RootDecider> {
  bool? _onboardingDone;
  bool? _permissionsGranted;

  @override
  void initState() {
    super.initState();
    _loadStartupFlags();
  }

  Future<void> _loadStartupFlags() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingDone = prefs.getBool('onboardingDone') ?? false;
    _permissionsGranted = prefs.getBool('permissions_granted') ?? false;
    if (mounted) {
      setState(() {});
    }
  }

  void _onPermissionsGranted() {
    if (mounted) {
      setState(() => _permissionsGranted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingDone == null || _permissionsGranted == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        if (!_onboardingDone!) {
          return const OnboardingScreen();
        }
        if (user == null) {
          return const LoginScreen();
        }

        // Catch unverified users and redirect them to the auto-check screen
        if (AuthAccountService.requiresEmailVerification(user)) {
          return const EmailVerificationScreen();
        }

        // Phone OTP is now handled inside the signup flow.
        // Users reach HomePage only after complete registration.
        if (_permissionsGranted!) {
          return const HomePage();
        }
        return PermissionScreen(
          onPermissionsGranted: _onPermissionsGranted,
        );
      },
    );
  }
}
