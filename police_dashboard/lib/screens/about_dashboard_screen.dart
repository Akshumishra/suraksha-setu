import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../widgets/public_dashboard_scaffold.dart';

class AboutDashboardScreen extends StatelessWidget {
  const AboutDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicDashboardScaffold(
      currentRoute: AppRoutes.about,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cardWidth = constraints.maxWidth >= 1040
              ? (constraints.maxWidth - 24) / 2
              : double.infinity;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _HeroBanner(
                title: 'About the police dashboard',
                description:
                    'Suraksha Setu Police Dashboard gives approved police teams a secure way to monitor SOS activity, review victim and location details, and coordinate faster response from the assigned station.',
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: const _InfoCard(
                      icon: Icons.sensors_outlined,
                      title: 'Live incident visibility',
                      description:
                          'See priority SOS alerts first, review assigned cases, and keep the live response queue in one place.',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: const _InfoCard(
                      icon: Icons.pin_drop_outlined,
                      title: 'Location and evidence context',
                      description:
                          'Open each case to access live coordinates, Google Maps links, media references, and station assignment details.',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: const _InfoCard(
                      icon: Icons.verified_user_outlined,
                      title: 'Approved access only',
                      description:
                          'Only accounts approved for the police role can enter the dashboard, helping keep station data restricted to the right team.',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: const _InfoCard(
                      icon: Icons.fact_check_outlined,
                      title: 'Response progress tracking',
                      description:
                          'Officers can move incidents through the workflow, add closure reports when resolving a case, and preserve follow-up history.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF12344D),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Why it exists',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The dashboard is designed to reduce handoff delay between an SOS trigger and station action. It puts the most urgent alerts, response context, and case transitions in a single interface that officers can use quickly during active incidents.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.86),
                            height: 1.6,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.policeLogin),
                    icon: const Icon(Icons.login),
                    label: const Text('Go to Login'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.howToUse),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Read How to Use'),
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context)
                        .pushNamed(AppRoutes.policeRegister),
                    icon: const Icon(Icons.app_registration_outlined),
                    label: const Text('Request Police Access'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF103A63), Color(0xFF2A6F97)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0F172A),
            blurRadius: 40,
            offset: Offset(0, 22),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Mission overview',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE4EEF7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF103A63)),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF102A43),
                ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF486581),
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}
