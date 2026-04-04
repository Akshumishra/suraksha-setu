import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/user_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const List<String> _genderOptions = <String>[
    'Female',
    'Male',
    'Non-binary',
    'Prefer not to say',
  ];

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  String? _selectedGender;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await UserService.getCurrentUserProfile();
      final user = _auth.currentUser;
      final data = profile ?? <String, dynamic>{};

      _nameController.text =
          _readString(data['name']) ?? user?.displayName?.trim() ?? '';
      _emailController.text =
          _readString(data['email']) ?? user?.email?.trim().toLowerCase() ?? '';
      _phoneController.text =
          _readString(data['phone']) ?? user?.phoneNumber?.trim() ?? '';
      _ageController.text = _readInt(data['age'])?.toString() ?? '';
      _cityController.text = _readString(data['city']) ?? '';

      if (!mounted) {
        return;
      }
      setState(() {
        _selectedGender = _readString(data['gender']);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load profile: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final ageText = _ageController.text.trim();
    final city = _cityController.text.trim();
    final age = ageText.isEmpty ? null : int.tryParse(ageText);

    try {
      FocusScope.of(context).unfocus();
      setState(() => _saving = true);

      await UserService.saveUserProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        gender: _selectedGender?.trim().isEmpty ?? true
            ? null
            : _selectedGender?.trim(),
        age: age,
        city: city.isEmpty ? null : city,
        clearMissingOptionalFields: true,
      );

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated.')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String? _readString(dynamic value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int? _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  String? _requiredTextValidator(String? value, String fieldLabel) {
    if ((value ?? '').trim().isEmpty) {
      return 'Enter your $fieldLabel';
    }
    return null;
  }

  String? _mobileValidator(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Enter your mobile number';
    }
    if (trimmed.length < 10 || trimmed.length > 15) {
      return 'Use 10 to 15 digits';
    }
    return null;
  }

  String? _ageValidator(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final age = int.tryParse(trimmed);
    if (age == null || age < 1 || age > 120) {
      return 'Enter a valid age';
    }
    return null;
  }

  String _profileMonogram() {
    final candidate = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : _emailController.text.trim();
    if (candidate.isEmpty) {
      return 'U';
    }
    return candidate.characters.first.toUpperCase();
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  Widget _buildGenderAndAgeFields() {
    final genderField = DropdownButtonFormField<String>(
      value: _selectedGender,
      isExpanded: true,
      decoration: _inputDecoration(
        label: 'Gender',
        icon: Icons.wc_outlined,
      ),
      items: _genderOptions
          .map(
            (gender) => DropdownMenuItem<String>(
              value: gender,
              child: Text(
                gender,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: _saving
          ? null
          : (value) {
              setState(() => _selectedGender = value);
            },
    );

    final ageField = TextFormField(
      controller: _ageController,
      enabled: !_saving,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(3),
      ],
      decoration: _inputDecoration(
        label: 'Age',
        icon: Icons.cake_outlined,
        hint: 'Optional',
      ),
      validator: _ageValidator,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackFields = constraints.maxWidth < 360;
        if (stackFields) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              genderField,
              const SizedBox(height: 14),
              ageField,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: genderField),
            const SizedBox(width: 12),
            Expanded(child: ageField),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      colorScheme.primaryContainer.withValues(alpha: 0.75),
                      colorScheme.surface,
                    ],
                  ),
                ),
                child: SafeArea(
                  top: true,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Card(
                      elevation: 1.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: colorScheme.primary,
                                    foregroundColor: colorScheme.onPrimary,
                                    child: Text(
                                      _profileMonogram(),
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Your safety profile',
                                          style: theme.textTheme.titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Keep your contact details current so responders, police, and offline SMS fallback can reach the right people quickly.',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _emailController,
                                enabled: false,
                                decoration: _inputDecoration(
                                  label: 'Account email',
                                  icon: Icons.email_outlined,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Email follows your login account and is shown here for reference.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _nameController,
                                enabled: !_saving,
                                textCapitalization: TextCapitalization.words,
                                decoration: _inputDecoration(
                                  label: 'Full Name',
                                  icon: Icons.badge_outlined,
                                  hint: 'Enter your full name',
                                ),
                                textInputAction: TextInputAction.next,
                                validator: (value) =>
                                    _requiredTextValidator(value, 'full name'),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _phoneController,
                                enabled: !_saving,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(15),
                                ],
                                decoration: _inputDecoration(
                                  label: 'Mobile Number',
                                  icon: Icons.phone_android_outlined,
                                  hint: '10 to 15 digits',
                                ),
                                validator: _mobileValidator,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'This number is used when SOS falls back to SMS during low or no internet.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _buildGenderAndAgeFields(),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _cityController,
                                enabled: !_saving,
                                textCapitalization: TextCapitalization.words,
                                decoration: _inputDecoration(
                                  label: 'City',
                                  icon: Icons.location_city_outlined,
                                  hint: 'Optional',
                                ),
                                textInputAction: TextInputAction.done,
                              ),
                              const SizedBox(height: 22),
                              FilledButton.icon(
                                onPressed: _saving ? null : _saveProfile,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  _saving ? 'Saving...' : 'Save profile',
                                ),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(54),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
