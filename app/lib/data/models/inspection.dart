import 'package:flutter/foundation.dart';

enum InspectionStatus {
  scheduled,
  inProgress,
  draft,
  overdue,
  submitted;

  static InspectionStatus parse(Object? name) => values.asNameMap()[name] ?? scheduled;

  String get label => switch (this) {
    scheduled => 'Scheduled',
    inProgress => 'In progress',
    draft => 'Draft',
    overdue => 'Overdue',
    submitted => 'Submitted',
  };

  bool get isOpen => this != submitted;
}

enum Priority {
  low,
  normal,
  high;

  static Priority parse(Object? name) => values.asNameMap()[name] ?? normal;
}

@immutable
class InspectionSummary {
  const InspectionSummary({
    required this.id,
    required this.site,
    required this.address,
    this.siteId = '',
    required this.city,
    required this.icon,
    required this.status,
    required this.scheduledAt,
    required this.type,
    this.priority = Priority.normal,
    this.lat,
    this.lng,
  });

  factory InspectionSummary.fromJson(Map<String, Object?> j) => InspectionSummary(
    id: j['id']! as String,
    siteId: j['siteId'] as String? ?? '',
    site: j['site']! as String,
    address: j['address'] as String? ?? '',
    city: j['city'] as String? ?? '',
    icon: j['icon'] as String? ?? 'location_on',
    status: InspectionStatus.parse(j['status']),
    scheduledAt: DateTime.parse(j['scheduledAt']! as String),
    type: j['type'] as String? ?? '',
    priority: Priority.parse(j['priority']),
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
  );

  final String id;
  final String siteId;
  final String site;
  final String address;
  final String city;

  /// Material Symbols name from the backend (`warehouse`, `bolt`, …).
  final String icon;
  final InspectionStatus status;
  final DateTime scheduledAt;
  final String type;
  final Priority priority;
  final double? lat;
  final double? lng;

  InspectionSummary copyWith({InspectionStatus? status}) => InspectionSummary(
    id: id,
    siteId: siteId,
    site: site,
    address: address,
    city: city,
    icon: icon,
    status: status ?? this.status,
    scheduledAt: scheduledAt,
    type: type,
    priority: priority,
    lat: lat,
    lng: lng,
  );
}

@immutable
class Person {
  const Person({required this.name, this.role = '', this.phone});

  factory Person.fromJson(Map<String, Object?> j) =>
      Person(name: j['name']! as String, role: j['role'] as String? ?? '', phone: j['phone'] as String?);

  final String name;
  final String role;
  final String? phone;
}

@immutable
class Photo {
  const Photo({required this.id, required this.caption, required this.takenAt, this.lat, this.lng, this.sizeBytes = 0, this.forItem});

  factory Photo.fromJson(Map<String, Object?> j) => Photo(
    id: j['id']! as String,
    caption: j['caption'] as String? ?? '',
    takenAt: DateTime.parse(j['takenAt']! as String),
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
    forItem: j['forItem'] as String?,
  );

  final String id;
  final String caption;
  final DateTime takenAt;
  final double? lat;
  final double? lng;
  final int sizeBytes;

  /// Checklist item this photo documents, if any.
  final String? forItem;
}

@immutable
class HistoryEvent {
  const HistoryEvent({required this.icon, required this.title, required this.at, this.by});

  factory HistoryEvent.fromJson(Map<String, Object?> j) => HistoryEvent(
    icon: j['icon']! as String,
    title: j['title']! as String,
    at: DateTime.parse(j['at']! as String),
    by: j['by'] as String?,
  );

  final String icon;
  final String title;
  final DateTime at;
  final String? by;
}

enum Answer {
  pass,
  fail,
  na;

  static Answer? parse(Object? name) => values.asNameMap()[name];
}

/// Extra detail required when a checklist item fails (P11).
@immutable
class FailDetail {
  const FailDetail({this.severity = 3, this.followUp = true, this.note = ''});

  factory FailDetail.fromJson(Map<String, Object?> j) => FailDetail(
    severity: ((j['severity'] as num?)?.toInt() ?? 3).clamp(1, 5),
    followUp: j['followUp'] != false,
    note: j['note'] as String? ?? '',
  );

