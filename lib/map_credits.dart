import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// "© OpenStreetMap contributors" on a map (item 64).
///
/// The map pictures come from OpenStreetMap's servers. Its licence (ODbL)
/// and tile usage policy require this credit on the map itself, where
/// people can see it; apps without it can be blocked. Put it last in a
/// FlutterMap's children. Tapping it opens openstreetmap.org/copyright.
///
/// The same file is in both apps.
class OsmCredit extends StatelessWidget {
  /// Where on the map: pick a corner that buttons and cards don't cover.
  final Alignment alignment;

  const OsmCredit({super.key, this.alignment = Alignment.bottomRight});

  Future<void> _open() async {
    try {
      await launchUrl(
        Uri.parse('https://www.openstreetmap.org/copyright'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // No browser: the credit is still shown.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Semantics(
          button: true,
          label: 'Map data from OpenStreetMap contributors',
          hint: 'Opens the copyright page',
          excludeSemantics: true,
          child: Material(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(4),
            child: InkWell(
              onTap: _open,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Text(
                  '© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 11, color: Color(0xFF1F2937)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
