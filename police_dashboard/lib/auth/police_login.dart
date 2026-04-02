import 'package:flutter/material.dart';

import '../app_routes.dart';
import '../services/police_auth_service.dart';
import '../utils/firebase_error_mapper.dart';
import '../widgets/public_dashboard_scaffold.dart';
import '../widgets/suraksha_setu_brand_logo.dart';

class PoliceLogin extends StatefulWidget {
  const PoliceLogin({super.key});

  @override
  State<PoliceLogin> createState() => _PoliceLoginState();
}

class _PoliceLoginState extends State<PoliceLogin> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  String _error = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error.isEmpty) {
      return;
    }
    setState(() => _error = '');
  }

  Future<void> _loginPolice() async {
    FocusScope.of(context).unfocus();

    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter both email and password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await PoliceAuthService.instance.signInPolice(
        email: email,
        password: password,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.home,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = FirebaseErrorMapper.toMessage(
          e,
          fallback: 'Police login failed. Please try again.',
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final controller = TextEditingController(text: _emailCtrl.text.trim());
    var dialogError = '';
    var sendingReset = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogBuilderContext, setDialogState) {
            Future<void> sendReset() async {
              final email = controller.text.trim();
              if (email.isEmpty) {
                setDialogState(() {
                  dialogError = 'Enter your approved email address.';
                });
                return;
              }

              setDialogState(() {
                dialogError = '';
                sendingReset = true;
              });

              try {
                final navigator = Navigator.of(dialogContext);
                final messenger = ScaffoldMessenger.of(context);
                await PoliceAuthService.instance.sendPasswordResetEmail(
                  email: email,
                );
                if (!mounted) {
                  return;
                }
                _emailCtrl.text = email;
                navigator.pop();
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text(
                        'Password reset email sent to $email.',
                      ),
                    ),
                  );
              } catch (e) {
                setDialogState(() {
                  dialogError = FirebaseErrorMapper.toMessage(
                    e,
                    fallback: 'Could not send a reset email right now.',
                  );
                  sendingReset = false;
                });
              }
            }

            return AlertDialog(
              title: const Text('Forgot password'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter the approved email on your police account. We will send you a password reset link.',
                      style: Theme.of(dialogBuilderContext)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                            color: const Color(0xFF486581),
                            height: 1.5,
                          ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      enabled: !sendingReset,
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Official email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      onSubmitted: (_) => sendReset(),
                    ),
                    if (dialogError.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogError,
                        style: const TextStyle(
                          color: Color(0xFFB42318),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sendingReset
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: sendingReset ? null : sendReset,
                  child: sendingReset
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send reset link'),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PublicDashboardScaffold(
      currentRoute: AppRoutes.policeLogin,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 980;

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _HeroPanel(onHowToUse: _openHowToUsePage)),
                const SizedBox(width: 24),
                SizedBox(
                  width: 430,
                  child: _LoginCard(
                    emailController: _emailCtrl,
                    passwordController: _passCtrl,
                    loading: _loading,
                    obscurePassword: _obscurePassword,
                    error: _error,
                    onEmailChanged: _clearError,
                    onPasswordChanged: _clearError,
                    onForgotPassword: _showForgotPasswordDialog,
                    onLogin: _loginPolice,
                    onTogglePasswordVisibility: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroPanel(onHowToUse: _openHowToUsePage),
              const SizedBox(height: 24),
              _LoginCard(
                emailController: _emailCtrl,
                passwordController: _passCtrl,
                loading: _loading,
                obscurePassword: _obscurePassword,
                error: _error,
                onEmailChanged: _clearError,
                onPasswordChanged: _clearError,
                onForgotPassword: _showForgotPasswordDialog,
                onLogin: _loginPolice,
                onTogglePasswordVisibility: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _openHowToUsePage() {
    Navigator.of(context).pushNamed(AppRoutes.howToUse);
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({required this.onHowToUse});

  final VoidCallback onHowToUse;

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
              'Secure station access',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 22),
          const SurakshaSetuBrandLogo(width: 220),
          const SizedBox(height: 22),
          Text(
            'Respond faster with a clearer police dashboard.',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Track live SOS alerts, open detailed case records, refresh locations, and move incidents through the response workflow from one station-linked workspace.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 26),
          const Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              SizedBox(
                width: 180,
                child: _HeroMetric(
                  icon: Icons.notifications_active_outlined,
                  title: 'Priority queue',
                  subtitle: 'Live SOS cases surface first',
                ),
              ),
              SizedBox(
                width: 180,
                child: _HeroMetric(
                  icon: Icons.map_outlined,
                  title: 'Case tools',
                  subtitle: 'Maps, evidence, status updates',
                ),
              ),
              SizedBox(
                width: 180,
                child: _HeroMetric(
                  icon: Icons.verified_user_outlined,
                  title: 'Approved access',
                  subtitle: 'Police role and station aware',
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick start',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                const _HeroBullet(
                  icon: Icons.app_registration_outlined,
                  text:
                      'Request police access using official officer and station details.',
                ),
                const SizedBox(height: 10),
                const _HeroBullet(
                  icon: Icons.verified_outlined,
                  text:
                      'Wait for admin approval before signing in to the dashboard.',
                ),
                const SizedBox(height: 10),
                const _HeroBullet(
                  icon: Icons.dynamic_feed_outlined,
                  text:
                      'Review assigned incidents, open case details, and update response status.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.tonalIcon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(AppRoutes.about),
                icon: const Icon(Icons.info_outline),
                label: const Text('About the Dashboard'),
              ),
              OutlinedButton.icon(
                onPressed: onHowToUse,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('How to Use This'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.obscurePassword,
    required this.error,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onForgotPassword,
    required this.onLogin,
    required this.onTogglePasswordVisibility,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final bool obscurePassword;
  final String error;
  final VoidCallback onEmailChanged;
  final VoidCallback onPasswordChanged;
  final VoidCallback onForgotPassword;
  final VoidCallback onLogin;
  final VoidCallback onTogglePasswordVisibility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4EEF7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF103A63),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Police Login',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in with your approved email to access the station dashboard.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF486581),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AutofillGroup(
            child: Column(
              children: [
                TextField(
                  controller: emailController,
                  enabled: !loading,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Official email',
                    hintText: 'officer@department.gov',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  onChanged: (_) => onEmailChanged(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  enabled: !loading,
                  obscureText: obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: loading ? null : onTogglePasswordVisibility,
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  onChanged: (_) => onPasswordChanged(),
                  onSubmitted: (_) {
                    if (!loading) {
                      onLogin();
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: loading ? null : onForgotPassword,
              child: const Text('Forgot password?'),
            ),
          ),
          if (error.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEECEC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF3B3B3)),
              ),
              child: Text(
                error,
                style: const TextStyle(
                  color: Color(0xFFB42318),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: loading ? null : onLogin,
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Login to Dashboard'),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: loading
                    ? null
                    : () => Navigator.of(context).pushNamed(
                          AppRoutes.policeRegister,
                        ),
                icon: const Icon(Icons.app_registration_outlined),
                label: const Text('Request police access'),
              ),
              TextButton.icon(
                onPressed: loading
                    ? null
                    : () => Navigator.of(context).pushNamed(
                          AppRoutes.adminLogin,
                        ),
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Admin approval login'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FB),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.mark_email_read_outlined,
                  color: Color(0xFF1F5E89),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Password recovery links are sent to the approved email connected to your police account.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF486581),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(height: 14),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

class _HeroBullet extends StatelessWidget {
  const _HeroBullet({
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
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                  height: 1.5,
                ),
          ),
        ),
      ],
    );
  }
}
