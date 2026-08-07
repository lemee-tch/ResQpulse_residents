import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> with TickerProviderStateMixin {
  // ── Hold-to-send state ──
  bool _isPressing = false;
  bool _isSending = false;
  bool _sosSent = false;
  String? _sendError;
  double _holdProgress = 0.0;
  Timer? _holdTimer;

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
    _holdTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  // ── Camera lifecycle ──────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
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

  // ── Hold-to-send handlers ──────────────────────────────────────────

  void _onPressStart() {
    if (_sosSent || _isSending) return;
    HapticFeedback.lightImpact();
    setState(() {
      _isPressing = true;
      _sendError = null;
    });

    const totalMs = 3000;
    const intervalMs = 50;
    int elapsed = 0;

    _holdTimer = Timer.periodic(const Duration(milliseconds: intervalMs), (t) {
      elapsed += intervalMs;
      setState(() => _holdProgress = elapsed / totalMs);
      if (elapsed >= totalMs) {
        t.cancel();
        _triggerSOS();
      }
    });
  }

  void _onPressEnd() {
    if (_sosSent || _isSending) return;
    _holdTimer?.cancel();
    setState(() {
      _isPressing = false;
      _holdProgress = 0.0;
    });
  }

  Future<void> _triggerSOS() async {
    HapticFeedback.heavyImpact();
    setState(() {
      _isPressing = false;
      _isSending = true;
      _holdProgress = 1.0;
      _locationStatus = 'Sending your location...';
    });

    File? photo;
    if (_cameraReady && _cameraController != null) {
      try {
        final XFile file = await _cameraController!.takePicture();
        photo = File(file.path);
        if (mounted) setState(() => _capturedPhoto = photo);
      } catch (e) {
        debugPrint('SOS photo capture failed: $e');
      }
    }

    try {
      final position = await _getCurrentLocation();
      if (!mounted) return;

      final result = await ApiService.sendSOS(
        latitude: position.latitude,
        longitude: position.longitude,
        photo: photo,
      );

      if (!mounted) return;

      if (result.success) {
        setState(() {
          _sosSent = true;
          _isSending = false;
          _locationStatus = 'Location sent to MDRRMO';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 SOS Alert sent — help is on the way.'),
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 4),
          ),
        );
      } else {
        setState(() {
          _isSending = false;
          _holdProgress = 0.0;
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
        _holdProgress = 0.0;
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
    if (_isPressing) return 'Keep Holding...';
    return '';
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
                _sosSent
                    ? 'MDRRMO has received your live location and photo.'
                    : (_isSending
                          ? 'Capturing photo and sharing your GPS location.'
                          : 'Press and hold the button below for 3 seconds.'),
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
                  // LIVE badge
                  if (!_sosSent && _capturedPhoto == null)
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(20),
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

              const SizedBox(height: 32),

              // ── Press & Hold SOS Button ─────────────────────────
              GestureDetector(
                onTapDown: (_) => _onPressStart(),
                onTapUp: (_) => _onPressEnd(),
                onTapCancel: _onPressEnd,
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
                            child: CircularProgressIndicator(
                              value: 1,
                              strokeWidth: 5,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation(
                                Colors.grey.withOpacity(0.15),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 140,
                            height: 140,
                            child: _isSending
                                ? const CircularProgressIndicator(
                                    strokeWidth: 5,
                                    valueColor: AlwaysStoppedAnimation(
                                      Color(0xFFD32F2F),
                                    ),
                                  )
                                : CircularProgressIndicator(
                                    value: _holdProgress,
                                    strokeWidth: 5,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation(
                                      _sosSent
                                          ? const Color(0xFF2E7D32)
                                          : const Color(0xFFD32F2F),
                                    ),
                                  ),
                          ),
                          Transform.scale(
                            scale: _isPressing ? 0.95 : _pulseAnim.value,
                            child: Container(
                              width: 122,
                              height: 122,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: _sosSent
                                      ? [
                                          const Color(0xFF2E7D32),
                                          const Color(0xFF43A047),
                                        ]
                                      : [
                                          const Color(0xFFD32F2F),
                                          const Color(0xFFB71C1C),
                                        ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        (_sosSent ? Colors.green : Colors.red)
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
              ),

              const SizedBox(height: 10),

              if (!_sosSent && !_isSending)
                Text(
                  _isPressing
                      ? 'Release to cancel'
                      : 'Press and hold for 3 seconds',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[500],
                  ),
                ),

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
            'What happens when you hold SOS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 14),
          const _InfoStep(
            icon: Icons.my_location,
            color: Color(0xFF1565C0),
            title: 'Your live GPS location is shared',
            subtitle: 'Pinpoints exactly where you are.',
          ),
          const SizedBox(height: 12),
          const _InfoStep(
            icon: Icons.camera_alt_outlined,
            color: Color(0xFFF57C00),
            title: 'A photo is captured automatically',
            subtitle: 'Gives responders visual context on arrival.',
          ),
          const SizedBox(height: 12),
          const _InfoStep(
            icon: Icons.shield_outlined,
            color: Color(0xFF2E7D32),
            title: 'MDRRMO is alerted instantly',
            subtitle:
                'Logged as a critical-priority incident for immediate dispatch.',
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
            'Responders have your location and photo, and are being dispatched now. '
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
