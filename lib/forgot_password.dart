import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';
import 'login.dart';

/// Forgot Password — the resident gets a 6-digit code, then sets a new
/// password with it.
///
///   Step 0  "Send the code to:" Email or Mobile Number.
///           Email          for accounts that log in with their email —
///                          the code goes to that email, as before.
///           Mobile Number  for accounts that log in with their mobile
///                          number (signed up with "Mobile Number", no
///                          email) — the code is texted to it
///                          (Api\AuthController::forgotPassword). Turned on
///                          only when the server can send texts
///                          (GET /api/verification-options), same as the
///                          Create Account screen.
///   Step 1  The code + the new password (POST /api/reset-password, with
///           the same email or mobile number).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Step 0 = choose where + enter email (and number), Step 1 = code + new password
  int _step = 0;
  bool _isLoading = false;
  String? _errorMessage;

  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  /// Where the code goes: 'email' or 'sms' (mobile number).
  String _via = 'email';

  /// Where the last code went — what step 1 talks about.
  String _sentVia = 'email';

  /// Texting needs an SMS gateway on the server; until it's ready the
  /// "Mobile Number" choice is shown but disabled.
  bool _smsAvailable = false;

  // After a code is sent, "Resend" waits a minute (the server allows one
  // text per number per minute).
  Timer? _resendTimer;
  int _resendCooldown = 0;
  static const int _resendCooldownSeconds = 60;

  @override
  void initState() {
    super.initState();
    _checkSmsAvailability();
  }

  Future<void> _checkSmsAvailability() async {
    final bool available = await ApiService.isSmsVerificationAvailable();
    if (!mounted) return;
    setState(() {
      _smsAvailable = available;
      if (!available && _via == 'sms') _via = 'email';
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _mobileController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

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

  /// Where the last code went, for the messages on step 1.
  String get _destination => _sentVia == 'sms'
      ? _mobileController.text.trim()
      : _emailController.text.trim();

  Future<void> _handleSendCode() async {
    // Only validate the email form when it's actually mounted (step 0).
    // On step 1, _emailFormKey isn't attached to anything, so skip validation.
    if (_step == 0 && !_emailFormKey.currentState!.validate()) return;

    await _sendCodeRequest();
  }

  Future<void> _handleResend() async {
    final String typed =
        (_sentVia == 'sms' ? _mobileController.text : _emailController.text)
            .trim();
    if (typed.isEmpty || _resendCooldown > 0) return;
    await _sendCodeRequest(isResend: true, via: _sentVia);
  }

  Future<void> _sendCodeRequest({bool isResend = false, String? via}) async {
    final String target = via ?? _via;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.forgotPassword(
      email: target == 'sms' ? null : _emailController.text.trim(),
      mobile: target == 'sms' ? _mobileController.text.trim() : null,
      via: target,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      setState(() {
        _step = 1;
        _sentVia = target;
        _via = target;
      });
      _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            target == 'sms'
                ? 'If an account logs in with $_destination, a code is on its way.'
                : (isResend
                      ? 'A new code was sent to $_destination'
                      : 'A 6-digit code was sent to $_destination'),
          ),
          backgroundColor: const Color(0xFF1A3A8F),
        ),
      );
    } else {
      setState(() => _errorMessage = result.error);
    }
  }

  Future<void> _handleResetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final bool bySms = _sentVia == 'sms';
    final result = await ApiService.resetPassword(
      email: bySms ? null : _emailController.text.trim(),
      mobile: bySms ? _mobileController.text.trim() : null,
      otp: _otpController.text.trim(),
      password: _newPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password reset successful. Please log in.'),
          backgroundColor: Color(0xFF1A3A8F),
        ),
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
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
            color: Color(0xFF1A1A2E),
            size: 20,
          ),
          onPressed: () {
            if (_step == 1) {
              setState(() {
                _step = 0;
                _errorMessage = null;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _step == 0 ? 'Forgot Password' : 'Reset Password',
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: _step == 0 ? _buildEmailStep() : _buildResetStep(),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    final bool bySms = _via == 'sms';

    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A8F).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset_rounded,
              color: Color(0xFF1A3A8F),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Forgot your password?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how you log in. We\'ll send a 6-digit code there, then '
            'you can set a new password.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 22),

          _buildLabel('Send the code to:'),
          const SizedBox(height: 8),
          _viaOption(
            value: 'email',
            icon: Icons.email_outlined,
            label: 'Email',
            note: 'If you log in with your email',
            enabled: true,
          ),
          const SizedBox(height: 10),
          _viaOption(
            value: 'sms',
            icon: Icons.sms_outlined,
            label: 'Mobile Number',
            note: _smsAvailable
                ? 'If you log in with your mobile number'
                : 'Not available yet — use Email for now',
            enabled: _smsAvailable,
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null) ...[
            _buildErrorBox(_errorMessage!),
            const SizedBox(height: 16),
          ],

          if (!bySms) ...[
            _buildLabel('Email'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
              decoration: _inputDecoration(
                'Enter your email',
                Icons.email_outlined,
              ).copyWith(helperText: 'The email you log in with.'),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter your email';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
          ] else ...[
            _buildLabel('Mobile Number'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _mobileController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
              decoration:
                  _inputDecoration(
                    'e.g. 09XXXXXXXXX',
                    Icons.phone_outlined,
                  ).copyWith(
                    helperText:
                        'The number you log in with. We\'ll text the code here.',
                  ),
              validator: (v) {
                if (v == null || v.isEmpty) {
                  return 'Please enter your mobile number';
                }
                if (!RegExp(r'^09\d{9}$').hasMatch(v)) {
                  return 'Enter a valid 11-digit mobile number (09XXXXXXXXX)';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSendCode,
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
                      'SEND CODE',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetStep() {
    final bool bySms = _sentVia == 'sms';

    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF1A3A8F).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              bySms ? Icons.sms_outlined : Icons.mark_email_read_outlined,
              color: const Color(0xFF1A3A8F),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Enter the code',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bySms
                ? 'If an account logs in with $_destination, we texted it a '
                      '6-digit code. It expires in 10 minutes.'
                : 'We sent a 6-digit code to $_destination. It expires in 10 minutes.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          if (_errorMessage != null) ...[
            _buildErrorBox(_errorMessage!),
            const SizedBox(height: 16),
          ],

          _buildLabel('6-Digit Code'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(
              fontSize: 20,
              color: Color(0xFF1A1A2E),
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
            ),
            decoration: _inputDecoration(
              '000000',
              Icons.pin_outlined,
            ).copyWith(counterText: ''),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter the code';
              if (v.length != 6) return 'Code must be 6 digits';
              return null;
            },
          ),
          const SizedBox(height: 16),

          _buildLabel('New Password'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
            decoration: _inputDecoration(
              'Create a new password',
              Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureNewPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey[500],
                  size: 22,
                ),
                onPressed: () =>
                    setState(() => _obscureNewPassword = !_obscureNewPassword),
              ),
            ),
            // Mirrors the server's rule (Api\AuthController::resetPassword —
            // Password::min(8)->mixedCase()->numbers()) so a citizen doesn't
            // enter a code + 6-char password, tap Reset, and only then
            // learn on the server's 422 that the password was too weak.
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter a new password';
              if (v.length < 8) return 'Password must be at least 8 characters';
              if (!RegExp(r'[A-Z]').hasMatch(v) ||
                  !RegExp(r'[a-z]').hasMatch(v)) {
                return 'Password must include upper and lower case letters';
              }
              if (!RegExp(r'[0-9]').hasMatch(v)) {
                return 'Password must include at least one number';
              }
              return null;
            },
          ),
          const SizedBox(height: 4),
          Text(
            'At least 8 characters, with upper & lower case letters and a number.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),

          _buildLabel('Confirm New Password'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
            decoration: _inputDecoration(
              'Re-enter your new password',
              Icons.lock_outline,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey[500],
                  size: 22,
                ),
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm your password';
              if (v != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleResetPassword,
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
                      'RESET PASSWORD',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: (_isLoading || _resendCooldown > 0)
                  ? null
                  : _handleResend,
              child: Text(
                _resendCooldown > 0
                    ? 'Didn\'t receive a code? Resend in ${_resendCooldown}s'
                    : "Didn't receive a code? Resend",
                style: TextStyle(
                  color: _resendCooldown > 0
                      ? Colors.grey[500]
                      : const Color(0xFF1A3A8F),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One "Send the code to:" choice — same look as Create Account step 3.
  Widget _viaOption({
    required String value,
    required IconData icon,
    required String label,
    required String note,
    required bool enabled,
  }) {
    final bool selected = _via == value;
    final Color color = enabled || selected
        ? const Color(0xFF1A3A8F)
        : Colors.grey;
    return GestureDetector(
      onTap: enabled
          ? () => setState(() {
              _via = value;
              _errorMessage = null;
            })
          : null,
      child: Opacity(
        opacity: (enabled || selected) ? 1 : 0.55,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF0F4FF) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? color : Colors.grey[300]!,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: color,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF444466),
      ),
    );
  }

  Widget _buildErrorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hint,
    IconData prefixIcon, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 15),
      prefixIcon: Icon(prefixIcon, color: Colors.grey[500], size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
