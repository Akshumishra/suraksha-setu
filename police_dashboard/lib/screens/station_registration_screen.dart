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
  PoliceStation? _editingStation;

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
                  if (_editingStation != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Editing ${_editingStation!.stationName}. Update the coordinates to match the real station location.',
                            ),
                          ),
                          TextButton(
                            onPressed: _saving ? null : _clearEditingState,
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Station Name'),
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
                    decoration: const InputDecoration(labelText: 'Contact Number'),
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
                    icon: Icon(
                      _editingStation == null
                          ? Icons.add_location_alt_outlined
                          : Icons.save_outlined,
                    ),
                    label: Text(
                      _saving
                          ? 'Saving...'
                          : _editingStation == null
                              ? 'Register Station'
                              : 'Update Station',
                    ),
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
                  final policeId = station.policeId;
                  final policeIdLine = policeId != null && policeId.isNotEmpty
                      ? 'Police ID: $policeId\n'
                      : '';
                  return ListTile(
                    title: Text(station.stationName),
                    subtitle: Text(
                      '$policeIdLine'
                      'Lat: ${station.latitude.toStringAsFixed(5)}, '
                      'Lon: ${station.longitude.toStringAsFixed(5)}\n'
                      'Radius: ${station.jurisdictionRadius} km | '
                      'Contact: ${station.contactNumber}',
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Edit station',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: _saving ? null : () => _startEditing(station),
                    ),
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

  void _startEditing(PoliceStation station) {
    setState(() {
      _editingStation = station;
      _nameCtrl.text = station.stationName;
      _latitudeCtrl.text = station.latitude.toString();
      _longitudeCtrl.text = station.longitude.toString();
      _contactCtrl.text = station.contactNumber;
      _radiusCtrl.text = station.jurisdictionRadius.toString();
    });
  }

  void _clearEditingState() {
    setState(() {
      _editingStation = null;
      _nameCtrl.clear();
      _latitudeCtrl.clear();
      _longitudeCtrl.clear();
      _contactCtrl.clear();
      _radiusCtrl.text = '10';
    });
  }

  Future<void> _saveStation() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    try {
      setState(() => _saving = true);
      final stationName = _nameCtrl.text.trim();
      final latitude = double.parse(_latitudeCtrl.text.trim());
      final longitude = double.parse(_longitudeCtrl.text.trim());
      final contactNumber = _contactCtrl.text.trim();
      final jurisdictionRadius = double.parse(_radiusCtrl.text.trim());
      final editingStation = _editingStation;

      if (editingStation == null) {
        await PoliceStationService.instance.createStation(
          stationName: stationName,
          latitude: latitude,
          longitude: longitude,
          contactNumber: contactNumber,
          jurisdictionRadius: jurisdictionRadius,
        );
      } else {
        await PoliceStationService.instance.updateStation(
          stationId: editingStation.id,
          stationName: stationName,
          latitude: latitude,
          longitude: longitude,
          contactNumber: contactNumber,
          jurisdictionRadius: jurisdictionRadius,
        );
      }

      _clearEditingState();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editingStation == null
                ? 'Police station registered.'
                : 'Police station updated.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save station: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
