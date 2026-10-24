import '../../core/validation/validators.dart';
import '../../data/models/draft.dart';
import '../../data/models/inspection.dart';

/// The five steps (P09–P13).
enum WizardStep {
  site('Site'),
  details('Details'),
  checklist('Checklist'),
  photos('Photos and files'),
  review('Review and submit');

  const WizardStep(this.title);
  final String title;

  int get number => index + 1;

  static WizardStep fromNumber(int n) => values[(n - 1).clamp(0, values.length - 1)];
}

/// Pure validation rules per step. Field key → message; empty means valid.
/// The same rules run on Next, on Review (per card) and in the step guard.
class WizardValidator {
  WizardValidator(this.t, {required this.today, this.checklist = const []});

  final ValidationText t;
  final DateTime today;
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

  Map<String, String> site(InspectionDraft d) => {
    if (!d.hasSite) 'site': d.siteName.trim().isEmpty ? t.required : 'Pick a site from the list or add a new one (3+ characters)',
  };

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

  /// Every item answered; each Fail needs a note or a photo.
  Map<String, String> checklistErrors(InspectionDraft d) {
    final errors = <String, String>{};
    for (final item in checklist) {
      final answer = d.answers[item.id];
      if (answer == null) {
        errors[item.id] = 'Answer this item';
      } else if (answer == Answer.fail) {
        final detail = d.failures[item.id] ?? const FailDetail();
        final hasPhoto = d.attachments.any((a) => a.forItem == item.id);
        if (detail.note.trim().isEmpty && !hasPhoto) errors[item.id] = 'Add a note or a photo for this failure';
      }
    }
    return errors;
  }

  Map<String, String> photos(InspectionDraft d) {
    final anyFail = d.answers.values.contains(Answer.fail);
    final tooBig = d.attachments.where((a) => a.sizeBytes > maxFileBytes).map((a) => a.name);
    final badType = d.attachments.where((a) => !allowedExtensions.contains(a.name.split('.').last.toLowerCase())).map((a) => a.name);
    return {
      if (anyFail && d.photos.isEmpty) 'photos': 'Add at least one photo of the failed items',
      if (d.photos.length > maxPhotos) 'photos': 'Use $maxPhotos photos or fewer',
      if (tooBig.isNotEmpty) 'size': '${tooBig.join(', ')}: files must be 20 MB or smaller',
      if (badType.isNotEmpty) 'type': '${badType.join(', ')}: use JPG, PNG, HEIC or PDF',
    };
  }

  Map<String, String> review(InspectionDraft d) => {if (!d.confirmed) 'confirmed': 'Confirm the findings before submitting'};

  /// The first step with errors before [upTo] (exclusive), or null.
  WizardStep? firstInvalidBefore(WizardStep upTo, InspectionDraft d) {
    for (final s in WizardStep.values.take(upTo.index)) {
      if (step(s, d).isNotEmpty) return s;
    }
    return null;
  }

  bool canSubmit(InspectionDraft d) => WizardStep.values.every((s) => step(s, d).isEmpty);
}
