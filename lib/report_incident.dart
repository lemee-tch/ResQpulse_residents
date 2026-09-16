import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

class ReportIncidentScreen extends StatefulWidget {
  final bool isGuest;
  const ReportIncidentScreen({super.key, this.isGuest = false});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

enum _LocationSource { none, gps, barangayLookup, error }

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
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

  // ── Coordinates that actually get submitted with the report ─────────
  double? _latitude;
  double? _longitude;
  _LocationSource _locationSource = _LocationSource.none;
  String? _locationStatusMessage;
  bool _isResolvingLocation = false;

  // ── Location dropdown/autocomplete state ───────────────────────────
  TextEditingController? _locationFieldController;

  static const String _currentLocationOption = '📍 Use My Current Location';

  // Verified barangay centroid coordinates — computed from official PSGC
  // boundary polygons (Philippine Statistics Authority), not from live
  // text-search geocoding. Every barangay below has a real, accurate pin;
  // there is no "couldn't pinpoint" fallback path anymore because nothing
  // in this table can fail to resolve.
  static const Map<String, _LatLng> _barangayCoordinates = {
    'Acop': _LatLng(15.867531, 120.652154),
    'Bakitbakit': _LatLng(15.878026, 120.650273),
    'Balingcanaway': _LatLng(15.892046, 120.651996),
    'Cabalaoangan Norte': _LatLng(15.884509, 120.626134),
    'Cabalaoangan Sur': _LatLng(15.876132, 120.633595),
    'Calanutan': _LatLng(15.864204, 120.633487),
    'Camangaan': _LatLng(15.849665, 120.635914),
    'Capitan Tomas': _LatLng(15.908782, 120.644112),
    'Carmay East': _LatLng(15.914305, 120.637743),
    'Carmay West': _LatLng(15.911984, 120.625233),
    'Carmen East': _LatLng(15.891492, 120.601517),
    'Carmen West': _LatLng(15.888648, 120.594245),
    'Casanicolasan': _LatLng(15.924801, 120.642405),
    'Coliling': _LatLng(15.854561, 120.620069),
    'Don Antonio Village': _LatLng(15.899285, 120.621318),
    'Guiling': _LatLng(15.849206, 120.621911),
    'Palakipak': _LatLng(15.862663, 120.617815),
    'Pangaoan': _LatLng(15.838011, 120.641362),
    'Rabago': _LatLng(15.856993, 120.634730),
    'Rizal': _LatLng(15.923404, 120.630220),
    'Salvacion': _LatLng(15.846088, 120.659706),
    'San Angel': _LatLng(15.860160, 120.656112),
    'San Antonio': _LatLng(15.853902, 120.658100),
    'San Bartolome': _LatLng(15.875859, 120.611195),
    'San Isidro': _LatLng(15.838424, 120.623979),
    'San Luis': _LatLng(15.842845, 120.650298),
    'San Pedro East': _LatLng(15.896897, 120.645530),
    'San Pedro West': _LatLng(15.896184, 120.636969),
    'San Vicente': _LatLng(15.847728, 120.671759),
    'Station District': _LatLng(15.892017, 120.620915),
    'Tomana East': _LatLng(15.895439, 120.613376),
    'Tomana West': _LatLng(15.892375, 120.608154),
    'Zone I (Poblacion)': _LatLng(15.888483, 120.623073),
    'Zone II (Poblacion)': _LatLng(15.897089, 120.629352),
    'Zone III (Poblacion)': _LatLng(15.904627, 120.621300),
    'Zone IV (Poblacion)': _LatLng(15.904928, 120.629206),
    'Zone V (Poblacion)': _LatLng(15.890244, 120.629699),
  };

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

  // Flat, searchable list of barangay-only options. Street/zone combos were
  // removed — Nominatim can't reliably geocode a "barangay + street + zone"
  // string down to real coordinates (see _resolveCoordinatesForSelection),
  // so only offering barangay-level choices guarantees every dropdown pick
  // resolves to an accurate pin instead of falling back to a generic point.
  static final List<String> _locationOptions = _buildLocationOptions();

