import 'package:flutter/foundation.dart';

import 'inspection.dart';

export 'inspection.dart' show FailDetail;

/// A photo or file added in step 4. Its bytes live in the local blob store
/// under [id]; entries without bytes (fixtures, ones already on the server)
/// show a placeholder.
@immutable
class DraftAttachment {
  const DraftAttachment({
    required this.id,
    required this.name,
    required this.sizeBytes,
    this.isPhoto = true,
    this.forItem,
    this.stored = false,
  });

  factory DraftAttachment.fromJson(Map<String, Object?> j) => DraftAttachment(
    id: j['id']! as String,
    name: j['name']! as String,
    sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
    isPhoto: j['isPhoto'] != false,
    forItem: j['forItem'] as String?,
    stored: j['stored'] == true,
  );

  final String id;
  final String name;
  final int sizeBytes;
  final bool isPhoto;

  /// Checklist item this photo documents, if any.
  final String? forItem;

  /// Already on the server (an edit started from the inspection): sent back
  /// by id so the server keeps it, and not re-checked for type or size.
  final bool stored;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'sizeBytes': sizeBytes,
    'isPhoto': isPhoto,
    'forItem': forItem,
    if (stored) 'stored': true,
  };
}

/// Everything the 5-step wizard collects (P09–P13). Saved on every change, so
/// it survives the app being killed or the browser tab being reloaded.
@immutable
class InspectionDraft {
  const InspectionDraft({
    this.inspectionId,
    this.siteId,
    this.siteName = '',
    this.siteAddress = '',
    this.siteLat,
    this.siteLng,
    this.myLat,
    this.myLng,
    this.myAccuracy,
    this.type,
    this.date,
    this.startMinutes,
    this.priority = Priority.normal,
    this.duration = '',
    this.notes = '',
    this.answers = const {},
    this.failures = const {},
    this.attachments = const [],
    this.confirmed = false,
    this.lastStep = 1,
    this.updatedAt,
    this.requestKey,
  });

