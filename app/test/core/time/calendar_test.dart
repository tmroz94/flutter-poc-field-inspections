import 'package:field_inspections/core/time/calendar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // In Europe/Warsaw (and the rest of the EU) the clocks go forward on
  // 29 Mar 2026: local midnight 29 → 30 Mar is only 23 hours, which
  // `Duration.inDays` used to round down to 0 ("Today" for yesterday).
  test('days across the spring daylight-saving change', () {
    expect(calendarDaysBetween(DateTime(2026, 3, 30, 12), DateTime(2026, 3, 29, 9, 30)), -1);
    expect(calendarDaysBetween(DateTime(2026, 3, 29, 12), DateTime(2026, 3, 30, 9, 30)), 1);
    expect(calendarDaysBetween(DateTime(2026, 3, 27, 8), DateTime(2026, 3, 30, 23)), 3);
  });

  test('days across the autumn change', () {
    expect(calendarDaysBetween(DateTime(2026, 10, 26), DateTime(2026, 10, 25, 23, 59)), -1);
    expect(calendarDaysBetween(DateTime(2026, 10, 24, 23), DateTime(2026, 10, 25, 1)), 1);
  });

  test('time of day does not matter', () {
    expect(calendarDaysBetween(DateTime(2026, 10, 24, 23, 59), DateTime(2026, 10, 24)), 0);
    expect(calendarDaysBetween(DateTime(2026, 12, 31, 23), DateTime(2027, 1, 1, 0, 1)), 1);
  });
}
