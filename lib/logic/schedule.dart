import 'dart:math';

import 'geo.dart';

/// Estimated timetable for MRT-6. These numbers are assumptions until
/// DMTCL publishes or shares an official timetable.
class ScheduleConfig {
  /// Minutes after midnight.
  final int openWeekday, openFriday, close;
  final int peakHeadway, offPeakHeadway;
  final List<(double, double)> peakHours;
  final double dwellSeconds, maxSpeedKmh, acceleration;

  const ScheduleConfig({
    this.openWeekday = 7 * 60 + 10,
    this.openFriday = 15 * 60,
    this.close = 21 * 60 + 40,
    this.peakHeadway = 8,
    this.offPeakHeadway = 10,
    this.peakHours = const [(7.5, 11.5), (16, 20)],
    this.dwellSeconds = 30,
    this.maxSpeedKmh = 80,
    this.acceleration = 0.9,
  });

  double get vmax => maxSpeedKmh / 3.6;
}

/// Seconds to run [distance] metres with accelerate / cruise / brake.
double segmentSeconds(double distance, ScheduleConfig c) {
  final accelDist = c.vmax * c.vmax / (2 * c.acceleration);
  if (distance > 2 * accelDist) {
    return 2 * c.vmax / c.acceleration + (distance - 2 * accelDist) / c.vmax;
  }
  return 2 * sqrt(distance / c.acceleration);
}

/// Speed (m/s) at position [x] within a segment of [distance] metres.
double profileSpeed(double x, double distance, ScheduleConfig c) => min(
    c.vmax,
    min(sqrt(2 * c.acceleration * max(x, 0)),
        sqrt(2 * c.acceleration * max(distance - x, 0))));

class NextTrain {
  final bool serviceClosed;
  final int minutes;
  final int headway;
  const NextTrain({this.serviceClosed = false, this.minutes = 0, this.headway = 0});
}

class Schedule {
  final LineGeometry geo;
  final ScheduleConfig config;
  const Schedule(this.geo, [this.config = const ScheduleConfig()]);

  int headwayAt(double hour) {
    for (final (from, to) in config.peakHours) {
      if (hour >= from && hour < to) return config.peakHeadway;
    }
    return config.offPeakHeadway;
  }

  /// Minutes for a train to travel from its origin terminal to [station].
  /// [direction] is 1 towards the last station, -1 towards the first.
  double offsetMinutes(int station, int direction) {
    final n = geo.stations.length;
    final origin = direction == 1 ? 0 : n - 1;
    var t = 0.0;
    for (var i = origin; i != station; i += direction) {
      final d = (geo.cumulative[i + direction] - geo.cumulative[i]).abs();
      t += segmentSeconds(d, config) + config.dwellSeconds;
    }
    return t / 60;
  }

  /// Chainage of a train [elapsed] seconds after leaving its origin, or null
  /// once it has reached the far terminal.
  double? chainageAfter(double elapsed, int direction) {
    final n = geo.stations.length;
    var i = direction == 1 ? 0 : n - 1;
    var t = elapsed;
    while (true) {
      if (t < config.dwellSeconds) return geo.cumulative[i];
      t -= config.dwellSeconds;
      final j = i + direction;
      if (j < 0 || j >= n) return null;
      final d = (geo.cumulative[j] - geo.cumulative[i]).abs();
      final run = segmentSeconds(d, config);
      if (t < run) {
        // Integrate the speed profile to find the distance covered.
        var x = 0.0, tt = 0.0;
        const step = 0.25;
        while (tt < t && x < d) {
          x += max(profileSpeed(x, d, config), 0.6) * step;
          tt += step;
        }
        return geo.cumulative[i] + direction * min(x, d);
      }
      t -= run;
      i = j;
    }
  }

  /// Estimated positions of every train running at [now].
  List<({double chainage, int direction})> trainsAt(DateTime now) {
    final open = now.weekday == DateTime.friday
        ? config.openFriday
        : config.openWeekday;
    final m = now.hour * 60 + now.minute + now.second / 60;
    final trains = <({double chainage, int direction})>[];
    for (final dir in const [1, -1]) {
      for (var dep = open.toDouble();
          dep <= config.close && dep <= m;
          dep += headwayAt(dep / 60)) {
        final c = chainageAfter((m - dep) * 60, dir);
        if (c != null) trains.add((chainage: c, direction: dir));
      }
    }
    return trains;
  }

  NextTrain next(int station, int direction, DateTime now) {
    final open = now.weekday == DateTime.friday
        ? config.openFriday
        : config.openWeekday;
    final m = now.hour * 60 + now.minute + now.second / 60;
    final off = offsetMinutes(station, direction);
    var t = open + off;
    while (t < m) {
      t += headwayAt((t - off) / 60);
    }
    if (t - off > config.close) return const NextTrain(serviceClosed: true);
    return NextTrain(
        minutes: (t - m).ceil(), headway: headwayAt(m / 60));
  }
}
