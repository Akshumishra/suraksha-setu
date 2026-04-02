import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../screens/admin_approval_screen.dart';
import '../screens/admin_sos_analysis_screen.dart';
import '../screens/station_registration_screen.dart';
import '../services/police_auth_service.dart';
import '../widgets/suraksha_setu_brand_logo.dart';

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

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            backgroundColor: const Color(0xFFF3F5F8),
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              title: Row(
                children: [
                  const SurakshaSetuBrandLogo(width: 54, compact: true),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Admin Response Console'),
                      Text(
                        'Review registrations, stations, and SOS intelligence',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              bottom: const TabBar(
                tabs: [
                  Tab(text: 'SOS Analysis'),
                  Tab(text: 'Requests'),
                  Tab(text: 'Stations'),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: FilledButton.tonalIcon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.home,
                        (route) => false,
                      );
                    },
                  ),
                ),
              ],
            ),
            body: const TabBarView(
              children: [
                AdminSosAnalysisScreen(),
                AdminApprovalScreen(),
                StationRegistrationScreen(),
              ],
            ),
          ),
        );
      },
    );
  }
}
