import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/time/calendar.dart';
import '../data/models/inspection.dart';
import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension InspectionStatusL10n on InspectionStatus {
  String localized(AppLocalizations l) => switch (this) {
    InspectionStatus.scheduled => l.statusScheduled,
    InspectionStatus.inProgress => l.statusInProgress,
    InspectionStatus.draft => l.statusDraft,
    InspectionStatus.overdue => l.statusOverdue,
    InspectionStatus.submitted => l.statusSubmitted,
  };
}

/// "52.2401° N, 21.0301° E", with the language's decimal separator.
String coordinatesText(BuildContext context, double lat, double lng) {
  final f = NumberFormat('0.0000', Localizations.localeOf(context).toLanguageTag());
  return '${f.format(lat.abs())}° ${lat < 0 ? 'S' : 'N'}, ${f.format(lng.abs())}° ${lng < 0 ? 'W' : 'E'}';
}

/// "1.2 MB", with the language's decimal separator.
String megabytesText(BuildContext context, int bytes) =>
    '${NumberFormat('0.0', Localizations.localeOf(context).toLanguageTag()).format(bytes / 1e6)} MB';

/// "Today 09:30", "Yesterday 14:00", "Wed 11:00" (within a week), else "14 Oct"
/// ("14 Oct 10:00" with [withTime]), in the current language.
String localizedWhen(BuildContext context, DateTime at, DateTime now, {bool withTime = false}) {
  final l = context.l10n;
  final locale = Localizations.localeOf(context).toLanguageTag();
  final diff = calendarDaysBetween(now, at);
  final time = DateFormat.Hm(locale).format(at);
  return switch (diff) {
    0 => l.todayAt(time),
    -1 => l.yesterdayAt(time),
    1 => l.tomorrowAt(time),
    > 1 && < 7 => '${DateFormat.E(locale).format(at)} $time',
    _ => withTime ? '${DateFormat.MMMd(locale).format(at)} $time' : DateFormat.MMMd(locale).format(at),
  };
}
