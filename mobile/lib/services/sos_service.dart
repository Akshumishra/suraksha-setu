import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SosService {
  static const MethodChannel _channel = MethodChannel('com.surakshasetu.sos');

  static bool _isSosRunning = false;

  static Future<void> triggerSos() async {
    if (_isSosRunning) {
      debugPrint('SOS trigger ignored: previous trigger still running.');
      return;
    }
    _isSosRunning = true;

    try {
      await _channel.invokeMethod<void>('triggerSOS');
      debugPrint('Native SOS foreground service trigger requested.');
    } on PlatformException catch (e, stackTrace) {
      debugPrint('Native SOS trigger failed: ${e.code} ${e.message}');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } finally {
      _isSosRunning = false;
    }
  }
}
