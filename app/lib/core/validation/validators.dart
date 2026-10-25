import 'package:material_ui/material_ui.dart';

/// Validation messages in English and Polish. Validators take this so tests
/// can check both languages, and the M4 ARB files can replace it later.
class ValidationText {
  const ValidationText._(this._pl);

  factory ValidationText.forLocale(Locale locale) => locale.languageCode == 'pl' ? pl : en;

  static ValidationText of(BuildContext context) => ValidationText.forLocale(Localizations.localeOf(context));

  static const en = ValidationText._(false);
  static const pl = ValidationText._(true);

  final bool _pl;

  String _t(String en, String pl) => _pl ? pl : en;

  String get required => _t('Required', 'Pole wymagane');
  String get email => _t('Enter a valid email, like name@example.com', 'Podaj poprawny e-mail, np. imie@example.com');
  String minLength(int n) => _t('Use $n or more characters', 'Użyj co najmniej $n znaków');
  String maxLength(int n) => _t('Use $n characters or fewer', 'Użyj najwyżej $n znaków');
  String get integer => _t('Enter a whole number', 'Podaj liczbę całkowitą');
  String intRange(int min, int max) => _t('Enter a number from $min to $max', 'Podaj liczbę od $min do $max');
  String get dateInPast => _t('Pick today or a later date', 'Wybierz dzisiejszą lub późniejszą datę');
  String get passwordsDiffer => _t("Passwords don't match", 'Hasła się różnią');
  String get passwordWeak => _t('Use 8+ characters with a letter and a digit', 'Użyj 8+ znaków, w tym litery i cyfry');
  String get emailTaken => _t('An account with this email already exists', 'Konto z tym adresem już istnieje');
  String get mustAccept => _t('Accept the terms to continue', 'Zaakceptuj warunki, aby kontynuować');
  String get unknownSite => _t('Pick a site from the list', 'Wybierz obiekt z listy');
  String get checklistIncomplete => _t('Answer every checklist item', 'Odpowiedz na każdy punkt listy kontrolnej');

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
    _ => _t('Check this field', 'Sprawdź to pole'),
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

  static StringValidator minLength(ValidationText t, int n) =>
      (v) => (v == null || v.isEmpty || v.length >= n) ? null : t.minLength(n);

  static StringValidator maxLength(ValidationText t, int n) =>
      (v) => (v == null || v.length <= n) ? null : t.maxLength(n);

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
