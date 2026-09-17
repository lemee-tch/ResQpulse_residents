import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'login.dart';
import 'push_notification.dart';
import 'home.dart';

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
  final _otpController = TextEditingController();

  // Municipality is now fixed to Rosales — no selection needed
  static const String _municipality = 'Rosales';

  String? _selectedBarangay;
  String? _selectedStreet;
  String? _selectedZone;

  bool _obscurePassword = true;
  bool _isSendingCode = false;
  bool _isVerifying = false;
  File? _uploadedFile;
  String? _uploadedFileName;
  final ImagePicker _picker = ImagePicker();
  String? _errorMessage;

  // Resend cooldown — after a code is sent, "Get Code" turns into a
  // disabled countdown ("Resend in 60s") so the person can't hammer the
  // endpoint if the email is just running late, and re-enables as
  // "Resend" once it hits zero.
  Timer? _resendTimer;
  int _resendCooldown = 0;
  static const int _resendCooldownSeconds = 60;

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendCooldown = _resendCooldownSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
      } else {
        setState(() => _resendCooldown -= 1);
      }
    });
  }

  // Inline OTP state — replaces the old "navigate to a separate
  // VerifyEmailScreen" flow. Once the code is sent, the whole form
  // (except the OTP field + the email field's inline "Resend" action)
  // locks so the account data being verified can't drift from what was
  // actually submitted to the backend.
  bool _otpSent = false;

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
    _otpController.dispose();
    _resendTimer?.cancel();
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

  /// Inline "Get Code" — validates the ENTIRE form (this endpoint creates
  /// the account and sends the OTP in one call, same as before), then
  /// stays on this page and reveals the verification-code field instead
  /// of navigating to a separate screen. No confirmation dialog here —
  /// that would interrupt the "just get me the code" action; the person
  /// already reviews everything one more time at the final "VERIFY &
  /// CONTINUE" step.
  Future<void> _handleGetCode() async {
    if (!_formKey.currentState!.validate()) return;

    if (_uploadedFile == null) {
      setState(() => _errorMessage = 'Please upload a valid ID to continue.');
      return;
    }

    setState(() {
      _isSendingCode = true;
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
    setState(() => _isSendingCode = false);

    if (result.success) {
      setState(() => _otpSent = true);
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We\'ve sent you a verification code — check your email.',
          ),
          backgroundColor: Color(0xFF1A3A8F),
        ),
      );
    } else {
      setState(() => _errorMessage = result.error);
    }
  }

  /// Inline "Resend" — same email, just asks the backend for a fresh
  /// code. Guarded by the cooldown (the button itself is disabled while
  /// counting down), but double-checked here too in case this ever gets
  /// wired to something else that could call it early.
  Future<void> _handleResendCode() async {
    if (_resendCooldown > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'We already sent you a code. You can resend in ${_resendCooldown}s '
            'if you didn\'t receive it.',
          ),
          backgroundColor: Colors.grey[700],
        ),
      );
      return;
    }

    setState(() => _isSendingCode = true);

    final result = await ApiService.resendVerificationOtp(
      email: _emailController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSendingCode = false);

    if (result.success) _startResendCooldown();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'A new code was sent to ${_emailController.text.trim()}'
              : (result.error ?? 'Could not resend code.'),
        ),
        backgroundColor: result.success ? const Color(0xFF1A3A8F) : Colors.red,
      ),
    );
  }

  /// Final step — verifies the OTP inline, then logs straight into Home
  /// (no separate confirmation screen).
  ///
  /// Sanitizes the OTP field before checking its length rather than just
  /// `.trim()`-ing it — some keyboards/autofill suggestions (SMS code
  /// autofill, one-tap suggestion bars) can insert non-digit characters
  /// like spaces or dashes that `trim()` doesn't remove, which made the
  /// "enter the 6-digit code" check fail even when 6 digits were visibly
  /// typed.
  Future<void> _handleVerifyEmail() async {
    final code = _otpController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (code.length != 6) {
      setState(
        () => _errorMessage =
            'Please enter the 6-digit code (currently ${code.length} digit${code.length == 1 ? '' : 's'}).',
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final result = await ApiService.verifyEmail(
      email: _emailController.text.trim(),
      otp: code,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (result.success) {
      await registerFcmToken();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } else {
      setState(() => _errorMessage = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool fieldsEnabled = !_otpSent;

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
                if (_otpSent) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2E7D32)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.mark_email_read_outlined,
                          color: Color(0xFF2E7D32),
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Code sent! Enter it below, then tap "Verify & '
                            'Continue" to finish.',
                            style: TextStyle(
                              color: Color(0xFF1B5E20),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

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
                  enabled: fieldsEnabled,
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
                  enabled: fieldsEnabled,
                  validator: (v) => null,
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _lastNameController,
                  label: 'Last Name',
                  hint: 'Enter your last name',
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.name,
                  enabled: fieldsEnabled,
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
                  enabled: fieldsEnabled,
                  validator: (v) => null,
                ),
                const SizedBox(height: 14),

                _buildTextField(
                  controller: _mobileController,
                  label: 'Mobile Number',
                  hint: 'e.g. 09XXXXXXXXX',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  enabled: fieldsEnabled,
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

                // Barangay
                _buildDropdown(
                  label: 'Barangay',
                  hint: 'Select your barangay',
                  icon: Icons.home_work_outlined,
                  value: _selectedBarangay,
                  items: _barangays,
                  enabled: fieldsEnabled,
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
                  enabled: fieldsEnabled,
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
                  enabled: fieldsEnabled,
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
                _buildUploadIDCard(enabled: fieldsEnabled),

                const SizedBox(height: 28),
                _sectionHeader('Create Account'),
                const SizedBox(height: 16),

                // ── Email + inline "Get Code" ────────────────────────
                _buildEmailField(),

                const SizedBox(height: 14),

                _buildTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Create a password',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  enabled: fieldsEnabled,
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
                    if (v.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // ── Verification Code (now after Password) ──────────
                _buildVerificationCodeField(),

                const SizedBox(height: 28),

                if (!_otpSent)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Fill in your details above, then tap "Get Code" next '
                      'to your email to receive a verification code and '
                      'create your account.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey[500],
                        height: 1.4,
                      ),
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: (!_otpSent || _isVerifying)
                        ? null
                        : _handleVerifyEmail,
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
                    child: _isVerifying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            'VERIFY & CONTINUE',
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

  /// Email field with a "Get Code" / "Resend" button positioned beside
  /// it (a real widget in a Row, not squeezed into suffixIcon — that
  /// approach clipped/hid the button).
  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF444466),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                readOnly: _otpSent,
                style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
                decoration: _inputDecoration(
                  'Enter your email',
                  Icons.email_outlined,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Email is required';
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(v)) {
                    return 'Enter a valid email address';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TextButton(
                onPressed: (_isSendingCode || _resendCooldown > 0)
                    ? null
                    : (_otpSent ? _handleResendCode : _handleGetCode),
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                ),
                child: _isSendingCode
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _resendCooldown > 0
                            ? 'Resend in ${_resendCooldown}s'
                            : (_otpSent ? 'Resend' : 'Get Code'),
                        style: TextStyle(
                          color: _resendCooldown > 0
                              ? Colors.grey[500]
                              : const Color(0xFFD32F2F),
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Verification code field — now rendered after Password in the form,
  /// but still driven by the same `_otpSent` / `_resendCooldown` state
  /// from the email block above it.
  Widget _buildVerificationCodeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Verification Code',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF444466),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 6,
            color: Color(0xFF1A1A2E),
          ),
          decoration: _inputDecoration(
            'Enter the 6-digit code',
            Icons.mail_outline,
          ).copyWith(counterText: ''),
        ),
        const SizedBox(height: 4),
        Text(
          _otpSent
              ? (_resendCooldown > 0
                    ? 'Code sent to ${_emailController.text.trim()}. '
                          'Didn\'t get it? You can resend in ${_resendCooldown}s.'
                    : 'Code sent to ${_emailController.text.trim()}. '
                          'Still nothing? Tap Resend above.')
              : 'Tap "Get Code" above to receive your verification code.',
          style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildUploadIDCard({required bool enabled}) {
    final bool uploaded = _uploadedFileName != null;
    return GestureDetector(
      onTap: enabled ? _handleUploadID : null,
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
                  if (enabled)
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
    bool enabled = true,
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
          enabled: enabled,
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
    bool enabled = true,
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
          onChanged: enabled ? onChanged : null,
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
