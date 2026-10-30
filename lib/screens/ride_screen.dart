import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../data/lines.dart';
import '../logic/geo.dart';
import '../logic/schedule.dart';
import '../logic/tracker.dart';
import '../util/bangla.dart';

enum Source { demo, gps }

const _lineColor = Color(0xFF0A7D4F);

/// MapTiler key, passed at build time with --dart-define (a GitHub secret).
/// Without one the app falls back to the public OpenStreetMap tiles, which
/// are fine for testing but not for a published app.
const _mapTilerKey = String.fromEnvironment('MAPTILER_KEY');

class RideScreen extends StatefulWidget {
  const RideScreen({super.key});

  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> {
  final geo = LineGeometry(mrt6.activeStations);
  late final schedule = Schedule(geo);
  final map = MapController();

  Source source = Source.demo;
  int direction = 1;
  int selectedStation = 10;
  late RideState state = RideState.at(0, chainage: 0);
  String? status;
  bool follow = true;
  StreamSubscription<RideState>? _sub;
  Timer? _clock;
  PositionInterpreter? _interp;

  @override
  void initState() {
    super.initState();
    _start();
    // Moves the scheduled trains and refreshes the next-train countdown.
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  void _start() {
    _sub?.cancel();
    if (source == Source.demo) {
      status = 'ডেমো: আপনার ট্রেন ১০ গুণ দ্রুত চলছে';
      _sub = DemoTrain(geo, direction).run().listen(_onState);
    } else {
      status = 'GPS খোঁজা হচ্ছে…';
      _interp = PositionInterpreter(geo)..direction = direction;
      _sub = gpsRide(_interp!).listen(_onState,
          onError: (e) => setState(() => status = e.toString()));
    }
    setState(() {});
  }

  LatLng _latLng(double chainage) {
    final (lat, lon) = geo.pointAt(chainage);
    return LatLng(lat, lon);
  }

  void _onState(RideState s) {
    setState(() {
      state = s;
      if (source == Source.gps) {
        // GPS infers the direction from movement.
        direction = _interp!.direction;
        final off = s.offTrackMetres ?? 0;
        status = off > 800
            ? 'আপনি মেট্রো লাইন থেকে ${bn((off / 1000).toStringAsFixed(1))} কিমি দূরে। নিকটতম অবস্থান দেখানো হচ্ছে।'
            : 'GPS নির্ভুলতা ±${bn((s.accuracy ?? 0).round())} মিটার';
      }
    });
    if (follow) {
      try {
        map.move(_latLng(s.chainage), map.camera.zoom);
      } catch (_) {
        // The map is not laid out yet on the first event.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = geo.stations;
    final others = schedule.trainsAt(DateTime.now());

    return Stack(children: [
      FlutterMap(
        mapController: map,
        options: MapOptions(
          initialCenter: _latLng(state.chainage),
          initialZoom: 14,
          minZoom: 11,
          maxZoom: 18,
          onPositionChanged: (_, hasGesture) {
            if (hasGesture && follow) setState(() => follow = false);
          },
        ),
        children: [
          TileLayer(
            urlTemplate: _mapTilerKey.isEmpty
                ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                : 'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}@2x.png?key=$_mapTilerKey',
            userAgentPackageName: 'com.metrorail.metro_jatri',
          ),
          PolylineLayer(polylines: [
            Polyline(
              points: [for (final s in st) LatLng(s.lat, s.lon)],
              color: _lineColor,
              strokeWidth: 7,
              borderColor: Colors.white,
              borderStrokeWidth: 2,
            ),
          ]),
          CircleLayer(circles: [
            for (final s in st)
              CircleMarker(
                point: LatLng(s.lat, s.lon),
                radius: 7,
                color: Colors.white,
                borderColor: _lineColor,
                borderStrokeWidth: 3,
              ),
          ]),
          MarkerLayer(markers: [
            for (final s in st)
              Marker(
                point: LatLng(s.lat, s.lon),
                width: 130,
                height: 24,
                alignment: const Alignment(1.15, 0),
                child: _StationLabel(s.nameBn),
              ),
            // Other trains, estimated from the timetable.
            for (final t in others)
              Marker(
                point: _latLng(t.chainage),
                width: 26,
                height: 26,
                child: _TrainIcon(
                    size: 26, color: scheme.outline, tooltip: t.direction == 1 ? 'মতিঝিলমুখী' : 'উত্তরামুখী'),
              ),
            Marker(
              point: _latLng(state.chainage),
              width: 46,
              height: 46,
              child: const _TrainIcon(size: 46, color: _lineColor, highlight: true),
            ),
          ]),
          RichAttributionWidget(attributions: [
            if (_mapTilerKey.isNotEmpty) const TextSourceAttribution('© MapTiler'),
            const TextSourceAttribution('© OpenStreetMap contributors'),
          ]),
        ],
      ),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Toggles(
              source: source,
              direction: direction,
              onSource: (s) {
                source = s;
                _start();
              },
              onDirection: (d) {
                direction = d;
                _start();
              },
            ),
          ]),
        ),
      ),
      Positioned(
        right: 16,
        bottom: MediaQuery.sizeOf(context).height * 0.3 + 12,
        child: FloatingActionButton.small(
          heroTag: 'follow',
          tooltip: 'ট্রেন অনুসরণ',
          backgroundColor: follow ? scheme.primary : scheme.surface,
          foregroundColor: follow ? scheme.onPrimary : scheme.primary,
          onPressed: () {
            setState(() => follow = true);
            map.move(_latLng(state.chainage), 15);
          },
          child: const Icon(Icons.my_location),
        ),
      ),
      DraggableScrollableSheet(
        initialChildSize: 0.3,
        minChildSize: 0.16,
        maxChildSize: 0.85,
        builder: (context, scroll) => Material(
          elevation: 8,
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: _InfoSheet(
            scroll: scroll,
            geo: geo,
            schedule: schedule,
            state: state,
            direction: direction,
            selectedStation: selectedStation,
            onSelectStation: (i) => setState(() => selectedStation = i),
            status: status,
            trainsRunning: others.length,
          ),
        ),
      ),
    ]);
  }
}

