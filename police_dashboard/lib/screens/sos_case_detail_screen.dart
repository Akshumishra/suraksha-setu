import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sos_case.dart';
import '../services/sos_dashboard_service.dart';

class SosCaseDetailScreen extends StatelessWidget {
  const SosCaseDetailScreen({
    super.key,
    required this.caseId,
    required this.stationId,
  });

  final String caseId;
  final String stationId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS Case Detail')),
      body: StreamBuilder<SosCase?>(
        stream: SosDashboardService.instance.watchCaseById(caseId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final sosCase = snapshot.data;
          if (sosCase == null) {
            return const Center(child: Text('Case not found.'));
          }

          if (sosCase.assignedStationId != stationId) {
            return const Center(
              child: Text('This SOS is not assigned to your station.'),
            );
          }

          final locationText = sosCase.location == null
              ? 'Unavailable'
              : '${sosCase.location!.latitude.toStringAsFixed(6)}, '
                  '${sosCase.location!.longitude.toStringAsFixed(6)}';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _item('Case ID', sosCase.id),
              _item('User ID', sosCase.userId),
              _item(
                'Timestamp',
                sosCase.timestamp == null
                    ? 'Pending'
                    : DateFormat('dd MMM yyyy, hh:mm:ss a')
                        .format(sosCase.timestamp!),
              ),
              _item('Live Location', locationText),
              _item('Status', sosCase.status.toUpperCase()),
              const SizedBox(height: 16),
              if (sosCase.mediaUrl.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(sosCase.mediaUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                  icon: const Icon(Icons.play_circle_fill),
                  label: const Text('Play Cloudinary Media'),
                ),
              const SizedBox(height: 20),
              if (sosCase.status != 'cancelled')
                _StatusDropdown(
                  caseId: sosCase.id,
                  currentStatus: sosCase.status,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _item(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _StatusDropdown extends StatefulWidget {
  const _StatusDropdown({
    required this.caseId,
    required this.currentStatus,
  });

  final String caseId;
  final String currentStatus;

  @override
  State<_StatusDropdown> createState() => _StatusDropdownState();
}

class _StatusDropdownState extends State<_StatusDropdown> {
  late String _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final status = widget.currentStatus.toLowerCase();
    _selected = (status == 'resolved') ? 'resolved' : 'accepted';
  }

  @override
  void didUpdateWidget(covariant _StatusDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    final status = widget.currentStatus.toLowerCase();
    _selected = (status == 'resolved') ? 'resolved' : 'accepted';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            key: ValueKey('${widget.caseId}_$_selected'),
            initialValue: _selected,
            decoration: const InputDecoration(
              labelText: 'Update Status',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
              DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
            ],
            onChanged: _saving
                ? null
                : (value) {
                    if (value == null) {
                      return;
                    }
                    setState(() => _selected = value);
                  },
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    setState(() => _saving = true);
                    await SosDashboardService.instance.updateStatus(
                      caseId: widget.caseId,
                      status: _selected,
                    );
                    if (!mounted) {
                      return;
                    }
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Status updated.')),
                    );
                  } catch (e) {
                    if (!mounted) {
                      return;
                    }
                    messenger.showSnackBar(
                      SnackBar(content: Text('Status update failed: $e')),
                    );
                  } finally {
                    if (mounted) {
                      setState(() => _saving = false);
                    }
                  }
                },
          child: _saving
              ? const SizedBox(
                  height: 14,
                  width: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
