import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'api_service.dart';

class EmergencyHotlinesScreen extends StatefulWidget {
  final bool isGuest;
  const EmergencyHotlinesScreen({super.key, this.isGuest = false});

  @override
  State<EmergencyHotlinesScreen> createState() =>
      _EmergencyHotlinesScreenState();
}

class _EmergencyHotlinesScreenState extends State<EmergencyHotlinesScreen> {
  bool _isLoading = true;
  String? _barangay;
  String _barangaySearchQuery = '';

  // ── Municipal-wide hotlines — same for every citizen ─────────────────
  static const List<_HotlineCategory> _municipalCategories = [
    _HotlineCategory(
      title: 'Police & Security',
      hotlines: [
        _Hotline(
          name: 'PNP Rosales',
          number: '+63 998 598 5140',
          description: 'Rosales Municipal Police Station',
          icon: Icons.local_police_outlined,
          color: Color(0xFF1565C0),
        ),
      ],
    ),
    _HotlineCategory(
      title: 'Fire & Rescue',
      hotlines: [
        _Hotline(
          name: 'BFP Rosales',
          number: '+63 917 187 1611',
          description: 'Rosales Fire Station',
          icon: Icons.local_fire_department_outlined,
          color: Color(0xFFE65100),
        ),
      ],
    ),
    _HotlineCategory(
      title: 'Medical & Health',
      hotlines: [
        _Hotline(
          name: 'RHU Rosales',
          number: '(075) 523-0889',
          description: 'Rural Health Unit landline',
          icon: Icons.local_hospital_outlined,
          color: Color(0xFF00897B),
        ),
      ],
    ),
    _HotlineCategory(
      title: 'Local Government',
      hotlines: [
        _Hotline(
          name: 'MDRRMO Rosales',
          number: '#2441',
          description: 'Municipal Disaster Risk Reduction',
          icon: Icons.shield_outlined,
          color: Color(0xFF00308F),
        ),
      ],
    ),
  ];

  // ── Per-barangay hotlines ─────────────────────────────────────────────
  // Key MUST exactly match the barangay strings used in register.dart /
  // report_incident.dart (_barangays list) so the lookup below works.
  //
  // TODO(MDRRMO): replace these placeholder numbers with the real contact
  // number for each Barangay Hall / Barangay Tanod / Barangay Captain.
  static const Map<String, String> _barangayHotlines = {
    'Acop': '+63 981 169 2647',
    'Bakitbakit': '+63 906 484 6318',
    'Balingcanaway': '+63 946 468 2986',
    'Cabalaoangan Norte': '+63 967 390 2830',
    'Cabalaoangan Sur': '+63 967 831 2889',
    'Calanutan': '+63 995 056 5507',
    'Camangaan': '+63 995 056 5507',
    'Capitan Tomas': '+63 963 229 5876',
    'Carmay East': '+63 995 982 2854',
    'Carmay West': '+63 930 500 3040',
    'Carmen East': '+63 907 075 6772',
    'Carmen West': '+63 920 946 7810',
    'Casanicolasan': '+63 920 946 7810',
    'Coliling': '+63 920 946 7810',
    'Don Antonio Village': '+63 920 946 7810',
    'Guiling': '+63 966 198 1140',
    'Palakipak': '+63 950 087 2967',
    'Pangaoan': '+63 981 289 5132',
    'Rabago': '+63 923 090 9435',
    'Rizal': '+63 912 291 2599',
    'Salvacion': '+63 923 746 7756',
    'San Angel': '+63 923 746 7756',
    'San Antonio': '+63 947 726 3594',
    'San Bartolome': '+63 947 726 3594',
    'San Isidro': '+63 947 726 3594',
    'San Luis': '+63 947 726 3594',
    'San Pedro East': '+63 950 513 9559',
    'San Pedro West': '+63 950 513 9559',
    'San Vicente': '+63 920 626 1002',
    'Station District': '+63 929 115 3818',
    'Tomana East': '+63 929 115 3818',
    'Tomana West': '+63 929 115 3818',
    'Zone I (Poblacion)': '+63 929 115 3818',
    'Zone II (Poblacion)': '+63 929 115 3818',
    'Zone III (Poblacion)': '+63 946 547 5014',
    'Zone IV (Poblacion)': '+63 981 258 1603',
    'Zone V (Poblacion)': '+63 968 887 7276',
  };

  @override
  void initState() {
    super.initState();
    _loadBarangay();
  }

  Future<void> _loadBarangay() async {
    // Guests have no stored citizen record — skip the lookup entirely
    // and fall through to showing the full barangay list at the bottom.
    if (widget.isGuest) {
      setState(() => _isLoading = false);
      return;
    }

    final citizen = await ApiService.getUser();
    if (!mounted) return;
    setState(() {
      _barangay = citizen?['barangay'];
      _isLoading = false;
    });
  }

