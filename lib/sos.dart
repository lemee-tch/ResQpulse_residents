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
      // logged-in citizens — the backend decides needs_review from that.
      final result = await ApiService.sendSOS(
        latitude: position.latitude,
        longitude: position.longitude,
        photo: _capturedPhoto,
        emergencyType: _resolvedEmergencyType,
      );

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _sosSent = true;
          _isSending = false;
          _awaitingConfirm = false;
          _locationStatus = widget.isGuest
              ? 'Location sent — awaiting MDRRMO review'
              : 'Location sent to MDRRMO';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isGuest
                  ? '🆘 SOS sent — MDRRMO will review it shortly.'
                  : '🚨 SOS Alert sent — help is on the way.',
            ),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 4),
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
                ? 'MDRRMO has received your live location and photo.'
                : 'MDRRMO has received your live location.');
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
                          'Guest mode: your location (and photo, if captured) is sent. MDRRMO reviews guest SOS alerts before dispatching responders.',
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

                const SizedBox(height: 28),

                // ── SOS button (tap to capture) OR confirm / retake ──
                if (_awaitingConfirm && !_sosSent)
                  _buildConfirmPanel()
                else ...[
                  _buildSosButton(),
                  const SizedBox(height: 10),
                  if (!_sosSent && !_isCapturing)
                    Text(
                      'Tap once to capture a photo',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                      ),
                    ),
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

  bool get _canContinueFromType =>
      _selectedEmergency != null &&
      (_selectedEmergency != 'Other' ||
          _otherEmergencyController.text.trim().isNotEmpty);

  void _confirmType() {
    if (!_canContinueFromType) return;
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
              onPressed: _canContinueFromType ? _confirmType : null,
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

  /// Compact "Emergency type: Fire — Change" bar shown above the camera.
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
            child: Text(
              _resolvedEmergencyType ?? 'Emergency',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
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
                            _sosSent
                                ? const Color(0xFF2E7D32)
                                : Colors.grey.withOpacity(0.15),
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
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _sosSent
                            ? [const Color(0xFF2E7D32), const Color(0xFF43A047)]
                            : [
                                const Color(0xFFD32F2F),
                                const Color(0xFFB71C1C),
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_sosSent ? Colors.green : Colors.red)
                              .withOpacity(0.4),
                          blurRadius: 22,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: Center(
                      child: _sosSent
                          ? const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 42,
                            )
                          : const Text(
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
          _InfoStep(
            icon: Icons.shield_outlined,
            color: const Color(0xFF2E7D32),
            title: 'MDRRMO is alerted',
            subtitle: widget.isGuest
                ? 'As a guest, MDRRMO reviews your alert before it\'s dispatched to responders.'
                : 'Logged as a critical-priority incident for immediate dispatch.',
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
            widget.isGuest
                ? 'MDRRMO will review your alert shortly before dispatching responders. '
                      'If your situation changes, you can call the hotline directly below.'
                : 'Responders have your location and photo, and are being dispatched now. '
                      'If your situation changes or you need to move, keep the app open so we '
                      'can track updates.',
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
            color:
                (_sosSent ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F))
                    .withOpacity(opacity),
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
