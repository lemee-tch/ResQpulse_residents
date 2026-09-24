import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

/// Edit Profile — lets a logged-in citizen update their name, mobile
/// number and address. Deliberately mirrors register.dart's field
/// layout/style (same barangay/street/zone lists, same input
/// decoration) so the two forms feel like the same app, but pre-filled
/// from the citizen's current record instead of starting blank.
///
/// Email and password are NOT editable here — email is tied to login
/// and verification_status, and password changes go through the
/// separate forgot/reset-password OTP flow (see login.dart /
/// forgot_password.dart). Municipality stays fixed to Rosales, same as
/// registration.
class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> citizen;

  const EditProfileScreen({super.key, required this.citizen});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _suffixController;
  late final TextEditingController _mobileController;

  static const String _municipality = 'Rosales';

  String? _selectedBarangay;
  String? _selectedStreet;
  String? _selectedZone;

  bool _isSaving = false;
  String? _errorMessage;

  // Same Rosales-only lists as register.dart, kept in sync so a citizen
  // editing their profile sees the exact same options they registered
  // with.
  static const List<String> _barangays = [
    'Acop',
    'Bakitbakit',
    'Balingcanaway',
    'Cabalaoangan Norte',
    'Cabalaoangan Sur',
    'Calanutan',
    'Camangaan',
    'Capitan Tomas',
    'Carmay East',
    'Carmay West',
    'Carmen East',
    'Carmen West',
    'Casanicolasan',
    'Coliling',
    'Don Antonio Village',
    'Guiling',
    'Palakipak',
    'Pangaoan',
    'Rabago',
    'Rizal',
    'Salvacion',
    'San Angel',
    'San Antonio',
    'San Bartolome',
    'San Isidro',
    'San Luis',
    'San Pedro East',
    'San Pedro West',
    'San Vicente',
    'Station District',
    'Tomana East',
    'Tomana West',
    'Zone I (Poblacion)',
    'Zone II (Poblacion)',
    'Zone III (Poblacion)',
    'Zone IV (Poblacion)',
    'Zone V (Poblacion)',
  ];

  static const List<String> _streets = [
    'A. Mabini St',
    'Bonifacio St',
    'Burgos St',
    'Gomez St',
    'Luna St',
    'MacArthur Hwy',
    'Quezon St',
    'Rizal St',
    'San Pedro St',
    'Zamora St',
  ];

  static const List<String> _zones = [
    'Zone I',
    'Zone II',
    'Zone III',
    'Zone IV',
    'Zone V',
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.citizen;
    _firstNameController = TextEditingController(
      text: c['first_name']?.toString() ?? '',
    );
    _middleNameController = TextEditingController(
      text: c['middle_name']?.toString() ?? '',
    );
    _lastNameController = TextEditingController(
      text: c['last_name']?.toString() ?? '',
    );
    _suffixController = TextEditingController(
      text: c['suffix']?.toString() ?? '',
    );
    _mobileController = TextEditingController(
      text: c['mobile']?.toString() ?? '',
    );

    // Dropdown values only take if they match a known option — an
    // out-of-date/free-typed value from before these lists existed
    // shouldn't crash the dropdown, it just starts unselected instead.
    final barangay = c['barangay']?.toString();
    if (barangay != null && _barangays.contains(barangay)) {
      _selectedBarangay = barangay;
    }
    final street = c['street']?.toString();
    if (street != null && _streets.contains(street)) {
      _selectedStreet = street;
    }
    final zone = c['zone']?.toString();
    if (zone != null && _zones.contains(zone)) {
      _selectedZone = zone;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _suffixController.dispose();
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final result = await ApiService.updateProfile(
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      suffix: _suffixController.text.trim(),
      mobile: _mobileController.text.trim(),
      barangay: _selectedBarangay ?? '',
      street: _selectedStreet,
      zone: _selectedZone,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated.'),
          backgroundColor: Color(0xFF1A3A8F),
        ),
      );
      // Hand the fresh citizen record back so ProfileScreen can update
      // its display without a separate getMe() round-trip.
      Navigator.pop(context, result.data['citizen']);
    } else {
      setState(() => _errorMessage = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF1A3A8F),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Personal Information',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                _buildTextField(
                  controller: _firstNameController,
                  label: 'First Name',
                  hint: 'Enter your first name',
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.name,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'First name is required'
                      : null,
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _middleNameController,
                  label: 'Middle Name (optional)',
                  hint: 'Enter your middle name',
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.name,
                  validator: (v) => null,
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _lastNameController,
                  label: 'Last Name',
                  hint: 'Enter your last name',
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.name,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Last name is required' : null,
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _suffixController,
                  label: 'Suffix (optional)',
                  hint: 'e.g. Jr., Sr., III',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.text,
                  validator: (v) => null,
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _mobileController,
                  label: 'Mobile Number',
                  hint: 'e.g. 09XXXXXXXXX',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Mobile number is required';
                    }
                    if (v.length < 10) return 'Enter a valid mobile number';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Municipality — fixed, shown as read-only info tile
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Municipality',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF444466),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF1A3A8F).withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_city_outlined,
                            color: const Color(0xFF1A3A8F).withOpacity(0.6),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Rosales, Pangasinan',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF1A3A8F),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: const Color(0xFF1A3A8F).withOpacity(0.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                _buildDropdown(
                  label: 'Barangay',
                  hint: 'Select your barangay',
                  icon: Icons.home_work_outlined,
                  value: _selectedBarangay,
                  items: _barangays,
                  onChanged: (v) => setState(() => _selectedBarangay = v),
                  validator: (v) =>
                      v == null ? 'Please select a barangay' : null,
                ),
                const SizedBox(height: 14),

                _buildDropdown(
                  label: 'Street',
                  hint: 'Select your street',
                  icon: Icons.location_on_outlined,
                  value: _selectedStreet,
                  items: _streets,
                  onChanged: (v) => setState(() => _selectedStreet = v),
                  validator: (v) => null,
                ),
                const SizedBox(height: 14),

                _buildDropdown(
                  label: 'Zone',
                  hint: 'Select your zone',
                  icon: Icons.map_outlined,
                  value: _selectedZone,
                  items: _zones,
                  onChanged: (v) => setState(() => _selectedZone = v),
                  validator: (v) => null,
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A3A8F),
                      disabledBackgroundColor: Colors.grey[300],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      shadowColor: const Color(0xFF1A3A8F).withOpacity(0.4),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'SAVE CHANGES',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF444466),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
          decoration: _inputDecoration(hint, icon),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String hint,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    required String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF444466),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          validator: validator,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF1A1A2E),
          ),
          style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
          decoration: _inputDecoration(hint, icon),
          items: items
              .map((item) => DropdownMenuItem(value: item, child: Text(item)))
              .toList(),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
      filled: true,
      fillColor: const Color(0xFFF8F9FF),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF1A3A8F), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }
}