  factory InspectionDraft.fromJson(Map<String, Object?> j) => InspectionDraft(
    inspectionId: j['inspectionId'] as String?,
    siteId: j['siteId'] as String?,
    siteName: j['siteName'] as String? ?? '',
    siteAddress: j['siteAddress'] as String? ?? '',
    siteLat: (j['siteLat'] as num?)?.toDouble(),
    siteLng: (j['siteLng'] as num?)?.toDouble(),
    myLat: (j['myLat'] as num?)?.toDouble(),
    myLng: (j['myLng'] as num?)?.toDouble(),
    myAccuracy: (j['myAccuracy'] as num?)?.toDouble(),
    type: j['type'] as String?,
    date: DateTime.tryParse(j['date'] as String? ?? ''),
    startMinutes: (j['startMinutes'] as num?)?.toInt(),
    priority: Priority.parse(j['priority']),
    duration: j['duration'] as String? ?? '',
    notes: j['notes'] as String? ?? '',
    answers: {for (final e in ((j['answers'] as Map?) ?? const {}).entries) e.key as String: ?Answer.parse(e.value)},
    failures: {
      for (final e in ((j['failures'] as Map?) ?? const {}).entries)
        e.key as String: FailDetail.fromJson((e.value as Map).cast<String, Object?>()),
    },
    attachments: [for (final a in (j['attachments'] as List?) ?? const []) DraftAttachment.fromJson((a as Map).cast<String, Object?>())],
    confirmed: j['confirmed'] == true,
    lastStep: (j['lastStep'] as num?)?.toInt() ?? 1,
    updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? ''),
    requestKey: j['requestKey'] as String?,
  );

  /// Prefill for `/inspections/:id/edit`.
  factory InspectionDraft.fromInspection(InspectionDetail d) {
    final s = d.summary;
    return InspectionDraft(
      inspectionId: s.id,
      siteId: s.siteId,
      siteName: s.site,
      siteAddress: s.address,
      siteLat: s.lat,
      siteLng: s.lng,
      type: s.type,
      date: DateTime(s.scheduledAt.year, s.scheduledAt.month, s.scheduledAt.day),
      startMinutes: s.scheduledAt.hour * 60 + s.scheduledAt.minute,
      priority: s.priority,
      duration: d.durationMin == 0 ? '' : '${d.durationMin}',
      notes: d.notes,
      answers: d.answers,
      // The PUT replaces photos and files with what it sends, so the ones
      // already on the server come along (by id) or they'd be deleted.
      failures: d.failures,
      attachments: [
        for (final p in d.photos)
          DraftAttachment(
            id: p.id,
            // The caption, possibly empty; the grid labels photos by number.
            name: p.caption,
            sizeBytes: p.sizeBytes,
            forItem: p.forItem,
            stored: true,
          ),
        for (final f in d.files) DraftAttachment(id: f.id, name: f.name, sizeBytes: f.sizeBytes, isPhoto: false, stored: true),
      ],
      // Every step already has its data: the step bar can open any of them.
      lastStep: 5,
    );
  }

  /// Null for a new inspection.
  final String? inspectionId;
  final String? siteId;
  final String siteName;
  final String siteAddress;
  final double? siteLat;
  final double? siteLng;

  /// Where the inspector was when they checked location (optional, P09).
  final double? myLat;
  final double? myLng;
  final double? myAccuracy;
  final String? type;

  /// Calendar day (time ignored); combined with [startMinutes].
  final DateTime? date;
  final int? startMinutes;
  final Priority priority;

  /// Raw text from the field so invalid input survives a reload as typed.
  final String duration;
  final String notes;
  final Map<String, Answer> answers;
  final Map<String, FailDetail> failures;
  final List<DraftAttachment> attachments;
  final bool confirmed;

  /// Furthest step reached, used to resume.
  final int lastStep;
  final DateTime? updatedAt;

  /// `Idempotency-Key` of a new inspection, made on its first submit and kept
  /// until one succeeds, so a retry after a lost answer can't create it twice.
  final String? requestKey;

  bool get hasSite => siteId != null || siteName.trim().length >= 3;
  bool get isEmpty =>
      !hasSite &&
      type == null &&
      date == null &&
      startMinutes == null &&
      priority == Priority.normal &&
      myLat == null &&
      answers.isEmpty &&
      failures.isEmpty &&
      attachments.isEmpty &&
      notes.isEmpty &&
      duration.isEmpty;

  DateTime? get scheduledAt {
    final d = date, m = startMinutes;
    return d == null || m == null ? null : DateTime(d.year, d.month, d.day, m ~/ 60, m % 60);
  }

  /// A site typed rather than picked: nothing of a previously picked site
  /// (id, address, coordinates) stays behind.
  InspectionDraft withNewSite(String name) =>
      copyWith(siteId: () => null, siteName: name, siteAddress: '', siteLat: () => null, siteLng: () => null);

  List<DraftAttachment> get photos => attachments.where((a) => a.isPhoto).toList();
  List<DraftAttachment> get files => attachments.where((a) => !a.isPhoto).toList();

  InspectionDraft copyWith({
    String? Function()? siteId,
    String? siteName,
    String? siteAddress,
    double? Function()? siteLat,
    double? Function()? siteLng,
    ({double lat, double lng, double accuracy})? Function()? myLocation,
    String? Function()? type,
    DateTime? Function()? date,
    int? Function()? startMinutes,
    Priority? priority,
    String? duration,
    String? notes,
    Map<String, Answer>? answers,
    Map<String, FailDetail>? failures,
    List<DraftAttachment>? attachments,
    bool? confirmed,
    int? lastStep,
    DateTime? updatedAt,
    String? requestKey,
  }) => InspectionDraft(
    inspectionId: inspectionId,
    siteId: siteId != null ? siteId() : this.siteId,
    siteName: siteName ?? this.siteName,
    siteAddress: siteAddress ?? this.siteAddress,
    siteLat: siteLat != null ? siteLat() : this.siteLat,
    siteLng: siteLng != null ? siteLng() : this.siteLng,
    myLat: myLocation != null ? myLocation()?.lat : myLat,
    myLng: myLocation != null ? myLocation()?.lng : myLng,
    myAccuracy: myLocation != null ? myLocation()?.accuracy : myAccuracy,
    type: type != null ? type() : this.type,
    date: date != null ? date() : this.date,
    startMinutes: startMinutes != null ? startMinutes() : this.startMinutes,
    priority: priority ?? this.priority,
    duration: duration ?? this.duration,
    notes: notes ?? this.notes,
    answers: answers ?? this.answers,
    failures: failures ?? this.failures,
    attachments: attachments ?? this.attachments,
    confirmed: confirmed ?? this.confirmed,
    lastStep: lastStep ?? this.lastStep,
    updatedAt: updatedAt ?? this.updatedAt,
    requestKey: requestKey ?? this.requestKey,
  );

  Map<String, Object?> toJson() => {
    'inspectionId': inspectionId,
    'siteId': siteId,
    'siteName': siteName,
    'siteAddress': siteAddress,
    'siteLat': siteLat,
    'siteLng': siteLng,
    'myLat': myLat,
    'myLng': myLng,
    'myAccuracy': myAccuracy,
    'type': type,
    'date': date?.toIso8601String(),
    'startMinutes': startMinutes,
    'priority': priority.name,
    'duration': duration,
    'notes': notes,
    'answers': {for (final e in answers.entries) e.key: e.value.name},
    'failures': {for (final e in failures.entries) e.key: e.value.toJson()},
    'attachments': [for (final a in attachments) a.toJson()],
    'confirmed': confirmed,
    'lastStep': lastStep,
    'updatedAt': updatedAt?.toIso8601String(),
    'requestKey': requestKey,
  };

  /// Body for `POST /inspections` / `PUT /inspections/:id`.
  Map<String, Object?> toApiBody() => {
    if (siteId != null) 'siteId': siteId else 'site': siteName.trim(),
    if (myLat != null) 'checkedInAt': {'lat': myLat, 'lng': myLng, 'accuracy': myAccuracy},
    'type': type,
    'scheduledAt': scheduledAt?.toIso8601String(),
    'durationMin': int.tryParse(duration.trim()),
    'priority': priority.name,
    'notes': notes,
    'answers': {for (final e in answers.entries) e.key: e.value.name},
    'failures': {for (final e in failures.entries) e.key: e.value.toJson()},
    'photos': [for (final a in photos) a.toJson()],
    'files': [for (final a in files) a.toJson()],
    'confirmed': confirmed,
  };
}
