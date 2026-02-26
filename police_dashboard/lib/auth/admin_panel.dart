import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/admin_approval_screen.dart';
import '../services/police_auth_service.dart';

class AdminPanel extends StatelessWidget {
  const AdminPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: PoliceAuthService.instance.isCurrentUserAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('Admin Access')),
            body: const Center(
              child: Text('Access denied. Please login with an admin account.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Admin - Police Onboarding'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/policeLogin',
                    (_) => false,
                  );
                },
              ),
            ],
          ),
          body: const AdminApprovalScreen(),
        );
      },
    );
  }
}
