import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

class EvacuationCentersScreen extends StatefulWidget {
  const EvacuationCentersScreen({super.key});

  @override
  State<EvacuationCentersScreen> createState() =>
      _EvacuationCentersScreenState();
}

class _EvacuationCentersScreenState extends State<EvacuationCentersScreen> {
  final MapController _mapController = MapController();

  // Center map on Rosales, Pangasinan (fallback until we get a GPS fix)
  final LatLng _mapCenter = const LatLng(15.8957, 120.6278);

  List<_EvacCenter> _centers = [];
  bool _isLoadingCenters = true;
  String? _centersError;

  int? _selectedIndex;

  LatLng? _userLocation;
  bool _isLocating = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _loadCenters();
    _determineUserLocation();
  }

  // ── Real evacuation centers, from the admin-managed evacuation_centers table ──
  Future<void> _loadCenters() async {
    setState(() {
      _isLoadingCenters = true;
      _centersError = null;
    });

    final result = await ApiService.getEvacuationCenters();

    if (!mounted) return;

    if (result.success && result.data is List) {
      setState(() {
        _centers = (result.data as List)
            .map((e) => _EvacCenter.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoadingCenters = false;
      });
    } else {
      setState(() {
        _centersError = result.error ?? 'Could not load evacuation centers.';
        _isLoadingCenters = false;
      });
    }
  }

  Future<void> _determineUserLocation() async {
    setState(() {
      _isLocating = true;
      _locationError = null;
    });

    try {
      // 1. Make sure location services are actually on.
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLocating = false;
          _locationError = 'Location services are turned off.';
        });
        return;
      }

      // 2. Check / request permission.
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLocating = false;
            _locationError = 'Location permission denied.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLocating = false;
          _locationError =
              'Location permission permanently denied. Enable it in Settings.';
        });
        return;
      }

      // 3. Get the current position.
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 12));

      if (!mounted) return;

      final userLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _userLocation = userLatLng;
        _isLocating = false;
      });

      // Fly the map to the user's actual location once we have it.
      _mapController.move(userLatLng, 15.5);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocating = false;
        _locationError = 'Could not get your location.';
      });
    }
  }

  void _flyTo(LatLng location, int index) {
    setState(() => _selectedIndex = index);
    _mapController.move(location, 15.5);
  }

  void _flyToMyLocation() {
    if (_userLocation != null) {
      setState(() => _selectedIndex = null);
      _mapController.move(_userLocation!, 16);
    } else {
      _determineUserLocation();
    }
  }

  /// Live distance from the user's current GPS position to a center —
  /// computed on-device, not stored, so it's always accurate.
  String _distanceTo(_EvacCenter center) {
    if (_userLocation == null) return '—';

    final meters = Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      center.latitude,
      center.longitude,
    );

    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'full':
        return const Color(0xFFD32F2F);
      case 'closed':
        return Colors.grey;
      default:
        return const Color(0xFF2E7D32);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'full':
        return 'Full';
      case 'closed':
        return 'Closed';
      default:
        return 'Open';
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
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
          'Evacuation Centers',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Column(
        children: [
          // ── Map ───────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _mapCenter,
                    initialZoom: 14.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.resqpulse.app',
                    ),

                    // Accuracy halo around the user's position
                    if (_userLocation != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _userLocation!,
                            radius: 60,
                            useRadiusInMeter: true,
                            color: const Color(0xFF1A3A8F).withOpacity(0.15),
                            borderColor: const Color(
                              0xFF1A3A8F,
                            ).withOpacity(0.3),
                            borderStrokeWidth: 1,
                          ),
                        ],
                      ),

                    MarkerLayer(
                      markers: [
                        // Evacuation center pins (real data from the admin panel)
                        ..._centers.asMap().entries.map((entry) {
                          final i = entry.key;
                          final center = entry.value;
                          final isSelected = _selectedIndex == i;
                          return Marker(
                            point: center.location,
                            width: 40,
                            height: 40,
                            child: GestureDetector(
                              onTap: () => _flyTo(center.location, i),
                              child: Icon(
                                Icons.location_pin,
                                color: isSelected
                                    ? const Color(0xFF1A3A8F)
                                    : _statusColor(center.status),
                                size: isSelected ? 40 : 32,
                              ),
                            ),
                          );
                        }),

                        // "You are here" marker
                        if (_userLocation != null)
                          Marker(
                            point: _userLocation!,
                            width: 26,
                            height: 26,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF1A73E8),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Recenter-on-me button
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: GestureDetector(
                    onTap: _flyToMyLocation,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _isLocating
                          ? const Padding(
                              padding: EdgeInsets.all(9),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Color(0xFF1A3A8F),
                              ),
                            )
                          : const Icon(
                              Icons.my_location,
                              color: Color(0xFF1A3A8F),
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Location error banner (permission denied / services off)
          if (_locationError != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      _locationError!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFE65100),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _determineUserLocation,
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFE65100),
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // ── Centers List ──────────────────────────────────────────
          Expanded(
            child: _isLoadingCenters
                ? const Center(child: CircularProgressIndicator())
                : _centersError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _centersError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _loadCenters,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _centers.isEmpty
                ? Center(
                    child: Text(
                      'No evacuation centers available yet.',
                      style: TextStyle(color: Colors.grey[500], fontSize: 15),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        Future.wait([_loadCenters(), _determineUserLocation()]),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      itemCount: _centers.length,
                      itemBuilder: (context, index) {
                        final center = _centers[index];
                        final isSelected = _selectedIndex == index;
                        return GestureDetector(
                          onTap: () => _flyTo(center.location, index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF1A3A8F)
                                    : Colors.grey[200]!,
                                width: isSelected ? 2 : 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Icon
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(
                                            0xFF1A3A8F,
                                          ).withOpacity(0.1)
                                        : Colors.grey[100],
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.home_work_outlined,
                                    color: isSelected
                                        ? const Color(0xFF1A3A8F)
                                        : Colors.grey[600],
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                // Text
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              center.name,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isSelected
                                                    ? const Color(0xFF1A3A8F)
                                                    : const Color(0xFF1A1A2E),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _statusColor(
                                                center.status,
                                              ).withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              _statusLabel(center.status),
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.bold,
                                                color: _statusColor(
                                                  center.status,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Brgy. ${center.barangay}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _distanceTo(center),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1A3A8F),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[400],
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Model ─────────────────────────────────────────────────────────────────────

class _EvacCenter {
  final int id;
  final String name;
  final String barangay;
  final double latitude;
  final double longitude;
  final int capacity;
  final int occupancy;
  final String status;

  const _EvacCenter({
    required this.id,
    required this.name,
    required this.barangay,
    required this.latitude,
    required this.longitude,
    required this.capacity,
    required this.occupancy,
    required this.status,
  });

  LatLng get location => LatLng(latitude, longitude);

  factory _EvacCenter.fromJson(Map<String, dynamic> json) {
    return _EvacCenter(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      barangay: json['barangay']?.toString() ?? '',
      latitude: double.tryParse('${json['latitude']}') ?? 0,
      longitude: double.tryParse('${json['longitude']}') ?? 0,
      capacity: json['capacity'] is int
          ? json['capacity']
          : int.tryParse('${json['capacity']}') ?? 0,
      occupancy: json['occupancy'] is int
          ? json['occupancy']
          : int.tryParse('${json['occupancy']}') ?? 0,
      status: json['status']?.toString() ?? 'open',
    );
  }
}
