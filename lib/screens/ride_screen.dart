import 'dart:async';

import 'package:flutter/material.dart';

import '../data/lines.dart';
import '../logic/geo.dart';
import '../logic/schedule.dart';
import '../logic/tracker.dart';
import '../util/bangla.dart';

enum Source { demo, gps }

class RideScreen extends StatefulWidget {
  const RideScreen({super.key});

  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> {
  final geo = LineGeometry(mrt6.activeStations);
  late final schedule = Schedule(geo);

  Source source = Source.demo;
  int direction = 1;
  int selectedStation = 10;
  RideState state = const RideState.at(0);
  String? status;
  StreamSubscription<RideState>? _sub;
  Timer? _clock;
  PositionInterpreter? _interp;

  @override
  void initState() {
    super.initState();
    _start();
    // Refresh the next-train countdown even when the position is unchanged.
    _clock = Timer.periodic(const Duration(seconds: 15), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _clock?.cancel();
    super.dispose();
  }

  void _start() {
    _sub?.cancel();
    status = null;
    if (source == Source.demo) {
      status = 'ডেমো: একটি ট্রেন লাইনে চলছে (১০ গুণ দ্রুত)';
      _sub = DemoTrain(geo, direction).run().listen(_onState);
    } else {
      status = 'GPS খোঁজা হচ্ছে…';
      _interp = PositionInterpreter(geo)..direction = direction;
      _sub = gpsRide(_interp!).listen(_onState,
          onError: (e) => setState(() => status = e.toString()));
    }
    setState(() {});
  }

  void _onState(RideState s) {
    setState(() {
      state = s;
      if (source == Source.gps) {
        // GPS infers the direction from movement.
        direction = _interp!.direction;
        final off = s.offTrackMetres ?? 0;
        status = off > 800
            ? 'আপনি মেট্রো লাইন থেকে ${bn((off / 1000).toStringAsFixed(1))} কিমি দূরে আছেন। নিকটতম অবস্থান দেখানো হচ্ছে।'
            : 'GPS নির্ভুলতা ±${bn((s.accuracy ?? 0).round())} মিটার';
      }
    });
  }

  List<int> get _order {
    final idx = List.generate(geo.stations.length, (i) => i);
    return direction == 1 ? idx : idx.reversed.toList();
  }

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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('মেট্রো যাত্রী · ${mrt6.nameBn}', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        SegmentedButton<Source>(
          segments: const [
            ButtonSegment(value: Source.demo, label: Text('ডেমো'), icon: Icon(Icons.play_circle)),
            ButtonSegment(value: Source.gps, label: Text('আমার GPS'), icon: Icon(Icons.my_location)),
          ],
          selected: {source},
          onSelectionChanged: (s) {
            source = s.first;
            _start();
          },
        ),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('মতিঝিলমুখী')),
            ButtonSegment(value: -1, label: Text('উত্তরামুখী')),
          ],
          selected: {direction},
          onSelectionChanged: (s) {
            direction = s.first;
            _start();
          },
        ),
        const SizedBox(height: 12),
        _Card(
          label: state.atStation != null ? 'এখন আছেন' : 'চলছে',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              state.atStation != null
                  ? '${st[state.atStation!].nameBn} স্টেশন'
                  : '${st[state.from!].nameBn} → ${st[state.to!].nameBn}',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (state.atStation == null)
              Text('পরের স্টেশন ${bn(state.remainingMetres.round())} মিটার দূরে'),
          ]),
        ),
        Row(children: [
          Expanded(
              child: _Card(
                  label: 'গতি',
                  child: _Big(bn(state.speedKmh.round()), 'কিমি/ঘ'))),
          const SizedBox(width: 12),
          Expanded(
              child: _Card(
                  label: next == null ? 'শেষ স্টেশন' : 'পরের স্টেশন',
                  child: _Big(eta == null ? '—' : bn(eta), 'মিনিট'))),
        ]),
        _Card(
          label: 'পরের মেট্রো কত মিনিট পর (আনুমানিক)',
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            DropdownButton<int>(
              value: selectedStation,
              isExpanded: true,
              items: [
                for (var i = 0; i < st.length; i++)
                  DropdownMenuItem(value: i, child: Text(st[i].nameBn))
              ],
              onChanged: (v) => setState(() => selectedStation = v!),
            ),
            nt.serviceClosed
                ? Text('সেবা বন্ধ', style: theme.textTheme.headlineMedium)
                : _Big(bn(nt.minutes), 'মিনিট'),
            Text(nt.serviceClosed
                ? 'আজকের সার্ভিস শেষ বা এখনো শুরু হয়নি'
                : 'এখন প্রতি ${bn(nt.headway)} মিনিট পর পর ট্রেন'),
          ]),
        ),
        _Card(
          label: 'স্টেশনসমূহ',
          child: Column(children: [
            for (final i in _order)
              _StationRow(
                name: st[i].nameBn,
                here: state.atStation == i,
                next: next == i,
              ),
          ]),
        ),
        if (status != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(status!, style: theme.textTheme.bodySmall),
          ),
        Text('স্টেশনের অবস্থান ও সময়সূচি আনুমানিক। অফিসিয়াল লাইভ ডেটা নয়।',
            style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final String label;
  final Widget child;
  const _Card({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            child,
          ]),
        ),
      );
}

class _Big extends StatelessWidget {
  final String value, unit;
  const _Big(this.value, this.unit);

  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(children: [
        TextSpan(
            text: value,
            style: Theme.of(context)
                .textTheme
                .displaySmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        TextSpan(text: ' $unit'),
      ]));
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