  /// 1 (minor) … 5 (critical).
  final int severity;
  final bool followUp;
  final String note;

  FailDetail copyWith({int? severity, bool? followUp, String? note}) =>
      FailDetail(severity: severity ?? this.severity, followUp: followUp ?? this.followUp, note: note ?? this.note);

  Map<String, Object?> toJson() => {'severity': severity, 'followUp': followUp, 'note': note};
}

/// A document attached to an inspection on the server (step 4 files).
@immutable
class StoredFile {
  const StoredFile({required this.id, required this.name, this.sizeBytes = 0});

  factory StoredFile.fromJson(Map<String, Object?> j) =>
      StoredFile(id: j['id']! as String, name: j['name'] as String? ?? '', sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0);

  final String id;
  final String name;
  final int sizeBytes;
}

@immutable
class InspectionDetail {
  const InspectionDetail({
    required this.summary,
    required this.postcode,
    required this.durationMin,
    required this.inspector,
    required this.siteManager,
    required this.answers,
    required this.photos,
    required this.notes,
    required this.answered,
    required this.total,
    required this.failed,
    required this.history,
    this.templateId = '',
    this.files = const [],
    this.failures = const {},
  });

  factory InspectionDetail.fromJson(Map<String, Object?> j) {
    final summary = (j['checklistSummary'] as Map?)?.cast<String, Object?>() ?? const {};
    return InspectionDetail(
      summary: InspectionSummary.fromJson(j),
      postcode: j['postcode'] as String? ?? '',
      durationMin: (j['durationMin'] as num?)?.toInt() ?? 0,
      inspector: Person.fromJson((j['inspector']! as Map).cast<String, Object?>()),
      siteManager: Person.fromJson((j['siteManager']! as Map).cast<String, Object?>()),
      answers: {for (final e in ((j['answers'] as Map?) ?? const {}).entries) e.key as String: ?Answer.parse(e.value)},
      photos: [for (final p in (j['photos'] as List?) ?? const []) Photo.fromJson((p as Map).cast<String, Object?>())],
      notes: j['notes'] as String? ?? '',
      answered: (summary['answered'] as num?)?.toInt() ?? 0,
      total: (summary['total'] as num?)?.toInt() ?? 0,
      failed: (summary['failed'] as num?)?.toInt() ?? 0,
      templateId: j['templateId'] as String? ?? '',
      history: [for (final h in (j['history'] as List?) ?? const []) HistoryEvent.fromJson((h as Map).cast<String, Object?>())],
      files: [for (final f in (j['files'] as List?) ?? const []) StoredFile.fromJson((f as Map).cast<String, Object?>())],
      failures: {
        for (final e in ((j['failures'] as Map?) ?? const {}).entries)
          if (e.value is Map) e.key as String: FailDetail.fromJson((e.value as Map).cast<String, Object?>()),
      },
    );
  }

  final InspectionSummary summary;
  final String postcode;
  final int durationMin;
  final Person inspector;
  final Person siteManager;
  final Map<String, Answer> answers;
  final List<Photo> photos;
  final String notes;
  final int answered;
  final int total;
  final int failed;
  final List<HistoryEvent> history;
  final String templateId;
  final List<StoredFile> files;

  /// Severity, follow-up and note per failed checklist item.
  final Map<String, FailDetail> failures;

  String get id => summary.id;
  DateTime get endsAt => summary.scheduledAt.add(Duration(minutes: durationMin));
}

@immutable
class PageResult<T> {
  const PageResult({required this.items, required this.total, required this.page, required this.hasMore});

  final List<T> items;
  final int total;
  final int page;
  final bool hasMore;
}

@immutable
class ChecklistItem {
  const ChecklistItem({required this.id, required this.title, this.placeholder = false});

  factory ChecklistItem.fromJson(Map<String, Object?> j) =>
      ChecklistItem(id: j['id']! as String, title: j['title']! as String, placeholder: j['placeholder'] == true);

  Map<String, Object?> toJson() => {'id': id, 'title': title, if (placeholder) 'placeholder': true};

  final String id;
  final String title;

  /// True for the 13 items not shown on the boards (see fixtures).
  final bool placeholder;
}
