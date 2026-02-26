import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/police_onboarding_service.dart';

class PoliceRegistrationScreen extends StatefulWidget {
  const PoliceRegistrationScreen({super.key});

  @override
  State<PoliceRegistrationScreen> createState() =>
      _PoliceRegistrationScreenState();
}

class _PoliceRegistrationScreenState extends State<PoliceRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _officerNameCtrl = TextEditingController();
  final _policeIdCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _stationNameCtrl = TextEditingController();
  final _contactNumberCtrl = TextEditingController();
  final _latitudeCtrl = TextEditingController();
  final _longitudeCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController(text: '10');

  bool _submitting = false;
  bool _uploadingProof = false;
  String? _idProofUrl;
  String? _idProofName;

  @override
  void dispose() {
    _officerNameCtrl.dispose();
    _policeIdCtrl.dispose();
    _emailCtrl.dispose();
    _stationNameCtrl.dispose();
    _contactNumberCtrl.dispose();
    _latitudeCtrl.dispose();
    _longitudeCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Police Registration Request')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _textField(
                    controller: _officerNameCtrl,
                    label: 'Police Officer Name',
                  ),
                  _textField(
                    controller: _policeIdCtrl,
                    label: 'Police ID Number',
                  ),
                  _textField(
                    controller: _emailCtrl,
                    label: 'Official Email',
                    keyboardType: TextInputType.emailAddress,
                    validator: _emailValidator,
                  ),
                  _textField(
                    controller: _stationNameCtrl,
                    label: 'Police Station Name',
                  ),
                  _textField(
                    controller: _contactNumberCtrl,
                    label: 'Station Contact Number',
                    keyboardType: TextInputType.phone,
                  ),
                  _textField(
                    controller: _latitudeCtrl,
                    label: 'Station Latitude',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: _numberValidator,
                  ),
                  _textField(
                    controller: _longitudeCtrl,
                    label: 'Station Longitude',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: _numberValidator,
                  ),
                  _textField(
                    controller: _radiusCtrl,
                    label: 'Jurisdiction Radius (km)',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: _numberValidator,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _uploadingProof ? null : _pickIdProof,
                        icon: _uploadingProof
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload_file),
                        label: Text(
                          _uploadingProof
                              ? 'Uploading...'
                              : 'Upload ID Proof (Optional)',
                        ),
                      ),
                      if (_idProofName != null)
                        Text(
                          _idProofName!,
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: Text(_submitting
                        ? 'Submitting Request...'
                        : 'Submit Registration Request'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        validator: validator ?? _requiredValidator,
      ),
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
      return 'Enter a valid number';
    }
    return null;
  }

  String? _emailValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    final email = value.trim();
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid official email';
    }
    return null;
  }

  Future<void> _pickIdProof() async {
    try {
      setState(() => _uploadingProof = true);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }
      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw StateError('Failed to read selected file bytes.');
      }

      final downloadUrl = await PoliceOnboardingService.instance.uploadIdProof(
        fileName: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _idProofUrl = downloadUrl;
        _idProofName = file.name;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ID proof upload failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploadingProof = false);
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    try {
      setState(() => _submitting = true);
      await PoliceOnboardingService.instance.submitPoliceRegistration(
        officerName: _officerNameCtrl.text.trim(),
        policeId: _policeIdCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        stationName: _stationNameCtrl.text.trim(),
        contactNumber: _contactNumberCtrl.text.trim(),
        latitude: double.parse(_latitudeCtrl.text.trim()),
        longitude: double.parse(_longitudeCtrl.text.trim()),
        jurisdictionRadius: double.parse(_radiusCtrl.text.trim()),
        idProofUrl: _idProofUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registration submitted. Admin approval is pending.'),
        ),
      );
      _formKey.currentState?.reset();
      _officerNameCtrl.clear();
      _policeIdCtrl.clear();
      _emailCtrl.clear();
      _stationNameCtrl.clear();
      _contactNumberCtrl.clear();
      _latitudeCtrl.clear();
      _longitudeCtrl.clear();
      _radiusCtrl.text = '10';
      setState(() {
        _idProofUrl = null;
        _idProofName = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
