import 'package:field_inspections/core/validation/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = ValidationText.en;
  final pl = ValidationText.pl;

  group('required', () {
    test('rejects null, empty and blank', () {
      final v = Validators.required(en);
      expect(v(null), en.required);
      expect(v(''), en.required);
      expect(v('   '), en.required);
      expect(v('x'), isNull);
    });
    test('speaks Polish', () => expect(Validators.required(pl)(''), 'Pole wymagane'));
  });

  group('email', () {
    final v = Validators.email(en);
    test('accepts common addresses, ignores surrounding spaces', () {
      for (final ok in ['anna.nowak@example.com', 'a+b@sub.example.pl', ' x@y.io ']) {
        expect(v(ok), isNull, reason: ok);
      }
    });
    test('rejects malformed addresses', () {
      for (final bad in ['anna', 'anna@', '@example.com', 'a@b', 'a b@c.de', 'a@b..c']) {
        expect(v(bad), en.email, reason: bad);
      }
    });
    test('empty passes so it composes with required', () => expect(v(''), isNull));
  });

  test('min and max length', () {
    expect(Validators.minLength(en, 8)('abc12'), 'Use 8 or more characters');
    expect(Validators.minLength(en, 8)('abcd1234'), isNull);
    expect(Validators.maxLength(en, 5)('123456'), 'Use 5 characters or fewer');
    expect(Validators.maxLength(pl, 500)('a' * 501), 'Użyj najwyżej 500 znaków');
  });

  group('intRange (wizard duration 15–480)', () {
    final v = Validators.intRange(en, 15, 480);
    test('bounds are inclusive', () {
      expect(v('15'), isNull);
      expect(v('480'), isNull);
      expect(v('14'), 'Enter a number from 15 to 480');
      expect(v('481'), 'Enter a number from 15 to 480');
      expect(v('5'), 'Enter a number from 15 to 480');
    });
    test('non-integers get their own message', () {
      expect(v('1.5'), en.integer);
      expect(v('abc'), en.integer);
    });
  });

  test('password needs 8+ with a letter and a digit', () {
    final v = Validators.password(en);
    expect(v('abcdefgh'), en.passwordWeak);
    expect(v('12345678'), en.passwordWeak);
    expect(v('abc1'), en.passwordWeak);
    expect(v('inspect123'), isNull);
  });

  test('matches compares with the other field at validation time', () {
    var other = 'secret12';
    final v = Validators.matches(en, () => other);
    expect(v('secret12'), isNull);
    other = 'changed1';
    expect(v('secret12'), en.passwordsDiffer);
  });

  test('all returns the first error in order', () {
    final v = Validators.all([Validators.required(en), Validators.email(en)]);
    expect(v(''), en.required);
    expect(v('nope'), en.email);
    expect(v('a@b.co'), isNull);
  });

  test('dateNotBefore compares calendar days', () {
    final today = DateTime(2026, 10, 24, 15);
    expect(Validators.dateNotBefore(en, DateTime(2026, 10, 24, 8), today), isNull);
    expect(Validators.dateNotBefore(en, DateTime(2026, 10, 23, 23), today), en.dateInPast);
    expect(Validators.dateNotBefore(en, null, today), en.required);
  });

  test('password strength 0–4', () {
    expect(Validators.passwordStrength(''), 0);
    expect(Validators.passwordStrength('abcdefgh'), 1);
    expect(Validators.passwordStrength('abcdefg1'), 2);
    expect(Validators.passwordStrength('Abcdefghijk1!'), 4);
  });

  test('server codes map to messages', () {
    expect(en.server('taken'), en.emailTaken);
    expect(en.server('range'), 'Enter a number from 15 to 480');
    expect(pl.server('whatever'), 'Sprawdź to pole');
  });
}
