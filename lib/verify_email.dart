import 'package:flutter/material.dart';
import 'api_service.dart';
import 'home.dart';
import 'push_notification.dart';

/// Enter the sign-up code — opened from Login when the account isn't
/// verified yet. For an email account the code goes to [email]; for an
/// account that logs in with its mobile number (no email), it is texted to
/// [mobile].
class VerifyEmailScreen extends StatefulWidget {
  final String? email;
  final String? mobile;
  const VerifyEmailScreen({super.key, this.email, this.mobile})
    : assert(email != null || mobile != null);

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;

  /// An account that logs in with its mobile number: codes are texted.
  bool get _bySms => (widget.email == null || widget.email!.isEmpty);

  /// Where the code goes, for the messages on this screen.
  String get _destination => (_bySms ? widget.mobile : widget.email) ?? '';

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.verifyEmail(
      email: _bySms ? null : widget.email,
      mobile: _bySms ? widget.mobile : null,
      otp: _otpController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

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

  Future<void> _handleResend() async {
    setState(() => _isResending = true);
    final result = await ApiService.resendVerificationOtp(
      email: _bySms ? null : widget.email,
      mobile: _bySms ? widget.mobile : null,
    );
    if (!mounted) return;
    setState(() => _isResending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'A new code was sent to $_destination'
              : (result.error ?? 'Could not resend code.'),
        ),
        backgroundColor: result.success ? const Color(0xFF1A3A8F) : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _bySms ? 'Verify Your Number' : 'Verify Your Email',
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3A8F).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _bySms
                        ? Icons.sms_outlined
                        : Icons.mark_email_unread_outlined,
                    color: const Color(0xFF1A3A8F),
                    size: 36,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _bySms ? 'Check your text messages' : 'Check your email',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the 6-digit code we sent to $_destination to activate '
                  'your account. If it expired or never came, tap Resend.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

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
                  decoration: InputDecoration(
                    hintText: '000000',
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey[300]!,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1A3A8F),
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter the code';
                    if (v.length != 6) return 'Code must be 6 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleVerify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A3A8F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                            'VERIFY',
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
                    onPressed: _isResending ? null : _handleResend,
                    child: Text(
                      _isResending
                          ? 'Sending...'
                          : "Didn't receive a code? Resend",
                      style: const TextStyle(
                        color: Color(0xFF1A3A8F),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
