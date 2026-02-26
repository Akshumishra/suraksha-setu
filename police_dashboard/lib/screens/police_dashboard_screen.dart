import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../models/sos_case.dart';
import '../services/police_auth_service.dart';
import '../services/sos_dashboard_service.dart';
import 'sos_case_detail_screen.dart';

class PoliceDashboardScreen extends StatelessWidget {
  const PoliceDashboardScreen({
    super.key,
    required this.session,
  });

  final PoliceSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live SOS Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await PoliceAuthService.instance.signOut();
              if (!context.mounted) {
                return;
              }
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: StreamBuilder<List<SosCase>>(
        stream: SosDashboardService.instance.watchAssignedCases(session.stationId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load cases: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final cases = snapshot.data!;
          final activeCount = cases.where((c) => c.status == 'active').length;
          final markers = cases
              .where((c) => c.location != null)
              .map(
                (c) => Marker(
                  point: LatLng(
                    c.location!.latitude,
                    c.location!.longitude,
                  ),
                  width: 34,
                  height: 34,
                  child: Tooltip(
                    message: '${c.id}\n${c.status.toUpperCase()}',
                    child: Icon(
                      Icons.location_on,
                      color: c.status == 'active'
                          ? Colors.red
                          : c.status == 'accepted'
                              ? Colors.orange
                              : c.status == 'resolved'
                                  ? Colors.green
                                  : Colors.blueGrey,
                    ),
                  ),
                ),
              )
              .toList(growable: false);

          final mapCenter = markers.isNotEmpty
              ? markers.first.point
              : const LatLng(20.5937, 78.9629);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    _metricCard(
                      context,
                      title: 'Assigned Cases',
                      value: '${cases.length}',
                      color: Colors.indigo,
                    ),
                    const SizedBox(width: 12),
                    _metricCard(
                      context,
                      title: 'Active SOS',
                      value: '$activeCount',
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 260,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: mapCenter,
                    initialZoom: 11,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.surakshasetu.police_dashboard',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: cases.isEmpty
                    ? const Center(child: Text('No assigned SOS cases yet.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: cases.length,
                        itemBuilder: (context, index) {
                          final sosCase = cases[index];
                          final timeText = sosCase.timestamp == null
                              ? 'Timestamp pending'
                              : DateFormat('dd MMM, hh:mm a')
                                  .format(sosCase.timestamp!);
                          final locationText = sosCase.location == null
                              ? 'No location'
                              : '${sosCase.location!.latitude.toStringAsFixed(4)}, '
                                  '${sosCase.location!.longitude.toStringAsFixed(4)}';

                          return Card(
                            child: ListTile(
                              title: Text('SOS ${sosCase.id.substring(0, 8)}'),
                              subtitle: Text(
                                '$timeText\n$locationText',
                              ),
                              isThreeLine: true,
                              trailing: _statusChip(sosCase.status),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SosCaseDetailScreen(
                                    caseId: sosCase.id,
                                    stationId: session.stationId,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required String title,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final (label, color) = switch (status.toLowerCase()) {
      'active' => ('Active', Colors.red),
      'accepted' => ('Accepted', Colors.orange),
      'resolved' => ('Resolved', Colors.green),
      'cancelled' => ('Cancelled', Colors.blueGrey),
      _ => (status, Colors.grey),
    };

    return Chip(
      label: Text(label),
      side: BorderSide(color: color.withValues(alpha: 0.5)),
      backgroundColor: color.withValues(alpha: 0.12),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
    );
  }
}
