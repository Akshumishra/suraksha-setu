import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import 'permission_screen.dart';
import 'services/sos_background_task_handler.dart';
import 'services/sos_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (e, stackTrace) {
    debugPrint('Failed to activate Firebase App Check: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  try {
    await SosBackgroundTaskHandler.instance.initialize();
  } catch (e, stackTrace) {
    debugPrint('Failed to initialize SOS background task handler: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  // Start periodic offline evidence sync in background.
  unawaited(
    SosSyncService.instance.startAutoSync().catchError((error, stackTrace) {
      debugPrint('Failed to start SOS auto-sync: $error');
      debugPrintStack(stackTrace: stackTrace);
    }),
  );

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
