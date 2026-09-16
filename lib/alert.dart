import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _selectedTab = 'Recent alerts';
  bool _isLoading = true;
  String? _errorMessage;

  final List<String> _tabs = ['Recent alerts', 'Alert History'];

  List<_AlertData> _allAlerts = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.getAlerts();

    if (!mounted) return;

    if (result.success && result.data is List) {
      setState(() {
        _allAlerts = (result.data as List)
            .map((e) => _AlertData.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result.error ?? 'Could not load alerts.';
        _isLoading = false;
      });
    }
  }

  /// "Recent alerts" = the latest 5, so citizens see what's new without
  /// scrolling; "Alert History" = everything ever broadcast. These are
  /// the two tab labels verbatim — matching on 'Recent' alone used to
  /// silently fail and made both tabs show the identical full list.
  /// "Recent alerts" = broadcast within the last 7 days — an actual time
  /// window, not just "the newest few regardless of age." Count-based
  /// filtering (latest 5) put a 3-week-old alert under "Recent" just
  /// because nothing newer existed, and made "Alert History" permanently
  /// empty whenever there were 5 or fewer alerts total. "Alert History"
  /// is the full archive — everything, including whatever's in Recent
  /// too, since that's what an archive is.
  List<_AlertData> get _filtered {
    if (_selectedTab == 'Recent alerts') {
      final cutoff = DateTime.now().subtract(const Duration(days: 7));
      return _allAlerts
          .where((a) => a.createdAt != null && a.createdAt!.isAfter(cutoff))
          .toList();
    }
    return _allAlerts;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Color(0xFF1A1A2E),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Alerts',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tab Bar ───────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: _tabs.map((tab) {
                final isSelected = _selectedTab == tab;
                return GestureDetector(
                  onTap: () => setState(() => _selectedTab = tab),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF1A1A2E)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF1A1A2E)
                            : Colors.grey[300]!,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Alert List ────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _loadAlerts,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _filtered.isEmpty
                ? Center(
                    child: Text(
                      _selectedTab == 'Recent alerts'
                          ? 'No new alerts this week — check Alert History for past updates.'
                          : 'No alert history yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 15),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadAlerts,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        return _AlertCard(alert: _filtered[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Alert Data Model ──────────────────────────────────────────────────────────
//
// Maps directly to the `alerts` table / Alert model fillable fields:
//   title, subtitle, body, type, user_id
//
// `subtitle` is used as the location line (e.g. "Rosales").
// `body` is the actual broadcast message (e.g. "ahfjkasfkjds") and was
// previously not read at all, which is why it never appeared in the app.

class _AlertData {
  final String title;
  final String? subtitle;
  final String? body;
  final String dateTime;
  final DateTime? createdAt;
  final String type;

  const _AlertData({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.dateTime,
    required this.createdAt,
    required this.type,
  });

  factory _AlertData.fromJson(Map<String, dynamic> json) {
    return _AlertData(
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
      body: json['body'],
      dateTime: _formatDate(json['created_at']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      type: json['type'] ?? 'Alerts',
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _formatDate(String? isoString) {
    if (isoString == null) return '';
    final date = DateTime.tryParse(isoString);
    if (date == null) return '';

    final month = _months[date.month - 1];
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$month ${date.day}, ${date.year} - $hour12:$minute $period';
  }
}

// ── Alert Card ────────────────────────────────────────────────────────────────

/// Picks an icon + color that actually matches what the alert is about,
/// by keyword-matching the title/subtitle — the Alert model has no
/// hazard-category field (its `type` column is an audience switch:
/// Citizens/Responders/Both, not a hazard type), so this is the only
/// signal available. Falls back to a generic advisory icon rather than
/// mislabeling every alert as a flood.
class _AlertStyle {
  final IconData icon;
  final Color color;
  const _AlertStyle(this.icon, this.color);
}

const _defaultAlertStyle = _AlertStyle(Icons.campaign, Color(0xFF1A3A8F));

const Map<String, _AlertStyle> _alertKeywordStyles = {
  'fire': _AlertStyle(Icons.local_fire_department, Color(0xFFD32F2F)),
  'flood': _AlertStyle(Icons.water, Color(0xFF1565C0)),
  'typhoon': _AlertStyle(Icons.cyclone, Color(0xFF6A1B9A)),
  'storm': _AlertStyle(Icons.cyclone, Color(0xFF6A1B9A)),
  'earthquake': _AlertStyle(Icons.landscape, Color(0xFF6D4C41)),
  'landslide': _AlertStyle(Icons.terrain, Color(0xFF6D4C41)),
  'evacuat': _AlertStyle(
    Icons.directions_run,
    Color(0xFFE65100),
  ), // evacuate/evacuation
  'health': _AlertStyle(Icons.local_hospital, Color(0xFF00897B)),
  'power': _AlertStyle(Icons.bolt, Color(0xFFF9A825)),
  'water supply': _AlertStyle(Icons.water_drop, Color(0xFF1565C0)),
  'road': _AlertStyle(Icons.warning_amber_rounded, Color(0xFFE65100)),
};

_AlertStyle _styleForAlert(_AlertData alert) {
  final text = '${alert.title} ${alert.subtitle ?? ''}'.toLowerCase();
  for (final entry in _alertKeywordStyles.entries) {
    if (text.contains(entry.key)) return entry.value;
  }
  return _defaultAlertStyle;
}

class _AlertCard extends StatelessWidget {
  final _AlertData alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final style = _styleForAlert(alert);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: style.color, width: 2),
            ),
            child: Icon(style.icon, color: style.color, size: 22),
          ),
          const SizedBox(width: 14),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                if (alert.subtitle != null && alert.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    alert.subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
                if (alert.body != null && alert.body!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    alert.body!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF1A1A2E),
                      height: 1.35,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  alert.dateTime,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
