/// Whole calendar days from [from] to [to] (negative when [to] is earlier),
/// ignoring the time of day. Counted on UTC dates: local midnights are 23 or
/// 25 hours apart across a daylight-saving change, and `inDays` truncates.
int calendarDaysBetween(DateTime from, DateTime to) =>
    DateTime.utc(to.year, to.month, to.day).difference(DateTime.utc(from.year, from.month, from.day)).inDays;
