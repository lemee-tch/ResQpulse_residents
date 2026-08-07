import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'login.dart';
import 'push_notification.dart';
import 'verify_email.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _suffixController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Municipality is now fixed to Rosales — no selection needed
  static const String _municipality = 'Rosales';

  String? _selectedBarangay;
  String? _selectedStreet;
  String? _selectedZone;

  bool _obscurePassword = true;
  bool _isLoading = false;
  File? _uploadedFile;
  String? _uploadedFileName;
  final ImagePicker _picker = ImagePicker();
  String? _errorMessage;

  // ── Rosales-only data ─────────────────────────────────────────────
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
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _suffixController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked != null) {
        setState(() {
          _uploadedFile = File(picked.path);
          _uploadedFileName = picked.name;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera
                  ? 'ID photo captured!'
                  : 'ID uploaded from gallery!',
            ),
            backgroundColor: source == ImageSource.camera
                ? const Color(0xFF1A3A8F)
                : const Color(0xFF00897B),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not access ${source == ImageSource.camera ? 'camera' : 'gallery'}: $e',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleUploadID() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload Valid ID',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Choose how you want to upload your ID',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _sourceOption(
                      ctx: ctx,
                      icon: Icons.camera_alt_outlined,
                      label: 'Camera',
                      subtitle: 'Take a photo',
                      color: const Color(0xFF1A3A8F),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _sourceOption(
                      ctx: ctx,
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      subtitle: 'Choose from files',
                      color: const Color(0xFF00897B),
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              if (_uploadedFileName != null) ...[
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _uploadedFileName = null;
                      _uploadedFile = null;
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Remove ID',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceOption({
    required BuildContext ctx,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showCreateAccountConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Create Account?',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        content: const Text(
          'Please make sure your details and uploaded ID are correct. '
          'You\'ll need to verify your email with a code before you can log in.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A3A8F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Create Account',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_uploadedFile == null) {
      setState(() => _errorMessage = 'Please upload a valid ID to continue.');
      return;
    }

    final confirmed = await _showCreateAccountConfirmation();
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.register(
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      suffix: _suffixController.text.trim(),
      mobile: _mobileController.text.trim(),
      municipality: _municipality,
      barangay: _selectedBarangay ?? '',
      street: _selectedStreet ?? '',
      zone: _selectedZone ?? '',
      email: _emailController.text.trim(),
      password: _passwordController.text,
      validId: _uploadedFile,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created! Check your email for a verification code.',
          ),
          backgroundColor: Color(0xFF1A3A8F),
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              VerifyEmailScreen(email: _emailController.text.trim()),
        ),
        (route) => false,
      );
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
          'Create Account',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Error message
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

                _sectionHeader('Personal Information'),
                const SizedBox(height: 16),

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
                    if (v == null || v.isEmpty)
                      return 'Mobile number is required';
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

                // Barangay
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

                // Street
                _buildDropdown(
                  label: 'Street',
                  hint: 'Select your street',
                  icon: Icons.location_on_outlined,
                  value: _selectedStreet,
                  items: _streets,
                  onChanged: (v) => setState(() => _selectedStreet = v),
                  validator: (v) => v == null ? 'Please select a street' : null,
                ),
                const SizedBox(height: 14),

                // Zone
                _buildDropdown(
                  label: 'Zone',
                  hint: 'Select your zone',
                  icon: Icons.map_outlined,
                  value: _selectedZone,
                  items: _zones,
                  onChanged: (v) => setState(() => _selectedZone = v),
                  validator: (v) => v == null ? 'Please select a zone' : null,
                ),
                const SizedBox(height: 20),

                const Text(
                  'Proof of Residency *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF444466),
                  ),
                ),
                const SizedBox(height: 6),
                _buildUploadIDCard(),

                const SizedBox(height: 28),
                _sectionHeader('Create Account'),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Enter your email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Email is required';
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(v))
                      return 'Enter a valid email address';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Create a password',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey[500],
                      size: 22,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6)
                      return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A3A8F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      shadowColor: const Color(0xFF1A3A8F).withOpacity(0.4),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'CREATE ACCOUNT',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadIDCard() {
    final bool uploaded = _uploadedFileName != null;
    return GestureDetector(
      onTap: _handleUploadID,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: uploaded ? const Color(0xFFE8F5E9) : const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: uploaded
                ? const Color(0xFF2E7D32)
                : const Color(0xFF1A3A8F).withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: uploaded
            ? Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _uploadedFile != null
                        ? Image.file(
                            _uploadedFile!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            color: const Color(0xFF2E7D32).withOpacity(0.12),
                            child: const Icon(
                              Icons.check_circle_outline,
                              color: Color(0xFF2E7D32),
                              size: 26,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ID Uploaded',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _uploadedFileName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _uploadedFileName = null;
                      _uploadedFile = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.red,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3A8F).withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.upload_file_outlined,
                      color: Color(0xFF1A3A8F),
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Upload Proof of Residency',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1A3A8F),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap to upload from camera or gallery',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A3A8F).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.camera_alt_outlined,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.photo_library_outlined,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Camera or Gallery',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFF1A3A8F),
            borderRadius: BorderRadius.circular(2),
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
    bool obscureText = false,
    Widget? suffixIcon,
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
          obscureText: obscureText,
          inputFormatters: inputFormatters,
          validator: validator,
          style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
          decoration: _inputDecoration(hint, icon, suffixIcon: suffixIcon),
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

  InputDecoration _inputDecoration(
    String hint,
    IconData icon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
      suffixIcon: suffixIcon,
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
