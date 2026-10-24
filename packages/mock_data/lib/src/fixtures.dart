/// Fixture data taken from the Claude Design boards (P02, P03, P06, P09, P17, T01, D03).
///
/// Dates are built relative to [now] so "Today 09:30" in the mocks stays "today"
/// whenever the PoC runs.
library;

/// Demo credentials. Test values only: they exist only in this mock backend.
const demoEmail = 'anna.nowak@example.com';
const demoPassword = 'inspect123';

const inspectorAnna = {'id': 'u-anna', 'name': 'Anna Nowak', 'email': demoEmail, 'initials': 'AN', 'role': 'Inspector'};

const siteManagerPiotr = {'name': 'Piotr Zieliński', 'role': 'Site manager', 'phone': '+48 600 000 000'};

/// Sites used by the list, the map and the wizard's autocomplete (P09).
const sites = <Map<String, Object?>>[
  {
    'id': 's-warehouse-a',
    'name': 'Warehouse A – loading dock',
    'address': 'ul. Przemysłowa 14',
    'postcode': '03-123',
    'city': 'Warsaw',
    'icon': 'warehouse',
    'lat': 52.2550,
    'lng': 21.0400,
  },
  {
    'id': 's-riverside-office',
    'name': 'Riverside office, floor 4',
    'address': 'ul. Wybrzeże 2',
    'postcode': '00-001',
    'city': 'Warsaw',
    'icon': 'apartment',
    'lat': 52.2400,
    'lng': 21.0300,
  },
  {
    'id': 's-riverside-warehouse',
    'name': 'Riverside warehouse',
    'address': 'ul. Portowa 8',
    'postcode': '03-200',
    'city': 'Warsaw',
    'icon': 'warehouse',
    'lat': 52.2600,
    'lng': 21.0550,
  },
  {
    'id': 's-river-pumping',
    'name': 'River pumping station',
    'address': 'ul. Wodna 1',
    'postcode': '00-100',
    'city': 'Warsaw',
    'icon': 'water_pump',
    'lat': 52.2180,
    'lng': 21.0450,
  },
  {
    'id': 's-substation-12',
    'name': 'Substation 12',
    'address': 'ul. Energetyczna 5',
    'postcode': '02-300',
    'city': 'Warsaw',
    'icon': 'bolt',
    'lat': 52.2050,
    'lng': 20.9800,
  },
  {
    'id': 's-cold-storage-3',
    'name': 'Cold storage unit 3',
    'address': 'ul. Chłodna 9',
    'postcode': '00-891',
    'city': 'Warsaw',
    'icon': 'ac_unit',
    'lat': 52.2350,
    'lng': 20.9950,
  },
  {
    'id': 's-parking-garage',
    'name': 'Parking garage, level −2',
    'address': 'ul. Parkowa 3',
    'postcode': '00-500',
    'city': 'Warsaw',
    'icon': 'local_parking',
    'lat': 52.2150,
    'lng': 21.0200,
  },
  {
    'id': 's-solar-farm',
    'name': 'Solar farm, inverter row B',
    'address': 'Kępa Solar Park',
    'postcode': '05-400',
    'city': 'Otwock',
    'icon': 'solar_power',
    'lat': 52.1050,
    'lng': 21.2600,
  },
  {
    'id': 's-school-gym',
    'name': 'School gym roof',
    'address': 'ul. Szkolna 1',
    'postcode': '01-200',
    'city': 'Warsaw',
    'icon': 'roofing',
    'lat': 52.2450,
    'lng': 20.9600,
  },
];