  /// Builds the final category list:
  /// - Logged-in citizens: their own Barangay Officials card first, then
  ///   the municipal-wide ones.
  /// - Guests: municipal-wide ones, then EVERY barangay's hotline listed
  ///   at the very bottom (since we don't know which one is "theirs").
  List<_HotlineCategory> get _categories {
    final List<_HotlineCategory> categories = [];

    if (!widget.isGuest && _barangay != null && _barangay!.isNotEmpty) {
      final number = _barangayHotlines[_barangay!];
      categories.add(
        _HotlineCategory(
          title: 'Barangay Officials',
          hotlines: [
            _Hotline(
              name: 'Brgy. $_barangay',
              number: number ?? 'Contact your Barangay Hall',
              description: 'Barangay Officials — Brgy. $_barangay',
              icon: Icons.home_work_outlined,
              color: const Color(0xFF2E7D32),
            ),
          ],
        ),
      );
    }

    categories.addAll(_municipalCategories);

    if (widget.isGuest) {
      final sortedBarangays = _barangayHotlines.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));

      final query = _barangaySearchQuery.trim().toLowerCase();
      final filteredBarangays = query.isEmpty
          ? sortedBarangays
          : sortedBarangays
                .where((entry) => entry.key.toLowerCase().contains(query))
                .toList();

      categories.add(
        _HotlineCategory(
          title: 'All Barangay Hotlines',
          hotlines: filteredBarangays
              .map(
                (entry) => _Hotline(
                  name: 'Brgy. ${entry.key}',
                  number: entry.value,
                  description: 'Barangay Officials — Brgy. ${entry.key}',
                  icon: Icons.home_work_outlined,
                  color: const Color(0xFF2E7D32),
                ),
              )
              .toList(),
        ),
      );
    }

    return categories;
  }

  Future<void> _callNumber(BuildContext context, String number) async {
    final cleaned = number.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No number on file yet.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final uri = Uri.parse('tel:$cleaned');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cannot call $number on this device.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showCallDialog(BuildContext context, _Hotline hotline) {
    final bool hasRealNumber =
        RegExp(r'\d').hasMatch(hotline.number) &&
        !hotline.number.toLowerCase().contains('contact');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: hotline.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(hotline.icon, color: hotline.color, size: 34),
              ),
              const SizedBox(height: 16),

              Text(
                hotline.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hotline.description,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),

              // Phone number display
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: hotline.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone, color: hotline.color, size: 20),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        hotline.number,
                        style: TextStyle(
                          fontSize: hasRealNumber ? 22 : 15,
                          fontWeight: FontWeight.bold,
                          color: hotline.color,
                          letterSpacing: hasRealNumber ? 1.5 : 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Call button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: hasRealNumber
                      ? () {
                          Navigator.pop(ctx);
                          _callNumber(context, hotline.number);
                        }
                      : null,
                  icon: const Icon(Icons.call, size: 20),
                  label: Text(
                    hasRealNumber ? 'Call ${hotline.number}' : 'No number yet',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hotline.color,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 2,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Cancel
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
          'Emergency Hotlines',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top banner
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD32F2F), Color(0xFFEF5350)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emergency,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'In case of emergency',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Tap any hotline below to call immediately',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Search bar — guest mode only, filters the barangay list below
                if (widget.isGuest)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    child: TextField(
                      onChanged: (v) =>
                          setState(() => _barangaySearchQuery = v),
                      decoration: InputDecoration(
                        hintText: 'Search barangay...',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.grey[500],
                          size: 20,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1.2,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1.2,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF1A3A8F),
                            width: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Hotline list
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _categories.length,
                    itemBuilder: (context, catIndex) {
                      final category = _categories[catIndex];

                      if (category.hotlines.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A2E),
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'No barangays match "$_barangaySearchQuery".',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 4,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: category.hotlines.first.color,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  category.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A2E),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...category.hotlines.map(
                            (hotline) => _HotlineCard(
                              hotline: hotline,
                              onTap: () => _showCallDialog(context, hotline),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Hotline Card ──────────────────────────────────────────────────────────────

class _HotlineCard extends StatelessWidget {
  final _Hotline hotline;
  final VoidCallback onTap;

  const _HotlineCard({required this.hotline, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: hotline.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(hotline.icon, color: hotline.color, size: 22),
            ),
            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hotline.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hotline.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),

            // Number + call button
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    hotline.number,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: hotline.color,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: hotline.color,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.call, color: Colors.white, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Call',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class _HotlineCategory {
  final String title;
  final List<_Hotline> hotlines;
  const _HotlineCategory({required this.title, required this.hotlines});
}

class _Hotline {
  final String name;
  final String number;
  final String description;
  final IconData icon;
  final Color color;
  const _Hotline({
    required this.name,
    required this.number,
    required this.description,
    required this.icon,
    required this.color,
  });
}
