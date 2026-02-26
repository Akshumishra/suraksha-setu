import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

import '../models/police_registration_request.dart';
import '../services/police_onboarding_service.dart';

class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> {
  final Set<String> _busyIds = <String>{};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PoliceRegistrationRequest>>(
      stream: PoliceOnboardingService.instance.watchPendingRequests(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
              child: Text('Failed to load requests: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data!;
        if (requests.isEmpty) {
          return const Center(child: Text('No pending police requests.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final isBusy = _busyIds.contains(request.id);
            final createdAt = request.createdAt == null
                ? 'Pending timestamp'
                : DateFormat('dd MMM yyyy, hh:mm a').format(request.createdAt!);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.officerName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _row('Police ID', request.policeId),
                    _row('Email', request.email),
                    _row('Station', request.stationName),
                    _row('Contact', request.contactNumber),
                    _row(
                      'Coordinates',
                      '${request.latitude.toStringAsFixed(6)}, ${request.longitude.toStringAsFixed(6)}',
                    ),
                    _row('Radius', '${request.jurisdictionRadius} km'),
                    _row('Created At', createdAt),
                    if (request.idProofUrl != null &&
                        request.idProofUrl!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(request.idProofUrl!),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon: const Icon(Icons.verified_user_outlined),
                          label: const Text('View ID Proof'),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        FilledButton.icon(
                          onPressed:
                              isBusy ? null : () => _approveRequest(request.id),
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(isBusy ? 'Processing...' : 'Approve'),
                        ),
                        OutlinedButton.icon(
                          onPressed:
                              isBusy ? null : () => _rejectRequest(request.id),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Reject'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Future<void> _approveRequest(String requestId) async {
    setState(() => _busyIds.add(requestId));
    try {
      await PoliceOnboardingService.instance.approveRequest(requestId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request approved. Credentials emailed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Approval failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyIds.remove(requestId));
      }
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    final reasonCtrl = TextEditingController();
    final shouldReject = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reject request'),
            content: TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Reject'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldReject) {
      reasonCtrl.dispose();
      return;
    }

    setState(() => _busyIds.add(requestId));
    try {
      await PoliceOnboardingService.instance.rejectRequest(
        requestId: requestId,
        reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request rejected.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rejection failed: $e')),
      );
    } finally {
      reasonCtrl.dispose();
      if (mounted) {
        setState(() => _busyIds.remove(requestId));
      }
    }
  }
}