/// The "Fire safety, annual" template has 18 items; the boards show the first 5.
/// The other 13 are plausible placeholders, flagged so the UI and docs can say so.
const fireSafetyTemplate = {
  'id': 'tpl-fire-annual-v3',
  'name': 'Fire safety, annual',
  'version': 3,
  'items': [
    {'id': 'c01', 'title': 'Fire extinguishers in date', 'placeholder': false},
    {'id': 'c02', 'title': 'Emergency exit clear', 'placeholder': false},
    {'id': 'c03', 'title': 'Exit signs lit', 'placeholder': false},
    {'id': 'c04', 'title': 'Sprinkler test log available', 'placeholder': false},
    {'id': 'c05', 'title': 'Alarm panel status', 'placeholder': false},
    {'id': 'c06', 'title': 'Fire doors close and latch', 'placeholder': true},
    {'id': 'c07', 'title': 'Emergency lighting tested', 'placeholder': true},
    {'id': 'c08', 'title': 'Smoke detectors working', 'placeholder': true},
    {'id': 'c09', 'title': 'Evacuation plan posted', 'placeholder': true},
    {'id': 'c10', 'title': 'Assembly point sign visible', 'placeholder': true},
    {'id': 'c11', 'title': 'Fire hose reels accessible', 'placeholder': true},
    {'id': 'c12', 'title': 'Manual call points unobstructed', 'placeholder': true},
    {'id': 'c13', 'title': 'Electrical panels unobstructed', 'placeholder': true},
    {'id': 'c14', 'title': 'Flammable materials stored safely', 'placeholder': true},
    {'id': 'c15', 'title': 'Fire blankets in kitchens', 'placeholder': true},
    {'id': 'c16', 'title': 'Hydrant access clear', 'placeholder': true},
    {'id': 'c17', 'title': 'Staff fire training records current', 'placeholder': true},
    {'id': 'c18', 'title': 'Hot work permits on file', 'placeholder': true},
  ],
};

const inspectionTypes = <String>['Fire safety, annual', 'Fire safety, follow-up', 'Electrical, periodic', 'Structural, visual'];

Map<String, Object?> _site(String id) => sites.firstWhere((s) => s['id'] == id);

DateTime _at(DateTime now, int dayOffset, int hour, int minute) => DateTime(now.year, now.month, now.day + dayOffset, hour, minute);

Map<String, Object?> _inspection({
  required String id,
  required String siteId,
  required String status,
  required DateTime scheduledAt,
  int durationMin = 90,
  String priority = 'normal',
  Map<String, String> answers = const {},
  int photoCount = 0,
  String notes = '',
}) {
  final site = _site(siteId);
  return {
    'id': id,
    'siteId': siteId,
    'site': site['name'],
    'address': site['address'],
    'postcode': site['postcode'],
    'city': site['city'],
    'icon': site['icon'],
    'lat': site['lat'],
    'lng': site['lng'],
    'status': status,
    'type': 'Fire safety, annual',
    'templateId': fireSafetyTemplate['id'],
    'scheduledAt': scheduledAt.toIso8601String(),
    'durationMin': durationMin,
    'priority': priority,
    'inspector': inspectorAnna,
    'siteManager': siteManagerPiotr,
    'answers': answers,
    'photos': [
      for (var i = 1; i <= photoCount; i++)
        {
          'id': 'p$i',
          'caption': i == 3 ? 'Emergency exit blocked by pallets' : 'Photo $i',
          'takenAt': scheduledAt.add(Duration(minutes: 10 + i * 3)).toIso8601String(),
          'lat': 52.2297,
          'lng': 21.0122,
          'sizeBytes': 3100000,
        },
    ],
    'files': <Map<String, Object?>>[],
    'notes': notes,
    'archived': false,
    'updatedAt': scheduledAt.toIso8601String(),
  };
}

