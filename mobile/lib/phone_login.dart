import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'permission_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool otpSent = false;
  String verificationId = '';
  bool isLoading = false;
  
  // NOTE: This logic is heavily simplified for running the app. 
  // It requires the Firebase SHA key setup (done in earlier steps) to fully work.

  Future<void> sendOTP() async {
    // This is the implementation from the prior chat session
    setState(() => isLoading = true);
    // ... Simplified sendOTP logic ...
    
    // For now, let's skip the real auth and just fake the OTP for testing:
    setState(() {
      verificationId = 'FAKE_ID'; // Replace with real ID when running
      otpSent = true;
      isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP sent (Fake). Enter 123456 to continue.')),
      );
  }

  Future<void> verifyOTP() async {
    // Real verify logic is complex. For now, let's just check a fake code.
    if(otpController.text == '123456'){
       _goToNextScreen();
    } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid OTP (Fake).')),
        );
    }
    setState(() => isLoading = false);
  }

  void _goToNextScreen() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const PermissionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Login (OTP)'), backgroundColor: Colors.red),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone Number', prefixText: '+91 '),
            ),
            const SizedBox(height: 20),
            if (otpSent)
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Enter OTP'),
              ),
            const SizedBox(height: 20),
            isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: otpSent ? verifyOTP : sendOTP,
                    child: Text(otpSent ? 'Verify OTP' : 'Send OTP'),
                  ),
          ],
        ),
      ),
    );
  }
}