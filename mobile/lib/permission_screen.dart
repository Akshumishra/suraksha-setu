import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart'; // adjust path

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _allGranted = false;
  bool _isRequesting = false;
  bool _gpsEnabled = false;

  Future<void> _requestAll() async {
    setState(() => _isRequesting = true);

    // request permissions
    final statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.location,
      Permission.sms,
      Permission.phone,
      Permission.storage,
    ].request();

    // location service status
    final gpsOn = await Geolocator.isLocationServiceEnabled();

    final allGranted = statuses.values.every((status) => status.isGranted);

    setState(() {
      _gpsEnabled = gpsOn;
      _allGranted = allGranted && gpsOn;
      _isRequesting = false;
    });

    if (!gpsOn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enable GPS to continue')),
      );
    }

    if (_allGranted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('permissions_granted', true);
    }
  }

  void _continue() {
    if (_allGranted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please grant all permissions first')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _requestAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
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
                  'Please grant all permissions to allow SOS to work properly.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),
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
        ),
      ),
    );
  }
}
