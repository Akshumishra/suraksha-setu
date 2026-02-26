import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class IncidentDetailScreen extends StatelessWidget {
  final String incidentId;

  const IncidentDetailScreen({super.key, required this.incidentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🚨 Incident Details')),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('sos')
            .doc(incidentId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final mediaUrl = (data['mediaUrl'] ?? data['videoUrl']) as String?;
          final locationValue = data['location'];
          final locationText = () {
            if (locationValue is GeoPoint) {
              return 'Lat: ${locationValue.latitude}, Lon: ${locationValue.longitude}';
            }
            if (locationValue is Map<String, dynamic>) {
              final lat = locationValue['latitude'] ?? locationValue['lat'];
              final lon = locationValue['longitude'] ?? locationValue['lon'];
              return 'Lat: $lat, Lon: $lon';
            }
            return 'Lat: ${data['lat']}, Lon: ${data['lon']}';
          }();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                _infoTile("Incident ID", incidentId),
                _infoTile("Status", data['status']),
                _infoTile(
                  "Location",
                  locationText,
                ),
                _infoTile(
                  "Time",
                  data['timestamp']?.toDate().toString() ?? 'N/A',
                ),

                const SizedBox(height: 20),
                const Text(
                  "📎 Evidence",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),

                if (data['audioUrl'] != null)
                  _evidenceButton(
                    icon: Icons.audiotrack,
                    label: "Play Audio Evidence",
                    url: data['audioUrl'],
                  ),

                if (mediaUrl != null && mediaUrl.isNotEmpty)
                  _evidenceButton(
                    icon: Icons.videocam,
                    label: "View Media Evidence",
                    url: mediaUrl,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text(
            "$title: ",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _evidenceButton({
    required IconData icon,
    required String label,
    required String url,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ElevatedButton.icon(
        icon: Icon(icon),
        label: Text(label),
        onPressed: () {
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        },
      ),
    );
  }
}
