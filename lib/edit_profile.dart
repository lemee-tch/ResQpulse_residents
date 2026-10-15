import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'change_contact.dart';

/// Profile → Personal Information.
///
/// Contact: the email and mobile number, each marked Verified or Not
/// verified, with Change (or Add email) and, for a number that isn't
/// verified yet, Verify. Those open ChangeContactScreen, which confirms the
/// new email or number with a 6-digit code sent to it — before, the number
/// was changed here with no code (and not at all for residents who log in
/// with it), and the email couldn't be changed.
///
/// Name and Address: edited here and saved with Save Changes. Same
/// barangay/street/zone lists as register.dart. Municipality stays fixed
/// to Rosales; password changes go through Forgot Password.
class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> citizen;

  const EditProfileScreen({super.key, required this.citizen});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const Color _navy = Color(0xFF1A3A8F);
  static const Color _ink = Color(0xFF1A1A2E);

  final _formKey = GlobalKey<FormState>();

  /// The profile as it is now — updated when the email or number changes.
  late Map<String, dynamic> _citizen;

  late final TextEditingController _firstNameController;
  late final TextEditingController _middleNameController;
  late final TextEditingController _lastNameController;
  late final TextEditingController _suffixController;

  String? _selectedBarangay;
  String? _selectedStreet;
  String? _selectedZone;

  /// What the form started with, to ask before leaving with unsaved edits.
  late final List<String?> _initialValues;

  bool _isSaving = false;
  String? _errorMessage;

  /// Whether texts can be sent right now (for Verify); null while checking.
  bool? _smsAvailable;

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

  String get _email => (_citizen['email'] ?? '').toString().trim();
  String get _mobile => (_citizen['mobile'] ?? '').toString().trim();
  bool get _hasEmail => _email.isNotEmpty;
  bool get _emailVerified => _citizen['email_verified_at'] != null;
  bool get _mobileVerified => _citizen['mobile_verified_at'] != null;

  @override
  void initState() {
    super.initState();
    _citizen = Map<String, dynamic>.from(widget.citizen);
    final c = _citizen;
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

    _initialValues = _currentValues();
    _checkSms();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _suffixController.dispose();
    super.dispose();
  }

  Future<void> _checkSms() async {
    final available = await ApiService.isSmsVerificationAvailable();
    if (mounted) setState(() => _smsAvailable = available);
  }

  List<String?> _currentValues() => [
    _firstNameController.text.trim(),
    _middleNameController.text.trim(),
    _lastNameController.text.trim(),
    _suffixController.text.trim(),
    _selectedBarangay,
    _selectedStreet,
    _selectedZone,
  ];

  bool get _hasUnsavedEdits {
    final now = _currentValues();
    for (var i = 0; i < now.length; i++) {
      if (now[i] != _initialValues[i]) return true;
    }
    return false;
  }

  /// Back with unsaved edits: ask first.
  Future<void> _leave() async {
    if (!_hasUnsavedEdits) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Discard changes?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Your changes to your name or address haven\'t been saved.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  /// Change / Add email, Change number, Verify number.
  Future<void> _openChange(String type, {bool verifyCurrent = false}) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeContactScreen(
          type: type,
          citizen: _citizen,
          verifyCurrent: verifyCurrent,
        ),
      ),
    );
    if (result == null || !mounted) return;

    final updated = result['citizen'];
    if (updated is Map) {
      setState(() => _citizen = Map<String, dynamic>.from(updated));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? 'Saved.'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
    );
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
      // Unchanged — the number is changed with a code (Contact above).
      mobile: _mobile,
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
          backgroundColor: Color(0xFF2E7D32),
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: _ink, size: 20),
            onPressed: _leave,
          ),
          title: const Text(
            'Personal Information',
            style: TextStyle(
              color: _ink,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                _contactCard(),
                const SizedBox(height: 16),
                _section(
                  title: 'Name',
                  icon: Icons.badge_outlined,
                  children: [
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'First Name',
                      hint: 'Enter your first name',
                      icon: Icons.person_outline,
                      keyboardType: TextInputType.name,
                      validator: (v) => (v == null || v.trim().isEmpty)
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
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      hint: 'Enter your last name',
                      icon: Icons.person_outline,
                      keyboardType: TextInputType.name,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Last name is required'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    _buildTextField(
                      controller: _suffixController,
                      label: 'Suffix (optional)',
                      hint: 'e.g. Jr., Sr., III',
                      icon: Icons.badge_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _section(
                  title: 'Address',
                  icon: Icons.home_outlined,
                  children: [
                    _municipalityTile(),
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
                      label: 'Street (optional)',
                      hint: 'Select your street',
                      icon: Icons.location_on_outlined,
                      value: _selectedStreet,
                      items: _streets,
                      onChanged: (v) => setState(() => _selectedStreet = v),
                    ),
                    const SizedBox(height: 14),
                    _buildDropdown(
                      label: 'Zone (optional)',
                      hint: 'Select your zone',
                      icon: Icons.map_outlined,
                      value: _selectedZone,
                      items: _zones,
                      onChanged: (v) => setState(() => _selectedZone = v),
                    ),
                  ],
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD32F2F),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      disabledBackgroundColor: Colors.grey[300],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
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
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Save Changes saves your name and address. Your email and '
                  'number are saved as soon as you confirm the code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Contact ─────────────────────────────────────────────────────────

  Widget _contactCard() {
    return _section(
      title: 'Contact',
      icon: Icons.contact_mail_outlined,
      children: [
        _contactRow(
          icon: Icons.mail_outline,
          label: 'Email',
          value: _hasEmail ? _email : 'No email yet',
          empty: !_hasEmail,
          verified: _emailVerified,
          actionLabel: _hasEmail ? 'Change' : 'Add',
          onAction: () => _openChange('email'),
        ),
        Divider(height: 24, color: Colors.grey[200]),
        _contactRow(
          icon: Icons.phone_outlined,
          label: 'Mobile number',
          value: _mobile.isEmpty ? 'No number yet' : _mobile,
          empty: _mobile.isEmpty,
          verified: _mobileVerified,
          actionLabel: 'Change',
          onAction: () => _openChange('mobile'),
          // Confirm the current number by text, when texts can be sent.
          onVerify:
              (!_mobileVerified && _mobile.isNotEmpty && _smsAvailable == true)
              ? () => _openChange('mobile', verifyCurrent: true)
              : null,
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _navy.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.login, size: 16, color: _navy),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _hasEmail
                      ? 'You can log in with your email or mobile number. A '
                            'change is confirmed with a code sent to the new '
                            'one.'
                      : 'You log in with your mobile number. A change is '
                            'confirmed with a code sent to the new one.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: _navy,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String label,
    required String value,
    required bool empty,
    required bool verified,
    required String actionLabel,
    required VoidCallback onAction,
    VoidCallback? onVerify,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _navy.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _navy, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: empty ? FontWeight.w500 : FontWeight.w700,
                  color: empty ? Colors.grey[500] : _ink,
                ),
              ),
              if (!empty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _statusChip(verified),
                    if (onVerify != null)
                      GestureDetector(
                        onTap: onVerify,
                        child: const Text(
                          'Verify now',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: onAction,
          style: OutlinedButton.styleFrom(
            foregroundColor: _navy,
            side: const BorderSide(color: Color(0xFFC7D2FE), width: 1.4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            minimumSize: const Size(0, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            actionLabel,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _statusChip(bool verified) {
    final Color bg = verified
        ? const Color(0xFFD1FAE5)
        : const Color(0xFFFEF3C7);
    final Color fg = verified
        ? const Color(0xFF065F46)
        : const Color(0xFF92400E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified : Icons.error_outline,
            size: 13,
            color: fg,
          ),
          const SizedBox(width: 4),
          Text(
            verified ? 'Verified' : 'Not verified',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  // ── Layout pieces ───────────────────────────────────────────────────

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey[500]),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _municipalityTile() {
    return Column(
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F4FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _navy.withOpacity(0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_city_outlined,
                color: _navy.withOpacity(0.6),
                size: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Rosales, Pangasinan',
                  style: TextStyle(
                    fontSize: 15,
                    color: _navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.lock_outline, size: 16, color: _navy.withOpacity(0.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
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
          textCapitalization: TextCapitalization.words,
          validator: validator,
          style: const TextStyle(fontSize: 15, color: _ink),
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
        DropdownButtonFormField<String>(
          value: value,
          onChanged: onChanged,
          validator: validator,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _ink),
          style: const TextStyle(fontSize: 15, color: _ink),
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
        borderSide: const BorderSide(color: _navy, width: 2),
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
