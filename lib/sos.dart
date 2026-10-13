import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';

class SOSScreen extends StatefulWidget {
  final bool isGuest;
  const SOSScreen({super.key, this.isGuest = false});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> with TickerProviderStateMixin {
  // ── Tap → capture → confirm / retake → send state ──
  //
  // Flow:
  //   0. The citizen first picks the type of emergency
  //      (_typeConfirmed) — the camera is hidden until they do.
  //   1. One tap on the SOS button instantly captures a photo
  //      (_isCapturing).
  //   2. The photo is frozen in the preview box and the user is asked to
  //      confirm (_awaitingConfirm): "Retake" goes back to the live
  //      camera, "Send SOS" actually fires the alert.
  //   3. Nothing is sent to MDRRMO until the user confirms, so an
  //      accidental tap can never raise a false alert.
  bool _typeConfirmed = false; // step 1 done → camera is shown
  bool _isCapturing = false;
  bool _awaitingConfirm = false;
  bool _isSending = false;
  bool _sosSent = false;
  String? _sendError;

  // ── Type of Emergency ──
  // Picked FIRST (before the camera is shown) — sent alongside the alert so
  // MDRRMO sees more than a bare "SOS Emergency" (e.g. "SOS Alert —
  // Accident"), and passed to the backend as a hint for the photo's AI
  // analysis (see Api\IncidentController::sos() /
  // ImageAnalysisService::classify()). Same list as the regular report
  // screen so the two stay consistent.
  String? _selectedEmergency; // null until the citizen picks one
  final _otherEmergencyController = TextEditingController();
  final List<String> _emergencyTypes = [
    'Fire',
    'Flood',
    'Earthquake',
    'Accident',
    'Medical Emergency',
    'Landslide',
    'Other',
  ];

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
  String? _cameraError;
  File? _capturedPhoto;

  // ── Location state ──
  String _locationStatus = 'Getting your location...';
  bool _locationReady = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;
  late AnimationController _waveController;
  late AnimationController _liveDotController;

  static const String _mdrrmoHotline = '#2441';

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _liveDotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _initCamera();
    _primeLocation();
    if (widget.isGuest) _loadGuestDetails();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _liveDotController.dispose();
    _cameraController?.dispose();
    _otherEmergencyController.dispose();
    super.dispose();
  }

  // ── Guest details ─────────────────────────────────────────────────

