import 'dart:async';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import 'emergency_contact_service.dart';
import 'sos_alert_notification_service.dart';
import 'sos_sync_service.dart';
import 'user_service.dart';

const int _notificationId = 54021;

@pragma('vm:entry-point')
Future<void> sosBackgroundServiceOnStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    debugPrint('SOS background isolate: Firebase initialized.');
  } catch (e, stackTrace) {
    debugPrint('SOS background isolate: Firebase init failed: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  if (service is AndroidServiceInstance) {
    await service.setForegroundNotificationInfo(
      title: 'Suraksha Setu active',
      content: 'Background SOS sync is running',
    );
  }

  Future<void> syncOnce() async {
    try {
      await EmergencyContactService.instance.refreshLocalCache();
      await UserService.refreshLocalProfileCache();
      await SosSyncService.instance.syncPendingFiles();
      await SosAlertNotificationService.instance.pollAndNotifyOnce();
    } catch (e, stackTrace) {
      debugPrint('SOS background sync failed: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  await syncOnce();

  final timer = Timer.periodic(
    const Duration(minutes: 5),
    (_) => syncOnce(),
  );
  final connectivitySubscription = Connectivity().onConnectivityChanged.listen((
    resultOrResults,
  ) {
    final hasConnection = switch (resultOrResults) {
      List<ConnectivityResult> results =>
        results.any((result) => result != ConnectivityResult.none),
      ConnectivityResult result => result != ConnectivityResult.none,
      _ => false,
    };
    if (!hasConnection) {
      return;
    }
    unawaited(syncOnce());
  });

  service.on('sync_now').listen((_) => syncOnce());
  service.on('stop_service').listen((_) {
    timer.cancel();
    connectivitySubscription.cancel();
    service.stopSelf();
  });
}

class SosBackgroundTaskHandler {
  SosBackgroundTaskHandler._();

  static final SosBackgroundTaskHandler instance = SosBackgroundTaskHandler._();

  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: sosBackgroundServiceOnStart,
        autoStart: true,
        autoStartOnBoot: true,
        isForegroundMode: true,
        initialNotificationTitle: 'Suraksha Setu active',
        initialNotificationContent: 'Background SOS sync is running',
        foregroundServiceNotificationId: _notificationId,
        foregroundServiceTypes: [AndroidForegroundType.dataSync],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: sosBackgroundServiceOnStart,
      ),
    );

    await service.startService();
  }

  Future<void> triggerImmediateSync() async {
    final service = FlutterBackgroundService();
    service.invoke('sync_now');
  }
}
