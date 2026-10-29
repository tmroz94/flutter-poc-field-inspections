import 'package:material_ui/material_ui.dart';

import '../../l10n/l10n.dart';

/// Validation messages in the app's language (from the ARB files). Validators
/// take this so tests can check both languages without a widget tree.
class ValidationText {
  const ValidationText(this._l);

  factory ValidationText.forLocale(Locale locale) => locale.languageCode == 'pl' ? pl : en;

  static ValidationText of(BuildContext context) => ValidationText(AppLocalizations.of(context));

  static final en = ValidationText(lookupAppLocalizations(const Locale('en')));
  static final pl = ValidationText(lookupAppLocalizations(const Locale('pl')));

  final AppLocalizations _l;

  String get required => _l.valRequired;
  String get email => _l.valEmail;
  String minLength(int n) => _l.valMinLength(n);
  String maxLength(int n) => _l.valMaxLength(n);
  String get integer => _l.valInteger;
  String intRange(int min, int max) => _l.valIntRange(min, max);
  String get dateInPast => _l.valDateInPast;
  String get passwordsDiffer => _l.valPasswordsDiffer;
  String get passwordWeak => _l.valPasswordWeak;
  String get emailTaken => _l.valEmailTaken;
  String get mustAccept => _l.valMustAccept;
  String get unknownSite => _l.valUnknownSite;
  String get checklistIncomplete => _l.valChecklistIncomplete;

  // Wizard (P09–P13).
  String get siteTooShort => _l.valSiteTooShort;
  String get answerItem => _l.valAnswerItem;
  String get failureNeedsDetail => _l.valFailureNeedsDetail;
  String get photoForFailure => _l.valPhotoForFailure;
  String tooManyPhotos(int n) => _l.valTooManyPhotos(n);
  String filesTooBig(String names) => _l.valFilesTooBig(names);
  String badFileType(String names) => _l.valBadFileType(names);
  String get confirmFindings => _l.valConfirmFindings;
  String get checklistNotLoaded => _l.valChecklistNotLoaded;

  /// Maps a server field error code (HTTP 422) for [field] to a message. The
  /// limits are the field's own; the defaults are the API's (password,
  /// duration, notes).
  String server(String code, {String field = 'email', int minChars = 8, int maxChars = 500, int min = 15, int max = 480}) => switch (code) {
    'required' => required,
    'invalid' when field == 'email' => email,
    'tooShort' => minLength(minChars),
    'weak' => passwordWeak,
    'taken' => emailTaken,
    'range' => intRange(min, max),
    'past' => dateInPast,
    'tooLong' => maxLength(maxChars),
    'unknown' => unknownSite,
    'incomplete' => checklistIncomplete,
    _ => _l.valCheckField,
  };
}

typedef StringValidator = String? Function(String? value);

/// Composable form validators. Each returns null when valid, else a message.
abstract final class Validators {
  static final _emailPattern = RegExp(r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$");

  /// Runs [validators] in order and returns the first error.
  static StringValidator all(List<StringValidator> validators) => (value) {
    for (final v in validators) {
      final error = v(value);
      if (error != null) return error;
    }
    return null;
  };

  static StringValidator required(ValidationText t) =>
      (v) => (v == null || v.trim().isEmpty) ? t.required : null;

  /// Empty passes, so combine with [required] when the field is mandatory.
  static StringValidator email(ValidationText t) =>
      (v) => (v == null || v.trim().isEmpty || _emailPattern.hasMatch(v.trim())) ? null : t.email;

  // Lengths count characters as people see them (an emoji is one), like a
  // text field's counter and the mock API do; String.length counts UTF-16 units.
  static StringValidator minLength(ValidationText t, int n) =>
      (v) => (v == null || v.isEmpty || v.characters.length >= n) ? null : t.minLength(n);

  static StringValidator maxLength(ValidationText t, int n) =>
      (v) => (v == null || v.characters.length <= n) ? null : t.maxLength(n);

  static StringValidator intRange(ValidationText t, int min, int max) => (v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = int.tryParse(v.trim());
    if (n == null) return t.integer;
    return n < min || n > max ? t.intRange(min, max) : null;
  };

  /// 8+ characters with at least one letter and one digit.
  static StringValidator password(ValidationText t) => (v) {
    if (v == null || v.isEmpty) return null;
    return v.length >= 8 && v.contains(RegExp('[A-Za-z]')) && v.contains(RegExp(r'\d')) ? null : t.passwordWeak;
  };

  static StringValidator matches(ValidationText t, String Function() other) =>
      (v) => v == other() ? null : t.passwordsDiffer;

  static String? dateNotBefore(ValidationText t, DateTime? value, DateTime earliest) {
    if (value == null) return t.required;
    final day = DateTime(value.year, value.month, value.day);
    final min = DateTime(earliest.year, earliest.month, earliest.day);
    return day.isBefore(min) ? t.dateInPast : null;
  }

  /// 0–4: length 8+, length 12+, mixed case, digit, symbol (capped at 4).
  static int passwordStrength(String v) {
    if (v.isEmpty) return 0;
    var score = 0;
    if (v.length >= 8) score++;
    if (v.length >= 12) score++;
    if (v.contains(RegExp('[a-z]')) && v.contains(RegExp('[A-Z]'))) score++;
    if (v.contains(RegExp(r'\d'))) score++;
    if (v.contains(RegExp(r'[^A-Za-z0-9]'))) score++;
    return score.clamp(0, 4);
  }
}
