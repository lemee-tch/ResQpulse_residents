import 'package:flutter/material.dart';
import 'api_service.dart';
import 'login.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  // Step 0 = enter email, Step 1 = enter OTP + new password
  int _step = 0;
  bool _isLoading = false;
  String? _errorMessage;

  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    // Only validate the email form when it's actually mounted (step 0).
    // On step 1, _emailFormKey isn't attached to anything, so skip validation.
    if (_step == 0 && !_emailFormKey.currentState!.validate()) return;

    await _sendCodeRequest();
  }

  Future<void> _handleResend() async {
    if (_emailController.text.trim().isEmpty) return;
    await _sendCodeRequest(isResend: true);
  }

  Future<void> _sendCodeRequest({bool isResend = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.forgotPassword(
      email: _emailController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      setState(() => _step = 1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isResend
                ? 'A new code was sent to ${_emailController.text.trim()}'
                : 'A 6-digit code was sent to ${_emailController.text.trim()}',
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

    final result = await ApiService.resetPassword(
      email: _emailController.text.trim(),
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
            'Enter the email linked to your account and we\'ll send you a 6-digit code to reset your password.',
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

          _buildLabel('Email'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
            decoration: _inputDecoration(
              'Enter your email',
              Icons.email_outlined,
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter your email';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
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
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: Color(0xFF1A3A8F),
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
            'We sent a 6-digit code to ${_emailController.text.trim()}. It expires in 10 minutes.',
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
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please enter a new password';
              if (v.length < 6) return 'Password must be at least 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),

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
              if (v != _newPasswordController.text)
                return 'Passwords do not match';
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
              onPressed: _isLoading ? null : _handleResend,
              child: const Text(
                "Didn't receive a code? Resend",
                style: TextStyle(
                  color: Color(0xFF1A3A8F),
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
