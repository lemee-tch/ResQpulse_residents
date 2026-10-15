import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

/// Personal Information → Change email / Add email / Change mobile number
/// / Verify mobile number.
///
/// Two steps: the new email or number (skipped when verifying the current
/// number), then the 6-digit code sent to it. Nothing on the account
/// changes until the code is entered. Pops with
/// {'citizen': <the updated profile>, 'message': <what changed>}.
///
/// While text messages can't be sent (SMS gateway off), the code for a new
/// number goes to the resident's email instead and the number shows as not
/// verified — the server decides that and says where the code went.
class ChangeContactScreen extends StatefulWidget {
  /// 'email' or 'mobile'.
  final String type;
  final Map<String, dynamic> citizen;

  /// Confirm the current number (not verified yet) instead of changing it.
  final bool verifyCurrent;

  const ChangeContactScreen({
    super.key,
    required this.type,
    required this.citizen,
    this.verifyCurrent = false,
  });

  @override
  State<ChangeContactScreen> createState() => _ChangeContactScreenState();
}

class _ChangeContactScreenState extends State<ChangeContactScreen> {
  static const Color _navy = Color(0xFF1A3A8F);
  static const Color _ink = Color(0xFF1A1A2E);
  static const Color _amber = Color(0xFFB45309);

  final _valueController = TextEditingController();
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();

  bool _codeStep = false;
  bool _busy = false;
  String? _error;

  // Where the code went (from the server).
  String _sentVia = 'email';
  String _sentTo = '';
  String _sentMessage = '';

  /// Whether texts can be sent right now (null while checking).
  bool? _smsAvailable;

  Timer? _timer;
  int _resendIn = 0;

  bool get _isEmail => widget.type == 'email';
  String get _currentEmail => (widget.citizen['email'] ?? '').toString().trim();
  String get _currentMobile =>
      (widget.citizen['mobile'] ?? '').toString().trim();
  bool get _hasEmail => _currentEmail.isNotEmpty;

  String get _title {
    if (widget.verifyCurrent) return 'Verify Mobile Number';
    if (_isEmail) return _hasEmail ? 'Change Email' : 'Add Email';
    return 'Change Mobile Number';
  }

  @override
  void initState() {
    super.initState();
    if (!_isEmail) _checkSms();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _valueController.dispose();
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _checkSms() async {
    final available = await ApiService.isSmsVerificationAvailable();
    if (mounted) setState(() => _smsAvailable = available);
  }

  /// "0917 123 4567", "+63 917…", "9171234567" → "09171234567"; null when
  /// it isn't a Philippine mobile number.
  static String? _normalizeMobile(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (RegExp(r'^09\d{9}$').hasMatch(digits)) return digits;
    if (RegExp(r'^639\d{9}$').hasMatch(digits)) {
      return '0${digits.substring(2)}';
    }
    if (RegExp(r'^9\d{9}$').hasMatch(digits)) return '0$digits';
    return null;
  }

  /// What's wrong with the typed email or number, if anything.
  String? _problemWith(String value) {
    if (_isEmail) {
      if (value.isEmpty) return 'Enter your new email.';
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
        return 'Enter a valid email address.';
      }
      if (value.toLowerCase() == _currentEmail.toLowerCase()) {
        return 'This is already your email.';
      }
      return null;
    }
    final number = _normalizeMobile(value);
    if (number == null) {
      return 'Enter a valid 11-digit mobile number (09XXXXXXXXX).';
    }
    if (number == _normalizeMobile(_currentMobile)) {
      return 'This is already your number.';
    }
    return null;
  }

