import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

class AlertsScreen extends StatefulWidget {
  /// Opens on "Alert History" instead of "Recent alerts" — used by Home's
  /// "See all" and by a recent alert there that's older than 24 hours.
  final bool openHistory;

  const AlertsScreen({super.key, this.openHistory = false});

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
    if (widget.openHistory) _selectedTab = 'Alert History';
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

  /// "Recent alerts" = broadcast within the last 24 hours — an actual
  /// time window, not just "the newest few regardless of age." A wider
  /// window (this used to be 7 days) kept days-old alerts showing under
  /// "Recent" long after they stopped being recent. "Alert History" is
  /// the full archive — everything, including whatever's in Recent too,
  /// since that's what an archive is. (The tab labels are matched
  /// verbatim — matching on 'Recent' alone once made both tabs show the
  /// same full list.)
  List<_AlertData> get _filtered {
    if (_selectedTab == 'Recent alerts') {
      final cutoff = DateTime.now().subtract(const Duration(hours: 24));
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        // "Recent" is the last 24 hours (see _filtered) —
                        // this used to say "this week".
                        _selectedTab == 'Recent alerts'
                            ? 'No alerts in the last 24 hours — check Alert History for past updates.'
                            : 'No alert history yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 15),
                      ),
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
      // The API sends a UTC-flagged timestamp (e.g. "...Z" or "+00:00").
      // DateTime.tryParse() keeps that UTC flag, so every .hour/.day
      // read off it — including the "Recent alerts" 24h cutoff above —
      // was silently 8 hours behind Manila time until this is converted
      // with .toLocal(). This is the field that filter actually reads.
      createdAt: DateTime.tryParse(
        json['created_at']?.toString() ?? '',
      )?.toLocal(),
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
    // Same fix as createdAt above — without .toLocal() this renders the
    // raw UTC wall-clock time on screen instead of Manila (UTC+8) time,
    // which is why the displayed timestamp was 8 hours off.
    final date = DateTime.tryParse(isoString)?.toLocal();
    if (date == null) return '';

    final month = _months[date.month - 1];
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$month ${date.day}, ${date.year} - $hour12:$minute $period';
  }
}

// ── Alert Card ────────────────────────────────────────────────────────────────

/// An alert's icon and color, picked from what the alert is about — see
/// alertStyleFor(). Also used by Home's "Recent Alerts" card, which used
/// to show the same icon for every alert.
class AlertStyle {
  final IconData icon;
  final Color color;
  const AlertStyle(this.icon, this.color);
}

const AlertStyle _defaultAlertStyle = AlertStyle(
  Icons.campaign,
  Color(0xFF1A3A8F),
);

/// Words (English and Filipino) that say what an alert is about. Each one
/// is matched at the start of a word, so "broadcast" no longer counts as
/// "road", and "bahay" doesn't count as "baha".
class _KeywordStyle {
  final RegExp pattern;
  final AlertStyle style;

  _KeywordStyle(String words, this.style)
    : pattern = RegExp('\\b($words)', caseSensitive: false);
}

/// Checked in this order — the first match wins.
final List<_KeywordStyle> _alertKeywordStyles = [
  _KeywordStyle(
    'fire|sunog',
    const AlertStyle(Icons.local_fire_department, Color(0xFFD32F2F)),
  ),
  _KeywordStyle(
    'flood|baha\\b|bumabaha|pagbaha',
    const AlertStyle(Icons.water, Color(0xFF1565C0)),
  ),
  _KeywordStyle(
    'typhoon|storm|thunderstorm|tropical|bagyo|signal (no|#)',
    const AlertStyle(Icons.cyclone, Color(0xFF6A1B9A)),
  ),
  _KeywordStyle(
    'earthquake|lindol',
    const AlertStyle(Icons.landscape, Color(0xFF6D4C41)),
  ),
  _KeywordStyle(
    'landslide|guho',
    const AlertStyle(Icons.terrain, Color(0xFF6D4C41)),
  ),
  _KeywordStyle(
    'evacuat|lumikas|paglikas|ilikas',
    const AlertStyle(Icons.directions_run, Color(0xFFE65100)),
  ),
  _KeywordStyle(
    'rain|ulan',
    const AlertStyle(Icons.umbrella, Color(0xFF1565C0)),
  ),
  _KeywordStyle('heat', const AlertStyle(Icons.thermostat, Color(0xFFD84315))),
  _KeywordStyle(
    'health|medical|dengue|vaccin',
    const AlertStyle(Icons.local_hospital, Color(0xFF00897B)),
  ),
  _KeywordStyle(
    'power|brownout|blackout|kuryente',
    const AlertStyle(Icons.bolt, Color(0xFFF9A825)),
  ),
  _KeywordStyle(
    'water supply|water interruption|walang tubig',
    const AlertStyle(Icons.water_drop, Color(0xFF1565C0)),
  ),
  _KeywordStyle(
    'suspen|walang pasok|no classes',
    const AlertStyle(Icons.school, Color(0xFF3949AB)),
  ),
  _KeywordStyle(
    'road|traffic|kalsada',
    const AlertStyle(Icons.warning_amber_rounded, Color(0xFFE65100)),
  ),
];

/// Picks an icon + color that actually matches what the alert is about,
/// from the words in its title and subtitle (then its message, when the
/// title says nothing) — the Alert model has no hazard-category field
/// (its `type` column is an audience switch: Citizens/Responders/Both,
/// not a hazard type), so this is the only signal available. Falls back
/// to a generic announcement icon rather than mislabeling every alert as
/// a flood.
AlertStyle alertStyleFor(String? title, [String? subtitle, String? body]) {
  final heading = '${title ?? ''} ${subtitle ?? ''}';
  for (final keyword in _alertKeywordStyles) {
    if (keyword.pattern.hasMatch(heading)) return keyword.style;
  }
  if (body != null && body.isNotEmpty) {
    for (final keyword in _alertKeywordStyles) {
      if (keyword.pattern.hasMatch(body)) return keyword.style;
    }
  }
  return _defaultAlertStyle;
}

class _AlertCard extends StatelessWidget {
  final _AlertData alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final style = alertStyleFor(alert.title, alert.subtitle, alert.body);

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
