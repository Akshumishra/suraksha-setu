import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home_page.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _checking = false;

  Future<void> _requestPermissions() async {
    setState(() => _checking = true);
    
    // Request all required permissions together
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.camera,
      Permission.microphone,
    ].request();

    bool allGranted = statuses.values.every((s) => s.isGranted);

    if (allGranted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomePage()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please grant all permissions to continue.')),
      );
    }
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    // This is a simplified UI from earlier steps
    return Scaffold(
      appBar: AppBar(title: const Text('Permissions Required')),
      body: Center(
        child: _checking
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: _requestPermissions,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red, padding: const EdgeInsets.all(20)),
                child: const Text('Allow Permissions'),
              ),
      ),
    );
  }
}