import 'package:flutter_test/flutter_test.dart';
import 'package:metro_jatri/data/lines.dart';
import 'package:metro_jatri/logic/geo.dart';
import 'package:metro_jatri/logic/schedule.dart';
import 'package:metro_jatri/logic/tracker.dart';
import 'package:metro_jatri/main.dart';

void main() {
  final geo = LineGeometry(mrt6.activeStations);

  test('MRT-6 station-to-station distance is close to the 20 km track', () {
    expect(geo.length, inInclusiveRange(17000, 22000));
  });

  test('a point at Farmgate is detected as Farmgate', () {
    final interp = PositionInterpreter(geo);
    final s = interp.update(23.7578, 90.3896, DateTime(2026));
    expect(geo.stations[s.atStation!].nameEn, 'Farmgate');
  });

  test('moving south between stations gives direction and speed', () {
    final interp = PositionInterpreter(geo);
    final t0 = DateTime(2026, 1, 1, 10);
    interp.update(23.7740, 90.3830, t0);
    final s = interp.update(23.7720, 90.3842, t0.add(const Duration(seconds: 10)));
    expect(interp.direction, 1);
    expect(geo.stations[s.from!].nameEn, 'Agargaon');
    expect(geo.stations[s.to!].nameEn, 'Bijoy Sarani');
    expect(s.speedKmh, inInclusiveRange(60, 110));
  });

  test('next train is within one headway during service', () {
    final sch = Schedule(geo);
    final nt = sch.next(10, 1, DateTime(2026, 10, 29, 12, 3)); // Thursday
    expect(nt.serviceClosed, isFalse);
    expect(nt.minutes, inInclusiveRange(0, 10));
  });

  test('no service late at night', () {
    final sch = Schedule(geo);
    expect(sch.next(0, 1, DateTime(2026, 10, 29, 23)).serviceClosed, isTrue);
  });

  test('Friday morning counts down to the 3 PM first train', () {
    final sch = Schedule(geo);
    expect(sch.next(0, 1, DateTime(2026, 10, 30, 9)).minutes, 360);
  });

  test('timetable puts trains on the line in both directions at noon', () {
    final trains = Schedule(geo).trainsAt(DateTime(2026, 10, 29, 12));
    expect(trains.where((t) => t.direction == 1), isNotEmpty);
    expect(trains.where((t) => t.direction == -1), isNotEmpty);
    for (final t in trains) {
      expect(t.chainage, inInclusiveRange(0, geo.length));
    }
  });

  test('pointAt returns station coordinates at station chainage', () {
    final (lat, lon) = geo.pointAt(geo.cumulative[10]);
    expect(lat, closeTo(geo.stations[10].lat, 1e-6));
    expect(lon, closeTo(geo.stations[10].lon, 1e-6));
  });

  testWidgets('app shows the ride screen', (tester) async {
    await tester.pumpWidget(const MetroJatriApp());
    expect(find.text('ডেমো'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
