
import 'package:flutter/services.dart';

class NativeSos {
  static const _channel = MethodChannel('com.surakshasetu.sos');

  static Future<void> startSos() async {
    await _channel.invokeMethod('startSos');
  }

  static Future<void> stopSos() async {
    await _channel.invokeMethod('stopSos');
  }
}
