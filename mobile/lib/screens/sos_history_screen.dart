import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../config/sos_config.dart';
import '../models/sos_case.dart';
import '../services/sos_repository.dart';

class SosHistoryScreen extends StatefulWidget {
  const SosHistoryScreen({super.key});

  @override
  State<SosHistoryScreen> createState() => _SosHistoryScreenState();
}

class _SosHistoryScreenState extends State<SosHistoryScreen> {
  static const Duration _cancelWindow = SosConfig.cancelWindow;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<SosCase>>(
      stream: SosRepository.instance.watchUserSosHistory(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Failed to load SOS history: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final records = snapshot.data!;
        if (records.isEmpty) {
          return const Center(child: Text('No SOS history found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: records.length,
          itemBuilder: (context, index) {
            final sos = records[index];
            final timestamp = sos.timestamp;
            final dateText = timestamp == null
                ? 'Pending timestamp'
                : DateFormat('dd MMM yyyy').format(timestamp);
            final timeText = timestamp == null
                ? '--:--'
                : DateFormat('hh:mm:ss a').format(timestamp);
            final locationText = sos.location == null
                ? 'Location unavailable'
                : '${sos.location!.latitude.toStringAsFixed(5)}, ${sos.location!.longitude.toStringAsFixed(5)}';
            final mediaUrl = sos.mediaUrl?.trim();
            final hasMediaUrl = mediaUrl != null && mediaUrl.isNotEmpty;

            final cancelRemaining = _cancelSecondsRemaining(sos);
            final canCancel = sos.isActive && cancelRemaining > 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date: $dateText',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text('Time: $timeText'),
                    Text('Location: $locationText'),
                    Text(
                      hasMediaUrl
                          ? '15 sec video: Link ready'
                          : '15 sec video: Upload pending or still syncing',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _statusChip(sos.status),
                        const Spacer(),
                        if (canCancel)
                          Text(
                            'Cancel in ${cancelRemaining}s',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    if (canCancel) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () => _cancelSos(context, sos.id),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancel SOS'),
                        ),
                      ),
                    ],
                    if (hasMediaUrl) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _showMediaLinkDialog(
                            context: context,
                            mediaUrl: mediaUrl!,
                          ),
                          icon: const Icon(Icons.video_library_outlined),
                          label: const Text('View video link'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  int _cancelSecondsRemaining(SosCase sos) {
    final timestamp = sos.timestamp;
    if (timestamp == null) {
      return _cancelWindow.inSeconds;
    }
    final elapsed = DateTime.now().difference(timestamp);
    final remaining = _cancelWindow - elapsed;
    return remaining.inSeconds.clamp(0, _cancelWindow.inSeconds);
  }

  Future<void> _cancelSos(BuildContext context, String sosId) async {
    try {
      await SosRepository.instance.cancelSos(sosId: sosId);
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('SOS cancelled successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Failed to cancel SOS: $e')),
      );
    }
  }

  Future<void> _showMediaLinkDialog({
    required BuildContext context,
    required String mediaUrl,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Emergency Video Link'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This is the same 15 second video link shared with police and your emergency contacts.',
              ),
              const SizedBox(height: 12),
              SelectableText(mediaUrl),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: mediaUrl));
              if (!context.mounted) {
                return;
              }
              messenger.showSnackBar(
                const SnackBar(content: Text('Video link copied.')),
              );
            },
            icon: const Icon(Icons.copy_all_outlined),
            label: const Text('Copy link'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final normalized = status.toLowerCase();
    final (label, color) = switch (normalized) {
      'active' => ('Active', Colors.red),
      'accepted' => ('Accepted', Colors.orange),
      'resolved' => ('Resolved', Colors.green),
      'cancelled' => ('Cancelled', Colors.blueGrey),
      _ => (status, Colors.grey),
    };

    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
