
import 'package:flutter/services.dart';

class NativeSos {
  static const _channel = MethodChannel('com.surakshasetu.sos');

  static Future<void> triggerSos() async {
    await _channel.invokeMethod<void>('triggerSOS');
  }

  static Future<void> openAccessibilitySettings() async {
    await _channel.invokeMethod<void>('openAccessibilitySettings');
  }

  static Future<bool> isVolumeSosAccessibilityEnabled() async {
    return (await _channel.invokeMethod<bool>('isVolumeSosAccessibilityEnabled')) ?? false;
  }

  static Future<void> openBatteryOptimizationSettings() async {
    await _channel.invokeMethod<void>('openBatteryOptimizationSettings');
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    return (await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations')) ?? false;
  }
}
