import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sos_alert.dart';
import 'sos_alert_service.dart';

class SosAlertNotificationService {
  SosAlertNotificationService._();

  static final SosAlertNotificationService instance =
      SosAlertNotificationService._();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'incoming_sos_alerts',
    'Incoming SOS Alerts',
    description:
        'Alerts when linked emergency contacts trigger SOS and share updates.',
    importance: Importance.max,
  );

  static const String _prefsKeyPrefix = 'incoming_sos_notified_ids_';
  static const int _maxStoredIds = 200;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<List<SosAlert>>? _subscription;

  bool _initialized = false;
  bool _primedCurrentUser = false;
  String? _activeUserId;
  Set<String> _notifiedIds = <String>{};

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(initializationSettings);
    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channel);
    await androidPlugin?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> startForCurrentUser() async {
    await initialize();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      await stop();
      return;
    }

    await _prepareForUser(user.uid);
    await _subscription?.cancel();
    _subscription = SosAlertService.instance.watchIncomingAlerts().listen(
      (alerts) {
        unawaited(_handleAlerts(alerts));
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Incoming SOS notification listener failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  Future<void> pollAndNotifyOnce() async {
    await initialize();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    await _prepareForUser(user.uid);
    final alerts = await SosAlertService.instance.fetchIncomingAlertsOnce();
    await _handleAlerts(alerts);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _activeUserId = null;
    _primedCurrentUser = false;
    _notifiedIds = <String>{};
  }

  Future<void> _prepareForUser(String userId) async {
    if (_activeUserId == userId) {
      return;
    }
    _activeUserId = userId;
    _primedCurrentUser = false;
    _notifiedIds = await _loadStoredIds(userId);
  }

  Future<void> _handleAlerts(List<SosAlert> alerts) async {
    final userId = _activeUserId;
    if (userId == null) {
      return;
    }

    if (!_primedCurrentUser) {
      _primedCurrentUser = true;
      _notifiedIds.addAll(alerts.map((alert) => alert.id));
      await _persistStoredIds(userId);
      return;
    }

    var changed = false;
    for (final alert in alerts) {
      if (_notifiedIds.contains(alert.id)) {
        continue;
      }
      _notifiedIds.add(alert.id);
      changed = true;
      if (!alert.isRead) {
        await _showIncomingAlertNotification(alert);
      }
    }

    if (changed) {
      await _persistStoredIds(userId);
    }
  }

  Future<void> _showIncomingAlertNotification(SosAlert alert) async {
    final stationLabel =
        (alert.assignedStationName ?? '').trim().isNotEmpty
            ? alert.assignedStationName!.trim()
            : 'Police assignment pending';
    final body = alert.mediaUrl?.trim().isNotEmpty == true
        ? '${alert.relation} needs help. Video link available. $stationLabel.'
        : '${alert.relation} needs help. Open the app for location and responder updates.';

    await _plugin.show(
      alert.id.hashCode,
      'SOS from ${alert.sourceName}',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.message,
          visibility: NotificationVisibility.public,
          ticker: 'Incoming SOS alert',
        ),
      ),
    );
  }

  Future<Set<String>> _loadStoredIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final values = prefs.getStringList('$_prefsKeyPrefix$userId') ?? <String>[];
    return values.toSet();
  }

  Future<void> _persistStoredIds(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final sorted = _notifiedIds.toList(growable: false);
    final trimmed = sorted.length > _maxStoredIds
        ? sorted.sublist(sorted.length - _maxStoredIds)
        : sorted;
    await prefs.setStringList('$_prefsKeyPrefix$userId', trimmed);
  }
}
