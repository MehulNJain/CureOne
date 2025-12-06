import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'home_page.dart';

class CreateUserPage extends StatefulWidget {
  final String phoneNumber;
  const CreateUserPage({Key? key, required this.phoneNumber}) : super(key: key);

  @override
  State<CreateUserPage> createState() => _CreateUserPageState();
}

class _CreateUserPageState extends State<CreateUserPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  DateTime? _dob;
  String? _gender; // 'Male','Female','Other'
  String? _bloodGroup;
  final List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    "Don't know",
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // update UI when name changes; also clear name error when typing
    _nameController.addListener(() {
      if (_nameError == true && _nameController.text.trim().isNotEmpty) {
        setState(() => _nameError = false);
      } else {
        setState(() {});
      }
    });
  }

  // validation error flags for required fields
  bool _nameError = false;
  bool _dobError = false;
  bool _genderError = false;
  bool _isSaving = false;

  Widget _label(String text, {bool required = false}) {
    return Row(
      children: [
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (required) ...[
          const SizedBox(width: 6),
          const Text(
            '*',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
          ),
        ],
      ],
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        // subtle card gradient to separate from page background
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7FBFE), Colors.white],
        ),
        borderRadius: BorderRadius.circular(14),
        // left accent to visually highlight the card
        border: const Border(
          left: BorderSide(color: Color(0xFF0A8FDC), width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A8FDC).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  void _onContinue() {
    // validate required fields: name, dob, gender
    final nameEmpty = _nameController.text.trim().isEmpty;
    final dobEmpty = _dob == null;
    final genderEmpty = _gender == null;

    setState(() {
      _nameError = nameEmpty;
      _dobError = dobEmpty;
      _genderError = genderEmpty;
    });

    if (nameEmpty || dobEmpty || genderEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill required fields: Name, Date of Birth and Gender',
          ),
        ),
      );
      return;
    }

    // persist profile data to realtime database
    _saveProfile();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      // Use region-specific DB URL to avoid region mismatch issues
      final db = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
            'https://cureone-4e269-default-rtdb.asia-southeast1.firebasedatabase.app',
      );

      // Node key should be the mobile number used to log in (digits only)
      final phoneKey = widget.phoneNumber.replaceAll(RegExp(r'\D'), '');
      final ref = db.ref('users/$phoneKey');

      int? parseInt(String? s) {
        if (s == null || s.trim().isEmpty) return null;
        return int.tryParse(s.trim());
      }

      // prepare a map and only include non-null values so update() doesn't remove fields
      final snapshot = await ref.get();
      final Map<String, Object?> payload = {};
      void putIfNotNull(String k, Object? v) {
        if (v != null) payload[k] = v;
      }

      putIfNotNull('name', _nameController.text.trim());
      putIfNotNull('dob', _dob?.toIso8601String());
      putIfNotNull('gender', _gender);
      putIfNotNull('bloodGroup', _bloodGroup);
      putIfNotNull('height', parseInt(_heightController.text));
      putIfNotNull('weight', parseInt(_weightController.text));
      // always include mobile (the user's login phone)
      putIfNotNull('mobile', widget.phoneNumber);

      // set createdAt only when creating a new profile
      if (!snapshot.exists) {
        payload['createdAt'] = ServerValue.timestamp;
      }

      if (payload.isNotEmpty) {
        await ref.update(payload);
      }

      setState(() => _isSaving = false);

      // navigate to main/home screen
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeBlue = const Color(0xFF0A8FDC);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // top half gradient (darker bluish tint)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.45,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFD0EAFF),
                      Color(0x00FFFFFF), // fade to transparent
                    ],
                  ),
                ),
              ),
            ),

            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  const SizedBox(height: 36),

                  // big circular icon
                  Container(
                    height: 120,
                    width: 120,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [Color(0xFF0A8FDC), Color(0xFF5DB8F3)],
                        center: Alignment(-0.2, -0.2),
                        radius: 0.9,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.person_add,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    'Complete Your Profile',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Help us personalize your healthcare experience',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF6C7A89)),
                  ),

                  const SizedBox(height: 24),

                  // Full name
                  _card(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: themeBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: Color(0xFF0A8FDC),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Name', required: true),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F9FE),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter your full name',
                                    border: InputBorder.none,
                                    isDense: true,
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                    errorText: _nameError ? 'Required' : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // DOB
                  _card(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: themeBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.calendar_today,
                            color: Color(0xFF0A8FDC),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Date of Birth', required: true),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  await _pickDob();
                                  if (_dob != null)
                                    setState(() => _dobError = false);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7FBFE),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _dobError
                                          ? Colors.red
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _dob == null
                                              ? 'dd/mm/yyyy'
                                              : '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}',
                                          style: TextStyle(
                                            color: _dob == null
                                                ? Colors.grey.shade400
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.calendar_month,
                                        color: Color(0xFF0A8FDC),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Gender (separate card)
                  _card(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: themeBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            color: Color(0xFF0A8FDC),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Gender', required: true),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _genderError
                                        ? Colors.red
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _genderButton('Male'),
                                    const SizedBox(width: 8),
                                    _genderButton('Female'),
                                    const SizedBox(width: 8),
                                    _genderButton('Other'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Blood group (optional)
                  _card(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: themeBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.bloodtype,
                            color: Color(0xFF0A8FDC),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Blood Group',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF7FBFE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _bloodGroup,
                                    isExpanded: true,
                                    hint: const Text(
                                      'Select blood group (optional)',
                                    ),
                                    items: _bloodGroups
                                        .map(
                                          (g) => DropdownMenuItem(
                                            value: g,
                                            child: Text(g),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _bloodGroup = v),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Height
                  _card(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: themeBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.height,
                            color: Color(0xFF0A8FDC),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Height (cm)',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F9FE),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextField(
                                  controller: _heightController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    hintText: '170',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Weight
                  _card(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: themeBlue.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.monitor_weight,
                            color: Color(0xFF0A8FDC),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Weight (kg)',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F9FE),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextField(
                                  controller: _weightController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    hintText: '65',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _genderButton(String label) {
    final selected = _gender == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _gender = label;
          _genderError = false;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF3F9FE) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? const Color(0xFF0A8FDC) : Colors.grey.shade300,
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? const Color(0xFF0A8FDC) : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
