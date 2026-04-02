import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_routes.dart';
import 'auth/admin_login.dart';
import 'auth/admin_panel.dart';
import 'auth/police_login.dart';
import 'firebase_options.dart';
import 'screens/about_dashboard_screen.dart';
import 'screens/how_to_use_screen.dart';
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
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF103A63),
      brightness: Brightness.light,
    ).copyWith(
      primary: const Color(0xFF103A63),
      secondary: const Color(0xFF2A6F97),
      surface: Colors.white,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Suraksha Setu Police Dashboard',
      theme: ThemeData(
        colorScheme: colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.88),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFD8E1EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFD8E1EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(
              color: Color(0xFF2A6F97),
              width: 1.5,
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF103A63),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF103A63),
            side: const BorderSide(color: Color(0xFFB6C7D8)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1F5E89),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      initialRoute: AppRoutes.home,
      routes: {
        AppRoutes.home: (_) => const _PoliceAuthGate(),
        AppRoutes.policeLogin: (_) => const PoliceLogin(),
        AppRoutes.policeRegister: (_) => const PoliceRegistrationScreen(),
        AppRoutes.adminLogin: (_) => const AdminLogin(),
        AppRoutes.admin: (_) => const AdminPanel(),
        AppRoutes.about: (_) => const AboutDashboardScreen(),
        AppRoutes.howToUse: (_) => const HowToUseScreen(),
      },
    );
  }
}

class _PoliceAuthGate extends StatelessWidget {
  const _PoliceAuthGate();

  Future<_AuthDestination> _resolveDestination() async {
    final policeSession =
        await PoliceAuthService.instance.getCurrentPoliceSession();
    if (policeSession != null) {
      return _AuthDestination.police(policeSession);
    }

    final isAdmin = await PoliceAuthService.instance.isCurrentUserAdmin();
    if (isAdmin) {
      return const _AuthDestination.admin();
    }

    return const _AuthDestination.denied();
  }

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

        return FutureBuilder<_AuthDestination>(
          future: _resolveDestination(),
          builder: (context, destinationSnapshot) {
            if (destinationSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final destination = destinationSnapshot.data;
            if (destination is _PoliceDestination) {
              return PoliceDashboardScreen(session: destination.session);
            }
            if (destination is _AdminDestination) {
              return const AdminPanel();
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              PoliceAuthService.instance.signOut();
            });
            if (destinationSnapshot.hasError) {
              return const Scaffold(
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Login session could not be validated. Please sign in again.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            }
            if (destination is _DeniedDestination) {
              return const PoliceLogin();
            }

            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
        );
      },
    );
  }
}

sealed class _AuthDestination {
  const _AuthDestination();

  factory _AuthDestination.police(PoliceSession session) = _PoliceDestination;
  const factory _AuthDestination.admin() = _AdminDestination;
  const factory _AuthDestination.denied() = _DeniedDestination;
}

class _PoliceDestination extends _AuthDestination {
  const _PoliceDestination(this.session);

  final PoliceSession session;
}

class _AdminDestination extends _AuthDestination {
  const _AdminDestination();
}

class _DeniedDestination extends _AuthDestination {
  const _DeniedDestination();
}
