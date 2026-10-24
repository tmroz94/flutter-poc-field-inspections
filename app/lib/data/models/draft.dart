import 'package:flutter/foundation.dart';

import 'inspection.dart';

/// Extra detail required when a checklist item fails (P11).
@immutable
class FailDetail {
  const FailDetail({this.severity = 3, this.followUp = true, this.note = ''});

  factory FailDetail.fromJson(Map<String, Object?> j) =>
      FailDetail(severity: (j['severity'] as num?)?.toInt() ?? 3, followUp: j['followUp'] != false, note: j['note'] as String? ?? '');

  /// 1 (minor) … 5 (critical).
  final int severity;
  final bool followUp;
  final String note;

  static const severityLabels = ['Minor', 'Low', 'Major', 'High', 'Critical'];
  String get severityLabel => '$severity · ${severityLabels[severity - 1]}';

  FailDetail copyWith({int? severity, bool? followUp, String? note}) =>
      FailDetail(severity: severity ?? this.severity, followUp: followUp ?? this.followUp, note: note ?? this.note);

  Map<String, Object?> toJson() => {'severity': severity, 'followUp': followUp, 'note': note};
}

/// A photo or file added in step 4. Real capture arrives in M3; until then
/// entries are placeholders with a name and size.
@immutable
class DraftAttachment {
  const DraftAttachment({required this.id, required this.name, required this.sizeBytes, this.isPhoto = true, this.forItem});

  factory DraftAttachment.fromJson(Map<String, Object?> j) => DraftAttachment(
    id: j['id']! as String,
    name: j['name']! as String,
    sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
    isPhoto: j['isPhoto'] != false,
    forItem: j['forItem'] as String?,
  );

  final String id;
  final String name;
  final int sizeBytes;
  final bool isPhoto;

  /// Checklist item this photo documents, if any.
  final String? forItem;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'sizeBytes': sizeBytes, 'isPhoto': isPhoto, 'forItem': forItem};
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
  });

  factory InspectionDraft.fromJson(Map<String, Object?> j) => InspectionDraft(
    inspectionId: j['inspectionId'] as String?,
    siteId: j['siteId'] as String?,
    siteName: j['siteName'] as String? ?? '',
    siteAddress: j['siteAddress'] as String? ?? '',
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
  );

  /// Prefill for `/inspections/:id/edit`.
  factory InspectionDraft.fromInspection(InspectionDetail d) {
    final s = d.summary;
    return InspectionDraft(
      inspectionId: s.id,
      siteId: s.siteId,
      siteName: s.site,
      siteAddress: s.address,
      type: s.type,
      date: DateTime(s.scheduledAt.year, s.scheduledAt.month, s.scheduledAt.day),
      startMinutes: s.scheduledAt.hour * 60 + s.scheduledAt.minute,
      priority: s.priority,
      duration: d.durationMin == 0 ? '' : '${d.durationMin}',
      notes: d.notes,
      answers: d.answers,
    );
  }

  /// Null for a new inspection.
  final String? inspectionId;
  final String? siteId;
  final String siteName;
  final String siteAddress;
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

  bool get hasSite => siteId != null || siteName.trim().length >= 3;
  bool get isEmpty => !hasSite && type == null && answers.isEmpty && attachments.isEmpty && notes.isEmpty && duration.isEmpty;

  DateTime? get scheduledAt {
    final d = date, m = startMinutes;
    return d == null || m == null ? null : DateTime(d.year, d.month, d.day, m ~/ 60, m % 60);
  }

  List<DraftAttachment> get photos => attachments.where((a) => a.isPhoto).toList();
  List<DraftAttachment> get files => attachments.where((a) => !a.isPhoto).toList();

  InspectionDraft copyWith({
    String? Function()? siteId,
    String? siteName,
    String? siteAddress,
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
  }) => InspectionDraft(
    inspectionId: inspectionId,
    siteId: siteId != null ? siteId() : this.siteId,
    siteName: siteName ?? this.siteName,
    siteAddress: siteAddress ?? this.siteAddress,
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
  );

  Map<String, Object?> toJson() => {
    'inspectionId': inspectionId,
    'siteId': siteId,
    'siteName': siteName,
    'siteAddress': siteAddress,
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
  };

  /// Body for `POST /inspections` / `PUT /inspections/:id`.
  Map<String, Object?> toApiBody() => {
    if (siteId != null) 'siteId': siteId else 'site': siteName.trim(),
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
