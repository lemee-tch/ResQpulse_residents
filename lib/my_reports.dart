import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api_service.dart';

// ── My Reports — List Screen ────────────────────────────────────────────────

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<_ReportData> _reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await ApiService.getMyIncidents();

    if (!mounted) return;

    if (result.success && result.data is List) {
      setState(() {
        _reports = (result.data as List)
            .map((e) => _ReportData.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _errorMessage = result.error ?? 'Could not load your reports.';
        _isLoading = false;
      });
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
          'My Reports',
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
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _loadReports,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : _reports.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No reports yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your submitted reports will appear here',
                    style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadReports,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _reports.length,
                itemBuilder: (context, index) {
                  final report = _reports[index];
                  return _ReportCard(
                    report: report,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportStatusScreen(report: report),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// ── Report Card ──────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final _ReportData report;
  final VoidCallback onTap;

  const _ReportCard({required this.report, required this.onTap});

  static const Map<String, IconData> _typeIcons = {
    'Fire': Icons.local_fire_department_outlined,
    'Flood': Icons.water_outlined,
    'Earthquake': Icons.landscape_outlined,
    'Accident': Icons.car_crash_outlined,
    'Medical Emergency': Icons.medical_services_outlined,
    'Landslide': Icons.terrain_outlined,
  };

  IconData get _icon =>
      _typeIcons[report.emergencyType] ?? Icons.warning_amber_rounded;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _statusStyle(report.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1A3A8F).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: const Color(0xFF1A3A8F), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          report.emergencyType,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusStyle.bg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusStyle.label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusStyle.fg,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    report.location,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.formattedDate,
                    style: TextStyle(fontSize: 12, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Report Status — Timeline Detail Screen ──────────────────────────────────

class ReportStatusScreen extends StatelessWidget {
  final _ReportData report;
  const ReportStatusScreen({super.key, required this.report});

  static const List<_StatusStep> _steps = [
    _StatusStep(
      key: 'pending',
      title: 'Pending',
      subtitle: 'Your report has been received',
    ),
    _StatusStep(
      key: 'responding',
      title: 'Responding',
      subtitle: 'Responders are on the way',
    ),
    _StatusStep(
      key: 'resolved',
      title: 'Resolved',
      subtitle: 'Incident has been resolved.',
    ),
  ];

  static const Color _navy = Color(0xFF1A3A8F);
  static const Color _amber = Color(0xFFF9A825);
  static const Color _green = Color(0xFF2E7D32);
  static const Color _grey = Color(0xFFD1D5DB);

  int get _currentIndex {
    final idx = _steps.indexWhere((s) => s.key == report.status);
    return idx == -1 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
    final currentIndex = _currentIndex;
    final bool isResolved = report.status == 'resolved';
    final Color activeColor = isResolved ? _green : _amber;

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
          'Incident Status',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // "Your Report" node — always filled navy, connects down with
            // navy/amber (something is already in motion) toward Pending.
            _TimelineRow(
              circleColor: _navy,
              icon: Icons.description,
              lineBelowColor: activeColor,
              title: 'Your Report',
              subtitleLines: [
                '${report.emergencyType} incident',
                report.location,
                report.formattedDate,
              ],
            ),

            ..._steps.asMap().entries.map((entry) {
              final i = entry.key;
              final step = entry.value;
              final bool reached = i <= currentIndex;
              final bool isLast = i == _steps.length - 1;

              final Color circleColor = reached ? activeColor : _grey;
              final Color lineColor = (!isLast && i < currentIndex)
                  ? activeColor
                  : _grey;

              return _TimelineRow(
                circleColor: circleColor,
                lineBelowColor: isLast ? null : lineColor,
                title: step.title,
                subtitleLines: [step.subtitle],
                dimmed: !reached,
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Timeline Row (shared by "Your Report" + each status step) ─────────────

class _TimelineRow extends StatelessWidget {
  final Color circleColor;
  final Color? lineBelowColor;
  final IconData? icon;
  final String title;
  final List<String> subtitleLines;
  final bool dimmed;

  const _TimelineRow({
    required this.circleColor,
    required this.lineBelowColor,
    this.icon,
    required this.title,
    required this.subtitleLines,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: icon != null ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: icon != null ? BorderRadius.circular(12) : null,
                ),
                child: Center(
                  child: icon != null
                      ? Icon(icon, color: Colors.white, size: 18)
                      : Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
              ),
              if (lineBelowColor != null)
                Expanded(child: Container(width: 3, color: lineBelowColor)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: dimmed
                          ? Colors.grey[400]
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...subtitleLines.map(
                    (line) => Text(
                      line,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: dimmed ? Colors.grey[350] : Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class _StatusStep {
  final String key;
  final String title;
  final String subtitle;
  const _StatusStep({
    required this.key,
    required this.title,
    required this.subtitle,
  });
}

class _ReportData {
  final int id;
  final String emergencyType;
  final String location;
  final String description;
  final String status;
  final DateTime? createdAt;

  const _ReportData({
    required this.id,
    required this.emergencyType,
    required this.location,
    required this.description,
    required this.status,
    required this.createdAt,
  });

  factory _ReportData.fromJson(Map<String, dynamic> json) {
    return _ReportData(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      emergencyType: json['emergency_type']?.toString() ?? 'Emergency',
      location: json['location']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
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

  String get formattedDate {
    final date = createdAt;
    if (date == null) return '';
    final month = _months[date.month - 1];
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$month ${date.day}, ${date.year} – $hour12:$minute $period';
  }
}

class _StatusStyle {
  final Color bg;
  final Color fg;
  final String label;
  const _StatusStyle({required this.bg, required this.fg, required this.label});
}

_StatusStyle _statusStyle(String status) {
  switch (status) {
    case 'responding':
      return const _StatusStyle(
        bg: Color(0xFFE0F2FE),
        fg: Color(0xFF0369A1),
        label: 'Responding',
      );
    case 'resolved':
      return const _StatusStyle(
        bg: Color(0xFFD1FAE5),
        fg: Color(0xFF065F46),
        label: 'Resolved',
      );
    default:
      return const _StatusStyle(
        bg: Color(0xFFFEF3C7),
        fg: Color(0xFF92400E),
        label: 'Pending',
      );
  }
}