  /// Uses the name and number this guest saved last time; the first time
  /// (nothing saved yet) the "Your details" pop-up opens right away.
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
    if (!_guestDetailsValid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _askGuestDetails();
      });
    }
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _cameraError = 'Camera unavailable: $e');
    }
  }

  // ── Location priming ───────────────────────────────────────────────

  Future<void> _primeLocation() async {
    try {
      await _getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _locationStatus = 'Location ready';
        _locationReady = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _locationStatus = e.toString());
    }
  }

  Future<Position> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are turned off. Please enable them.';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permission denied.';
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw 'Location permission permanently denied. Enable it in settings.';
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // ── Tap-to-capture / retake / confirm handlers ─────────────────────

  /// Step 1 — a single tap on the SOS button takes the photo right away.
  /// Nothing is sent yet; the user gets to review it first.
  Future<void> _onSosTap() async {
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
      // Even if the camera failed we still move to the confirm step, so
      // the user can send their location without a photo instead of being
      // stuck unable to call for help.
      _awaitingConfirm = true;
    });
  }

  /// Step 2a — discard the photo and go back to the live camera.
  void _retake() {
    if (_isSending) return;
    HapticFeedback.selectionClick();
    setState(() {
      _capturedPhoto = null;
      _awaitingConfirm = false;
      _sendError = null;
    });
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

  /// Step 2b — the user confirmed the photo; send the alert.
  Future<void> _confirmAndSendSOS() async {
    if (_isSending || _sosSent) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _isSending = true;
      _sendError = null;
      _locationStatus = 'Sending your location...';
    });

    try {
      final position = await _getCurrentLocation();
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
        // The SOS button is hidden from now on, so stop its pulse and
        // wave animations instead of letting them run in the background.
        _pulseController.stop();
        _waveController.stop();
        setState(() {
          _sosSent = true;
          _isSending = false;
          _awaitingConfirm = false;
          _locationStatus = 'Location sent — awaiting MDRRMO review';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              useServerMessage
                  ? '🆘 $serverMessage'
                  : '🆘 SOS sent. MDRRMO will verify it right away and then send responders.',
            ),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        // Stay on the confirm step (photo kept) so the user can just
        // press "Send SOS" again.
        setState(() {
          _isSending = false;
          _sendError = result.error;
          _locationStatus = result.error ?? 'Failed to send location';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.error ?? 'Failed to send SOS. Please try again.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _sendError = e.toString();
        _locationStatus = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send SOS: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _callMDRRMO() async {
    final uri = Uri.parse('tel:$_mdrrmoHotline');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot place a call on this device.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // ── UI ───────────────────────────────────────────────────────────

  String get _headlineText {
    if (_sosSent) return 'Alert Sent';
    if (_isSending) return 'Sending Your Alert...';
    if (_isCapturing) return 'Capturing Photo...';
    if (_awaitingConfirm) return 'Confirm Your Photo';
    return '';
  }

  String get _subtitleText {
    if (_sosSent) {
      return widget.isGuest
          ? 'MDRRMO has received your location and will review it shortly.'
          : (_capturedPhoto != null
                ? 'MDRRMO has received your live location and photo and will review it shortly.'
                : 'MDRRMO has received your live location and will review it shortly.');
    }
    if (_isSending) return 'Sharing your GPS location and photo.';
    if (_isCapturing) return 'Hold your phone steady.';
    if (_awaitingConfirm) {
      return _capturedPhoto != null
          ? 'Happy with this photo? Send the alert, or retake it.'
          : 'No photo was captured. You can still send your location.';
    }
    return 'Tap the button below to capture a photo.';
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F6FA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF1A1A2E),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'SOS Emergency',
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
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            children: [
              if (widget.isGuest && !_sosSent && !_isSending)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFFE65100),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Guest mode: your name, number, location and photo are sent. MDRRMO reviews every SOS and may call you to confirm before sending responders.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ── Type of Emergency (STEP 1) ────────────────────────
              // The citizen picks the emergency type FIRST. Only after they
              // continue does the camera appear (step 2), and the chosen
              // type is sent with the SOS so the backend's AI photo
              // analysis can use it as a guide (see
              // Api\IncidentController::sos() / ImageAnalysisService).
              if (_sosSent) ...[
                if (_resolvedEmergencyType != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department_outlined,
                            color: Color(0xFF2E7D32),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Reported as: $_resolvedEmergencyType',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ] else if (_typeConfirmed)
                _buildTypeSummary(),

              if (_typeConfirmed || _sosSent) ...[
                // ── Headline + subtitle ──────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _headlineText,
                    key: ValueKey(_headlineText),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _sosSent
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _subtitleText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 20),

                // ── Camera preview / captured photo box ──────────────
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            border: Border.all(
                              color: _sosSent
                                  ? const Color(0xFF2E7D32).withOpacity(0.4)
                                  : Colors.grey[300]!,
                              width: 1.5,
                            ),
                          ),
                          child: _buildPhotoBox(),
                        ),
                      ),
                    ),
                    // Captured confirmation badge
                    if (_capturedPhoto != null)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32).withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 13,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'CAPTURED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                // ── SOS button (tap to capture) OR confirm / retake ──
                // Nothing here once the SOS is sent — no big check circle
                // (panel revision #21). The "Alert Sent" headline, the
                // location pill and the card below already confirm it.
                if (!_sosSent) ...[
                  const SizedBox(height: 28),
                  if (_awaitingConfirm)
                    _buildConfirmPanel()
                  else ...[
                    _buildSosButton(),
                    const SizedBox(height: 10),
                    if (!_isCapturing)
                      Text(
                        'Tap once to capture a photo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[500],
                        ),
                      ),
                  ],
                ],
              ] else
                _buildTypePicker(),

              const SizedBox(height: 28),

              // ── Location status pill ─────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _sendError != null
                        ? Colors.redAccent.withOpacity(0.4)
                        : (_locationReady
                              ? const Color(0xFF2E7D32).withOpacity(0.3)
                              : Colors.grey[300]!),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _sosSent
                          ? Icons.check_circle_outline
                          : Icons.location_on_outlined,
                      size: 18,
                      color: _sendError != null
                          ? Colors.redAccent
                          : (_sosSent || _locationReady
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFF6B7280)),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _locationStatus,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _sendError != null
                              ? Colors.redAccent
                              : (_sosSent || _locationReady
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFF6B7280)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Content: pre-send explainer OR post-send next steps ──
              if (_sosSent) _buildSuccessCard() else _buildExplainerCard(),

              const SizedBox(height: 20),

              // ── Safety disclaimer ─────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 15, color: Colors.grey[400]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only use SOS for genuine emergencies. False alerts can delay '
                      'responders reaching someone who needs real help.',
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

  // ── STEP 1: pick the type of emergency (camera stays hidden) ──────

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
    HapticFeedback.selectionClick();
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

  Widget _buildTypePicker() {
    final borderSide = BorderSide(color: Colors.grey[300]!, width: 1.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.isGuest) _buildGuestBar(),
        const Text(
          'What type of emergency is it?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose the emergency type first. The camera opens right after, and '
          'your choice helps the system understand your photo.',
          style: TextStyle(fontSize: 13, color: Colors.grey[600], height: 1.4),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedEmergency,
              isExpanded: true,
              hint: Text(
                'Select type of emergency',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF1A1A2E),
              ),
              style: const TextStyle(
                color: Color(0xFF1A1A2E),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              items: _emergencyTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) {
                if (val == null) return;
                setState(() => _selectedEmergency = val);
                // Every standard type opens the camera straight away.
                // "Other" first needs the user to describe it.
                if (val != 'Other') _confirmType();
              },
            ),
          ),
        ),
        if (_selectedEmergency == 'Other') ...[
          const SizedBox(height: 10),
          TextField(
            controller: _otherEmergencyController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _confirmType(),
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 15, color: Color(0xFF1A1A2E)),
            decoration: InputDecoration(
              hintText: 'Please specify the emergency type',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 15,
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
                borderSide: const BorderSide(
                  color: Color(0xFFD32F2F),
                  width: 2,
                ),
              ),
            ),
          ),
        ],
        if (_selectedEmergency == 'Other') ...[
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _typeChosen ? _confirmType : null,
              icon: const Icon(Icons.camera_alt_rounded, size: 20),
              label: const Text(
                'Continue to Camera',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[500],
                elevation: 3,
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

  /// Guests: the name and number the SOS will be sent with, and Edit —
  /// or, if the pop-up was closed without them, a red reminder with Add.
  Widget _buildGuestBar() {
    final bool ready = _guestDetailsValid;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: BoxDecoration(
        color: ready ? Colors.white : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ready ? Colors.grey[300]! : const Color(0xFFD32F2F),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.badge_outlined,
            size: 20,
            color: ready ? const Color(0xFF6B7280) : const Color(0xFFD32F2F),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ready
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Your details',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Colors.grey[500],
                        ),
                      ),
                      Text(
                        '$_guestName · $_guestMobile',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                    ],
                  )
                : const Text(
                    'Add your name and mobile number to send an SOS.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD32F2F),
                    ),
                  ),
          ),
          TextButton(
            onPressed: () => _askGuestDetails(),
            child: Text(
              ready ? 'Edit' : 'Add',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  /// Compact "Emergency type: Fire — Change" bar shown above the camera.
  /// For guests it also shows the name and number being sent; "Change"
  /// goes back to edit both.
  Widget _buildTypeSummary() {
    final locked = _isSending || _isCapturing;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1.2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFD32F2F),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _resolvedEmergencyType ?? 'Emergency',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                if (widget.isGuest)
                  Text(
                    '$_guestName · $_guestMobile',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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

  // ── Big round SOS button (single tap captures the photo) ──────────

  Widget _buildSosButton() {
    final busy = _isCapturing || _isSending;
    return GestureDetector(
      onTap: _onSosTap,
      child: SizedBox(
        width: 190,
        height: 190,
        child: AnimatedBuilder(
          animation: Listenable.merge([_waveController, _pulseAnim]),
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                _buildWave(
                  _waveController,
                  const Interval(0.0, 1.0, curve: Curves.easeOut),
                  95,
                ),
                _buildWave(
                  _waveController,
                  const Interval(0.3, 1.0, curve: Curves.easeOut),
                  83,
                ),
                _buildWave(
                  _waveController,
                  const Interval(0.6, 1.0, curve: Curves.easeOut),
                  72,
                ),
                SizedBox(
                  width: 140,
                  height: 140,
                  child: busy
                      ? const CircularProgressIndicator(
                          strokeWidth: 5,
                          valueColor: AlwaysStoppedAnimation(Color(0xFFD32F2F)),
                        )
                      : CircularProgressIndicator(
                          value: 1,
                          strokeWidth: 5,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation(
                            Colors.grey.withOpacity(0.15),
                          ),
                        ),
                ),
                Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 122,
                    height: 122,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFD32F2F), Color(0xFFB71C1C)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.4),
                          blurRadius: 22,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'SOS',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Confirm / Retake panel (shown after the photo is captured) ────

  Widget _buildConfirmPanel() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _isSending ? null : _confirmAndSendSOS,
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 20),
            label: Text(
              _isSending
                  ? 'Sending...'
                  : (_sendError != null ? 'Try Again — Send SOS' : 'Send SOS'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD32F2F),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFD32F2F).withOpacity(0.6),
              disabledForegroundColor: Colors.white,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: _isSending ? null : _retake,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(
              _capturedPhoto != null ? 'Retake Photo' : 'Try Camera Again',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A1A2E),
              side: BorderSide(color: Colors.grey[400]!, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExplainerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
          const Text(
            'How SOS works',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 14),
          if (widget.isGuest) ...[
            const _InfoStep(
              icon: Icons.badge_outlined,
              color: Color(0xFF6A1B9A),
              title: 'Guests enter their name and number',
              subtitle: 'So MDRRMO can call you back. Saved on this phone.',
            ),
            const SizedBox(height: 12),
          ],
          const _InfoStep(
            icon: Icons.warning_amber_rounded,
            color: Color(0xFFD32F2F),
            title: 'You pick the type of emergency',
            subtitle: 'It guides the AI that reads your photo for responders.',
          ),
          const SizedBox(height: 12),
          const _InfoStep(
            icon: Icons.camera_alt_outlined,
            color: Color(0xFFF57C00),
            title: 'A photo is captured with one tap',
            subtitle:
                'You can review it and retake it before anything is sent.',
          ),
          const SizedBox(height: 12),
          const _InfoStep(
            icon: Icons.my_location,
            color: Color(0xFF1565C0),
            title: 'Your live GPS location is shared',
            subtitle: 'Pinpoints exactly where you are once you confirm.',
          ),
          const SizedBox(height: 12),
          const _InfoStep(
            icon: Icons.shield_outlined,
            color: Color(0xFF2E7D32),
            title: 'MDRRMO is alerted',
            subtitle:
                'MDRRMO verifies every SOS first, then sends responders right away.',
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E7D32).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield,
                  color: Color(0xFF2E7D32),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Stay where you are if it\'s safe to do so',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'MDRRMO is verifying your alert and will send responders as soon as it\'s confirmed. '
            'Keep your phone nearby in case they call you. '
            'If your situation changes, call the hotline directly below.',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _callMDRRMO,
              icon: const Icon(Icons.call, size: 18, color: Color(0xFF2E7D32)),
              label: const Text(
                'Call MDRRMO Hotline',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32),
                  fontSize: 13.5,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF2E7D32), width: 1.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _cameraError != null
                ? Icons.no_photography_outlined
                : Icons.camera_alt_outlined,
            size: 36,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _cameraError ?? 'Preparing camera...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey[500]),
            ),
          ),
        ],
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
            color: const Color(0xFFD32F2F).withOpacity(opacity),
          ),
        );
      },
    );
  }
}

// ── Info Step row (used in the explainer card) ────────────────────────────

class _InfoStep extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  const _InfoStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Colors.grey[600],
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
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
