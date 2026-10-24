import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('pl')];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Field Inspections'**
  String get appName;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navInspections.
  ///
  /// In en, this message translates to:
  /// **'Inspections'**
  String get navInspections;

  /// No description provided for @navMap.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get navMap;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navPocResults.
  ///
  /// In en, this message translates to:
  /// **'PoC results'**
  String get navPocResults;

  /// No description provided for @newInspection.
  ///
  /// In en, this message translates to:
  /// **'New inspection'**
  String get newInspection;

  /// No description provided for @newShort.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newShort;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get seeAll;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @statusAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get statusAll;

  /// No description provided for @statusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get statusScheduled;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get statusInProgress;

  /// No description provided for @statusDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get statusDraft;

  /// No description provided for @statusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get statusOverdue;

  /// No description provided for @statusSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get statusSubmitted;

  /// No description provided for @todayAt.
  ///
  /// In en, this message translates to:
  /// **'Today {time}'**
  String todayAt(String time);

  /// No description provided for @yesterdayAt.
  ///
  /// In en, this message translates to:
  /// **'Yesterday {time}'**
  String yesterdayAt(String time);

  /// No description provided for @tomorrowAt.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow {time}'**
  String tomorrowAt(String time);

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning, {name}'**
  String greetingMorning(String name);

  /// No description provided for @greetingAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}'**
  String greetingAfternoon(String name);

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String greetingEvening(String name);

  /// No description provided for @homeToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get homeToday;

  /// No description provided for @homeDueThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Due this week'**
  String get homeDueThisWeek;

  /// No description provided for @homeNothingToday.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled for today.'**
  String get homeNothingToday;

  /// No description provided for @homeNothingWeek.
  ///
  /// In en, this message translates to:
  /// **'Nothing else due this week.'**
  String get homeNothingWeek;

  /// No description provided for @overdueByDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Overdue by 1 day} other{Overdue by {count} days}}'**
  String overdueByDays(int count);

  /// No description provided for @draftNotSynced.
  ///
  /// In en, this message translates to:
  /// **'Draft · not synced'**
  String get draftNotSynced;

  /// No description provided for @homeDraftsOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Drafts on this device'**
  String get homeDraftsOnDevice;

  /// No description provided for @homeWaitingToSend.
  ///
  /// In en, this message translates to:
  /// **'Waiting to send'**
  String get homeWaitingToSend;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String stepOf(int step, int total);

  /// No description provided for @savedAt.
  ///
  /// In en, this message translates to:
  /// **'saved {time}'**
  String savedAt(String time);

  /// No description provided for @offlineTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline'**
  String get offlineTitle;

  /// No description provided for @offlineConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect to load your inspections.'**
  String get offlineConnect;

  /// No description provided for @offlineReportsWaiting.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 report will sync when you\'re back online} other{{count} reports will sync when you\'re back online}}'**
  String offlineReportsWaiting(int count);

  /// No description provided for @accountAndSettings.
  ///
  /// In en, this message translates to:
  /// **'Account and settings'**
  String get accountAndSettings;

  /// No description provided for @notificationsUnread.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Notifications} =1{Notifications, 1 unread} other{Notifications, {count} unread}}'**
  String notificationsUnread(int count);

  /// No description provided for @inspectionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Inspections'**
  String get inspectionsTitle;

  /// No description provided for @searchSiteOrId.
  ///
  /// In en, this message translates to:
  /// **'Search site or ID'**
  String get searchSiteOrId;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @filterAndSort.
  ///
  /// In en, this message translates to:
  /// **'Filter and sort'**
  String get filterAndSort;

  /// No description provided for @filterAndSortActive.
  ///
  /// In en, this message translates to:
  /// **'Filter and sort, {count} active'**
  String filterAndSortActive(int count);

  /// No description provided for @refreshList.
  ///
  /// In en, this message translates to:
  /// **'Refresh list'**
  String get refreshList;

  /// No description provided for @noMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No inspections match'**
  String get noMatchTitle;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @loadErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load inspections'**
  String get loadErrorTitle;

  /// No description provided for @loadErrorOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline and nothing is saved on this device yet. Connect and try again.'**
  String get loadErrorOffline;

  /// No description provided for @loadErrorServer.
  ///
  /// In en, this message translates to:
  /// **'The server had a problem. Try again in a moment.'**
  String get loadErrorServer;

  /// No description provided for @loadingMore.
  ///
  /// In en, this message translates to:
  /// **'Loading more'**
  String get loadingMore;

  /// No description provided for @archived.
  ///
  /// In en, this message translates to:
  /// **'{id} archived'**
  String archived(String id);

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @showOnMap.
  ///
  /// In en, this message translates to:
  /// **'Show on map'**
  String get showOnMap;

  /// No description provided for @selectInspection.
  ///
  /// In en, this message translates to:
  /// **'Select an inspection'**
  String get selectInspection;

  /// No description provided for @selectInspectionHint.
  ///
  /// In en, this message translates to:
  /// **'Pick one from the list to see its details here.'**
  String get selectInspectionHint;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @showResults.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show 1 result} other{Show {count} results}}'**
  String showResults(int count);

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @due.
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get due;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @tabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get tabOverview;

  /// No description provided for @tabChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get tabChecklist;

  /// No description provided for @tabPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get tabPhotos;

  /// No description provided for @tabHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get tabHistory;

  /// No description provided for @directions.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get directions;

  /// No description provided for @callSite.
  ///
  /// In en, this message translates to:
  /// **'Call site'**
  String get callSite;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'Export PDF'**
  String get exportPdf;

  /// No description provided for @shareReport.
  ///
  /// In en, this message translates to:
  /// **'Share report'**
  String get shareReport;

  /// No description provided for @continueAction.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueAction;

  /// No description provided for @checkedOf.
  ///
  /// In en, this message translates to:
  /// **'{answered} of {total} checked'**
  String checkedOf(int answered, int total);

  /// No description provided for @failedCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 failed} other{{count} failed}}'**
  String failedCount(int count);

  /// No description provided for @inspectionNotFound.
  ///
  /// In en, this message translates to:
  /// **'Inspection not found'**
  String get inspectionNotFound;

  /// No description provided for @backToInspections.
  ///
  /// In en, this message translates to:
  /// **'Back to inspections'**
  String get backToInspections;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all as read'**
  String get markAllRead;

  /// No description provided for @remindersOff.
  ///
  /// In en, this message translates to:
  /// **'Reminders are off on this device'**
  String get remindersOff;

  /// No description provided for @remindersOffBody.
  ///
  /// In en, this message translates to:
  /// **'Turn them on to get an alert 30 minutes before each inspection.'**
  String get remindersOffBody;

  /// No description provided for @remindersOffWeb.
  ///
  /// In en, this message translates to:
  /// **'Browsers show notifications only while the app is open and can’t schedule them.'**
  String get remindersOffWeb;

  /// No description provided for @turnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get turnOn;

  /// No description provided for @notificationDismissed.
  ///
  /// In en, this message translates to:
  /// **'Notification dismissed'**
  String get notificationDismissed;

  /// No description provided for @earlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get earlier;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @appearanceAndLanguage.
  ///
  /// In en, this message translates to:
  /// **'Appearance and language'**
  String get appearanceAndLanguage;

  /// No description provided for @appearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme, contrast, text size, language'**
  String get appearanceSubtitle;

  /// No description provided for @inspectionReminders.
  ///
  /// In en, this message translates to:
  /// **'Inspection reminders'**
  String get inspectionReminders;

  /// No description provided for @remindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'30 minutes before start'**
  String get remindersSubtitle;

  /// No description provided for @remindersWebSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Not available in the browser'**
  String get remindersWebSubtitle;

  /// No description provided for @biometricUnlock.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock'**
  String get biometricUnlock;

  /// No description provided for @biometricSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lock after 5 minutes in the background'**
  String get biometricSubtitle;

  /// No description provided for @offlineData.
  ///
  /// In en, this message translates to:
  /// **'Offline data'**
  String get offlineData;

  /// No description provided for @offlineDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{drafts, plural, =1{1 draft} other{{drafts} drafts}} · {waiting} waiting to send'**
  String offlineDataSubtitle(int drafts, int waiting);

  /// No description provided for @pocTools.
  ///
  /// In en, this message translates to:
  /// **'PoC tools'**
  String get pocTools;

  /// No description provided for @resultsTracker.
  ///
  /// In en, this message translates to:
  /// **'Results tracker'**
  String get resultsTracker;

  /// No description provided for @resultsTrackerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pass, fail and notes per platform'**
  String get resultsTrackerSubtitle;

  /// No description provided for @adaptiveWidgets.
  ///
  /// In en, this message translates to:
  /// **'Adaptive widgets'**
  String get adaptiveWidgets;

  /// No description provided for @diagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// No description provided for @deepLinkTester.
  ///
  /// In en, this message translates to:
  /// **'Deep-link tester'**
  String get deepLinkTester;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @contrast.
  ///
  /// In en, this message translates to:
  /// **'Contrast'**
  String get contrast;

  /// No description provided for @contrastStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get contrastStandard;

  /// No description provided for @contrastMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get contrastMedium;

  /// No description provided for @contrastHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get contrastHigh;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @textSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Follows the system setting until you change it here'**
  String get textSizeHint;

  /// No description provided for @useSystemSize.
  ///
  /// In en, this message translates to:
  /// **'Use system size'**
  String get useSystemSize;

  /// No description provided for @reduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get reduceMotion;

  /// No description provided for @reduceMotionHint.
  ///
  /// In en, this message translates to:
  /// **'Fewer animations; page changes without movement'**
  String get reduceMotionHint;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get languageSystem;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @previewSite.
  ///
  /// In en, this message translates to:
  /// **'Warehouse A – loading dock'**
  String get previewSite;

  /// No description provided for @inspectionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 inspection} other{{count} inspections}}'**
  String inspectionsCount(int count);

  /// No description provided for @saveDraft.
  ///
  /// In en, this message translates to:
  /// **'Save draft'**
  String get saveDraft;

  /// No description provided for @editInspection.
  ///
  /// In en, this message translates to:
  /// **'Edit {id}'**
  String editInspection(String id);

  /// No description provided for @stepSite.
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get stepSite;

  /// No description provided for @stepDetails.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get stepDetails;

  /// No description provided for @stepChecklist.
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get stepChecklist;

  /// No description provided for @stepPhotos.
  ///
  /// In en, this message translates to:
  /// **'Photos and files'**
  String get stepPhotos;

  /// No description provided for @stepReview.
  ///
  /// In en, this message translates to:
  /// **'Review and submit'**
  String get stepReview;

  /// No description provided for @nextStep.
  ///
  /// In en, this message translates to:
  /// **'Next: {step}'**
  String nextStep(String step);

  /// No description provided for @draftSavedAt.
  ///
  /// In en, this message translates to:
  /// **'Draft saved on this device · {time}'**
  String draftSavedAt(String time);

  /// No description provided for @leaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Leave without submitting?'**
  String get leaveTitle;

  /// No description provided for @leaveBody.
  ///
  /// In en, this message translates to:
  /// **'Your answers are saved as a draft on this device. You can finish it later from Home.'**
  String get leaveBody;

  /// No description provided for @discardDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard draft'**
  String get discardDraft;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @submit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submit;

  /// No description provided for @confirmFindings.
  ///
  /// In en, this message translates to:
  /// **'I confirm the findings are accurate'**
  String get confirmFindings;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @keepSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Keep me signed in'**
  String get keepSignedIn;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @useDemoAccount.
  ///
  /// In en, this message translates to:
  /// **'Use demo account'**
  String get useDemoAccount;

  /// No description provided for @createAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get createAnAccount;

  /// No description provided for @resultsTitle.
  ///
  /// In en, this message translates to:
  /// **'PoC results'**
  String get resultsTitle;

  /// No description provided for @sampleData.
  ///
  /// In en, this message translates to:
  /// **'Sample data'**
  String get sampleData;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterFailing.
  ///
  /// In en, this message translates to:
  /// **'Failing'**
  String get filterFailing;

  /// No description provided for @filterNotTested.
  ///
  /// In en, this message translates to:
  /// **'Not tested'**
  String get filterNotTested;

  /// No description provided for @resultPass.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get resultPass;

  /// No description provided for @resultPartial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get resultPartial;

  /// No description provided for @resultFail.
  ///
  /// In en, this message translates to:
  /// **'Fail'**
  String get resultFail;

  /// No description provided for @resultNotTested.
  ///
  /// In en, this message translates to:
  /// **'Not tested'**
  String get resultNotTested;

  /// No description provided for @resultNa.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get resultNa;

  /// No description provided for @testedOf.
  ///
  /// In en, this message translates to:
  /// **'{tested} of {total} tested'**
  String testedOf(int tested, int total);

  /// No description provided for @exportResults.
  ///
  /// In en, this message translates to:
  /// **'Export results'**
  String get exportResults;

  /// No description provided for @importResults.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importResults;

  /// No description provided for @device.
  ///
  /// In en, this message translates to:
  /// **'Device and version'**
  String get device;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @platform.
  ///
  /// In en, this message translates to:
  /// **'Platform'**
  String get platform;

  /// No description provided for @dueAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get dueAny;

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dueToday;

  /// No description provided for @dueWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get dueWeek;

  /// No description provided for @dueCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get dueCustom;

  /// No description provided for @sortDueAsc.
  ///
  /// In en, this message translates to:
  /// **'Due date, soonest first'**
  String get sortDueAsc;

  /// No description provided for @sortDueDesc.
  ///
  /// In en, this message translates to:
  /// **'Due date, latest first'**
  String get sortDueDesc;

  /// No description provided for @sortSiteAsc.
  ///
  /// In en, this message translates to:
  /// **'Site name, A to Z'**
  String get sortSiteAsc;

  /// No description provided for @selectAtLeastOneStatus.
  ///
  /// In en, this message translates to:
  /// **'Select at least one status'**
  String get selectAtLeastOneStatus;

  /// No description provided for @completeStepFirst.
  ///
  /// In en, this message translates to:
  /// **'Complete “{step}” first'**
  String completeStepFirst(String step);

  /// No description provided for @showResultsPlain.
  ///
  /// In en, this message translates to:
  /// **'Show results'**
  String get showResultsPlain;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
