import 'package:flutter/material.dart';
import '../services/sos_service.dart';

class SosTriggerButton extends StatelessWidget {
  const SosTriggerButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
      label: const Text(
        'SOS',
        style: TextStyle(fontSize: 20, color: Colors.white),
      ),
      onPressed: () async {
        await SosService.triggerSos();
        if (!context.mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SOS initiated! Recording...')),
        );
      },
    );
  }
}
