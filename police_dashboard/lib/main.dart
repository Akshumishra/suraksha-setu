import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth/admin_login.dart';
import 'auth/admin_panel.dart';
import 'auth/police_login.dart';
import 'firebase_options.dart';
import 'screens/police_dashboard_screen.dart';
import 'screens/police_registration_screen.dart';
import 'services/police_auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PoliceDashboardApp());
}

class PoliceDashboardApp extends StatelessWidget {
  const PoliceDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Suraksha Setu Police Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      routes: {
        '/policeLogin': (_) => const PoliceLogin(),
        '/policeRegister': (_) => const PoliceRegistrationScreen(),
        '/adminLogin': (_) => const AdminLogin(),
        '/admin': (_) => const AdminPanel(),
      },
      home: const _PoliceAuthGate(),
    );
  }
}

class _PoliceAuthGate extends StatelessWidget {
  const _PoliceAuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: PoliceAuthService.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (user == null) {
          return const PoliceLogin();
        }

        return FutureBuilder(
          future: PoliceAuthService.instance.getCurrentPoliceSession(),
          builder: (context, sessionSnapshot) {
            if (sessionSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final session = sessionSnapshot.data;
            if (session == null) {
              PoliceAuthService.instance.signOut();
              return const PoliceLogin();
            }
            return PoliceDashboardScreen(session: session);
          },
        );
      },
    );
  }
}
