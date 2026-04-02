import 'package:flutter/material.dart';

import '../app_routes.dart';
import 'suraksha_setu_brand_logo.dart';

class PublicDashboardScaffold extends StatelessWidget {
  const PublicDashboardScaffold({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  final Widget child;
  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = screenWidth < 720 ? 20.0 : 32.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[
              Color(0xFFF4F7FB),
              Color(0xFFE8EEF7),
              Color(0xFFF8F2EA),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -120,
              right: -80,
              child: _GlowOrb(
                size: 260,
                color: Color(0xFFBFD1EA),
              ),
            ),
            const Positioned(
              bottom: -120,
              left: -80,
              child: _GlowOrb(
                size: 300,
                color: Color(0xFFD8E6D4),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontalPadding,
                    24,
                    horizontalPadding,
                    32,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PublicNavigationBar(currentRoute: currentRoute),
                        const SizedBox(height: 28),
                        child,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _PublicNavigationBar extends StatelessWidget {
  const _PublicNavigationBar({required this.currentRoute});

  final String currentRoute;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 920;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 30,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _BrandLockup(),
                const SizedBox(height: 16),
                _NavigationActions(currentRoute: currentRoute),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(child: _BrandLockup()),
                const SizedBox(width: 20),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _NavigationActions(currentRoute: currentRoute),
                  ),
                ),
              ],
            ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SurakshaSetuBrandLogo(width: 78, compact: true),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suraksha Setu',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF102A43),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Police response dashboard',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF486581),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavigationActions extends StatelessWidget {
  const _NavigationActions({required this.currentRoute});

  final String currentRoute;

  void _openRoute(BuildContext context, String routeName) {
    if (routeName == currentRoute) {
      return;
    }
    Navigator.of(context).pushNamed(routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 10,
      runSpacing: 10,
      children: [
        _RouteChip(
          label: 'Login',
          routeName: AppRoutes.policeLogin,
          currentRoute: currentRoute,
          onTap: () => _openRoute(context, AppRoutes.policeLogin),
        ),
        _RouteChip(
          label: 'About',
          routeName: AppRoutes.about,
          currentRoute: currentRoute,
          onTap: () => _openRoute(context, AppRoutes.about),
        ),
        _RouteChip(
          label: 'How to Use',
          routeName: AppRoutes.howToUse,
          currentRoute: currentRoute,
          onTap: () => _openRoute(context, AppRoutes.howToUse),
        ),
        OutlinedButton.icon(
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.policeRegister),
          icon: const Icon(Icons.app_registration_outlined),
          label: const Text('Request Access'),
        ),
        TextButton.icon(
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.adminLogin),
          icon: const Icon(Icons.admin_panel_settings_outlined),
          label: const Text('Admin Login'),
        ),
      ],
    );
  }
}

class _RouteChip extends StatelessWidget {
  const _RouteChip({
    required this.label,
    required this.routeName,
    required this.currentRoute,
    required this.onTap,
  });

  final String label;
  final String routeName;
  final String currentRoute;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isActive = routeName == currentRoute;

    if (isActive) {
      return FilledButton.tonal(
        onPressed: null,
        child: Text(label),
      );
    }

    return OutlinedButton(
      onPressed: onTap,
      child: Text(label),
    );
  }
}