class _Toggles extends StatelessWidget {
  final Source source;
  final int direction;
  final ValueChanged<Source> onSource;
  final ValueChanged<int> onDirection;
  const _Toggles(
      {required this.source,
      required this.direction,
      required this.onSource,
      required this.onDirection});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return Card(
      elevation: 4,
      color: surface,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SegmentedButton<Source>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: Source.demo, label: Text('ডেমো'), icon: Icon(Icons.play_circle)),
              ButtonSegment(value: Source.gps, label: Text('আমার GPS'), icon: Icon(Icons.gps_fixed)),
            ],
            selected: {source},
            onSelectionChanged: (s) => onSource(s.first),
          ),
          const SizedBox(height: 6),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 1, label: Text('মতিঝিলমুখী')),
              ButtonSegment(value: -1, label: Text('উত্তরামুখী')),
            ],
            selected: {direction},
            onSelectionChanged: (s) => onDirection(s.first),
          ),
        ]),
      ),
    );
  }
}

class _TrainIcon extends StatelessWidget {
  final double size;
  final Color color;
  final bool highlight;
  final String? tooltip;
  const _TrainIcon(
      {required this.size, required this.color, this.highlight = false, this.tooltip});

  @override
  Widget build(BuildContext context) {
    final icon = Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: highlight ? 3 : 2),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black38)],
      ),
      child: Icon(Icons.directions_subway_filled,
          color: Colors.white, size: size * 0.55),
    );
    return tooltip == null ? icon : Tooltip(message: tooltip!, child: icon);
  }
}

class _StationLabel extends StatelessWidget {
  final String name;
  const _StationLabel(this.name);

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(name,
              style: const TextStyle(
                  fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w600)),
        ),
      );
}

class _InfoSheet extends StatelessWidget {
  final ScrollController scroll;
  final LineGeometry geo;
  final Schedule schedule;
  final RideState state;
  final int direction, selectedStation, trainsRunning;
  final ValueChanged<int> onSelectStation;
  final String? status;

