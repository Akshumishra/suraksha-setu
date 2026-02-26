import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'config/sos_config.dart';
import 'login_screen.dart';
import 'screens/sos_alerts_screen.dart';
import 'screens/emergency_contacts_screen.dart';
import 'screens/sos_history_screen.dart';
import 'services/sos_repository.dart';
import 'services/sos_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _tabIndex = 0;
  bool _triggeringSos = false;

  static const _tabs = <Widget>[
    _SosActionPanel(),
    SosAlertsScreen(),
    EmergencyContactsScreen(),
    SosHistoryScreen(),
  ];

  static const _titles = <String>[
    'SOS',
    'Alerts',
    'Emergency Contacts',
    'SOS History',
  ];

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_tabIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: _tabs.map((screen) {
          if (screen is _SosActionPanel) {
            return _SosActionPanel(
              onTriggerStart: () => setState(() => _triggeringSos = true),
              onTriggerDone: () => setState(() => _triggeringSos = false),
            );
          }
          return screen;
        }).toList(growable: false),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: [
          NavigationDestination(
            icon: _triggeringSos
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sos),
            label: 'SOS',
          ),
          const NavigationDestination(
            icon: Icon(Icons.notifications_active_outlined),
            label: 'Alerts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.contact_phone_outlined),
            label: 'Contacts',
          ),
          const NavigationDestination(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }
}

class _SosActionPanel extends StatefulWidget {
  const _SosActionPanel({
    this.onTriggerStart,
    this.onTriggerDone,
  });

  final VoidCallback? onTriggerStart;
  final VoidCallback? onTriggerDone;

  @override
  State<_SosActionPanel> createState() => _SosActionPanelState();
}

class _SosActionPanelState extends State<_SosActionPanel> {
  bool _busy = false;

  Future<void> _triggerSos() async {
    try {
      setState(() => _busy = true);
      widget.onTriggerStart?.call();
      await SosService.triggerSos();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'SOS triggered. You can cancel within 30 seconds if not accepted.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to trigger SOS: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      widget.onTriggerDone?.call();
    }
  }

  Future<void> _cancelLatest() async {
    try {
      await SosRepository.instance.cancelLatestActiveSos();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Latest active SOS cancelled.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel SOS: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(58),
              ),
              onPressed: _busy ? null : _triggerSos,
              icon: const Icon(Icons.warning_amber_rounded),
              label: Text(_busy ? 'Triggering SOS...' : 'Trigger SOS'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _cancelLatest,
              icon: const Icon(Icons.cancel_outlined),
              label: Text(
                'Cancel Latest SOS (${SosConfig.cancelWindow.inSeconds}s window)',
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Police dashboard receives updates in real time when status changes.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
