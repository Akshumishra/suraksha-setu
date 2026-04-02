import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../widgets/public_dashboard_scaffold.dart';

class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PublicDashboardScaffold(
      currentRoute: AppRoutes.howToUse,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _PageHero(),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final stepWidth = constraints.maxWidth >= 960
                  ? (constraints.maxWidth - 24) / 2
                  : double.infinity;

              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  SizedBox(
                    width: stepWidth,
                    child: const _StepCard(
                      step: '1',
                      title: 'Request police access',
                      description:
                          'Use the Request Access form with official officer, station, and contact details so the admin team can verify your profile.',
                      icon: Icons.app_registration_outlined,
                    ),
                  ),
                  SizedBox(
                    width: stepWidth,
                    child: const _StepCard(
                      step: '2',
                      title: 'Wait for admin approval',
                      description:
                          'An admin must approve the account before the dashboard will allow police sign-in. If approval is pending, the account will be denied access.',
                      icon: Icons.verified_outlined,
                    ),
                  ),
                  SizedBox(
                    width: stepWidth,
                    child: const _StepCard(
                      step: '3',
                      title: 'Log in with your approved email',
                      description:
                          'Use the same approved email and password on the login page. If you forget the password, use the reset link to receive a recovery email.',
                      icon: Icons.login_outlined,
                    ),
                  ),
                  SizedBox(
                    width: stepWidth,
                    child: const _StepCard(
                      step: '4',
                      title: 'Review the live response queue',
                      description:
                          'After login, open the priority queue to see active SOS cases first, station-level metrics, and the latest assigned incident activity.',
                      icon: Icons.emergency_outlined,
                    ),
                  ),
                  SizedBox(
                    width: stepWidth,
                    child: const _StepCard(
                      step: '5',
                      title: 'Open a case and act on it',
                      description:
                          'Inside the case detail view, review victim information, location updates, maps links, evidence references, and move the case from active to accepted or resolved.',
                      icon: Icons.assignment_turned_in_outlined,
                    ),
                  ),
                  SizedBox(
                    width: stepWidth,
                    child: const _StepCard(
                      step: '6',
                      title: 'Add a report when closing a case',
                      description:
                          'When marking a case resolved, include the resolution report so the dashboard keeps a useful closure record for follow-up and analysis.',
                      icon: Icons.edit_note_outlined,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          const _TipsPanel(),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.policeLogin),
                icon: const Icon(Icons.login),
                label: const Text('Back to Login'),
              ),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.about),
                icon: const Icon(Icons.info_outline),
                label: const Text('About the Dashboard'),
              ),
              TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.policeRegister),
                icon: const Icon(Icons.app_registration_outlined),
                label: const Text('Request Access'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PageHero extends StatelessWidget {
  const _PageHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 32,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE3EDF7),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Operator guide',
              style: TextStyle(
                color: Color(0xFF103A63),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'How to use the police dashboard',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF102A43),
                ),
          ),
          const SizedBox(height: 14),
          Text(
            'This quick guide walks officers from onboarding through daily SOS handling so the dashboard stays easy to use during urgent response work.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF486581),
                  height: 1.5,
                ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String step;
  final String title;
  final String description;
  final IconData icon;

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
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF103A63),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  step,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6EEF7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF103A63)),
              ),
            ],
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

class _TipsPanel extends StatelessWidget {
  const _TipsPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFEF6E8), Color(0xFFF9E4C6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Helpful tips',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF7C4A03),
                ),
          ),
          const SizedBox(height: 14),
          const _TipLine(
            icon: Icons.alternate_email_outlined,
            text:
                'Sign in with the same approved email address used during onboarding.',
          ),
          const SizedBox(height: 10),
          const _TipLine(
            icon: Icons.refresh_outlined,
            text:
                'Use the live location refresh tools inside case details when coordinates need an updated fetch.',
          ),
          const SizedBox(height: 10),
          const _TipLine(
            icon: Icons.description_outlined,
            text:
                'Resolution reports are required when closing a case, so keep outcome notes concise and factual.',
          ),
          const SizedBox(height: 10),
          const _TipLine(
            icon: Icons.support_agent_outlined,
            text:
                'If access is denied after sign-in, contact the admin approval team to verify role approval and station assignment.',
          ),
        ],
      ),
    );
  }
}

class _TipLine extends StatelessWidget {
  const _TipLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF7C4A03), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF7C4A03),
                  height: 1.55,
                ),
          ),
        ),
      ],
    );
  }
}
