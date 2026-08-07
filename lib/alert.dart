import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String _selectedTab = 'All';
  bool _isLoading = true;
  String? _errorMessage;

  final List<String> _tabs = ['All', 'Alerts', 'Updates'];

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

  List<_AlertData> get _filtered {
    if (_selectedTab == 'All') return _allAlerts;
    return _allAlerts.where((a) => a.type == _selectedTab).toList();
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
                      'No $_selectedTab found.',
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
  final String type;

  const _AlertData({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.dateTime,
    required this.type,
  });

  factory _AlertData.fromJson(Map<String, dynamic> json) {
    return _AlertData(
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
      body: json['body'],
      dateTime: _formatDate(json['created_at']),
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

class _AlertCard extends StatelessWidget {
  final _AlertData alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
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
              border: Border.all(color: Colors.red, width: 2),
            ),
            child: const Icon(Icons.waves, color: Colors.red, size: 22),
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