  Future<void> _sendCode() async {
    final String value;
    if (widget.verifyCurrent) {
      value = _normalizeMobile(_currentMobile) ?? _currentMobile;
    } else {
      final typed = _valueController.text.trim();
      final problem = _problemWith(typed);
      if (problem != null) {
        setState(() => _error = problem);
        return;
      }
      value = _isEmail ? typed : _normalizeMobile(typed)!;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ApiService.requestContactChange(
      type: widget.type,
      value: value,
    );
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _busy = false;
        _error = result.error;
      });
      final wait = result.data is Map ? result.data['retry_after'] : null;
      if (_codeStep && wait is num && wait > 0) _startTimer(wait.toInt());
      return;
    }

    final data = result.data as Map;
    setState(() {
      _busy = false;
      _codeStep = true;
      _sentVia = data['sent_via']?.toString() ?? (_isEmail ? 'email' : 'sms');
      _sentTo = data['sent_to']?.toString() ?? value;
      _sentMessage = data['message']?.toString() ?? '';
      _codeController.clear();
    });
    _startTimer((data['resend_after'] as num?)?.toInt() ?? 60);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _codeFocus.requestFocus();
    });
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    setState(() => _resendIn = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      if (_resendIn == 0) timer.cancel();
    });
  }

  Future<void> _confirm() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await ApiService.confirmContactChange(
      type: widget.type,
      code: code,
    );
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _busy = false;
        _error = result.error;
      });
      return;
    }

    Navigator.pop(context, <String, dynamic>{
      'citizen': result.data['citizen'],
      'message': result.data['message']?.toString() ?? 'Saved.',
    });
  }

  void _useDifferent() {
    _timer?.cancel();
    setState(() {
      _codeStep = false;
      _error = null;
      _resendIn = 0;
      _codeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _ink, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _title,
          style: const TextStyle(
            color: _ink,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: _codeStep ? _codeStepChildren() : _valueStepChildren(),
        ),
      ),
    );
  }

  // ── Step 1: the new email or number ─────────────────────────────────

  List<Widget> _valueStepChildren() {
    final bool noTexting = !_isEmail && _smsAvailable == false;
    // A resident without an email logs in with their number and can only
    // get codes by text.
    final bool blocked = noTexting && (!_hasEmail || widget.verifyCurrent);

    return [
      _bigIcon(_isEmail ? Icons.alternate_email : Icons.smartphone),
      const SizedBox(height: 16),
      Text(
        widget.verifyCurrent
            ? 'Confirm your mobile number'
            : _isEmail
            ? (_hasEmail ? 'What\'s your new email?' : 'Add an email')
            : 'What\'s your new mobile number?',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _ink,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        _explanation(),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.45),
      ),
      const SizedBox(height: 22),

      if (!widget.verifyCurrent) ...[
        if (_isEmail ? _hasEmail : _currentMobile.isNotEmpty) ...[
          _currentRow(
            _isEmail ? 'Current email' : 'Current number',
            _isEmail ? _currentEmail : _currentMobile,
          ),
          const SizedBox(height: 14),
        ],
        Text(
          _isEmail ? 'New email' : 'New mobile number',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF444466),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _valueController,
          autofocus: true,
          enabled: !_busy && !blocked,
          keyboardType: _isEmail
              ? TextInputType.emailAddress
              : TextInputType.phone,
          textInputAction: TextInputAction.done,
          autocorrect: false,
          inputFormatters: _isEmail
              ? null
              : [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _sendCode(),
          style: const TextStyle(fontSize: 16, color: _ink),
          decoration: _fieldDecoration(
            hint: _isEmail ? 'name@example.com' : '09XXXXXXXXX',
            icon: _isEmail ? Icons.mail_outline : Icons.phone_outlined,
          ),
        ),
      ] else
        _currentRow('Mobile number', _currentMobile),

      if (!_isEmail && !_hasEmail && !widget.verifyCurrent) ...[
        const SizedBox(height: 12),
        _note(
          Icons.login,
          'You log in with your mobile number. After the change, use the '
          'new number to log in.',
        ),
      ],
      if (_isEmail && _hasEmail) ...[
        const SizedBox(height: 12),
        _note(
          Icons.login,
          'After the change, log in with the new email (or your mobile '
          'number).',
        ),
      ],

      if (_error != null) ...[const SizedBox(height: 16), _errorBox(_error!)],
      const SizedBox(height: 24),
      _primaryButton(
        label: widget.verifyCurrent ? 'Text Me a Code' : 'Send Code',
        onPressed: blocked ? null : _sendCode,
      ),
    ];
  }

  String _explanation() {
    if (_isEmail) {
      return _hasEmail
          ? 'We\'ll send a 6-digit code to the new email to confirm it\'s '
                'yours. Your email changes only after you enter the code.'
          : 'We\'ll send a 6-digit code to this email to confirm it\'s '
                'yours. You can then log in with it, and reset your password '
                'by email.';
    }
    if (widget.verifyCurrent) {
      return _smsAvailable == false
          ? 'Text messages aren\'t available right now, so your number '
                'can\'t be verified yet. Please try again later.'
          : 'We\'ll text a 6-digit code to your number to confirm it\'s '
                'yours.';
    }
    switch (_smsAvailable) {
      case true:
        return 'We\'ll text a 6-digit code to the new number to confirm '
            'it\'s yours. Your number changes only after you enter the code.';
      case false:
        return _hasEmail
            ? 'Text messages aren\'t available right now, so we\'ll send '
                  'the code to your email ($_currentEmail) instead. The new '
                  'number will show as not verified until it can be '
                  'confirmed by text.'
            : 'Text messages aren\'t available right now, so your number '
                  'can\'t be changed yet. Please try again later.';
      default:
        return 'We\'ll send a 6-digit code to confirm the change. Your '
            'number changes only after you enter the code.';
    }
  }

  // ── Step 2: the code ────────────────────────────────────────────────

  List<Widget> _codeStepChildren() {
    final bool byEmail = _sentVia == 'email';
    // The code for a new number went to the email (texts unavailable).
    final bool emailedInstead = byEmail && !_isEmail;

    return [
      _bigIcon(byEmail ? Icons.mark_email_read_outlined : Icons.sms_outlined),
      const SizedBox(height: 16),
      const Text(
        'Enter the code',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _ink,
        ),
      ),
      const SizedBox(height: 8),
      Text.rich(
        TextSpan(
          style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.45),
          children: [
            TextSpan(
              text: byEmail
                  ? 'We sent a 6-digit code to '
                  : 'We texted a 6-digit code to ',
            ),
            TextSpan(
              text: _sentTo,
              style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
            ),
            const TextSpan(text: '. It expires in 10 minutes.'),
          ],
        ),
        textAlign: TextAlign.center,
      ),
      if (emailedInstead && _sentMessage.isNotEmpty) ...[
        const SizedBox(height: 14),
        _note(Icons.info_outline, _sentMessage, color: _amber),
      ],
      const SizedBox(height: 24),

      TextField(
        controller: _codeController,
        focusNode: _codeFocus,
        enabled: !_busy,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.oneTimeCode],
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6),
        ],
        onChanged: (value) {
          if (_error != null) setState(() => _error = null);
          // All 6 digits in: check it right away.
          if (value.length == 6 && !_busy) _confirm();
        },
        onSubmitted: (_) => _confirm(),
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 12,
          color: _ink,
        ),
        decoration: _fieldDecoration(hint: '••••••').copyWith(
          hintStyle: TextStyle(
            fontSize: 28,
            letterSpacing: 12,
            color: Colors.grey[350],
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),

      if (_error != null) ...[const SizedBox(height: 16), _errorBox(_error!)],
      const SizedBox(height: 24),
      _primaryButton(label: 'Confirm', onPressed: _confirm),
      const SizedBox(height: 10),

      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Didn\'t get it?',
            style: TextStyle(fontSize: 13.5, color: Colors.grey[600]),
          ),
          TextButton(
            onPressed: (_busy || _resendIn > 0) ? null : _sendCode,
            style: TextButton.styleFrom(foregroundColor: _navy),
            child: Text(
              _resendIn > 0 ? 'Resend code in ${_resendIn}s' : 'Resend code',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      if (byEmail)
        Text(
          'Check your spam or junk folder if you don\'t see it.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: Colors.grey[500]),
        ),
      if (!widget.verifyCurrent)
        Center(
          child: TextButton(
            onPressed: _busy ? null : _useDifferent,
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: Text(
              _isEmail ? 'Use a different email' : 'Use a different number',
            ),
          ),
        ),
    ];
  }

  // ── Pieces ──────────────────────────────────────────────────────────

  Widget _bigIcon(IconData icon) {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: _navy.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: _navy, size: 34),
      ),
    );
  }

  Widget _currentRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _note(IconData icon, String text, {Color color = _navy}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: color, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFD32F2F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _navy,
          disabledBackgroundColor: Colors.grey[300],
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }

  InputDecoration _fieldDecoration({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: Colors.grey[500], size: 20),
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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _navy, width: 2),
      ),
    );
  }
}
