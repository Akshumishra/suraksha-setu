import 'dart:async';
import 'package:flutter/services.dart';
import 'package:volume_controller/volume_controller.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class SosTriggerService {
  static final SosTriggerService _instance = SosTriggerService._internal();
  factory SosTriggerService() => _instance;
  SosTriggerService._internal();

  int _volumePressCount = 0;
  Timer? _resetTimer;
  bool _initialized = false;

  Future<void> startListening() async {
    if (_initialized) return;
    _initialized = true;

    VolumeController().listener((volume) async {
      _onVolumeButtonPressed();
    });
  }

  void _onVolumeButtonPressed() {
    _volumePressCount++;
    _resetTimer?.cancel();

    _resetTimer = Timer(const Duration(seconds: 2), () {
      _volumePressCount = 0;
    });

    // Trigger SOS if both buttons pressed quickly (simulated by multiple volume presses)
    if (_volumePressCount >= 2) {
      _volumePressCount = 0;
      _triggerSOS();
    }
  }

  Future<void> _triggerSOS() async {
    try {
      const platform = MethodChannel('com.surakshasetu.sos');
      await platform.invokeMethod('triggerSOS');
    } catch (e) {
      print("Error triggering SOS: $e");
    }
  }
}
