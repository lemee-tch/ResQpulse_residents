import 'package:shared_preferences/shared_preferences.dart';

/// Alerts cleared on this phone (panel comment #22: clear past alerts).
///
/// Swiping an alert away, or "Clear all" on the Alerts screen, hides it on
/// this phone only — the alert ids are kept here. Alerts also clear by
/// themselves: the server stops sending an alert when its time is up or
/// when MDRRMO clears it (Alerts & Broadcast on the admin web), so this
/// list only needs the ids the server still sends — see [keepOnly].
class ClearedAlerts {
  ClearedAlerts._();

  static const _key = 'cleared_alert_ids';

  // One shared set, so quick swipes in a row never overwrite each other.
  static Future<Set<int>>? _loading;

  static Future<Set<int>> _all() => _loading ??= _read();

  static Future<Set<int>> _read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key) ?? const <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
    } catch (_) {
      return <int>{};
    }
  }

  static Future<void> _write(Set<int> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, ids.map((id) => '$id').toList());
    } catch (_) {
      // Not saved: the alert shows again next time. Nothing else breaks.
    }
  }

  /// The ids of the alerts cleared on this phone.
  static Future<Set<int>> ids() async => Set<int>.of(await _all());

  /// Hides these alerts on this phone.
  static Future<void> clear(Iterable<int> ids) async {
    final all = await _all();
    all.addAll(ids);
    await _write(all);
  }

  /// Shows them again (Undo).
  static Future<void> restore(Iterable<int> ids) async {
    final all = await _all();
    all.removeAll(ids);
    await _write(all);
  }

  /// Forgets the alerts the server no longer sends (they cleared by
  /// themselves), so this list stays small. [stillSent] must be every id
  /// in a list the server just sent.
  static Future<void> keepOnly(Iterable<int> stillSent) async {
    final all = await _all();
    final before = all.length;
    all.retainAll(stillSent.toSet());
    if (all.length != before) await _write(all);
  }
}
