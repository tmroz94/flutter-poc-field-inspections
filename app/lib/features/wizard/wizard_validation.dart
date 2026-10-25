import '../../core/validation/validators.dart';
import '../../data/models/draft.dart';
import '../../data/models/inspection.dart';

/// The five steps (P09–P13). Titles are localized (`stepTitle`).
enum WizardStep {
  site,
  details,
  checklist,
  photos,
  review;

  int get number => index + 1;

  static WizardStep fromNumber(int n) => values[(n - 1).clamp(0, values.length - 1)];
}

/// Pure validation rules per step. Field key → message; empty means valid.
/// The same rules run on Next, on Review (per card) and in the step guard.
class WizardValidator {
  WizardValidator(this.t, {required this.today, this.checklist = const []});

  final ValidationText t;
  final DateTime today;

  /// Empty until the template loads; step 3 is invalid until then.
  final List<ChecklistItem> checklist;

  static const maxPhotos = 20;
  static const maxFileBytes = 20 * 1000 * 1000;
  static const allowedExtensions = {'jpg', 'jpeg', 'png', 'heic', 'pdf'};

  Map<String, String> step(WizardStep s, InspectionDraft d) => switch (s) {
    WizardStep.site => site(d),
    WizardStep.details => details(d),
    WizardStep.checklist => checklistErrors(d),
    WizardStep.photos => photos(d),
    WizardStep.review => review(d),
  };

  Map<String, String> site(InspectionDraft d) => {if (!d.hasSite) 'site': d.siteName.trim().isEmpty ? t.required : t.siteTooShort};

  Map<String, String> details(InspectionDraft d) {
    final duration = Validators.all([Validators.required(t), Validators.intRange(t, 15, 480)])(d.duration);
    final date = d.inspectionId == null ? Validators.dateNotBefore(t, d.date, today) : (d.date == null ? t.required : null);
    return {
      if (d.type == null) 'type': t.required,
      'date': ?date,
      if (d.startMinutes == null) 'time': t.required,
      'duration': ?duration,
      'notes': ?Validators.maxLength(t, 500)(d.notes),
    };
  }

  /// Every item answered; each Fail needs a note or a photo. Without the
  /// template nothing can be checked, so the step can't pass (submitting
  /// with no answers would only be rejected later, from the outbox).
  Map<String, String> checklistErrors(InspectionDraft d) {
    if (checklist.isEmpty) return {'checklist': t.checklistNotLoaded};
    final errors = <String, String>{};
    for (final item in checklist) {
      final answer = d.answers[item.id];
      if (answer == null) {
        errors[item.id] = t.answerItem;
      } else if (answer == Answer.fail) {
        final detail = d.failures[item.id] ?? const FailDetail();
        final hasPhoto = d.attachments.any((a) => a.forItem == item.id);
        if (detail.note.trim().isEmpty && !hasPhoto) errors[item.id] = t.failureNeedsDetail;
      }
    }
    return errors;
  }

  Map<String, String> photos(InspectionDraft d) {
    final anyFail = d.answers.values.contains(Answer.fail);
    // Attachments already on the server were checked when they were added.
    final added = d.attachments.where((a) => !a.stored);
    final tooBig = added.where((a) => a.sizeBytes > maxFileBytes).map((a) => a.name);
    final badType = added.where((a) => !allowedExtensions.contains(a.name.split('.').last.toLowerCase())).map((a) => a.name);
    return {
      if (anyFail && d.photos.isEmpty) 'photos': t.photoForFailure,
      if (d.photos.length > maxPhotos) 'photos': t.tooManyPhotos(maxPhotos),
      if (tooBig.isNotEmpty) 'size': t.filesTooBig(tooBig.join(', ')),
      if (badType.isNotEmpty) 'type': t.badFileType(badType.join(', ')),
    };
  }

  Map<String, String> review(InspectionDraft d) => {if (!d.confirmed) 'confirmed': t.confirmFindings};

  /// The first step with errors before [upTo] (exclusive), or null.
  WizardStep? firstInvalidBefore(WizardStep upTo, InspectionDraft d) {
    for (final s in WizardStep.values.take(upTo.index)) {
      if (step(s, d).isNotEmpty) return s;
    }
    return null;
  }

  bool canSubmit(InspectionDraft d) => WizardStep.values.every((s) => step(s, d).isEmpty);
}
