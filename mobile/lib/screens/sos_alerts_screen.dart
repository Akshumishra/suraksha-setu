import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/sos_alert.dart';
import '../services/sos_alert_service.dart';
import 'video_player_screen.dart';

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
              final stationName = alert.assignedStationName?.trim();
              final stationContact = alert.assignedStationContactNumber?.trim();
              final stationLabel = stationName != null && stationName.isNotEmpty
                  ? stationName
                  : 'Station assignment pending';
              final stationSummary =
                  stationContact != null && stationContact.isNotEmpty
                      ? '$stationLabel (${stationContact})'
                      : stationLabel;
              final mediaUrl = alert.mediaUrl?.trim();
              final mediaStatus = mediaUrl != null && mediaUrl.isNotEmpty
                  ? 'Video ready — tap to play'
                  : 'Video upload pending';

              return Card(
                color: alert.isRead ? null : Colors.red.shade50,
                child: ListTile(
                  leading: Icon(
                    alert.isActive ? Icons.warning_amber_rounded : Icons.info,
                    color: alert.isActive ? Colors.red : Colors.blueGrey,
                  ),
                  title: Text('SOS from ${alert.sourceName}'),
                  subtitle: Text(
                    '${alert.relation}\n$timestampLabel\n$locationLabel\nPolice: $stationSummary\nMedia: $mediaStatus',
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
                    final messenger = ScaffoldMessenger.of(context);
                    await showDialog<void>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text('SOS ${alert.status.toUpperCase()}'),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'From: ${alert.sourceName}\n'
                                'Phone: ${alert.sourcePhone.isEmpty ? 'N/A' : alert.sourcePhone}\n'
                                'Relation: ${alert.relation}\n'
                                'Location: $locationLabel\n'
                                'Police station: $stationLabel\n'
                                'Station contact: ${stationContact == null || stationContact.isEmpty ? 'Unavailable' : stationContact}\n'
                                'SOS ID: ${alert.sosId}',
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'SOS Recording',
                                style: Theme.of(dialogContext)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              if (mediaUrl != null && mediaUrl.isNotEmpty)
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () {
                                      Navigator.pop(dialogContext);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => VideoPlayerScreen(
                                            videoUrl: mediaUrl,
                                            title: 'SOS from ${alert.sourceName}',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.play_circle_outline),
                                    label: const Text('Play Video'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                  ),
                                )
                              else
                                const Text(
                                  'The 15 second video is still uploading or waiting for internet sync.',
                                ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext),
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
