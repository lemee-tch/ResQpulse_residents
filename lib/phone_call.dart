import 'package:url_launcher/url_launcher.dart';

/// Opens the phone's dialer with [number] filled in, for Emergency Hotlines
/// and the SOS screen's "Call MDRRMO".
///
/// Keeps "#" and "*": MDRRMO's hotline is the short code #2441. Before,
/// Hotlines removed the "#" (the phone dialed 2441), and the SOS screen put
/// a bare "#" in the tel: link — which phones read as the end of the
/// number, so the dialer opened empty. Uri(scheme: 'tel', ...) writes it
/// as %23, which the dialer turns back into "#".
///
/// Returns false when there's no number to call or the phone can't open
/// its dialer (the caller then tells the resident to dial it themselves).
Future<bool> openDialer(String number) async {
  final cleaned = number.replaceAll(RegExp(r'[^\d+*#]'), '');
  if (!RegExp(r'\d').hasMatch(cleaned)) return false;

  try {
    return await launchUrl(Uri(scheme: 'tel', path: cleaned));
  } catch (_) {
    return false;
  }
}
