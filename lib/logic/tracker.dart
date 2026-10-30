import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'geo.dart';
import 'schedule.dart';

/// What the passenger sees: at a station, or between two stations.
class RideState {
  final int? atStation;
  final int? from, to;
  final double speedKmh;
  final double remainingMetres;
  final double? offTrackMetres;
  final double? accuracy;

  const RideState.at(int station, {this.speedKmh = 0, this.offTrackMetres, this.accuracy})
      : atStation = station,
        from = null,
        to = null,
        remainingMetres = 0;

  const RideState.between(int this.from, int this.to,
      {required this.speedKmh,
      required this.remainingMetres,
      this.offTrackMetres,
      this.accuracy})
      : atStation = null;

  /// The station the train reaches next, or null at the terminal.
  int? nextStation(int direction, int stationCount) {
    if (atStation == null) return to;
    final n = atStation! + direction;
    return n >= 0 && n < stationCount ? n : null;
  }
}

/// Turns a series of positions on the line into [RideState]s.
class PositionInterpreter {
  final LineGeometry geo;
  final double stationRadius;
  double? _lastChainage;
  DateTime? _lastTime;
  int direction = 1;

  PositionInterpreter(this.geo, {this.stationRadius = 200});

  RideState update(double lat, double lon, DateTime time,
      {double? gpsSpeed, double? accuracy}) {
    final pos = geo.project(lat, lon);
    double? speed = gpsSpeed != null && gpsSpeed >= 0 ? gpsSpeed * 3.6 : null;
    if (_lastChainage != null && _lastTime != null) {
      final dt = time.difference(_lastTime!).inMilliseconds / 1000;
      final dc = pos.chainage - _lastChainage!;
      if (speed == null && dt > 0) speed = dc.abs() / dt * 3.6;
      if (dc.abs() > 15) direction = dc > 0 ? 1 : -1;
    }
    _lastChainage = pos.chainage;
    _lastTime = time;

    final near = geo.nearestStation(pos.chainage);
    if ((geo.cumulative[near] - pos.chainage).abs() < stationRadius) {
      return RideState.at(near,
          speedKmh: speed ?? 0, offTrackMetres: pos.offTrack, accuracy: accuracy);
    }
    final a = geo.segmentStart(pos.chainage);
    final (f, t) = direction == 1 ? (a, a + 1) : (a + 1, a);
    return RideState.between(f, t,
        speedKmh: speed ?? 0,
        remainingMetres: (geo.cumulative[t] - pos.chainage).abs(),
        offTrackMetres: pos.offTrack,
        accuracy: accuracy);
  }
}

/// Phone GPS → ride states.
Stream<RideState> gpsRide(PositionInterpreter interp) async* {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw 'লোকেশন সার্ভিস বন্ধ আছে। ফোনের GPS চালু করুন।';
  }
  var perm = await Geolocator.checkPermission();
  if (perm == LocationPermission.denied) {
    perm = await Geolocator.requestPermission();
  }
  if (perm == LocationPermission.denied ||
      perm == LocationPermission.deniedForever) {
    throw 'লোকেশন পারমিশন দেওয়া হয়নি।';
  }
  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 5),
  ).map((p) => interp.update(p.latitude, p.longitude, p.timestamp,
      gpsSpeed: p.speed, accuracy: p.accuracy));
}

/// A simulated train for trying the app without riding the metro.
class DemoTrain {
  final LineGeometry geo;
  final ScheduleConfig config;
  final int direction;
  int _k = 0;
  bool _dwelling = true;
  double _t = 0;

  DemoTrain(this.geo, this.direction, [this.config = const ScheduleConfig()]);

  int _station(int k) => direction == 1 ? k : geo.stations.length - 1 - k;

  RideState tick(double seconds) {
    _t += seconds;
    final n = geo.stations.length;
    if (_dwelling) {
      final at = _station(_k);
      if (_t >= config.dwellSeconds) {
        _t = 0;
        if (_k >= n - 1) {
          _k = 0;
        } else {
          _dwelling = false;
        }
      }
      return RideState.at(at);
    }
    final a = _station(_k), b = _station(_k + 1);
    final d = (geo.cumulative[b] - geo.cumulative[a]).abs();
    if (_t >= segmentSeconds(d, config)) {
      _k++;
      _dwelling = true;
      _t = 0;
      return RideState.at(b);
    }
    // Integrate the speed profile to find how far the train has gone.
    var x = 0.0, tt = 0.0;
    const step = 0.25;
    while (tt < _t && x < d) {
      final v = profileSpeed(x, d, config);
      x += (v < 0.6 ? 0.6 : v) * step;
      tt += step;
    }
    return RideState.between(a, b,
        speedKmh: profileSpeed(x, d, config) * 3.6, remainingMetres: d - x);
  }

  Stream<RideState> run({double speedUp = 10}) => Stream.periodic(
      const Duration(milliseconds: 500), (_) => tick(0.5 * speedUp));
}
