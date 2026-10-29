import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

/// Home → Report Emergency: the type, what happened, photos — and where,
/// which is the phone's own location, the same as SOS (item 49). There is
/// no barangay search anymore: the location is looked for as soon as the
/// screen opens (_primeLocation), shown at the Location field
/// (_buildLocationCard) with a button to fix it when location is off or
/// not allowed, and found again when the report is sent (_positionForSend).
/// The server turns the pin into the street and barangay
/// (Api\IncidentController::store()).
class ReportIncidentScreen extends StatefulWidget {
  final bool isGuest;
  const ReportIncidentScreen({super.key, this.isGuest = false});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen>
    with WidgetsBindingObserver {
  static const Color _green = Color(0xFF2E7D32);
  static const Color _red = Color(0xFFD32F2F);

  // Guests only need to send a location pin — photos and a written
  // description are optional for them (they can still add photos if they
  // want to, up to the same max). Logged-in citizens keep the original
  // 3-5 required photos.
  static const int _minPhotosLoggedIn = 3;
  static const int _maxPhotos = 5;
  int get _minPhotos => widget.isGuest ? 0 : _minPhotosLoggedIn;

  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _otherEmergencyController = TextEditingController();

  String _selectedEmergency = 'Fire';
  final List<File> _pickedImages = [];
  bool _isLoading = false;

  // ── Location: the phone's GPS, like SOS ─────────────────────────────
  static const String _finding = 'Finding your location…';
  bool _locating = false; // _primeLocation() is running
  bool _locationReady = false;
  String _locationStatus = _finding;

  /// Location is off or not allowed: what's wrong, and how to fix it
  /// ('location_settings', 'app_settings' or 'ask').
  String? _locationError;
  String? _locationFix;

  /// The location found when this screen opened (or the latest one since).
  /// Sending uses it when a fresh GPS fix takes too long — see
  /// _positionForSend().
  Position? _lastPosition;

  /// Roughly where that is ("Rizal St, Zone II, Rosales"), so the resident
  /// can see it's right. Only shown; the server works out the place itself.
  String? _nearText;

  final List<String> _emergencyTypes = [
    'Fire',
    'Flood',
    'Earthquake',
    'Accident',
    'Medical Emergency',
    'Landslide',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _primeLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _descriptionController.dispose();
    _otherEmergencyController.dispose();
    super.dispose();
  }

  /// Coming back to the app (e.g. after turning location on in the
  /// phone's settings) looks for the location again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_locationReady && !_isLoading) {
      _primeLocation();
    }
  }

  // ── Location ──────────────────────────────────────────────────────

  /// Finds the location as soon as the screen opens, so it's ready by the
  /// time the resident sends the report. Waits at most 20 seconds, then
  /// uses the phone's last known location if there is one.
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
      _found(position);
    } on TimeoutException {
      final known = await _lastKnownPosition();
      if (!mounted) return;
      if (known != null) {
        _found(known);
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

  /// The location is ready; roughly where it is is looked up for the
  /// Location field.
  void _found(Position position) {
    _lastPosition = position;
    if (!mounted) return;
    setState(() {
      _locationReady = true;
      _locationStatus = 'Location ready';
    });
    _reverseGeocode(position.latitude, position.longitude).then((near) {
      if (mounted && near != null && _lastPosition == position) {
        setState(() => _nearText = near);
      }
    });
  }

  /// "Turn on" / "Allow" on the Location field.
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

  /// The location sent with the report: a fresh GPS fix if the phone gets
  /// one within 10 seconds, otherwise the one found when the screen
  /// opened, otherwise the phone's last known location.
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

    // Location off / not allowed come with their own message, shown at
    // the Location field too.
    if (problem is _LocationProblem) {
      final p = problem;
      if (mounted) {
        setState(() {
          _locationError = p.message;
          _locationFix = p.fix;
        });
      }
      throw p.message;
    }
    throw 'We couldn\'t find your location. Move near a window or outside '
        'and try again, or call MDRRMO.';
  }

  Future<Position> _getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const _LocationProblem(
        'Your phone\'s location is off. Turn it on so MDRRMO can find the '
            'emergency.',
        'location_settings',
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const _LocationProblem(
          'ResQPulse isn\'t allowed to use your location. Allow it so '
              'MDRRMO can find the emergency.',
          'ask',
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const _LocationProblem(
        'ResQPulse isn\'t allowed to use your location. Allow it in your '
            'phone\'s settings so MDRRMO can find the emergency.',
        'app_settings',
      );
    }

    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Roughly where a pin is, from OpenStreetMap ("Rizal St, Zone II,
  /// Rosales"). Null if it can't be found — the report is sent either way.
  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final response = await http
          .get(uri, headers: {'User-Agent': 'ResQPulse-MDRRMO-Rosales/1.0'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final address = data['address'] as Map<String, dynamic>?;

      final parts = <String>[];
      if (address != null) {
        final road = address['road'] ?? address['street'];
        final suburb =
            address['suburb'] ?? address['village'] ?? address['neighbourhood'];
        final city =
            address['town'] ?? address['city'] ?? address['municipality'];
        if (road != null) parts.add(road.toString());
        if (suburb != null) parts.add(suburb.toString());
        if (city != null) parts.add(city.toString());
      }

      return parts.isNotEmpty
          ? parts.join(', ')
          : data['display_name']?.toString();
    } catch (_) {
      return null;
    }
  }

  bool get _canAddMore => _pickedImages.length < _maxPhotos;

  // Photos are shrunk before they're sent. A phone camera photo is often
  // 3–6 MB: the server refuses any photo over 5 MB, and 3–5 full-size
  // photos took too long to upload on mobile data. At 1600 px they're
  // still clear enough to see what happened, at a few hundred KB each.
  static const double _photoMaxSide = 1600;
  static const int _photoQuality = 75;

  Future<void> _pickImageFromCamera() async {
    if (!_canAddMore) return;
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: _photoMaxSide,
        maxHeight: _photoMaxSide,
        imageQuality: _photoQuality,
      );
      if (pickedFile != null) {
        setState(() => _pickedImages.add(File(pickedFile.path)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open camera: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (!_canAddMore) return;
    try {
      final picker = ImagePicker();
      final remainingSlots = _maxPhotos - _pickedImages.length;

      final pickedFiles = await picker.pickMultiImage(
        maxWidth: _photoMaxSide,
        maxHeight: _photoMaxSide,
        imageQuality: _photoQuality,
      );
      if (pickedFiles.isNotEmpty) {
        final toAdd = pickedFiles.take(remainingSlots).toList();
        setState(() {
          _pickedImages.addAll(toAdd.map((x) => File(x.path)));
        });

        if (pickedFiles.length > remainingSlots && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Only $remainingSlots more photo(s) could be added (max $_maxPhotos).',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open gallery: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _removeImageAt(int index) {
    setState(() => _pickedImages.removeAt(index));
  }

  void _showImageSourceDialog() {
    if (!_canAddMore) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You can upload a maximum of $_maxPhotos photos.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Upload Photo',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3A8F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFF1A3A8F),
                  ),
                ),
                title: const Text(
                  'Take a Photo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Open camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageFromCamera();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A3A8F).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFF1A3A8F),
                  ),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text('Pick one or more photos'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageFromGallery();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The location for the report, or null after saying what's wrong.
  Future<Position?> _positionOrExplain() async {
    try {
      final position = await _positionForSend();
      if (mounted && !_locationReady) {
        setState(() {
          _locationReady = true;
          _locationStatus = 'Location ready';
          _locationError = null;
        });
      }
      return position;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
        ),
      );
      return null;
    }
  }

  void _handleSubmit() async {
    if (_isLoading) return;
    if (!_formKey.currentState!.validate()) return;

    if (_pickedImages.length < _minPhotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please upload at least $_minPhotos photos (${_pickedImages.length}/$_minPhotos so far).',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final resolvedEmergencyType = _selectedEmergency == 'Other'
        ? _otherEmergencyController.text.trim()
        : _selectedEmergency;

    setState(() => _isLoading = true);

    // The phone's location, like SOS: a fresh fix if it comes quickly,
    // otherwise the one found when the screen opened.
    final position = await _positionOrExplain();
    if (!mounted) return;
    if (position == null) {
      setState(() => _isLoading = false);
      return;
    }

    final result = await ApiService.submitIncident(
      emergencyType: resolvedEmergencyType,
      description: _descriptionController.text.trim(),
      photos: _pickedImages,
      latitude: position.latitude,
      longitude: position.longitude,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      // Every report is reviewed by MDRRMO before responders are sent —
      // the server's message says so (Api\IncidentController::store).
      final data = result.data;
      final String message = (data is Map && data['message'] is String)
          ? data['message'] as String
          : 'Report submitted. MDRRMO will review it and then send responders.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 5),
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to submit report.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Report Incident',
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
          padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.isGuest)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFFE65100),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Guest mode: only your location is required. Photos and a '
                            'description are optional. MDRRMO reviews guest reports before '
                            'they reach responders.',
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

                // ── Type of Emergency ───────────────────────────────
                _fieldLabel('Type of Emergency'),
                const SizedBox(height: 8),

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
                          .map(
                            (type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedEmergency = val);
                        }
                      },
                    ),
                  ),
                ),

                // ── "Other" emergency — free text input ─────────────
                if (_selectedEmergency == 'Other') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _otherEmergencyController,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1A1A2E),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Please specify the emergency type',
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 15,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.grey[300]!,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
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
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 1.5,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Colors.redAccent,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (v) {
                      if (_selectedEmergency != 'Other') return null;
                      return (v == null || v.trim().isEmpty)
                          ? 'Please specify the type of emergency'
                          : null;
                    },
                  ),
                ],

                const SizedBox(height: 20),

                // ── Location: the phone's own, like SOS (item 49) ────
                _fieldLabel('Location'),
                const SizedBox(height: 8),
                _buildLocationCard(),
                const SizedBox(height: 6),
                Text(
                  'Your phone\'s location is sent with the report, the same as '
                  'SOS. If you\'re not at the emergency, say where it is in '
                  'the description.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 20),

                // ── Description ─────────────────────────────────────
                Row(
                  children: [
                    _fieldLabel('Description'),
                    if (widget.isGuest) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(Optional)',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF1A1A2E),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Describe the incident...',
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF1A3A8F),
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
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
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.redAccent,
                        width: 1.5,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Colors.redAccent,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (v) {
                    if (widget.isGuest) return null;
                    return (v == null || v.isEmpty)
                        ? 'Please describe the incident'
                        : null;
                  },
                ),

                const SizedBox(height: 24),

                // ── Upload Photos ────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Upload Photos',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (widget.isGuest) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(Optional)',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      widget.isGuest
                          ? '${_pickedImages.length}/$_maxPhotos'
                          : '${_pickedImages.length}/$_maxPhotos  (min $_minPhotos required)',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _pickedImages.length >= _minPhotos
                            ? const Color(0xFF2E7D32)
                            : Colors.grey[600],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Photo grid + add tile
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pickedImages.length + (_canAddMore ? 1 : 0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    if (index == _pickedImages.length) {
                      return GestureDetector(
                        onTap: _showImageSourceDialog,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 1.5,
                            ),
                            color: const Color(0xFFF5F6FA),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_a_photo_outlined,
                                color: const Color(0xFF1A3A8F),
                                size: 24,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final image = _pickedImages[index];
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(image, fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImageAt(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 6),
                Text(
                  widget.isGuest
                      ? 'Photos are optional as a guest, but help responders prepare.'
                      : 'Upload $_minPhotos to $_maxPhotos photos of the incident.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),

                const SizedBox(height: 36),

                // ── Submit Button ────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A3A8F),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
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
                            'Submit Report',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Whether the location is ready, with roughly where it is — or what's
  /// wrong and a button to fix it ("Turn on" / "Allow"), like on SOS.
  Widget _buildLocationCard() {
    final bool problem = _locationError != null;
    final Color color = problem
        ? _red
        : (_locationReady ? _green : const Color(0xFF6B7280));
    final Color bg = problem
        ? const Color(0xFFFFEBEE)
        : (_locationReady ? const Color(0xFFE8F5E9) : const Color(0xFFF5F6FA));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(14, 12, problem ? 6 : 14, 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          if (!problem && !_locationReady && _locating)
            SizedBox(
              width: 18,
              height: 18,
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
              size: 20,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  problem
                      ? _locationError!
                      : (_locationReady
                            ? 'Location ready — MDRRMO can find you.'
                            : _locationStatus),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                    height: 1.35,
                  ),
                ),
                if (!problem && _locationReady && _nearText != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'Near $_nearText',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey[700],
                      height: 1.35,
                    ),
                  ),
                ],
              ],
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

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A2E),
      ),
    );
  }
}

/// Location is off or not allowed: the message to show, and how to fix it
/// ('location_settings', 'app_settings' or 'ask'). Same as on SOS.
class _LocationProblem implements Exception {
  final String message;
  final String fix;
  const _LocationProblem(this.message, this.fix);

  @override
  String toString() => message;
}
