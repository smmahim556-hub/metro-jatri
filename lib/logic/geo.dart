import 'dart:math';

import '../data/lines.dart';

const _earthRadius = 6371000.0;
double _rad(double d) => d * pi / 180;

/// Great-circle distance in metres.
double haversine(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _rad(lat2 - lat1), dLon = _rad(lon2 - lon1);
  final h = pow(sin(dLat / 2), 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * _earthRadius * asin(sqrt(h));
}

/// Where a point sits along a line, measured as distance (m) from the first
/// station ("chainage"), plus how far it is from the track.
class LinePosition {
  final double chainage;
  final double offTrack;
  const LinePosition(this.chainage, this.offTrack);
}

/// Pre-computed geometry for one line's operational stations.
class LineGeometry {
  final List<Station> stations;
  late final List<double> cumulative;

  LineGeometry(this.stations) {
    cumulative = [0];
    for (var i = 1; i < stations.length; i++) {
      final a = stations[i - 1], b = stations[i];
      cumulative.add(cumulative[i - 1] + haversine(a.lat, a.lon, b.lat, b.lon));
    }
  }

  double get length => cumulative.last;

  /// Projects a GPS point onto the station-to-station polyline.
  LinePosition project(double lat, double lon) {
    var best = const LinePosition(0, double.infinity);
    for (var i = 0; i < stations.length - 1; i++) {
      final a = stations[i], b = stations[i + 1];
      // Local equirectangular frame in metres around station a.
      final kx = cos(_rad(a.lat)) * _earthRadius * pi / 180;
      const ky = _earthRadius * pi / 180;
      final bx = (b.lon - a.lon) * kx, by = (b.lat - a.lat) * ky;
      final px = (lon - a.lon) * kx, py = (lat - a.lat) * ky;
      final len2 = bx * bx + by * by;
      final u = ((px * bx + py * by) / len2).clamp(0.0, 1.0);
      final off = sqrt(pow(px - u * bx, 2) + pow(py - u * by, 2));
      if (off < best.offTrack) {
        best = LinePosition(
            cumulative[i] + u * (cumulative[i + 1] - cumulative[i]), off);
      }
    }
    return best;
  }

  /// Index of the station nearest to a chainage.
  int nearestStation(double chainage) {
    var n = 0;
    for (var i = 1; i < cumulative.length; i++) {
      if ((cumulative[i] - chainage).abs() < (cumulative[n] - chainage).abs()) {
        n = i;
      }
    }
    return n;
  }

  /// Index of the station at the start of the segment containing chainage.
  int segmentStart(double chainage) {
    var a = 0;
    while (a < cumulative.length - 2 && cumulative[a + 1] < chainage) {
      a++;
    }
    return a;
  }
}