/// The 7 inspections shown on the boards plus older submitted ones so paging
/// (20 per page) has something to load.
List<Map<String, Object?>> buildInspections(DateTime now) {
  final answers1042 = <String, String>{
    'c01': 'pass',
    'c02': 'fail',
    'c03': 'pass',
    'c04': 'na',
    'c06': 'pass',
    'c07': 'pass',
    'c08': 'fail',
    'c09': 'pass',
    'c10': 'pass',
    'c11': 'pass',
    'c12': 'pass',
    'c13': 'pass',
  };
  final list = <Map<String, Object?>>[
    _inspection(
      id: 'INS-1042',
      siteId: 's-warehouse-a',
      status: 'inProgress',
      scheduledAt: _at(now, 0, 9, 30),
      answers: answers1042,
      photoCount: 6,
      notes: 'Access through gate 3. Bring the fire panel key.',
    ),
    _inspection(id: 'INS-1043', siteId: 's-riverside-office', status: 'scheduled', scheduledAt: _at(now, 0, 13, 0)),
    _inspection(id: 'INS-1038', siteId: 's-substation-12', status: 'overdue', scheduledAt: _at(now, -1, 14, 0), priority: 'high'),
    _inspection(id: 'INS-1040', siteId: 's-cold-storage-3', status: 'draft', scheduledAt: _at(now, 2, 11, 0)),
    _inspection(id: 'INS-1045', siteId: 's-parking-garage', status: 'scheduled', scheduledAt: _at(now, 4, 10, 0)),
    _inspection(id: 'INS-1031', siteId: 's-solar-farm', status: 'submitted', scheduledAt: _at(now, -9, 10, 0)),
    _inspection(id: 'INS-1029', siteId: 's-school-gym', status: 'submitted', scheduledAt: _at(now, -10, 9, 0)),
  ];
  const olderSites = [
    's-warehouse-a',
    's-riverside-office',
    's-substation-12',
    's-cold-storage-3',
    's-solar-farm',
    's-school-gym',
    's-river-pumping',
    's-riverside-warehouse',
  ];
  for (var n = 1028; n >= 1000; n--) {
    final daysAgo = 11 + (1028 - n) * 2;
    list.add(
      _inspection(
        id: 'INS-$n',
        siteId: olderSites[n % olderSites.length],
        status: 'submitted',
        scheduledAt: _at(now, -daysAgo, 9 + n % 6, 0),
      ),
    );
  }
  return list;
}

List<Map<String, Object?>> buildHistory(String inspectionId, DateTime now) {
  if (inspectionId != 'INS-1042') {
    return [
      {'icon': 'assignment_ind', 'title': 'Assigned to Anna Nowak', 'at': _at(now, -3, 16, 20).toIso8601String(), 'by': null},
    ];
  }
  return [
    {'icon': 'cloud_done', 'title': 'Synced to server', 'at': _at(now, 0, 10, 12).toIso8601String(), 'by': null},
    {'icon': 'save', 'title': 'Draft saved offline', 'at': _at(now, 0, 9, 58).toIso8601String(), 'by': 'Anna Nowak'},
    {'icon': 'play_circle', 'title': 'Inspection started', 'at': _at(now, 0, 9, 34).toIso8601String(), 'by': 'GPS confirmed on site'},
    {'icon': 'assignment_ind', 'title': 'Assigned to Anna Nowak', 'at': _at(now, -3, 16, 20).toIso8601String(), 'by': null},
  ];
}

/// P17. Each notification carries the route it opens: the deep-link payload.
List<Map<String, Object?>> buildNotifications(DateTime now) => [
  {
    'id': 'n1',
    'kind': 'overdue',
    'icon': 'error',
    'title': 'Substation 12 is overdue',
    'body': 'Was due yesterday at 14:00',
    'at': _at(now, 0, 8, 2).toIso8601String(),
    'read': false,
    'route': '/inspections/INS-1038',
  },
  {
    'id': 'n2',
    'kind': 'reminder',
    'icon': 'alarm',
    'title': 'Warehouse A at 09:30',
    'body': 'Starts in 30 minutes',
    'at': _at(now, 0, 9, 0).toIso8601String(),
    'read': false,
    'route': '/inspections/INS-1042?tab=checklist',
  },
  {
    'id': 'n3',
    'kind': 'synced',
    'icon': 'cloud_done',
    'title': 'Draft synced',
    'body': 'Cold storage unit 3 is on the server',
    'at': _at(now, 0, 7, 45).toIso8601String(),
    'read': false,
    'route': '/inspections/INS-1040',
  },
  {
    'id': 'n4',
    'kind': 'assigned',
    'icon': 'assignment_ind',
    'title': 'New inspection assigned',
    'body': 'Parking garage, level −2 · Fri 10:00',
    'at': _at(now, -2, 12, 0).toIso8601String(),
    'read': true,
    'route': '/inspections/INS-1045',
  },
  {
    'id': 'n5',
    'kind': 'approved',
    'icon': 'task_alt',
    'title': 'Report approved',
    'body': 'Solar farm, inverter row B',
    'at': _at(now, -3, 15, 0).toIso8601String(),
    'read': true,
    'route': '/inspections/INS-1031?tab=history',
  },
];
