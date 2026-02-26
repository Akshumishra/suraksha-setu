import 'package:flutter/material.dart';

import '../models/police_station.dart';
import '../services/police_station_service.dart';

class StationRegistrationScreen extends StatefulWidget {
  const StationRegistrationScreen({super.key});

  @override
  State<StationRegistrationScreen> createState() =>
      _StationRegistrationScreenState();
}

class _StationRegistrationScreenState extends State<StationRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _latitudeCtrl = TextEditingController();
  final _longitudeCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController(text: '10');
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _latitudeCtrl.dispose();
    _longitudeCtrl.dispose();
    _contactCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Station Name'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _latitudeCtrl,
                    decoration: const InputDecoration(labelText: 'Latitude'),
                    validator: _numberValidator,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _longitudeCtrl,
                    decoration: const InputDecoration(labelText: 'Longitude'),
                    validator: _numberValidator,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _contactCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Contact Number'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _radiusCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Jurisdiction Radius (km)',
                    ),
                    validator: _numberValidator,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _saveStation,
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: Text(_saving ? 'Saving...' : 'Register Station'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<PoliceStation>>(
            stream: PoliceStationService.instance.watchStations(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final stations = snapshot.data!;
              if (stations.isEmpty) {
                return const Center(
                  child: Text('No police stations registered yet.'),
                );
              }
              return ListView.builder(
                itemCount: stations.length,
                itemBuilder: (context, index) {
                  final station = stations[index];
                  return ListTile(
                    title: Text(station.stationName),
                    subtitle: Text(
                      'Lat: ${station.latitude.toStringAsFixed(5)}, '
                      'Lon: ${station.longitude.toStringAsFixed(5)}\n'
                      'Radius: ${station.jurisdictionRadius} km • '
                      'Contact: ${station.contactNumber}',
                    ),
                    isThreeLine: true,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _numberValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    if (double.tryParse(value.trim()) == null) {
      return 'Must be a valid number';
    }
    return null;
  }

  Future<void> _saveStation() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    try {
      setState(() => _saving = true);
      await PoliceStationService.instance.createStation(
        stationName: _nameCtrl.text,
        latitude: double.parse(_latitudeCtrl.text.trim()),
        longitude: double.parse(_longitudeCtrl.text.trim()),
        contactNumber: _contactCtrl.text,
        jurisdictionRadius: double.parse(_radiusCtrl.text.trim()),
      );
      _nameCtrl.clear();
      _latitudeCtrl.clear();
      _longitudeCtrl.clear();
      _contactCtrl.clear();
      _radiusCtrl.text = '10';
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Police station registered.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to register station: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
