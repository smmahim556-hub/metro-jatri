/// Metro line and station data.
///
/// Coordinates are approximate (taken from public maps) and should be
/// replaced with surveyed values from DMTCL before release.
class Station {
  final String nameBn;
  final String nameEn;
  final double lat;
  final double lon;
  final bool upcoming;

  const Station(this.nameBn, this.nameEn, this.lat, this.lon,
      {this.upcoming = false});
}

class MetroLine {
  final String id;
  final String nameBn;
  final String routeBn;
  final bool operational;
  final List<Station> stations;

  const MetroLine({
    required this.id,
    required this.nameBn,
    required this.routeBn,
    required this.operational,
    this.stations = const [],
  });

  /// Stations that trains currently serve.
  List<Station> get activeStations =>
      stations.where((s) => !s.upcoming).toList();
}

const mrt6 = MetroLine(
  id: 'MRT-6',
  nameBn: 'এমআরটি লাইন-৬',
  routeBn: 'উত্তরা উত্তর – মতিঝিল',
  operational: true,
  stations: [
    Station('উত্তরা উত্তর', 'Uttara North', 23.8693, 90.3672),
    Station('উত্তরা সেন্টার', 'Uttara Center', 23.8597, 90.3655),
    Station('উত্তরা দক্ষিণ', 'Uttara South', 23.8456, 90.3633),
    Station('পল্লবী', 'Pallabi', 23.8263, 90.3645),
    Station('মিরপুর ১১', 'Mirpur 11', 23.8193, 90.3653),
    Station('মিরপুর ১০', 'Mirpur 10', 23.8070, 90.3685),
    Station('কাজীপাড়া', 'Kazipara', 23.7976, 90.3727),
    Station('শেওড়াপাড়া', 'Shewrapara', 23.7905, 90.3757),
    Station('আগারগাঁও', 'Agargaon', 23.7781, 90.3800),
    Station('বিজয় সরণি', 'Bijoy Sarani', 23.7656, 90.3881),
    Station('ফার্মগেট', 'Farmgate', 23.7577, 90.3897),
    Station('কারওয়ান বাজার', 'Karwan Bazar', 23.7509, 90.3925),
    Station('শাহবাগ', 'Shahbagh', 23.7387, 90.3958),
    Station('ঢাকা বিশ্ববিদ্যালয়', 'Dhaka University', 23.7329, 90.3976),
    Station('বাংলাদেশ সচিবালয়', 'Bangladesh Secretariat', 23.7299, 90.4078),
    Station('মতিঝিল', 'Motijheel', 23.7275, 90.4180),
    Station('কমলাপুর', 'Kamalapur', 23.7322, 90.4260, upcoming: true),
  ],
);

/// Lines under construction or planned. Shown as "আসছে" (coming soon).
const upcomingLines = [
  MetroLine(
      id: 'MRT-1',
      nameBn: 'এমআরটি লাইন-১',
      routeBn: 'বিমানবন্দর – কমলাপুর ও নতুনবাজার – পূর্বাচল',
      operational: false),
  MetroLine(
      id: 'MRT-5N',
      nameBn: 'এমআরটি লাইন-৫ (উত্তর)',
      routeBn: 'হেমায়েতপুর – ভাটারা',
      operational: false),
  MetroLine(
      id: 'MRT-5S',
      nameBn: 'এমআরটি লাইন-৫ (দক্ষিণ)',
      routeBn: 'গাবতলী – দাশেরকান্দি',
      operational: false),
  MetroLine(
      id: 'MRT-2',
      nameBn: 'এমআরটি লাইন-২',
      routeBn: 'গাবতলী – নারায়ণগঞ্জ',
      operational: false),
  MetroLine(
      id: 'MRT-4',
      nameBn: 'এমআরটি লাইন-৪',
      routeBn: 'কমলাপুর – নারায়ণগঞ্জ',
      operational: false),
];

const allLines = [mrt6, ...upcomingLines];
