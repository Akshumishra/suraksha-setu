import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/sos_alert.dart';
import '../services/sos_alert_service.dart';

class SosAlertsScreen extends StatelessWidget {
  const SosAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<SosAlert>>(
        stream: SosAlertService.instance.watchIncomingAlerts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load alerts: ${snapshot.error}'),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final alerts = snapshot.data!;
          if (alerts.isEmpty) {
            return const Center(
              child: Text('No SOS alerts from linked emergency contacts yet.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final timestampLabel = alert.timestamp == null
                  ? 'Time pending'
                  : DateFormat('dd MMM, hh:mm a').format(alert.timestamp!);
              final locationLabel = alert.location == null
                  ? 'Location unavailable'
                  : '${alert.location!.latitude.toStringAsFixed(5)}, '
                      '${alert.location!.longitude.toStringAsFixed(5)}';

              return Card(
                color: alert.isRead ? null : Colors.red.shade50,
                child: ListTile(
                  leading: Icon(
                    alert.isActive ? Icons.warning_amber_rounded : Icons.info,
                    color: alert.isActive ? Colors.red : Colors.blueGrey,
                  ),
                  title: Text('SOS from ${alert.sourceName}'),
                  subtitle: Text(
                    '${alert.relation}\n$timestampLabel\n$locationLabel',
                  ),
                  isThreeLine: true,
                  trailing: alert.isRead
                      ? null
                      : const Icon(Icons.fiber_new, color: Colors.red),
                  onTap: () async {
                    if (!alert.isRead) {
                      await SosAlertService.instance.markAsRead(alert.id);
                    }
                    if (!context.mounted) {
                      return;
                    }
                    await showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text('SOS ${alert.status.toUpperCase()}'),
                        content: Text(
                          'From: ${alert.sourceName}\n'
                          'Phone: ${alert.sourcePhone.isEmpty ? 'N/A' : alert.sourcePhone}\n'
                          'Relation: ${alert.relation}\n'
                          'Location: $locationLabel\n'
                          'SOS ID: ${alert.sosId}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
