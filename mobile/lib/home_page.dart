import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart'; // REQUIRED: For getting the User ID

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance; // Reference to Firebase Auth

  Future<void> sendSOS() async {
    // 1. Check if user is logged in
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Error: User not logged in. Please log in first.')),
      );
      return;
    }

    try {
      setState(() => isLoading = true);

      // 2. Request and check location permission
      LocationPermission permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied. Cannot send SOS.')),
        );
        setState(() => isLoading = false);
        return;
      }

      // 3. Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 4. Create Firestore document with the actual UID
      await FirebaseFirestore.instance.collection('incidents').add({
        'userId': user.uid, // 🔥 LINKING THE SOS TO THE LOGGED-IN USER
        'timestamp': DateTime.now().toIso8601String(),
        'lat': position.latitude,
        'lon': position.longitude,
        'status': 'active',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🚨 SOS sent successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending SOS: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suraksha Setu')),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 60, vertical: 25),
                  textStyle: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
                onPressed: sendSOS,
                child: const Text('🚨 SOS'),
              ),
      ),
    );
  }
}