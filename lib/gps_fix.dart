import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// The most precise GPS fix the phone gets, for Report Emergency and SOS
/// (item 59: more accurate locations).
///
/// A phone's first fix can be off by hundreds of meters while its GPS
/// warms up, and better ones follow within seconds. This listens for
/// fixes and returns the best one:
///   - as soon as one is within [goodEnough] meters;
///   - otherwise [improve] after the first fix (the best so far);
///   - otherwise when [limit] runs out — with the best so far, or a
///     TimeoutException when there was no fix at all.
/// The caller checks that location is on and allowed first.
Future<Position> bestGpsFix({
  Duration limit = const Duration(seconds: 10),
  Duration improve = const Duration(seconds: 4),
  double goodEnough = 20,
}) {
  final completer = Completer<Position>();
  Position? best;
  StreamSubscription<Position>? subscription;
  Timer? limitTimer;
  Timer? improveTimer;

  void finish([Object? error]) {
    if (completer.isCompleted) return;
    limitTimer?.cancel();
    improveTimer?.cancel();
    subscription?.cancel();
    final found = best;
    if (found != null) {
      completer.complete(found);
    } else {
      completer.completeError(
        error ?? TimeoutException('No GPS fix yet', limit),
      );
    }
  }

  subscription = Geolocator.getPositionStream(locationSettings: _fixSettings())
      .listen((position) {
        final current = best;
        if (current == null || position.accuracy < current.accuracy) {
          best = position;
        }
        // 0 = the phone can't say how close it is; waiting won't help.
        if (position.accuracy <= goodEnough) {
          finish();
        } else {
          improveTimer ??= Timer(improve, finish);
        }
      }, onError: (Object error) => finish(error));
  limitTimer = Timer(limit, finish);

  return completer.future;
}

/// A fix every second. On Android the stream otherwise gives one every 5
/// seconds, too slow to pick the best of the first few.
LocationSettings _fixSettings() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return AndroidSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 1),
    );
  }
  return const LocationSettings(
    accuracy: LocationAccuracy.best,
    distanceFilter: 0,
  );
}

/// How many seconds old a fix is — the phone's last known location can
/// be from minutes or hours ago. Never negative.
int gpsAgeSeconds(Position position) {
  final seconds = DateTime.now().difference(position.timestamp).inSeconds;
  return seconds < 0 ? 0 : seconds;
}

/// "within about 12 m", "within about 1.2 km" — how close a fix is.
/// (Check gpsAccuracyKnown() first.)
String gpsAccuracyText(double meters) {
  if (meters >= 1000) {
    final km = (meters / 1000).toStringAsFixed(1);
    return 'within about ${km.endsWith('.0') ? km.substring(0, km.length - 2) : km} km';
  }
  if (meters < 20) return 'within about ${meters.round().clamp(1, 19)} m';
  return 'within about ${(meters / 5).round() * 5} m';
}

/// Beyond this many meters a fix is only rough.
const double gpsRoughMeters = 100;

/// "4 min ago", "2 h ago", "3 days ago" — how old a fix is.
String gpsAgeText(Position position) {
  final seconds = gpsAgeSeconds(position);
  if (seconds < 3600) return '${(seconds / 60).round().clamp(1, 59)} min ago';
  if (seconds < 86400) return '${(seconds / 3600).round().clamp(1, 23)} h ago';
  final days = (seconds / 86400).round();
  return days == 1 ? '1 day ago' : '$days days ago';
}

/// Beyond this many seconds the phone's last known location is old.
const int gpsOldSeconds = 120;

/// Whether the phone said how close the fix is — Geolocator gives 0 when
/// it can't tell.
bool gpsAccuracyKnown(Position position) =>
    position.accuracy.isFinite && position.accuracy > 0;

/// A fix the phone says is more than [gpsRoughMeters] off.
bool gpsIsRough(Position position) =>
    gpsAccuracyKnown(position) && position.accuracy > gpsRoughMeters;
