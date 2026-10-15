import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import 'phone_call.dart';

/// Home → SOS. Three clear steps, shown in a step bar at the top:
///
///   1. Emergency  big tiles (Fire, Flood, Accident…); tapping one goes on.
///                 "Other" asks what it is first.
///   2. Photo      the camera with its own shutter button, or "Continue
///                 without a photo".
///   3. Send       a review of what will be sent, and the big SOS button,
///                 which sends it.
///
/// Before, the type was picked from a dropdown and the big SOS button only
/// took the photo ("Tap once to capture a photo"), which wasn't what people
/// expected an SOS button to do.
///
/// Always on screen: whether the location is ready (with a button to fix
/// it when location is off or not allowed), Call #2441 in the top bar, and
/// for guests the name and number being sent. The phone's Back button goes
/// to the previous step. Nothing is sent until SOS is pressed on step 3.
class SOSScreen extends StatefulWidget {
  final bool isGuest;
  const SOSScreen({super.key, this.isGuest = false});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const Color _red = Color(0xFFD32F2F);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _ink = Color(0xFF1A1A2E);

  // ── Steps ──
  bool _typeConfirmed = false; // step 1 done → the camera is shown
  bool _isCapturing = false;
  bool _awaitingConfirm = false; // step 2 done (photo taken or skipped)
  bool _isSending = false;
  bool _sosSent = false;
  String? _sendError;

  /// 0 = Emergency, 1 = Photo, 2 = Send.
  int get _step => !_typeConfirmed ? 0 : (_awaitingConfirm ? 2 : 1);

  // ── Type of Emergency ──
  // Sent with the SOS so MDRRMO sees more than a bare "SOS Emergency"
  // (e.g. "SOS Alert — Accident"), and passed to the backend as a hint for
  // the photo's AI analysis (see Api\IncidentController::sos() /
  // ImageAnalysisService::classify()). Same values as the report screen.
  String? _selectedEmergency; // null until the citizen picks one
  final _otherEmergencyController = TextEditingController();
  static const List<_EmergencyType> _emergencyTypes = [
    _EmergencyType(
      'Fire',
      'Fire',
      Icons.local_fire_department,
      Color(0xFFE53935),
    ),
    _EmergencyType('Flood', 'Flood', Icons.flood, Color(0xFF1E88E5)),
    _EmergencyType('Accident', 'Accident', Icons.car_crash, Color(0xFFF57C00)),
    _EmergencyType(
      'Medical Emergency',
      'Medical',
      Icons.medical_services,
      Color(0xFF00897B),
    ),
    _EmergencyType(
      'Earthquake',
      'Earthquake',
      Icons.landscape,
      Color(0xFF6D4C41),
    ),
    _EmergencyType(
      'Landslide',
      'Landslide',
      Icons.landslide,
      Color(0xFF8D6E63),
    ),
  ];
  static const _EmergencyType _otherType = _EmergencyType(
    'Other',
    'Other',
    Icons.more_horiz,
    Color(0xFF546E7A),
  );

  _EmergencyType get _selectedType => _emergencyTypes.firstWhere(
    (t) => t.value == _selectedEmergency,
    orElse: () => _otherType,
  );

  // ── Guest details (guest mode only) ──
  // Guests must give their first name, last name and mobile number before
  // they can send an SOS, so MDRRMO can call them back to confirm it and
  // pranks can be traced. The server rejects a guest SOS without them
  // (Api\IncidentController::sos — it gets "First Last" as guest_name).
  // Asked in the "Your details" pop-up (_GuestDetailsDialog) and saved on
  // the phone, so a guest only types them once.
  String _guestFirstName = '';
  String _guestLastName = '';
  String _guestMobile = '';
  bool _askingGuestDetails = false; // the pop-up is open

  /// "First Last" — what's sent as guest_name and shown on screen.
  String get _guestName => _tidyName('$_guestFirstName $_guestLastName');

  // ── Camera state ──
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _cameraStarting = false; // _initCamera() is running
  String? _cameraError;
  File? _capturedPhoto;

  // ── Location state ──
  static const String _finding = 'Finding your location…';
  bool _locating = false; // _primeLocation() is running
  bool _locationReady = false;
  String _locationStatus = _finding;

  /// Location is off or not allowed: what's wrong, and how to fix it
  /// ('location_settings', 'app_settings' or 'ask').
  String? _locationError;
  String? _locationFix;

  /// The location found when this screen opened (or the latest one since).
  /// Send uses it when a fresh GPS fix takes too long — see
  /// _positionForSend().
  Position? _lastPosition;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _waveController;

