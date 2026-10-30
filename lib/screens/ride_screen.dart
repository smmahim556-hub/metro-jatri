import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../data/lines.dart';
import '../logic/geo.dart';
import '../logic/schedule.dart';
import '../logic/tracker.dart';
import '../util/bangla.dart';
import 'map_icons.dart';

enum Source { demo, gps }

const _lineColor = Color(0xFF0A7D4F);

class RideScreen extends StatefulWidget {
  const RideScreen({super.key});

  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> {
  final geo = LineGeometry(mrt6.activeStations);
  late final schedule = Schedule(geo);
  GoogleMapController? _map;
  BitmapDescriptor? _myTrainIcon, _otherTrainIcon;
  List<BitmapDescriptor>? _stationIcons;

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
    _loadIcons();
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

  Future<void> _loadIcons() async {
    final my = await MapIcons.train(_lineColor);
    final other = await MapIcons.train(const Color(0xFF6B7772), size: 28);
    final stations = [
      for (final s in geo.stations) await MapIcons.station(s.nameBn, _lineColor)
    ];
    if (!mounted) return;
    setState(() {
      _myTrainIcon = my;
      _otherTrainIcon = other;
      _stationIcons = stations;
    });
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
    if (follow) _map?.moveCamera(CameraUpdate.newLatLng(_latLng(s.chainage)));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = geo.stations;
    final others = schedule.trainsAt(DateTime.now());

    return Stack(children: [
      // Touching the map stops the camera from following the train.
      Listener(
        onPointerDown: (_) {
          if (follow) setState(() => follow = false);
        },
        child: GoogleMap(
          initialCameraPosition:
              CameraPosition(target: _latLng(state.chainage), zoom: 14),
          onMapCreated: (c) => _map = c,
          minMaxZoomPreference: const MinMaxZoomPreference(11, 19),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          // Leave room for the bottom sheet and the toggles.
          padding: EdgeInsets.only(
              top: 120, bottom: MediaQuery.sizeOf(context).height * 0.3),
          polylines: {
            Polyline(
              polylineId: const PolylineId('casing'),
              points: [for (final s in st) LatLng(s.lat, s.lon)],
              color: Colors.white,
              width: 11,
              zIndex: 0,
            ),
            Polyline(
              polylineId: const PolylineId('mrt6'),
              points: [for (final s in st) LatLng(s.lat, s.lon)],
              color: _lineColor,
              width: 7,
              zIndex: 1,
            ),
          },
          markers: {
            if (_stationIcons != null)
              for (var i = 0; i < st.length; i++)
                Marker(
                  markerId: MarkerId('st$i'),
                  position: LatLng(st[i].lat, st[i].lon),
                  icon: _stationIcons![i],
                  anchor: const Offset(0.5, 0.5),
                  zIndexInt: 1,
                  infoWindow: InfoWindow(title: st[i].nameBn, snippet: st[i].nameEn),
                ),
            // Other trains, estimated from the timetable.
            for (var i = 0; i < others.length; i++)
              Marker(
                markerId: MarkerId('t$i'),
                position: _latLng(others[i].chainage),
                icon: _otherTrainIcon ?? BitmapDescriptor.defaultMarker,
                anchor: const Offset(0.5, 0.5),
                zIndexInt: 2,
                infoWindow: InfoWindow(
                    title: others[i].direction == 1 ? 'মতিঝিলমুখী ট্রেন' : 'উত্তরামুখী ট্রেন',
                    snippet: 'সময়সূচি থেকে আনুমানিক অবস্থান'),
              ),
            Marker(
              markerId: const MarkerId('me'),
              position: _latLng(state.chainage),
              icon: _myTrainIcon ?? BitmapDescriptor.defaultMarker,
              anchor: const Offset(0.5, 0.5),
              zIndexInt: 3,
            ),
          },
        ),
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
            _map?.animateCamera(
                CameraUpdate.newLatLngZoom(_latLng(state.chainage), 15));
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
