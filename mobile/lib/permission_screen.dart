import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'home_page.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key, this.onPermissionsGranted});

  final VoidCallback? onPermissionsGranted;

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _platform = MethodChannel('com.surakshasetu.sos');
  static const String _permissionsGrantedKey = 'permissions_granted';

  bool _permissionsGranted = false;
  bool _isRequesting = false;
  bool _gpsEnabled = false;
  bool _accessibilityEnabled = false;
  bool _ignoringBatteryOptimizations = true;

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  List<Permission> get _requiredPermissions => <Permission>[
        Permission.camera,
        Permission.microphone,
        Permission.location,
        Permission.sms,
        Permission.phone,
        if (_isAndroid) Permission.notification,
      ];

  bool get _allGranted =>
      _permissionsGranted && _gpsEnabled && _accessibilityEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadInitialStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshCurrentStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadInitialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadyCompleted = prefs.getBool(_permissionsGrantedKey) ?? false;

    await _refreshCurrentStatus();

    if (!mounted) return;
    if (alreadyCompleted) {
      // Permission setup is one-time. Do not force re-consent on transient checks.
      widget.onPermissionsGranted?.call();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
      return;
    }

    if (_allGranted) {
      if (!alreadyCompleted) {
        await prefs.setBool(_permissionsGrantedKey, true);
      }
      _continue();
      return;
    }

    await _requestAll();
  }

  Future<void> _refreshCurrentStatus() async {
    final runtimeStatuses = await Future.wait(
      _requiredPermissions.map((permission) => permission.status),
    );
    final runtimeGranted = runtimeStatuses.every((status) => status.isGranted);
    final gpsOn = await Geolocator.isLocationServiceEnabled();
    final accessibilityEnabled = await _checkAccessibilityEnabled();
    final ignoringBatteryOptimizations = await _checkBatteryOptimizationStatus();

    if (!mounted) return;
    setState(() {
      _permissionsGranted = runtimeGranted;
      _gpsEnabled = gpsOn;
      _accessibilityEnabled = accessibilityEnabled;
      _ignoringBatteryOptimizations = ignoringBatteryOptimizations;
    });
  }

  Future<bool> _checkAccessibilityEnabled() async {
    try {
      final enabled = await _platform.invokeMethod<bool>(
        'isVolumeSosAccessibilityEnabled',
      );
      return enabled ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await _platform.invokeMethod('openAccessibilitySettings');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open Accessibility settings: $e')),
      );
    }
  }

  Future<bool> _checkBatteryOptimizationStatus() async {
    if (!_isAndroid) {
      return true;
    }
    try {
      final enabled = await _platform.invokeMethod<bool>(
        'isIgnoringBatteryOptimizations',
      );
      return enabled ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openBatteryOptimizationSettings() async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _platform.invokeMethod('openBatteryOptimizationSettings');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open battery settings: $e')),
      );
    }
  }

  Future<void> _openSystemGestureSettings() async {
    if (!_isAndroid) {
      return;
    }
    try {
      await _platform.invokeMethod('openSystemGestureSettings');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open gesture settings: $e')),
      );
    }
  }

  Future<void> _requestAll() async {
    setState(() => _isRequesting = true);

    final statuses = await _requiredPermissions.request();
    final runtimeGranted = statuses.values.every((status) => status.isGranted);
    final gpsOn = await Geolocator.isLocationServiceEnabled();
    final accessibilityEnabled = await _checkAccessibilityEnabled();
    final ignoringBatteryOptimizations = await _checkBatteryOptimizationStatus();

    if (!mounted) return;
    setState(() {
      _permissionsGranted = runtimeGranted;
      _gpsEnabled = gpsOn;
      _accessibilityEnabled = accessibilityEnabled;
      _ignoringBatteryOptimizations = ignoringBatteryOptimizations;
      _isRequesting = false;
    });

    final prefs = await SharedPreferences.getInstance();
    if (_allGranted) {
      await prefs.setBool(_permissionsGrantedKey, true);
    }

    if (!gpsOn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable GPS to continue')),
      );
    }

    if (!accessibilityEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enable Suraksha Setu in Accessibility settings for volume key SOS.',
          ),
        ),
      );
    }
  }

  void _continue() {
    if (!_allGranted) {
      final message = !_accessibilityEnabled
          ? 'Enable Accessibility service for volume SOS first.'
          : 'Please grant all permissions first.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    widget.onPermissionsGranted?.call();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.security, size: 100, color: Colors.blueAccent),
                    const SizedBox(height: 20),
                    const Text(
                      'Permissions Required',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Grant permissions once to enable SOS in the background.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _accessibilityEnabled
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _accessibilityEnabled
                              ? Colors.green.shade300
                              : Colors.orange.shade300,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                _accessibilityEnabled
                                    ? Icons.check_circle
                                    : Icons.warning_amber_rounded,
                                color: _accessibilityEnabled
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _accessibilityEnabled
                                      ? 'Volume SOS accessibility service is enabled.'
                                      : 'Volume SOS requires Accessibility service.',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _openAccessibilitySettings,
                            icon: const Icon(Icons.accessibility_new),
                            label: const Text('Open Accessibility Settings'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.blue.shade200,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.flashlight_on, color: Colors.blue),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'If your phone turns on flashlight with Volume Up + Down, disable that system gesture so SOS can use the combo.',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _openSystemGestureSettings,
                            icon: const Icon(Icons.tune),
                            label: const Text('Open Gesture Settings'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _ignoringBatteryOptimizations
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _ignoringBatteryOptimizations
                              ? Colors.green.shade300
                              : Colors.orange.shade300,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                _ignoringBatteryOptimizations
                                    ? Icons.check_circle
                                    : Icons.battery_alert_rounded,
                                color: _ignoringBatteryOptimizations
                                    ? Colors.green
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _ignoringBatteryOptimizations
                                      ? 'Battery optimization is already disabled for Suraksha Setu.'
                                      : 'For reliable SOS in locked/background mode, disable battery optimization.',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _openBatteryOptimizationSettings,
                            icon: const Icon(Icons.battery_saver),
                            label: const Text('Open Battery Settings'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_isRequesting)
                      const CircularProgressIndicator()
                    else
                      ElevatedButton.icon(
                        onPressed: _requestAll,
                        icon: const Icon(Icons.settings),
                        label: const Text('Grant Permissions'),
                      ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _allGranted ? _continue : null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(_allGranted ? 'Continue' : 'Awaiting Permissions'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _allGranted ? Colors.green : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