  const _InfoSheet({
    required this.scroll,
    required this.geo,
    required this.schedule,
    required this.state,
    required this.direction,
    required this.selectedStation,
    required this.onSelectStation,
    required this.status,
    required this.trainsRunning,
  });

  int? _minutesToNext() {
    final next = state.nextStation(direction, geo.stations.length);
    if (next == null) return null;
    final c = schedule.config;
    final secs = state.atStation != null
        ? c.dwellSeconds / 2 +
            segmentSeconds(
                (geo.cumulative[next] - geo.cumulative[state.atStation!]).abs(), c)
        : state.remainingMetres /
            (state.speedKmh / 3.6).clamp(c.vmax * 0.6, c.vmax);
    return (secs / 60).round().clamp(1, 99);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final st = geo.stations;
    final next = state.nextStation(direction, st.length);
    final eta = _minutesToNext();
    final nt = schedule.next(selectedStation, direction, DateTime.now());
    final order = direction == 1
        ? List.generate(st.length, (i) => i)
        : List.generate(st.length, (i) => st.length - 1 - i);

    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Text(state.atStation != null ? 'এখন আছেন' : 'চলছে',
            style: theme.textTheme.labelMedium),
        Text(
          state.atStation != null
              ? '${st[state.atStation!].nameBn} স্টেশন'
              : '${st[state.from!].nameBn} → ${st[state.to!].nameBn}',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _Stat('গতি', bn(state.speedKmh.round()), 'কিমি/ঘ')),
          Expanded(
              child: _Stat(next == null ? 'শেষ স্টেশন' : 'পরের: ${st[next].nameBn}',
                  eta == null ? '—' : bn(eta), 'মিনিট')),
        ]),
        const Divider(height: 24),
        Text('পরের মেট্রো কত মিনিট পর (আনুমানিক)', style: theme.textTheme.labelMedium),
        DropdownButton<int>(
          value: selectedStation,
          isExpanded: true,
          items: [
            for (var i = 0; i < st.length; i++)
              DropdownMenuItem(value: i, child: Text(st[i].nameBn))
          ],
          onChanged: (v) => onSelectStation(v!),
        ),
        nt.serviceClosed
            ? Text('সেবা বন্ধ', style: theme.textTheme.headlineSmall)
            : _Stat(null, bn(nt.minutes), 'মিনিট'),
        Text(
          nt.serviceClosed
              ? 'আজকের সার্ভিস শেষ বা এখনো শুরু হয়নি'
              : 'প্রতি ${bn(nt.headway)} মিনিট পর পর ট্রেন · ম্যাপে ধূসর ট্রেন: ${bn(trainsRunning)}টি (আনুমানিক)',
          style: theme.textTheme.bodySmall,
        ),
        const Divider(height: 24),
        for (final i in order)
          _StationRow(name: st[i].nameBn, here: state.atStation == i, next: next == i),
        const SizedBox(height: 8),
        if (status != null) Text(status!, style: theme.textTheme.bodySmall),
        Text('স্টেশনের অবস্থান ও সময়সূচি আনুমানিক। অফিসিয়াল লাইভ ডেটা নয়।',
            style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String? label;
  final String value, unit;
  const _Stat(this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label != null)
        Text(label!, style: theme.textTheme.labelMedium, overflow: TextOverflow.ellipsis),
      Text.rich(TextSpan(children: [
        TextSpan(
            text: value,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        TextSpan(text: ' $unit'),
      ])),
    ]);
  }
}

class _StationRow extends StatelessWidget {
  final String name;
  final bool here, next;
  const _StationRow({required this.name, required this.here, required this.next});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(here ? Icons.radio_button_checked : Icons.circle_outlined,
            size: 18, color: here || next ? scheme.primary : scheme.outline),
        const SizedBox(width: 10),
        Expanded(
          child: Text(name,
              style: TextStyle(
                  fontWeight: here ? FontWeight.bold : null,
                  color: here ? scheme.primary : null)),
        ),
        if (here) const Chip(label: Text('এখানে'), visualDensity: VisualDensity.compact),
        if (next) const Chip(label: Text('পরের'), visualDensity: VisualDensity.compact),
      ]),
    );
  }
}