  static const String _mdrrmoHotline = '#2441';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _primeLocation();
    if (widget.isGuest) _loadGuestDetails();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _waveController.dispose();
    _cameraController?.dispose();
    _otherEmergencyController.dispose();
    super.dispose();
  }

  /// The camera is let go while the app is in the background (e.g. while
  /// the resident is on a call to MDRRMO) and started again when they come
  /// back. Before, it stayed attached and the preview came back black.
  /// Coming back also looks for the location again, e.g. after turning it
  /// on in the phone's settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (controller != null) {
        _cameraController = null;
        if (mounted) setState(() => _cameraReady = false);
        controller.dispose();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_cameraController == null && !_sosSent && _cameraError == null) {
        _initCamera();
      }
      if (!_locationReady && !_sosSent) _primeLocation();
    }
  }

  // ── Guest details ─────────────────────────────────────────────────

  /// The "Your details" pop-up opens every time a guest opens SOS, filled
  /// in with the name and number saved last time, so they can confirm or
  /// correct them before sending.
  Future<void> _loadGuestDetails() async {
    final saved = await ApiService.getGuestDetails();
    if (!mounted) return;
    if (saved != null) {
      setState(() {
        _guestFirstName = saved['first_name'] ?? '';
        _guestLastName = saved['last_name'] ?? '';
        _guestMobile = saved['mobile'] ?? '';
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _askGuestDetails();
    });
  }

  bool get _guestDetailsValid =>
      !widget.isGuest ||
      (_namePartProblem(_guestFirstName, 'first') == null &&
          _namePartProblem(_guestLastName, 'last') == null &&
          _guestMobileProblem(_guestMobile) == null);

  /// Opens the "Your details" pop-up. With [thenContinue] (the guest had
  /// already picked the emergency type), the camera opens as soon as the
  /// details are in.
  Future<void> _askGuestDetails({bool thenContinue = false}) async {
    if (_askingGuestDetails || !mounted) return;
    _askingGuestDetails = true;
    final Map<String, String>? result = await showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _GuestDetailsDialog(
        initialFirstName: _guestFirstName,
        initialLastName: _guestLastName,
        initialMobile: _guestMobile,
      ),
    );
    _askingGuestDetails = false;
    if (!mounted || result == null) return; // Cancel

    setState(() {
      _guestFirstName = result['first_name'] ?? '';
      _guestLastName = result['last_name'] ?? '';
      _guestMobile = result['mobile'] ?? '';
    });
    ApiService.saveGuestDetails(
      firstName: _guestFirstName,
      lastName: _guestLastName,
      mobile: _guestMobile,
    );
    if (thenContinue) _confirmType();
  }

  // ── Camera lifecycle ──────────────────────────────────────────────

  Future<void> _initCamera() async {
    // Asking for the camera permission briefly sends the app to the
    // background and back, which calls this again — start only once.
    if (_cameraStarting) return;
    _cameraStarting = true;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() => _cameraError = 'No camera available on this device.');
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraReady = true;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      final denied = e.code.startsWith('CameraAccessDenied');
      setState(
        () => _cameraError = denied
            ? 'The camera is not allowed for ResQPulse. You can still send '
                  'your SOS without a photo, or allow the camera in your '
                  'phone settings.'
            : 'The camera isn\'t available right now. You can still send '
                  'your SOS without a photo.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _cameraError =
            'The camera isn\'t available right now. You can still send your '
            'SOS without a photo.',
      );
    } finally {
      _cameraStarting = false;
    }
  }

  // ── Location ──────────────────────────────────────────────────────

  /// Finds the location as soon as the screen opens, so it's ready by the
  /// time the resident presses Send. Waits at most 20 seconds, then uses
  /// the phone's last known location if there is one. Shown at the top
  /// (_buildLocationBar).
  Future<void> _primeLocation() async {
    if (_locating) return;
    _locating = true;
    // Trying again (after "Allow" / "Turn on", or coming back to the app).
    if (mounted && (_locationError != null || _locationStatus != _finding)) {
      setState(() {
        _locationError = null;
        _locationFix = null;
        _locationStatus = _finding;
      });
    }
    try {
      final position = await _getCurrentLocation().timeout(
        const Duration(seconds: 20),
      );
      _lastPosition = position;
      if (!mounted) return;
      setState(() {
        _locationReady = true;
        _locationStatus = 'Location ready';
      });
    } on TimeoutException {
      final known = await _lastKnownPosition();
      if (!mounted) return;
      if (known != null) {
        _lastPosition = known;
        setState(() {
          _locationReady = true;
          _locationStatus = 'Location ready';
        });
      } else {
        setState(
          () => _locationStatus =
              'Still looking for your location — it tries again when you '
              'send.',
        );
      }
    } on _LocationProblem catch (p) {
      if (!mounted) return;
      setState(() {
        _locationError = p.message;
        _locationFix = p.fix;
      });
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _locationStatus =
            'Still looking for your location — it tries again when you send.',
      );
    } finally {
      _locating = false;
    }
  }

  /// "Turn on" / "Allow" on the location bar.
  Future<void> _fixLocation() async {
    switch (_locationFix) {
      case 'location_settings':
        await Geolocator.openLocationSettings();
        break; // looked for again when the resident comes back
      case 'app_settings':
        await Geolocator.openAppSettings();
        break;
      default:
        await _primeLocation(); // asks for the permission again
    }
  }

  Future<Position?> _lastKnownPosition() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }

  /// The location sent with the SOS: a fresh GPS fix if the phone gets one
  /// within 10 seconds, otherwise the one found when the screen opened,
  /// otherwise the phone's last known location. Before, Send waited for a
  /// fresh fix with no time limit — indoors that could leave the SOS stuck
  /// on "Sending…".
  Future<Position> _positionForSend() async {
    Object? problem;
    try {
      final fresh = await _getCurrentLocation().timeout(
        const Duration(seconds: 10),
      );
      _lastPosition = fresh;
      return fresh;
    } catch (e) {
      problem = e;
    }

    final fallback = _lastPosition ?? await _lastKnownPosition();
    if (fallback != null) return fallback;

    // Location off / not allowed come with their own message.
    throw problem is _LocationProblem
        ? problem.message
        : 'We couldn\'t find your location. Move near a window or outside '
              'and try again, or call MDRRMO.';
  }

  Future<Position> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const _LocationProblem(
        'Your phone\'s location is off. Turn it on so MDRRMO can find you.',
        'location_settings',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const _LocationProblem(
          'ResQPulse isn\'t allowed to use your location. Allow it so '
              'MDRRMO can find you.',
          'ask',
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const _LocationProblem(
        'ResQPulse isn\'t allowed to use your location. Allow it in your '
            'phone\'s settings so MDRRMO can find you.',
        'app_settings',
      );
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // ── Step handlers ─────────────────────────────────────────────────

  /// Step 1 — a tile was tapped. Every type but "Other" goes straight on to
  /// the camera; "Other" first asks what it is.
  void _pickType(String value) {
    if (_isSending) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedEmergency = value);
    if (value != 'Other') _confirmType();
  }

  bool get _typeChosen =>
      _selectedEmergency != null &&
      (_selectedEmergency != 'Other' ||
          _otherEmergencyController.text.trim().isNotEmpty);

  void _confirmType() {
    // Guests can't go on to the camera without their name and number —
    // ask for them, then carry on.
    if (!_guestDetailsValid) {
      _askGuestDetails(thenContinue: true);
      return;
    }
    if (!_typeChosen) return;
    FocusScope.of(context).unfocus();
    setState(() => _typeConfirmed = true);
  }

  /// Back to step 1 — drops any captured photo, since the photo was
  /// taken for the previous type.
  void _changeType() {
    if (_isSending || _isCapturing) return;
    setState(() {
      _typeConfirmed = false;
      _awaitingConfirm = false;
      _capturedPhoto = null;
      _sendError = null;
    });
  }

  /// Step 2 — the shutter button takes the photo. Nothing is sent yet.
  Future<void> _capturePhoto() async {
    if (_sosSent || _isSending || _isCapturing || _awaitingConfirm) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isCapturing = true;
      _sendError = null;
    });

    File? photo;
    if (_cameraReady && _cameraController != null) {
      try {
        final XFile file = await _cameraController!.takePicture();
        photo = File(file.path);
      } catch (e) {
        debugPrint('SOS photo capture failed: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      _capturedPhoto = photo;
      _isCapturing = false;
      // Even if the camera failed, go on to step 3 so the resident can
      // send their location without a photo instead of being stuck.
      _awaitingConfirm = true;
    });
  }

  /// Step 2 — "Continue without a photo".
  void _skipPhoto() {
    if (_isCapturing) return;
    HapticFeedback.selectionClick();
    setState(() {
      _capturedPhoto = null;
      _awaitingConfirm = true;
      _sendError = null;
    });
  }

  /// Step 3 — "Retake photo" / "Add a photo": back to the camera.
  void _retake() {
    if (_isSending) return;
    HapticFeedback.selectionClick();
    setState(() {
      _capturedPhoto = null;
      _awaitingConfirm = false;
      _sendError = null;
    });
  }

  /// The phone's Back button and the back arrow: the previous step, or
  /// leave SOS from step 1. Not while the SOS is being sent.
  void _stepBack() {
    if (_isSending) return;
    if (_step == 2) {
      _retake();
    } else if (_step == 1) {
      _changeType();
    } else {
      Navigator.of(context).pop();
    }
  }

  /// What actually gets sent to the server — the free-typed "Other" text
  /// when that's selected, otherwise the picked category. Null (not an
  /// empty string) when there's nothing usable, so the backend's
  /// "?: null" treats a blank "Other" the same as never having picked
  /// anything.
  String? get _resolvedEmergencyType {
    if (_selectedEmergency == 'Other') {
      final other = _otherEmergencyController.text.trim();
      return other.isEmpty ? null : other;
    }
    return _selectedEmergency;
  }

  /// Step 3 — the big SOS button: send the alert.
  Future<void> _confirmAndSendSOS() async {
    if (_isSending || _sosSent) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _isSending = true;
      _sendError = null;
    });

    try {
      final position = await _positionForSend();
      if (!mounted) return;

      // ApiService.sendSOS() only attaches an Authorization header when a
      // token exists, so this call works identically for guests and
      // logged-in citizens. Either way the SOS waits for MDRRMO to
      // verify it before responders are notified.
      final result = await ApiService.sendSOS(
        latitude: position.latitude,
        longitude: position.longitude,
        photo: _capturedPhoto,
        emergencyType: _resolvedEmergencyType,
        guestName: widget.isGuest ? _guestName : null,
        guestMobile: widget.isGuest ? _guestMobile : null,
      );

      if (!mounted) return;

      if (result.success) {
        _pulseController.stop();
        _waveController.stop();
        setState(() {
          _sosSent = true;
          _isSending = false;
        });
        // Every SOS is verified by MDRRMO before responders are sent.
        // Show the server's own wording (it differs for a pin outside
        // Rosales). An older server only says "SOS sent.", so fall back
        // to a message that explains the review.
        final data = result.data;
        final serverMessage = data is Map && data['message'] is String
            ? (data['message'] as String).trim()
            : '';
        final useServerMessage =
            serverMessage.isNotEmpty && serverMessage != 'SOS sent.';
        await _showSentDialog(
          useServerMessage
              ? serverMessage
              : 'SOS sent. MDRRMO will verify it right away and then send responders.',
        );
        // However the pop-up was closed — Back to Home, or the phone's
        // Back button — the resident goes back to Home.
        if (mounted) Navigator.of(context).pop();
      } else {
        // Stay on step 3 (photo kept) so the resident can press SOS again.
        HapticFeedback.vibrate();
        setState(() {
          _isSending = false;
          _sendError = result.error ?? 'Failed to send SOS. Please try again.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.vibrate();
      setState(() {
        _isSending = false;
        _sendError = e.toString();
      });
    }
  }

  /// Opens the dialer with #2441 (see phone_call.dart — a bare "#" in the
  /// tel: link used to leave the dialer empty).
  Future<void> _callMDRRMO() async {
    final opened = await openDialer(_mdrrmoHotline);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't open the phone app. Please dial $_mdrrmoHotline yourself.",
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// "SOS Sent" pop-up, shown once the alert went through: the server's
  /// message and what to do while waiting, with Call MDRRMO (the pop-up
  /// stays open) and Back to Home. Closes with Back to Home or the phone's
  /// Back button; the caller then returns to Home.
  Future<void> _showSentDialog(String message) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: _green,
                  size: 34,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'SOS Sent',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: _ink, height: 1.45),
              ),
              const SizedBox(height: 10),
              Text(
                'Stay where you are if it\'s safe to do so, and keep your '
                'phone nearby in case MDRRMO calls you.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _callMDRRMO,
                  icon: const Icon(Icons.call, size: 18),
                  label: const Text(
                    'Call MDRRMO ($_mdrrmoHotline)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _green,
                    side: const BorderSide(color: _green, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A3A8F),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── UI ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Widget content = _sosSent
        ? _buildSentState()
        : switch (_step) {
            0 => _buildTypeStep(),
            1 => _buildPhotoStep(),
            _ => _buildSendStep(),
          };

    return PopScope(
      canPop: _sosSent || (_step == 0 && !_isSending),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _stepBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F6FA),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F6FA),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: _ink, size: 20),
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
          ),
          title: const Text(
            'Send SOS',
            style: TextStyle(
              color: _ink,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          actions: [
            // A call works without mobile data — always one tap away.
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _callMDRRMO,
                icon: const Icon(Icons.call, size: 17),
                label: const Text(
                  _mdrrmoHotline,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: _green,
                  backgroundColor: const Color(0xFFE8F5E9),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 36),
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              if (!_sosSent) ...[
                _buildStepBar(),
                const SizedBox(height: 14),
                _buildLocationBar(),
                if (widget.isGuest) ...[
                  const SizedBox(height: 10),
                  _buildGuestBar(),
                ],
                const SizedBox(height: 22),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: KeyedSubtree(
                  key: ValueKey(_sosSent ? 'sent' : 'step$_step'),
                  child: content,
                ),
              ),
              const SizedBox(height: 26),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 15, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only use SOS for real emergencies. MDRRMO checks every '
                      'SOS before sending responders, and may call you.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey[500],
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top: steps, location, guest ───────────────────────────────────

  Widget _buildStepBar() {
    const labels = ['Emergency', 'Photo', 'Send'];
    final children = <Widget>[];
    for (var i = 0; i < labels.length; i++) {
      if (i > 0) {
        children.add(
          Expanded(
            child: Container(
              height: 3,
              // Level with the middle of the circles.
              margin: const EdgeInsets.fromLTRB(4, 13.5, 4, 0),
              decoration: BoxDecoration(
                color: i <= _step ? _red : const Color(0xFFE0E3EA),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        );
      }
      final bool done = i < _step;
      final bool current = i == _step;
      children.add(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? _green : (current ? _red : Colors.white),
                border: Border.all(
                  color: done
                      ? _green
                      : (current ? _red : const Color(0xFFD5D9E2)),
                  width: 2,
                ),
              ),
              child: done
                  ? const Icon(Icons.check, color: Colors.white, size: 17)
                  : Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: current ? Colors.white : Colors.grey[500],
                      ),
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              labels[i],
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                color: current ? _ink : Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  /// Whether the location is ready — on every step, so the resident knows
  /// MDRRMO will be able to find them.
  Widget _buildLocationBar() {
    final bool problem = _locationError != null;
    final Color color = problem
        ? _red
        : (_locationReady ? _green : const Color(0xFF6B7280));
    final Color bg = problem
        ? const Color(0xFFFFEBEE)
        : (_locationReady ? const Color(0xFFE8F5E9) : Colors.white);

    return Container(
      padding: EdgeInsets.fromLTRB(14, 10, problem ? 6 : 14, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          if (!problem && !_locationReady && _locating)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(
              problem
                  ? Icons.location_off
                  : (_locationReady
                        ? Icons.my_location
                        : Icons.location_searching),
              color: color,
              size: 18,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              problem
                  ? _locationError!
                  : (_locationReady
                        ? 'Location ready — MDRRMO can find you.'
                        : _locationStatus),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.35,
              ),
            ),
          ),
          if (problem)
            TextButton(
              onPressed: _fixLocation,
              style: TextButton.styleFrom(foregroundColor: _red),
              child: Text(
                _locationFix == 'location_settings' ? 'Turn on' : 'Allow',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }

  /// Guests: the name and number the SOS is sent with, and Edit — or, if
  /// the pop-up was closed without them, a red reminder with Add.
  Widget _buildGuestBar() {
    final bool ready = _guestDetailsValid;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
      decoration: BoxDecoration(
        color: ready ? Colors.white : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ready ? const Color(0xFFE0E3EA) : _red,
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.badge_outlined,
            size: 18,
            color: ready ? const Color(0xFF6B7280) : _red,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ready
                ? Text.rich(
                    TextSpan(
                      style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                      children: [
                        const TextSpan(text: 'Sending as '),
                        TextSpan(
                          text: '$_guestName · $_guestMobile',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _ink,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                : const Text(
                    'Add your name and mobile number to send an SOS.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _red,
                    ),
                  ),
          ),
          TextButton(
            onPressed: _isSending ? null : () => _askGuestDetails(),
            child: Text(
              ready ? 'Edit' : 'Add',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepTitle(String title, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: _ink,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ── Step 1: what's happening ──────────────────────────────────────

  Widget _buildTypeStep() {
    final bool otherPicked = _selectedEmergency == 'Other';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepTitle(
          'What\'s happening?',
          'Tap the one closest to your emergency.',
        ),
        const SizedBox(height: 18),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
          children: _emergencyTypes.map(_typeTile).toList(),
        ),
        const SizedBox(height: 12),
        // "Other": a wide tile; then what it is, and Continue.
        _otherTile(otherPicked),
        if (otherPicked) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _otherEmergencyController,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirmType(),
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 15, color: _ink),
            decoration: InputDecoration(
              hintText: 'What is the emergency? (e.g. gas leak)',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE0E3EA)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFFE0E3EA),
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _red, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _typeChosen ? _confirmType : null,
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[500],
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _typeTile(_EmergencyType type) {
    final bool selected = _selectedEmergency == type.value;
    return Material(
      color: selected ? type.color.withOpacity(0.08) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected ? type.color : const Color(0xFFE6E8EF),
          width: selected ? 2 : 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _pickType(type.value),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: type.color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(type.icon, color: type.color, size: 27),
            ),
            const SizedBox(height: 8),
            Text(
              type.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _otherTile(bool selected) {
    final type = _otherType;
    return Material(
      color: selected ? type.color.withOpacity(0.06) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? type.color : const Color(0xFFE6E8EF),
          width: selected ? 2 : 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _pickType('Other'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: type.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(type.icon, color: type.color, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Something else',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: _ink,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Step 2: photo ─────────────────────────────────────────────────

  /// The chosen emergency, with Change — on steps 2 and 3.
  Widget _buildTypeChip() {
    final type = _selectedType;
    final locked = _isSending || _isCapturing;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6E8EF), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: type.color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(type.icon, color: type.color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Emergency',
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                ),
                Text(
                  _resolvedEmergencyType ?? type.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: locked ? null : _changeType,
            child: const Text(
              'Change',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoStep() {
    final bool canShoot = _cameraReady && _cameraController != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTypeChip(),
        const SizedBox(height: 18),
        _stepTitle(
          'Take a photo of the scene',
          'It helps MDRRMO confirm your SOS. You can skip it.',
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Color(0xFF111827)),
                _buildPhotoBox(),
                if (canShoot)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 18,
                    child: Center(child: _shutterButton()),
                  ),
                if (canShoot && !_isCapturing)
                  Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.45),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Tap the white button to take the photo',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        // Without a working camera this is the way on, so it's a full
        // button then; otherwise a quieter one under the camera.
        if (canShoot)
          TextButton.icon(
            onPressed: _isCapturing ? null : _skipPhoto,
            icon: const Icon(Icons.arrow_forward_rounded, size: 19),
            label: const Text(
              'Continue without a photo',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
              minimumSize: const Size(0, 46),
            ),
          )
        else
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _skipPhoto,
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: const Text(
                'Continue without a photo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The camera's shutter, over the bottom of the preview.
  Widget _shutterButton() {
    return GestureDetector(
      onTap: _capturePhoto,
      child: Container(
        width: 74,
        height: 74,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: _isCapturing
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(strokeWidth: 3, color: _red),
                )
              : const Icon(Icons.photo_camera, color: _red, size: 28),
        ),
      ),
    );
  }

  /// The live camera, or why it isn't there.
  Widget _buildPhotoBox() {
    if (_capturedPhoto != null) {
      return Image.file(_capturedPhoto!, fit: BoxFit.cover);
    }

    if (_cameraReady && _cameraController != null) {
      return FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize?.height ?? 1,
          height: _cameraController!.value.previewSize?.width ?? 1,
          child: CameraPreview(_cameraController!),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_cameraError == null)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white70,
                ),
              )
            else
              const Icon(
                Icons.no_photography_outlined,
                size: 38,
                color: Colors.white70,
              ),
            const SizedBox(height: 12),
            Text(
              _cameraError ?? 'Opening the camera…',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 3: review and send ───────────────────────────────────────

  Widget _buildSendStep() {
    final type = _selectedType;
    final bool hasPhoto = _capturedPhoto != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepTitle(
          _sendError != null ? 'Your SOS wasn\'t sent' : 'Ready to send',
          _sendError != null
              ? 'Check the problem below, then press SOS again.'
              : 'Check the details, then press the SOS button.',
        ),
        const SizedBox(height: 16),

        // What MDRRMO will get.
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE6E8EF), width: 1.2),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 78,
                  height: 78,
                  child: hasPhoto
                      ? Image.file(_capturedPhoto!, fit: BoxFit.cover)
                      : Container(
                          color: const Color(0xFFF1F3F7),
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            color: Colors.grey[400],
                            size: 28,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(type.icon, color: type.color, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _resolvedEmergencyType ?? type.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _reviewLine(
                      hasPhoto
                          ? Icons.photo_camera
                          : Icons.no_photography_outlined,
                      hasPhoto ? 'Photo attached' : 'No photo',
                      hasPhoto ? _green : Colors.grey[600]!,
                    ),
                    const SizedBox(height: 3),
                    _reviewLine(
                      _locationReady
                          ? Icons.my_location
                          : Icons.location_searching,
                      _locationReady
                          ? 'Your location'
                          : 'Location is found when you send',
                      _locationReady ? _green : Colors.grey[600]!,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        Center(child: _buildSosButton()),
        const SizedBox(height: 8),
        Text(
          _isSending
              ? 'Sending your SOS… keep this screen open.'
              : (_sendError != null
                    ? 'Press SOS to try again.'
                    : 'Press SOS to send it to MDRRMO.'),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),

        // The SOS didn't go through (no internet, no location): a call
        // works without mobile data.
        if (_sendError != null && !_isSending) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 19),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _sendError!,
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
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _callMDRRMO,
              icon: const Icon(Icons.call, size: 19),
              label: const Text(
                'Call MDRRMO instead ($_mdrrmoHotline)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 14),
        // Wraps onto two lines on narrow phones instead of overflowing.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            TextButton.icon(
              onPressed: _isSending ? null : _retake,
              icon: Icon(
                hasPhoto ? Icons.refresh_rounded : Icons.add_a_photo_outlined,
                size: 18,
              ),
              label: Text(hasPhoto ? 'Retake photo' : 'Add a photo'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            ),
            TextButton.icon(
              onPressed: _isSending ? null : _changeType,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Change emergency'),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            ),
          ],
        ),
      ],
    );
  }

  Widget _reviewLine(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  /// The big round SOS button on step 3 — this is what sends the alert.
  Widget _buildSosButton() {
    return Semantics(
      button: true,
      label: 'Send SOS',
      child: GestureDetector(
        onTap: _isSending ? null : _confirmAndSendSOS,
        child: SizedBox(
          width: 200,
          height: 200,
          child: AnimatedBuilder(
            animation: Listenable.merge([_waveController, _pulseAnim]),
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  if (!_isSending) ...[
                    _buildWave(
                      _waveController,
                      const Interval(0.0, 1.0, curve: Curves.easeOut),
                      100,
                    ),
                    _buildWave(
                      _waveController,
                      const Interval(0.3, 1.0, curve: Curves.easeOut),
                      88,
                    ),
                  ],
                  SizedBox(
                    width: 150,
                    height: 150,
                    child: _isSending
                        ? const CircularProgressIndicator(
                            strokeWidth: 5,
                            valueColor: AlwaysStoppedAnimation(_red),
                          )
                        : const SizedBox.shrink(),
                  ),
                  Transform.scale(
                    scale: _isSending ? 1.0 : _pulseAnim.value,
                    child: Container(
                      width: 132,
                      height: 132,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFE53935), Color(0xFFB71C1C)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.4),
                            blurRadius: 22,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'SOS',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            _isSending
                                ? 'SENDING'
                                : (_sendError != null
                                      ? 'TRY AGAIN'
                                      : 'TAP TO SEND'),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWave(AnimationController ctrl, Interval interval, double maxR) {
    final anim = CurvedAnimation(parent: ctrl, curve: interval);
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final size = maxR * 2 * anim.value;
        final opacity = ((1.0 - anim.value) * 0.18).clamp(0.0, 1.0);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _red.withOpacity(opacity),
          ),
        );
      },
    );
  }

  /// Behind the "SOS Sent" pop-up, until it closes and Home opens again.
  Widget _buildSentState() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(
            color: Color(0xFFE8F5E9),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            color: _green,
            size: 48,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'SOS sent',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: _green,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'MDRRMO is checking your SOS and will send responders once it\'s '
          'confirmed.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// One tile on step 1. [value] is what's sent (same as the report screen);
/// [label] is what the tile says.
class _EmergencyType {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _EmergencyType(this.value, this.label, this.icon, this.color);
}

/// Location is off or not allowed — [fix] says which button helps.
class _LocationProblem implements Exception {
  final String message;
  final String fix;
  const _LocationProblem(this.message, this.fix);

  @override
  String toString() => message;
}

// ── Guest details: rules + the "Your details" pop-up ─────────────────────

/// The name with extra spaces removed.
String _tidyName(String name) => name.trim().replaceAll(RegExp(r'\s+'), ' ');

// Each returns what's wrong, or null when it's fine. Together they match
// the server's rules (Api\IncidentController::prepareGuestDetails), which
// gets the two names joined as "First Last".

/// [which] is 'first' or 'last'. Letters only; spaces, dots, apostrophes
/// and hyphens are fine (e.g. "Ma. Lourdes", "Dela Cruz", "O'Neil").
String? _namePartProblem(String raw, String which) {
  final String name = _tidyName(raw);
  if (name.isEmpty) return 'Enter your $which name';
  if (!RegExp(
    r"^[\p{L}\p{M}][\p{L}\p{M}.'-]*( [\p{L}\p{M}][\p{L}\p{M}.'-]*)*$",
    unicode: true,
  ).hasMatch(name)) {
    return 'Use letters only';
  }
  if (name.length < 2) return 'Enter your full $which name';
  return null;
}

String? _guestMobileProblem(String raw) {
  final String mobile = raw.trim();
  if (mobile.isEmpty) return 'Enter your mobile number';
  if (!RegExp(r'^09\d{9}$').hasMatch(mobile)) {
    return 'Enter an 11-digit number, e.g. 09171234567';
  }
  return null;
}

/// Pop-up card asking a guest for their first name, last name and mobile
/// number. Closes with {'first_name', 'last_name', 'mobile'} on Continue,
/// or null on Cancel.
class _GuestDetailsDialog extends StatefulWidget {
  final String initialFirstName;
  final String initialLastName;
  final String initialMobile;

  const _GuestDetailsDialog({
    required this.initialFirstName,
    required this.initialLastName,
    required this.initialMobile,
  });

  @override
  State<_GuestDetailsDialog> createState() => _GuestDetailsDialogState();
}

class _GuestDetailsDialogState extends State<_GuestDetailsDialog> {
  late final TextEditingController _firstName = TextEditingController(
    text: widget.initialFirstName,
  );
  late final TextEditingController _lastName = TextEditingController(
    text: widget.initialLastName,
  );
  late final TextEditingController _mobile = TextEditingController(
    text: widget.initialMobile,
  );

  // Problems are shown only after the first tap on Continue, then update
  // as the guest types.
  bool _submitted = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _mobile.dispose();
    super.dispose();
  }

  void _submit() {
    if (_namePartProblem(_firstName.text, 'first') != null ||
        _namePartProblem(_lastName.text, 'last') != null ||
        _guestMobileProblem(_mobile.text) != null) {
      HapticFeedback.vibrate();
      setState(() => _submitted = true);
      return;
    }
    Navigator.of(context).pop(<String, String>{
      'first_name': _tidyName(_firstName.text),
      'last_name': _tidyName(_lastName.text),
      'mobile': _mobile.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.badge_outlined,
                color: Color(0xFFD32F2F),
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your details',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Guests need to give their name and mobile number before '
              'sending an SOS. MDRRMO may call this number to confirm it.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _label('First name'),
            _field(
              controller: _firstName,
              hint: 'e.g. Juan',
              icon: Icons.person_outline,
              keyboardType: TextInputType.name,
              capitalization: TextCapitalization.words,
              action: TextInputAction.next,
              autofocus: widget.initialFirstName.isEmpty,
              error: _submitted
                  ? _namePartProblem(_firstName.text, 'first')
                  : null,
            ),
            const SizedBox(height: 12),
            _label('Last name'),
            _field(
              controller: _lastName,
              hint: 'e.g. Dela Cruz',
              icon: Icons.person_outline,
              keyboardType: TextInputType.name,
              capitalization: TextCapitalization.words,
              action: TextInputAction.next,
              error: _submitted
                  ? _namePartProblem(_lastName.text, 'last')
                  : null,
            ),
            const SizedBox(height: 12),
            _label('Mobile number'),
            _field(
              controller: _mobile,
              hint: '09XXXXXXXXX',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              action: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              error: _submitted ? _guestMobileProblem(_mobile.text) : null,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.lock_outline, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Saved on this phone, so you only type it once.',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A1A2E),
                        side: BorderSide(color: Colors.grey[400]!, width: 1.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF444466),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required TextInputType keyboardType,
    required TextInputAction action,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    bool autofocus = false,
    ValueChanged<String>? onSubmitted,
    String? error,
  }) {
    final borderSide = BorderSide(color: Colors.grey[300]!, width: 1.5);
    const errorSide = BorderSide(color: Color(0xFFD32F2F), width: 1.5);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      textInputAction: action,
      inputFormatters: formatters,
      autofocus: autofocus,
      onSubmitted: onSubmitted,
      onChanged: (_) {
        if (_submitted) setState(() {});
      },
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey[500], size: 20),
        errorText: error,
        errorMaxLines: 2,
        filled: true,
        fillColor: const Color(0xFFF8F9FB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: borderSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: borderSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: errorSide,
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
        ),
      ),
    );
  }
}
