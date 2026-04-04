import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../home_page.dart';
import '../login_screen.dart';
import '../permission_screen.dart';
import '../services/auth_account_service.dart';
import '../widgets/suraksha_setu_brand_logo.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _checking = false;
  bool _sending = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Start polling for verification status every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkVerification(silent: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _email => FirebaseAuth.instance.currentUser?.email?.trim() ?? '';

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _continueToApp() async {
    final prefs = await SharedPreferences.getInstance();
    final permissionsGranted = prefs.getBool('permissions_granted') ?? false;
    if (!mounted) {
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            permissionsGranted ? const HomePage() : const PermissionScreen(),
      ),
      (route) => false,
    );
  }

  Future<void> _checkVerification({bool silent = false}) async {
    if (!silent) setState(() => _checking = true);
    try {
      final verified = await AuthAccountService.reloadAndCheckVerification();
      if (verified) {
        _timer?.cancel();
        await _continueToApp();
      } else if (!silent) {
        _showSnackBar('Email is still not verified. Check your inbox first.');
      }
    } on FirebaseAuthException catch (error) {
      if (!silent) {
        _showSnackBar(error.message ?? 'Could not refresh status.');
      }
    } catch (error) {
      if (!silent) {
        _showSnackBar('Could not refresh status: $error');
      }
    } finally {
      if (mounted && !silent) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _sending = true);
    try {
      await AuthAccountService.sendEmailVerification();
      _showSnackBar('Verification email sent again.');
    } on FirebaseAuthException catch (error) {
      _showSnackBar(error.message ?? 'Could not resend verification email.');
    } catch (error) {
      _showSnackBar('Could not resend verification email: $error');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _signOutToLogin() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) {
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.primaryContainer.withValues(alpha: 0.85),
              colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(
                        child: SurakshaSetuBrandLogo(width: 130, compact: true),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Verify your email to finish signup',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _email.isEmpty
                            ? 'Open the verification email we sent and confirm your account.'
                            : 'We sent a verification email to $_email. Open it, verify your account, then come back here.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _checking ? null : _checkVerification,
                        icon: _checking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.verified_user_outlined),
                        label: Text(
                          _checking ? 'Checking...' : 'I verified my email',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _sending ? null : _resendVerificationEmail,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.mark_email_read_outlined),
                        label: Text(
                          _sending ? 'Sending...' : 'Resend email',
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _signOutToLogin,
                        child: const Text('Use another account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
