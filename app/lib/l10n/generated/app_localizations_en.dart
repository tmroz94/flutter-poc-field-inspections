// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Field Inspections';

  @override
  String get navHome => 'Home';

  @override
  String get navInspections => 'Inspections';

  @override
  String get navMap => 'Map';

  @override
  String get navSettings => 'Settings';

  @override
  String get navPocResults => 'PoC results';

  @override
  String get newInspection => 'New inspection';

  @override
  String get newShort => 'New';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get retry => 'Retry';

  @override
  String get tryAgain => 'Try again';

  @override
  String get close => 'Close';

  @override
  String get seeAll => 'See all';

  @override
  String get openSettings => 'Open settings';

  @override
  String get syncNow => 'Sync now';

  @override
  String get signOut => 'Sign out';

  @override
  String get undo => 'Undo';

  @override
  String get edit => 'Edit';

  @override
  String get statusAll => 'All';

  @override
  String get statusScheduled => 'Scheduled';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusDraft => 'Draft';

  @override
  String get statusOverdue => 'Overdue';

  @override
  String get statusSubmitted => 'Submitted';

  @override
  String todayAt(String time) {
    return 'Today $time';
  }

  @override
  String yesterdayAt(String time) {
    return 'Yesterday $time';
  }

  @override
  String tomorrowAt(String time) {
    return 'Tomorrow $time';
  }

  @override
  String greetingMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String greetingAfternoon(String name) {
    return 'Good afternoon, $name';
  }

  @override
  String greetingEvening(String name) {
    return 'Good evening, $name';
  }

  @override
  String get homeToday => 'Today';

  @override
  String get homeDueThisWeek => 'Due this week';

  @override
  String get homeNothingToday => 'Nothing scheduled for today.';

  @override
  String get homeNothingWeek => 'Nothing else due this week.';

  @override
  String overdueByDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Overdue by $count days', one: 'Overdue by 1 day');
    return '$_temp0';
  }

  @override
  String get draftNotSynced => 'Draft · not synced';

  @override
  String get homeDraftsOnDevice => 'Drafts on this device';

  @override
  String get homeWaitingToSend => 'Waiting to send';

  @override
  String stepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String savedAt(String time) {
    return 'saved $time';
  }

  @override
  String get offlineTitle => 'You\'re offline';

  @override
  String get offlineConnect => 'Connect to load your inspections.';

  @override
  String offlineReportsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reports will sync when you\'re back online',
      one: '1 report will sync when you\'re back online',
    );
    return '$_temp0';
  }

  @override
  String get accountAndSettings => 'Account and settings';

  @override
  String notificationsUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Notifications, $count unread',
      one: 'Notifications, 1 unread',
      zero: 'Notifications',
    );
    return '$_temp0';
  }

  @override
  String get inspectionsTitle => 'Inspections';

  @override
  String get searchSiteOrId => 'Search site or ID';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get filterAndSort => 'Filter and sort';

  @override
  String filterAndSortActive(int count) {
    return 'Filter and sort, $count active';
  }

  @override
  String get refreshList => 'Refresh list';

  @override
  String get noMatchTitle => 'No inspections match';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get loadErrorTitle => 'Couldn\'t load inspections';

  @override
  String get loadErrorOffline => 'You\'re offline and nothing is saved on this device yet. Connect and try again.';

  @override
  String get loadErrorServer => 'The server had a problem. Try again in a moment.';

  @override
  String get loadingMore => 'Loading more';

  @override
  String archived(String id) {
    return '$id archived';
  }

  @override
  String get archive => 'Archive';

  @override
  String get copyLink => 'Copy link';

  @override
  String get showOnMap => 'Show on map';

  @override
  String get selectInspection => 'Select an inspection';

  @override
  String get selectInspectionHint => 'Pick one from the list to see its details here.';

  @override
  String get loadMore => 'Load more';

  @override
  String showResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'Show $count results', one: 'Show 1 result');
    return '$_temp0';
  }

  @override
  String get reset => 'Reset';

  @override
  String get sortBy => 'Sort by';

  @override
  String get due => 'Due';

  @override
  String get status => 'Status';

  @override
  String get tabOverview => 'Overview';

  @override
  String get tabChecklist => 'Checklist';

  @override
  String get tabPhotos => 'Photos';

  @override
  String get tabHistory => 'History';

  @override
  String get directions => 'Directions';

  @override
  String get callSite => 'Call site';

  @override
  String get exportPdf => 'Export PDF';

  @override
  String get shareReport => 'Share report';

  @override
  String get continueAction => 'Continue';

  @override
  String checkedOf(int answered, int total) {
    return '$answered of $total checked';
  }

  @override
  String failedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count failed', one: '1 failed');
    return '$_temp0';
  }

  @override
  String get inspectionNotFound => 'Inspection not found';

  @override
  String get backToInspections => 'Back to inspections';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String get remindersOff => 'Reminders are off on this device';

  @override
  String get remindersOffBody => 'Turn them on to get an alert 30 minutes before each inspection.';

  @override
  String get remindersOffWeb => 'Browsers show notifications only while the app is open and can’t schedule them.';

  @override
  String get turnOn => 'Turn on';

  @override
  String get notificationDismissed => 'Notification dismissed';

  @override
  String get earlier => 'Earlier';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get appearanceAndLanguage => 'Appearance and language';

  @override
  String get appearanceSubtitle => 'Theme, contrast, text size, language';

  @override
  String get inspectionReminders => 'Inspection reminders';

  @override
  String get remindersSubtitle => '30 minutes before start';

  @override
  String get remindersWebSubtitle => 'Not available in the browser';

  @override
  String get remindersLinuxSubtitle => 'Not available on Linux';

  @override
  String get biometricUnlock => 'Biometric unlock';

  @override
  String get biometricSubtitle => 'Lock after 5 minutes in the background';

  @override
  String get offlineData => 'Offline data';

  @override
  String offlineDataSubtitle(int drafts, int waiting) {
    String _temp0 = intl.Intl.pluralLogic(drafts, locale: localeName, other: '$drafts drafts', one: '1 draft');
    return '$_temp0 · $waiting waiting to send';
  }

  @override
  String get pocTools => 'PoC tools';

  @override
  String get resultsTracker => 'Results tracker';

  @override
  String get resultsTrackerSubtitle => 'Pass, fail and notes per platform';

  @override
  String get adaptiveWidgets => 'Adaptive widgets';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get deepLinkTester => 'Deep-link tester';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get contrast => 'Contrast';

  @override
  String get contrastStandard => 'Standard';

  @override
  String get contrastMedium => 'Medium';

  @override
  String get contrastHigh => 'High';

  @override
  String get textSize => 'Text size';

  @override
  String get textSizeHint => 'Follows the system setting until you change it here';

  @override
  String get useSystemSize => 'Use system size';

  @override
  String get reduceMotion => 'Reduce motion';

  @override
  String get reduceMotionHint => 'Fewer animations; page changes without movement';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Device language';

  @override
  String get preview => 'Preview';

  @override
  String get previewSite => 'Warehouse A – loading dock';

  @override
  String inspectionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count inspections', one: '1 inspection');
    return '$_temp0';
  }

  @override
  String get saveDraft => 'Save draft';

  @override
  String editInspection(String id) {
    return 'Edit $id';
  }

  @override
  String get stepSite => 'Site';

  @override
  String get stepDetails => 'Details';

  @override
  String get stepChecklist => 'Checklist';

  @override
  String get stepPhotos => 'Photos and files';

  @override
  String get stepReview => 'Review and submit';

  @override
  String nextStep(String step) {
    return 'Next: $step';
  }

  @override
  String draftSavedAt(String time) {
    return 'Draft saved on this device · $time';
  }

  @override
  String get leaveTitle => 'Leave without submitting?';

  @override
  String get leaveBody => 'Your answers are saved as a draft on this device. You can finish it later from Home.';

  @override
  String get discardDraft => 'Discard draft';

  @override
  String get stay => 'Stay';

  @override
  String get leave => 'Leave';

  @override
  String get submit => 'Submit';

  @override
  String get confirmFindings => 'I confirm the findings are accurate';

  @override
  String get signIn => 'Sign in';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get keepSignedIn => 'Keep me signed in';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get useDemoAccount => 'Use demo account';

  @override
  String get createAnAccount => 'Create an account';

  @override
  String get resultsTitle => 'PoC results';

  @override
  String get sampleData => 'Sample data';

  @override
  String get filterAll => 'All';

  @override
  String get filterFailing => 'Failing';

  @override
  String get filterNotTested => 'Not tested';

  @override
  String get resultPass => 'Pass';

  @override
  String get resultPartial => 'Partial';

  @override
  String get resultFail => 'Fail';

  @override
  String get resultNotTested => 'Not tested';

  @override
  String get resultNa => 'N/A';

  @override
  String testedOf(int tested, int total) {
    return '$tested of $total tested';
  }

  @override
  String get exportResults => 'Export results';

  @override
  String get importResults => 'Import';

  @override
  String get device => 'Device and version';

  @override
  String get notes => 'Notes';

  @override
  String get platform => 'Platform';

  @override
  String get dueAny => 'Any';

  @override
  String get dueToday => 'Today';

  @override
  String get dueWeek => 'Week';

  @override
  String get dueCustom => 'Custom';

  @override
  String get sortDueAsc => 'Due date, soonest first';

  @override
  String get sortDueDesc => 'Due date, latest first';

  @override
  String get sortSiteAsc => 'Site name, A to Z';

  @override
  String get selectAtLeastOneStatus => 'Select at least one status';

  @override
  String completeStepFirst(String step) {
    return 'Complete “$step” first';
  }

  @override
  String get showResultsPlain => 'Show results';
}
