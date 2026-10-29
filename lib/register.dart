import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart' as cam;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';
import 'id_photo_quality.dart';
import 'login.dart';
import 'push_notification.dart';
import 'home.dart';

/// Create Account — step by step (panel revisions #3, #14, #15, #16).
///
///   Step 1  Personal Information   name, municipality, barangay, street, zone
///   Step 2  Proof of Residency     take a photo of a valid ID inside an
///                                  on-screen frame. Every photo is checked
///                                  for blur, darkness and glare. A blurry
///                                  photo can only be retaken (no Use Photo,
///                                  item 52); otherwise the resident chooses
///                                  Retake Photo or Use Photo.
///   Step 3  Account                "Verify using one:" Email or Mobile
///                                  Number, then the contact details,
///                                  password, and the 6-digit code.
///
/// The choice decides how the resident logs in:
///   Email          email + mobile number (so MDRRMO can call during an
///                  emergency). Logs in with the email; the code is emailed.
///   Mobile Number  mobile number only — no email. Logs in with the number;
///                  the code is texted.
///
/// Nothing is sent to the server until "Send Code" on step 3 — that single
/// call creates the account and sends the code (POST /api/register, with
/// `verify_via` = email | sms).
///
/// After "Send Code" everything stays editable. If the resident changes
/// anything (a mistyped email, say), the code entry is replaced by
/// "Send New Code": the form is sent again with `previous_email` /
/// `previous_password`, the server replaces the unfinished sign-up, and a
/// new code goes to the corrected email or number.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with WidgetsBindingObserver {
  // One form for all steps. Only the current step's fields are built, so
  // validate() only ever checks the step the resident is on.
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _suffixController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();

  // "Wrong email? Change it" puts the cursor back in the field.
  final _emailFocus = FocusNode();
  final _mobileFocus = FocusNode();

  // Municipality is fixed to Rosales — no selection needed
  static const String _municipality = 'Rosales';

  String? _selectedBarangay;
  String? _selectedStreet;
  String? _selectedZone;

  bool _obscurePassword = true;
  bool _isSendingCode = false;
  bool _isVerifying = false;

  // The red error box, shown right above the step's main button. Set it
  // with _showError() so it shakes, vibrates and scrolls into view.
  String? _errorMessage;
  int _errorTick = 0; // a new value replays the shake
  final GlobalKey _errorKey = GlobalKey();

  // ── Steps ─────────────────────────────────────────────────────────
  // 0 = Personal Information, 1 = Proof of Residency, 2 = Account
  int _step = 0;
  static const List<String> _stepTitles = [
    'Personal\nInfo',
    'Proof of\nResidency',
    'Account',
  ];

  // ── Proof of residency (ID photo) ─────────────────────────────────
  // Width : height of the on-screen ID frame. Camera photos are checked
  // only inside this frame (see IdPhotoQuality.analyze).
  static const double _idFrameAspect = 1.5;

  cam.CameraController? _cameraController;
  bool _cameraReady = false;
  String? _cameraError;
  bool _isCapturing = false;
  bool _cameraPausedByApp = false;

  // A photo that was just taken (or picked) and is waiting for
  // "Retake Photo" or "Use Photo".
  File? _reviewPhoto;
  bool _reviewFromGallery = false;
  bool _checkingPhoto = false;
  IdPhotoQuality? _photoQuality;

  /// The check found the photo being reviewed blurry. It can't be used —
  /// "Use Photo" isn't shown, only Retake Photo (item 52). A dark photo or
  /// one with glare only gets a warning.
  bool get _reviewIsBlurry =>
      _reviewPhoto != null &&
      !_checkingPhoto &&
      _photoQuality?.isBlurry == true;

  // The photo the resident chose to use — this is what gets uploaded.
  File? _uploadedFile;
  bool _acceptedFromGallery = false;

  final ImagePicker _picker = ImagePicker();

  // ── Verification ──────────────────────────────────────────────────
  // Where the 6-digit code is sent: 'email' or 'sms' (mobile number).
  // Null until the resident picks one.
  String? _verifyVia;

  // SMS needs an SMS gateway on the server. The app asks the server once
  // (GET /api/verification-options); until it says SMS is ready, the
  // "Mobile Number" choice is shown but disabled.
  bool _smsAvailable = false;

  // ── After "Send Code" ─────────────────────────────────────────────
  // The account exists on the server but isn't finished until the code is
  // entered. These hold what that "Send Code" sent; all null before it.

  /// Every detail that was sent, as one string (see [_formValues]).
  String? _sentValues;
  String? _sentEmail;
  String? _sentMobile;
  String? _sentPassword;

  /// Where the code went: 'email' or 'sms'.
  String? _sentVia;

  // Resend cooldown — after a code is sent, "Resend code" turns into a
  // disabled countdown so the endpoint can't be hammered.
  Timer? _resendTimer;
  int _resendCooldown = 0;
  static const int _resendCooldownSeconds = 60;

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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSmsAvailability();
  }

  Future<void> _checkSmsAvailability() async {
    final bool available = await ApiService.isSmsVerificationAvailable();
    if (!mounted) return;
    setState(() {
      _smsAvailable = available;
      if (!available && _verifyVia == 'sms') _verifyVia = null;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _suffixController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _emailFocus.dispose();
    _mobileFocus.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  /// Frees the camera while the app is in the background and reopens it
  /// when the resident comes back (needed on Android).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cam.CameraController? controller = _cameraController;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Nothing to free if the camera never finished opening — e.g. the
      // camera permission dialog is what made the app "inactive".
      if (controller == null || !controller.value.isInitialized) return;
      _cameraPausedByApp = true;
      if (mounted) {
        setState(_disposeCamera);
      } else {
        _disposeCamera();
      }
    } else if (state == AppLifecycleState.resumed && _cameraPausedByApp) {
      _cameraPausedByApp = false;
      if (_needsCamera) _initCamera();
    }
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

  /// Where the code was sent, for the messages on step 3.
  String get _codeDestination =>
      (_sentVia == 'sms' ? _sentMobile : _sentEmail) ?? '';

  /// Every detail that goes to the server, as one string — used to tell
  /// whether anything changed after the code was sent.
  String _formValues() => [
    _firstNameController.text.trim(),
    _middleNameController.text.trim(),
    _lastNameController.text.trim(),
    _suffixController.text.trim(),
    _selectedBarangay ?? '',
    _selectedStreet ?? '',
    _selectedZone ?? '',
    _uploadedFile?.path ?? '',
    _mobileController.text.trim(),
    // A mobile-number account has no email.
    _verifyVia == 'sms' ? '' : _emailController.text.trim(),
    _passwordController.text,
  ].join('\u0000');

  /// A code was sent and nothing changed since — show the code entry.
  bool get _waitingForCode =>
      _sentValues != null &&
      _verifyVia == _sentVia &&
      _formValues() == _sentValues;

  /// A code was sent, but the resident changed something afterwards.
  bool get _changedAfterSend => _sentValues != null && !_waitingForCode;

  /// Typing in an account field after the code was sent switches step 3
  /// between the code entry and "Send New Code".
  void _onAccountFieldChanged(String _) {
    if (_sentValues != null) setState(() {});
  }

  /// "Wrong email? Change it" — puts the cursor at the end of the email
  /// (or mobile number) field so the resident can fix it.
  void _changeContact() {
    final bool bySms = _sentVia == 'sms';
    final TextEditingController controller = bySms
        ? _mobileController
        : _emailController;
    (bySms ? _mobileFocus : _emailFocus).requestFocus();
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  // ── Step navigation ───────────────────────────────────────────────

  /// The live camera is only needed on step 2 while there's no photo yet.
  bool get _needsCamera =>
      _step == 1 && _uploadedFile == null && _reviewPhoto == null;

  void _goNext() {
    FocusScope.of(context).unfocus();

    if (_step == 0) {
      if (!_formKey.currentState!.validate()) return;
      setState(() {
        _errorMessage = null;
        _step = 1;
      });
      if (_needsCamera) _initCamera();
      return;
    }

    if (_step == 1) {
      if (_reviewPhoto != null) {
        _showError(
          _reviewIsBlurry
              ? 'This photo is blurry. Retake it to continue.'
              : 'Tap "Use Photo" to keep this photo, or retake it.',
        );
        return;
      }
      if (_uploadedFile == null) {
        _showError('Please take a photo of your ID to continue.');
        return;
      }
      setState(() {
        _errorMessage = null;
        _disposeCamera();
        _step = 2;
      });
    }
  }

  /// Back arrow / system back. Goes to the previous step; leaves the screen
  /// from step 1. After "Send Code" the resident can still go back and fix
  /// anything — step 3 then offers "Send New Code".
  void _goBack() {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _errorMessage = null;
      if (_step == 1) _disposeCamera();
      _step -= 1;
    });
    if (_needsCamera) _initCamera();
  }

  // ── Camera ────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    if (_cameraController != null || !mounted) return;
    setState(() {
      _cameraError = null;
      _cameraReady = false;
    });

    try {
      final List<cam.CameraDescription> cameras = await cam.availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(
          () => _cameraError =
              'No camera found on this phone. Upload a photo from your '
              'gallery instead.',
        );
        return;
      }

      final cam.CameraDescription backCamera = cameras.firstWhere(
        (c) => c.lensDirection == cam.CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final cam.CameraController controller = cam.CameraController(
        backCamera,
        cam.ResolutionPreset.veryHigh,
        enableAudio: false,
      );
      _cameraController = controller;

      await controller.initialize();
      // Flash makes glare on ID cards — keep it off.
      try {
        await controller.setFlashMode(cam.FlashMode.off);
      } catch (_) {}

      if (!mounted || _cameraController != controller) {
        await controller.dispose();
        return;
      }
      setState(() => _cameraReady = true);
    } catch (e) {
      final cam.CameraController? failed = _cameraController;
      _cameraController = null;
      try {
        await failed?.dispose();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _cameraReady = false;
        _cameraError =
            'The camera could not be opened. Allow camera access in your '
            'phone settings, or upload a photo from your gallery.';
      });
    }
  }

  void _disposeCamera() {
    final cam.CameraController? controller = _cameraController;
    _cameraController = null;
    _cameraReady = false;
    controller?.dispose();
  }

  Future<void> _takeIdPhoto() async {
    final cam.CameraController? controller = _cameraController;
    if (controller == null ||
        !_cameraReady ||
        _isCapturing ||
        controller.value.isTakingPicture) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => _isCapturing = true);

    try {
      final shot = await controller.takePicture();
      if (!mounted) return;
      setState(() => _isCapturing = false);
      await _reviewNewPhoto(File(shot.path), fromGallery: false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCapturing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not take the photo. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1600,
      );
      if (picked == null || !mounted) return;
      await _reviewNewPhoto(File(picked.path), fromGallery: true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open your gallery: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Shows the new photo and checks it for blur, darkness and glare
  /// (panel revision #3). A blurry photo can't be used, only retaken
  /// (item 52); darkness and glare only warn — the resident decides.
  Future<void> _reviewNewPhoto(File file, {required bool fromGallery}) async {
    setState(() {
      _reviewPhoto = file;
      _reviewFromGallery = fromGallery;
      _photoQuality = null;
      _checkingPhoto = true;
      _errorMessage = null;
    });

    final IdPhotoQuality? quality = await IdPhotoQuality.analyze(
      file,
      frameAspect: fromGallery ? null : _idFrameAspect,
    );
    if (!mounted || _reviewPhoto != file) return;

    setState(() {
      _photoQuality = quality;
      _checkingPhoto = false;
    });
  }

  void _clearReview() {
    _reviewPhoto = null;
    _photoQuality = null;
    _checkingPhoto = false;
  }

  /// "Retake Photo" while reviewing — back to the camera (or the gallery,
  /// if that's where the photo came from).
  void _retakePhoto() {
    final bool fromGallery = _reviewFromGallery;
    setState(_clearReview);
    if (fromGallery) {
      _pickFromGallery();
    } else {
      _initCamera(); // does nothing if the camera is still open
    }
  }

  /// "Use Photo" — keeps the photo and moves on to the Account step. Not
  /// for a blurry photo (the button isn't shown then).
  void _usePhoto() {
    final File? file = _reviewPhoto;
    if (file == null || _checkingPhoto || _reviewIsBlurry) return;
    setState(() {
      _uploadedFile = file;
      _acceptedFromGallery = _reviewFromGallery;
      _clearReview();
      _errorMessage = null;
      _disposeCamera();
      _step = 2;
    });
  }

  /// Throws the saved photo away and opens the camera again.
  void _retakeSavedPhoto() {
    setState(() {
      _uploadedFile = null;
      _acceptedFromGallery = false;
    });
    _initCamera();
  }

  /// Delete button on the saved photo (panel revision #14).
  Future<void> _confirmDeletePhoto() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this photo?'),
        content: const Text(
          'You will need to take a new photo of your ID to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true && mounted) _retakeSavedPhoto();
  }

  // ── Account creation + verification (step 3) ──────────────────────

  /// "Send Code" — creates the account and sends the code to the email or
  /// mobile number the resident chose.
  ///
  /// "Send New Code" (details changed after a code was sent) is the same
  /// call plus the email and password the last one used, so the server
  /// replaces that unfinished sign-up (Api\AuthController::register).
  Future<void> _handleGetCode() async {
    FocusScope.of(context).unfocus();

    if (_verifyVia == null) {
      _showError('Choose Email or Mobile Number first.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    // Safety net — step 2 already requires the photo.
    if (_uploadedFile == null) {
      setState(() => _step = 1);
      _showError('Please take a photo of your ID to continue.');
      if (_needsCamera) _initCamera();
      return;
    }

    // Taken before the request, so edits made while it's sending don't
    // count as "sent".
    final String via = _verifyVia!;
    final bool correcting = _sentValues != null;
    final String values = _formValues();
    // A mobile-number account has no email — it logs in with the number.
    final String email = via == 'sms' ? '' : _emailController.text.trim();
    final String mobile = _mobileController.text.trim();
    final String password = _passwordController.text;

    setState(() {
      _isSendingCode = true;
      _errorMessage = null;
    });

    final result = await ApiService.register(
      firstName: _firstNameController.text.trim(),
      middleName: _middleNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      suffix: _suffixController.text.trim(),
      mobile: mobile,
      municipality: _municipality,
      barangay: _selectedBarangay ?? '',
      street: _selectedStreet ?? '',
      zone: _selectedZone ?? '',
      email: via == 'sms' ? null : email,
      password: password,
      validId: _uploadedFile,
      verifyVia: via,
      previousEmail: _sentEmail,
      previousMobile: _sentMobile,
      previousPassword: _sentPassword,
    );

    if (!mounted) return;
    setState(() => _isSendingCode = false);

    if (result.success) {
      final data = result.data;
      // The server says if the code could not be delivered (the account is
      // still created — "Resend code" tries again).
      final bool codeSent = !(data is Map && data['code_sent'] == false);
      final String sentVia = (data is Map && data['verify_via'] is String)
          ? data['verify_via'] as String
          : via;
      setState(() {
        _sentValues = values;
        _sentEmail = email;
        _sentMobile = mobile;
        _sentPassword = password;
        _sentVia = sentVia;
        _verifyVia = sentVia;
        _otpController.clear();
      });
      if (codeSent) _startResendCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !codeSent
                ? 'Your account was created, but the code could not be sent. Tap "Resend code".'
                : correcting
                ? 'Details updated. We sent a new code to $_codeDestination.'
                : (sentVia == 'sms'
                      ? 'We sent a verification code to your mobile number.'
                      : 'We sent a verification code to your email.'),
          ),
          backgroundColor: codeSent
              ? const Color(0xFF1A3A8F)
              : Colors.orange[800],
        ),
      );
    } else {
      _showError(result.error);
    }
  }

  /// Sends a fresh code to where the last one went — the email, or the
  /// mobile number for a mobile-number account. Returns whether it worked.
  Future<bool> _handleResendCode() async {
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
      return false;
    }

    final String target = _sentVia ?? 'email';
    final bool bySms = target == 'sms';
    setState(() => _isSendingCode = true);

    final result = await ApiService.resendVerificationOtp(
      email: bySms ? null : (_sentEmail ?? _emailController.text.trim()),
      mobile: bySms ? (_sentMobile ?? _mobileController.text.trim()) : null,
      verifyVia: target,
    );

    if (!mounted) return false;
    setState(() {
      _isSendingCode = false;
      if (result.success) {
        _sentVia = target;
        _verifyVia = target;
      }
    });

    if (result.success) _startResendCooldown();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'A new code was sent to $_codeDestination'
              : (result.error ?? 'Could not resend code.'),
        ),
        backgroundColor: result.success ? const Color(0xFF1A3A8F) : Colors.red,
      ),
    );
    return result.success;
  }

  /// Final action — verifies the code, then logs straight into Home.
  ///
  /// Sanitizes the code before checking its length — some keyboards /
  /// autofill bars insert spaces or dashes that trim() doesn't remove.
  Future<void> _handleVerifyEmail() async {
    final code = _otpController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (code.length != 6) {
      _showError(
        'Please enter the 6-digit code (currently ${code.length} digit${code.length == 1 ? '' : 's'}).',
      );
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final bool bySms = _sentVia == 'sms';
    final result = await ApiService.verifyEmail(
      email: bySms ? null : (_sentEmail ?? _emailController.text.trim()),
      mobile: bySms ? (_sentMobile ?? _mobileController.text.trim()) : null,
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
      _showError(result.error);
    }
  }

  /// Shows [message] in the red error box right above the step's main
  /// button, with a shake and a short vibration so it isn't missed, and
  /// scrolls the box into view if it's off screen.
  void _showError(String? message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = (message == null || message.trim().isEmpty)
          ? 'Something went wrong. Please try again.'
          : message;
      _errorTick++;
    });
    HapticFeedback.vibrate();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final BuildContext? box = _errorKey.currentContext;
      if (box == null || !box.mounted) return;
      const Duration scroll = Duration(milliseconds: 300);
      // Scrolls only if the box is below or above what's on screen.
      await Scrollable.ensureVisible(
        box,
        duration: scroll,
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
      if (!box.mounted) return;
      await Scrollable.ensureVisible(
        box,
        duration: scroll,
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // System back goes to the previous step instead of closing the screen.
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
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
            onPressed: _goBack,
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
          child: Column(
            children: [
              _buildStepHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Errors show right above each step's main button
                        // (see _errorSlot), where the resident just tapped.
                        if (_step == 0) ..._buildPersonalInfoStep(),
                        if (_step == 1) ..._buildProofOfResidencyStep(),
                        if (_step == 2) ..._buildAccountStep(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 1 ── 2 ── 3 progress header.
  Widget _buildStepHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_stepTitles.length * 2 - 1, (i) {
          if (i.isOdd) {
            final bool done = _step > i ~/ 2;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(top: 14, left: 6, right: 6),
                color: done ? const Color(0xFF1A3A8F) : Colors.grey[300],
              ),
            );
          }
          final int index = i ~/ 2;
          final bool active = _step == index;
          final bool done = _step > index;
          return Column(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (active || done)
                      ? const Color(0xFF1A3A8F)
                      : Colors.white,
                  border: Border.all(
                    color: (active || done)
                        ? const Color(0xFF1A3A8F)
                        : Colors.grey[400]!,
                    width: 1.5,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: active ? Colors.white : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
              ),
              const SizedBox(height: 4),
              Text(
                _stepTitles[index],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                  color: active ? const Color(0xFF1A3A8F) : Colors.grey[600],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  // ── Step 1: Personal Information ──────────────────────────────────

  List<Widget> _buildPersonalInfoStep() {
    return [
      _sectionHeader('Personal Information'),
      const SizedBox(height: 16),
      _buildTextField(
        controller: _firstNameController,
        label: 'First Name',
        hint: 'Enter your first name',
        icon: Icons.person_outline,
        keyboardType: TextInputType.name,
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'First name is required' : null,
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
            (v == null || v.trim().isEmpty) ? 'Last name is required' : null,
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
      _buildMunicipalityTile(),
      const SizedBox(height: 14),
      _buildDropdown(
        label: 'Barangay',
        hint: 'Select your barangay',
        icon: Icons.home_work_outlined,
        value: _selectedBarangay,
        items: _barangays,
        onChanged: (v) => setState(() => _selectedBarangay = v),
        validator: (v) => v == null ? 'Please select a barangay' : null,
      ),
      const SizedBox(height: 14),
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
      _buildDropdown(
        label: 'Zone',
        hint: 'Select your zone',
        icon: Icons.map_outlined,
        value: _selectedZone,
        items: _zones,
        onChanged: (v) => setState(() => _selectedZone = v),
        validator: (v) => v == null ? 'Please select a zone' : null,
      ),
      const SizedBox(height: 28),
      ..._errorSlot(),
      _primaryButton(label: 'NEXT', onPressed: _goNext),
    ];
  }

  // ── Step 2: Proof of Residency ────────────────────────────────────

  List<Widget> _buildProofOfResidencyStep() {
    final bool canContinue = _uploadedFile != null && _reviewPhoto == null;
    return [
      _sectionHeader('Proof of Residency'),
      const SizedBox(height: 10),
      Text(
        'Take a photo of a valid ID that shows your address in Rosales, '
        'Pangasinan. MDRRMO uses this to verify that you are a resident.',
        style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.45),
      ),
      const SizedBox(height: 16),
      _buildIdFrame(),
      const SizedBox(height: 14),
      ..._buildIdPhotoControls(),
      const SizedBox(height: 24),
      ..._errorSlot(),
      Row(
        children: [
          Expanded(
            child: _secondaryButton(label: 'BACK', onPressed: _goBack),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _primaryButton(
              label: 'NEXT',
              onPressed: canContinue ? _goNext : null,
            ),
          ),
        ],
      ),
    ];
  }

  /// The ID frame: live camera with a guide, the photo being reviewed, or
  /// the saved photo (with its Delete button).
  Widget _buildIdFrame() {
    final File? reviewing = _reviewPhoto;
    final File? saved = _uploadedFile;
    final File? shown = reviewing ?? saved;
    final bool shownFromGallery = reviewing != null
        ? _reviewFromGallery
        : _acceptedFromGallery;

    Widget content;
    if (shown != null) {
      // Camera photos fill the frame the same way the preview did; gallery
      // photos are shown whole so no part of the ID is cut off.
      content = Image.file(
        shown,
        fit: shownFromGallery ? BoxFit.contain : BoxFit.cover,
      );
    } else if (_cameraReady && _cameraController != null) {
      final Size? previewSize = _cameraController!.value.previewSize;
      content = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize?.height ?? 1,
          height: previewSize?.width ?? 1,
          child: cam.CameraPreview(_cameraController!),
        ),
      );
    } else {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _cameraError != null
                  ? Icons.no_photography_outlined
                  : Icons.camera_alt_outlined,
              size: 34,
              color: Colors.white54,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _cameraError ?? 'Opening camera...',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: _idFrameAspect,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF111827)),
            content,
            if (shown == null && _cameraReady) _buildIdGuideOverlay(),
            if (_isCapturing)
              const ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            if (saved != null && reviewing == null) ...[
              Positioned(top: 10, left: 10, child: _savedBadge()),
              Positioned(top: 8, right: 8, child: _deleteButton()),
            ],
          ],
        ),
      ),
    );
  }

  /// White guide box over the live camera.
  Widget _buildIdGuideOverlay() {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.9),
                    width: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Fit your ID inside the box · avoid glare',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _savedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D32).withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, color: Colors.white, size: 14),
          SizedBox(width: 5),
          Text(
            'ID PHOTO SAVED',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Panel revision #14 — a labelled Delete button in the top-right corner
  /// instead of a small "x".
  Widget _deleteButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _confirmDeletePhoto,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline, color: Colors.red, size: 16),
              SizedBox(width: 4),
              Text(
                'Delete',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Buttons under the frame, depending on where the resident is.
  List<Widget> _buildIdPhotoControls() {
    // Reviewing a new photo: the check result + Retake Photo / Use Photo.
    if (_reviewPhoto != null) {
      final String retakeLabel = _reviewFromGallery
          ? 'CHOOSE ANOTHER'
          : 'RETAKE PHOTO';
      final IconData retakeIcon = _reviewFromGallery
          ? Icons.photo_library_outlined
          : Icons.camera_alt_outlined;

      // A blurry photo can't be used (item 52): no Use Photo, only Retake.
      if (_reviewIsBlurry) {
        return [
          _buildPhotoCheckResult(),
          const SizedBox(height: 14),
          _primaryButton(
            label: retakeLabel,
            icon: retakeIcon,
            onPressed: _retakePhoto,
          ),
        ];
      }

      return [
        _buildPhotoCheckResult(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _secondaryButton(
                label: retakeLabel,
                icon: retakeIcon,
                onPressed: _retakePhoto,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _primaryButton(
                label: 'USE PHOTO',
                icon: Icons.check,
                onPressed: _checkingPhoto ? null : _usePhoto,
              ),
            ),
          ],
        ),
      ];
    }

    // A photo is already saved.
    if (_uploadedFile != null) {
      return [
        Text(
          'Your ID photo is saved. Retake it if your name or address is hard '
          'to read.',
          style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        _secondaryButton(
          label: 'RETAKE PHOTO',
          icon: Icons.camera_alt_outlined,
          onPressed: _retakeSavedPhoto,
        ),
      ];
    }

    // Live camera.
    return [
      _primaryButton(
        label: 'TAKE PHOTO',
        icon: Icons.camera_alt_outlined,
        onPressed: (_cameraReady && !_isCapturing) ? _takeIdPhoto : null,
        loading: _isCapturing,
      ),
      if (_cameraError != null) ...[
        const SizedBox(height: 10),
        _secondaryButton(
          label: 'TRY CAMERA AGAIN',
          icon: Icons.refresh,
          onPressed: _initCamera,
        ),
      ],
      const SizedBox(height: 6),
      Center(
        child: TextButton.icon(
          onPressed: _pickFromGallery,
          icon: const Icon(Icons.photo_library_outlined, size: 18),
          label: const Text('Upload a photo from your gallery instead'),
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF00897B)),
        ),
      ),
    ];
  }

  /// Result of the blur / darkness / glare check (panel revision #3).
  Widget _buildPhotoCheckResult() {
    if (_checkingPhoto) {
      return Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Checking the photo...',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      );
    }

    final IdPhotoQuality? quality = _photoQuality;

    // Blurry: it can't be used, so it's red, not a warning (item 52).
    if (quality != null && quality.isBlurry) {
      final String fix = _reviewFromGallery
          ? 'Choose a clearer photo, or take one with the camera.'
          : (quality.advice ?? '');
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF1A7A0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.blur_on_rounded,
              color: Color(0xFFC62828),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quality.title ?? 'The photo is blurry.',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Color(0xFF7F1D1D),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'MDRRMO has to read your name and address, so a blurry '
                    'photo can\'t be used. $fix',
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Color(0xFF991B1B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (quality != null && !quality.isClear) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7E6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF5C26B)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFB45309),
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quality.title ?? 'Check your photo.',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: Color(0xFF78350F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    quality.advice ?? '',
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF2E7D32),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              quality != null
                  ? 'The photo looks clear. Check that your name and address '
                        'are readable.'
                  : 'Check that your name and address are easy to read.',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF1B5E20)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 3: Account ───────────────────────────────────────────────

  List<Widget> _buildAccountStep() {
    final bool waiting = _waitingForCode;
    final bool changed = _changedAfterSend;
    return [
      _sectionHeader('Create Account'),
      const SizedBox(height: 10),
      Text(
        'Choose how you\'ll log in. We\'ll send a 6-digit code there to '
        'verify your account.',
        style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.45),
      ),
      const SizedBox(height: 16),

      // Panel revision #15 — the resident chooses where the code goes.
      const Text(
        'Verify using one:',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF444466),
        ),
      ),
      const SizedBox(height: 8),
      _verifyOption(
        value: 'email',
        icon: Icons.email_outlined,
        label: 'Email',
        note: 'Log in with your email. We\'ll email the code.',
        enabled: true,
      ),
      const SizedBox(height: 10),
      _verifyOption(
        value: 'sms',
        icon: Icons.sms_outlined,
        label: 'Mobile Number',
        note: _smsAvailable
            ? 'Log in with your mobile number. No email needed.'
            : 'Not available yet — use Email for now',
        enabled: _smsAvailable,
      ),

      if (_verifyVia != null) ...[
        const SizedBox(height: 22),
        ..._buildContactFields(),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          hint: 'Create a password',
          icon: Icons.lock_outline,
          obscureText: _obscurePassword,
          onChanged: _onAccountFieldChanged,
          helper:
              'At least 8 characters, with upper & lower case letters and a number.',
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
          // Mirrors the server's rule (Api\AuthController::register —
          // Password::min(8)->mixedCase()->numbers()).
          validator: (v) {
            if (v == null || v.isEmpty) return 'Password is required';
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
        const SizedBox(height: 24),
        if (waiting)
          ..._buildCodeEntry()
        else ...[
          if (changed) ...[_buildChangedNotice(), const SizedBox(height: 14)],
          ..._errorSlot(),
          _primaryButton(
            label: changed ? 'SEND NEW CODE' : 'SEND CODE',
            onPressed: _handleGetCode,
            loading: _isSendingCode,
          ),
        ],
      ],
    ];
  }

  /// Email: the email (log in + code) and the mobile number, so MDRRMO can
  /// call the resident during an emergency (panel revision #16 moved it
  /// here). Mobile Number: only the mobile number — it's how they log in
  /// and where the code is texted; no email is asked.
  List<Widget> _buildContactFields() {
    final bool bySms = _verifyVia == 'sms';

    final Widget mobileField = KeyedSubtree(
      key: const ValueKey('mobile-field'),
      child: _buildTextField(
        controller: _mobileController,
        focusNode: _mobileFocus,
        label: 'Mobile Number',
        hint: 'e.g. 09XXXXXXXXX',
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
        onChanged: _onAccountFieldChanged,
        helper: bySms
            ? 'You\'ll log in with this number. We\'ll text your 6-digit code here.'
            : 'So MDRRMO can call you during an emergency.',
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(11),
        ],
        validator: (v) {
          if (v == null || v.isEmpty) return 'Mobile number is required';
          if (!RegExp(r'^09\d{9}$').hasMatch(v)) {
            return 'Enter a valid 11-digit mobile number (09XXXXXXXXX)';
          }
          return null;
        },
      ),
    );

    final Widget emailField = KeyedSubtree(
      key: const ValueKey('email-field'),
      child: _buildTextField(
        controller: _emailController,
        focusNode: _emailFocus,
        label: 'Email',
        hint: 'Enter your email',
        icon: Icons.email_outlined,
        keyboardType: TextInputType.emailAddress,
        onChanged: _onAccountFieldChanged,
        helper:
            'We\'ll send your 6-digit code here. You\'ll also use it to log in.',
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Email is required';
          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
            return 'Enter a valid email address';
          }
          return null;
        },
      ),
    );

    // A mobile-number account has no email.
    return bySms
        ? [mobileField]
        : [emailField, const SizedBox(height: 14), mobileField];
  }

  /// Shown on step 3 once the account is created and the code was sent.
  List<Widget> _buildCodeEntry() {
    final bool bySms = _sentVia == 'sms';
    return [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2E7D32)),
        ),
        child: Row(
          children: [
            Icon(
              bySms ? Icons.sms_outlined : Icons.mark_email_read_outlined,
              color: const Color(0xFF2E7D32),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'We sent a 6-digit code to $_codeDestination. '
                'Enter it below to finish creating your account.',
                style: const TextStyle(
                  color: Color(0xFF1B5E20),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      // A mistyped email / number can still be fixed: the field above is
      // editable, and changing it switches this to "Send New Code".
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _changeContact,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: Text(
            bySms ? 'Wrong number? Change it' : 'Wrong email? Change it',
          ),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF1A3A8F),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      _buildVerificationCodeField(),
      const SizedBox(height: 6),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          TextButton(
            onPressed: (_isSendingCode || _resendCooldown > 0)
                ? null
                : _handleResendCode,
            child: _isSendingCode
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _resendCooldown > 0
                        ? 'Resend in ${_resendCooldown}s'
                        : 'Resend code',
                    style: TextStyle(
                      color: _resendCooldown > 0
                          ? Colors.grey[500]
                          : const Color(0xFFD32F2F),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      ..._errorSlot(),
      _primaryButton(
        label: 'VERIFY & CONTINUE',
        onPressed: _handleVerifyEmail,
        loading: _isVerifying,
      ),
    ];
  }

  /// Shown on step 3 instead of the code entry when the resident changed
  /// something after the code was sent.
  Widget _buildChangedNotice() {
    final String typed =
        (_verifyVia == 'sms' ? _mobileController.text : _emailController.text)
            .trim();
    final String where = typed.isNotEmpty
        ? typed
        : (_verifyVia == 'sms' ? 'your mobile number' : 'your email');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB300)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.edit_note, color: Color(0xFFE65100), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'You changed your details. Tap "Send New Code" to save them '
              'and get a new code at $where. The code we sent before will '
              'stop working.',
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF5D4037),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _verifyOption({
    required String value,
    required IconData icon,
    required String label,
    required String note,
    required bool enabled,
  }) {
    final bool selected = _verifyVia == value;
    final Color color = enabled || selected
        ? const Color(0xFF1A3A8F)
        : Colors.grey;
    return GestureDetector(
      onTap: enabled
          ? () => setState(() {
              _verifyVia = value;
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

  // ── Shared pieces ─────────────────────────────────────────────────

  /// The error box and the space under it — or nothing when there's no
  /// error. Each step puts it right above its main button.
  List<Widget> _errorSlot() {
    final String? message = _errorMessage;
    if (message == null) return const [];
    return [_buildErrorBox(message), const SizedBox(height: 14)];
  }

  /// Solid red so it can't be missed. Shakes each time a new error is
  /// shown (see _showError).
  Widget _buildErrorBox(String message) {
    return KeyedSubtree(
      key: _errorKey,
      child: TweenAnimationBuilder<double>(
        key: ValueKey<int>(_errorTick),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        // A quick left-right shake that settles.
        builder: (context, t, child) => Transform.translate(
          offset: Offset(math.sin(t * math.pi * 6) * 10 * (1 - t), 0),
          child: child,
        ),
        child: Semantics(
          liveRegion: true, // read out by screen readers
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x59D32F2F),
                  blurRadius: 14,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    // Lines the first line up with the icon.
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
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

  /// Button label with an optional icon; scales down instead of
  /// overflowing when two buttons share a row on a small phone.
  Widget _buttonLabel(String label, IconData? icon) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 19), const SizedBox(width: 8)],
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A3A8F),
          disabledBackgroundColor: Colors.grey[300],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
          shadowColor: const Color(0xFF1A3A8F).withOpacity(0.4),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : _buttonLabel(label, icon),
      ),
    );
  }

  Widget _secondaryButton({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1A3A8F),
          side: const BorderSide(color: Color(0xFF1A3A8F), width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _buttonLabel(label, icon),
      ),
    );
  }

  Widget _buildMunicipalityTile() {
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
    );
  }

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
          _resendCooldown > 0
              ? 'Didn\'t get it? You can resend in ${_resendCooldown}s.'
              : 'Didn\'t get it? Tap "Resend code" below.',
          style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
        ),
      ],
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
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool enabled = true,
    String? helper,
    Widget? suffixIcon,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
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
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: obscureText,
          enabled: enabled,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          validator: validator,
          style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
          decoration: _inputDecoration(hint, icon, suffixIcon: suffixIcon),
        ),
        if (helper != null) ...[
          const SizedBox(height: 4),
          Text(
            helper,
            style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
          ),
        ],
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
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
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