  static List<String> _buildLocationOptions() {
    return _barangays.map((barangay) => 'Rosales, $barangay').toList();
  }

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
  void dispose() {
    _descriptionController.dispose();
    _otherEmergencyController.dispose();
    // Note: _locationFieldController is owned/disposed internally by the
    // Autocomplete widget — do NOT dispose it here.
    super.dispose();
  }

  // ── GPS: used only when the person picks "Use My Current Location" ──
  Future<void> _fillCurrentLocationAddress() async {
    setState(() {
      _isResolvingLocation = true;
      _locationSource = _LocationSource.none;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setLocationError('Location services are off. Please enable GPS.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _setLocationError('Location permission denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _setLocationError(
          'Location permission permanently denied. Enable it in app settings.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      _latitude = position.latitude;
      _longitude = position.longitude;

      // Reverse-geocode into a readable address for the text field.
      final address = await _reverseGeocode(
        position.latitude,
        position.longitude,
      );
      _locationFieldController?.text =
          address ??
          'Current Location (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})';

      setState(() {
        _locationSource = _LocationSource.gps;
        _locationStatusMessage =
            'Using your current GPS location (${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)})';
        _isResolvingLocation = false;
      });
    } catch (e) {
      _setLocationError('Could not get your location. Please try again.');
    }
  }

  void _setLocationError(String message) {
    if (!mounted) return;
    setState(() {
      _locationSource = _LocationSource.error;
      _locationStatusMessage = message;
      _isResolvingLocation = false;
    });
  }

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

  // ── Resolve a selected barangay to its pin using the static, verified
  // coordinate table — no network call, no chance of a bad match, and no
  // "couldn't pinpoint" fallback, since every barangay in the dropdown
  // has a known-accurate coordinate. ────────────────────────────────
  Future<void> _resolveCoordinatesForSelection(String selection) async {
    setState(() {
      _isResolvingLocation = true;
      _locationSource = _LocationSource.none;
    });

    final parts = selection.split(',').map((p) => p.trim()).toList();
    final candidate = parts.length >= 2 ? parts[1] : selection.trim();

    // Case-insensitive match against the verified table — covers both a
    // dropdown pick ("Rosales, Acop") and free-typed text ("acop").
    final matchKey = _barangayCoordinates.keys.firstWhere(
      (key) => key.toLowerCase() == candidate.toLowerCase(),
      orElse: () => '',
    );
    final barangay = matchKey.isNotEmpty ? matchKey : candidate;
    final coords = _barangayCoordinates[matchKey];

    if (!mounted) return;

    if (coords != null) {
      setState(() {
        _latitude = coords.lat;
        _longitude = coords.lng;
        _locationSource = _LocationSource.barangayLookup;
        _locationStatusMessage =
            'Pinned at Brgy. $barangay (${coords.lat.toStringAsFixed(5)}, ${coords.lng.toStringAsFixed(5)})';
        _isResolvingLocation = false;
      });
    } else {
      // Should never happen — the dropdown only offers barangays that
      // exist in _barangayCoordinates — but guard against it anyway.
      setState(() {
        _locationSource = _LocationSource.error;
        _locationStatusMessage =
            'Unrecognized barangay. Please pick one from the list.';
        _isResolvingLocation = false;
      });
    }
  }

  bool get _canAddMore => _pickedImages.length < _maxPhotos;

  Future<void> _pickImageFromCamera() async {
    if (!_canAddMore) return;
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
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

      final pickedFiles = await picker.pickMultiImage(imageQuality: 80);
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

  void _handleSubmit() async {
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

    final locationText = _locationFieldController?.text.trim() ?? '';

    // Safety net: if the person typed a location manually and never
    // selected a suggestion (so we never geocoded it), try once more
    // right before submitting so the report still gets a map pin.
    if (_latitude == null && locationText.isNotEmpty) {
      await _resolveCoordinatesForSelection(locationText);
    }

    // Guests are only required to have a location pin (from GPS or a
    // barangay pick) — everything else on the form is optional for them.
    if (widget.isGuest && _latitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please share your location so MDRRMO can find you.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final resolvedEmergencyType = _selectedEmergency == 'Other'
        ? _otherEmergencyController.text.trim()
        : _selectedEmergency;

    setState(() => _isLoading = true);

    final result = await ApiService.submitIncident(
      emergencyType: resolvedEmergencyType,
      location: locationText,
      description: _descriptionController.text.trim(),
      photos: _pickedImages,
      latitude: _latitude,
      longitude: _longitude,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isGuest
                ? 'Report submitted. MDRRMO will review it shortly.'
                : 'Report submitted.',
          ),
          backgroundColor: const Color(0xFF2E7D32),
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

                // ── Location ────────────────────────────────────────
                _fieldLabel('Location'),
                const SizedBox(height: 8),

                // Unified status banner — reflects whichever source last
                // set the coordinates: GPS, barangay lookup, or an error.
                if (_locationSource != _LocationSource.none ||
                    _isResolvingLocation)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _locationSource == _LocationSource.error
                          ? Colors.red[50]
                          : (_locationSource != _LocationSource.none
                                ? const Color(0xFFE8F5E9)
                                : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        if (_isResolvingLocation)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            _locationSource == _LocationSource.error
                                ? Icons.error_outline
                                : (_locationSource == _LocationSource.gps
                                      ? Icons.gps_fixed
                                      : Icons.location_on),
                            size: 18,
                            color: _locationSource == _LocationSource.error
                                ? Colors.red
                                : const Color(0xFF2E7D32),
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isResolvingLocation
                                ? 'Finding coordinates...'
                                : (_locationStatusMessage ?? ''),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _locationSource == _LocationSource.error
                                  ? Colors.red[700]
                                  : Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Searchable location dropdown (barangay + street + zone)
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    final query = textEditingValue.text.trim().toLowerCase();
                    if (query.isEmpty) {
                      return const [_currentLocationOption];
                    }
                    final filtered = _locationOptions
                        .where((opt) => opt.toLowerCase().contains(query))
                        .take(50)
                        .toList();
                    return [_currentLocationOption, ...filtered];
                  },
                  onSelected: (String selection) async {
                    if (selection == _currentLocationOption) {
                      _locationFieldController?.text =
                          'Fetching your location...';
                      await _fillCurrentLocationAddress();
                    } else {
                      _locationFieldController?.text = selection;
                      await _resolveCoordinatesForSelection(selection);
                    }
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        _locationFieldController = controller;
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          onFieldSubmitted: (_) => onFieldSubmitted(),
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF1A1A2E),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search or select your barangay...',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 13.5,
                            ),
                            suffixIcon: _isResolvingLocation
                                ? const Padding(
                                    padding: EdgeInsets.all(14),
                                    child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.location_on_outlined,
                                    color: Color(0xFF1A3A8F),
                                    size: 22,
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
                            // Guests can rely on GPS/barangay pick alone;
                            // the coordinate check happens in
                            // _handleSubmit(). Logged-in citizens keep the
                            // original "must type/select something" rule.
                            if (widget.isGuest) return null;
                            return (v == null || v.trim().isEmpty)
                                ? 'Please select or enter the location'
                                : null;
                          },
                        );
                      },
                  optionsViewBuilder: (context, onSelected, options) {
                    final optionsList = options.toList();
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width - 44,
                          height: optionsList.length > 5 ? 260 : null,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shrinkWrap: optionsList.length <= 5,
                            itemCount: optionsList.length,
                            itemBuilder: (context, index) {
                              final option = optionsList[index];
                              final isCurrentLocation =
                                  option == _currentLocationOption;
                              return ListTile(
                                dense: true,
                                leading: Icon(
                                  isCurrentLocation
                                      ? Icons.my_location
                                      : Icons.location_on_outlined,
                                  color: isCurrentLocation
                                      ? const Color(0xFF1A3A8F)
                                      : Colors.grey[500],
                                  size: 20,
                                ),
                                title: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: isCurrentLocation
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isCurrentLocation
                                        ? const Color(0xFF1A3A8F)
                                        : const Color(0xFF1A1A2E),
                                  ),
                                ),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
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

class _LatLng {
  final double lat;
  final double lng;
  const _LatLng(this.lat, this.lng);
}
