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

  /// No description provided for @outboxQueued.
  ///
  /// In en, this message translates to:
  /// **'Queued {time} · sends when online'**
  String outboxQueued(String time);

  /// No description provided for @outboxRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected by the server: {reason}'**
  String outboxRejected(String reason);

  /// No description provided for @outboxOptions.
  ///
  /// In en, this message translates to:
  /// **'Report options'**
  String get outboxOptions;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @outboxEditBusy.
  ///
  /// In en, this message translates to:
  /// **'Finish or discard the open draft for this inspection first.'**
  String get outboxEditBusy;

  /// No description provided for @outboxDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this report?'**
  String get outboxDeleteTitle;

  /// No description provided for @outboxDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'It never reached the server, so it can\'t be recovered.'**
  String get outboxDeleteBody;

  /// No description provided for @signOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get signOutTitle;

  /// No description provided for @signOutLocalData.
  ///
  /// In en, this message translates to:
  /// **'These are saved only on this device and will be deleted:'**
  String get signOutLocalData;

  /// No description provided for @signOutUnsent.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 report not sent yet} other{{count} reports not sent yet}}'**
  String signOutUnsent(int count);

  /// No description provided for @signOutDrafts.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 draft} other{{count} drafts}}'**
  String signOutDrafts(int count);

  /// No description provided for @signOutConfirm.
  ///
  /// In en, this message translates to:
  /// **'Sign out and delete'**
  String get signOutConfirm;

  /// No description provided for @remindersBlocked.
  ///
  /// In en, this message translates to:
  /// **'Notifications are blocked for this app. Allow them in the system settings.'**
  String get remindersBlocked;

  /// No description provided for @remindersMobileOnly.
  ///
  /// In en, this message translates to:
  /// **'Browsers can’t schedule notifications, so reminders are mobile-only.'**
  String get remindersMobileOnly;

  /// No description provided for @remindersScheduleFailed.
  ///
  /// In en, this message translates to:
  /// **'Reminders are on, but they couldn\'t be scheduled yet. They\'ll be set up when the inspections load.'**
  String get remindersScheduleFailed;

  /// No description provided for @biometricNotSetUp.
  ///
  /// In en, this message translates to:
  /// **'Set up a fingerprint, face or screen lock on this device first.'**
  String get biometricNotSetUp;

  /// No description provided for @reminderTitle.
  ///
  /// In en, this message translates to:
  /// **'{site} at {time}'**
  String reminderTitle(String site, String time);

  /// No description provided for @reminderBody.
  ///
  /// In en, this message translates to:
  /// **'Starts in 30 minutes'**
  String get reminderBody;

  /// No description provided for @reminderChannel.
  ///
  /// In en, this message translates to:
  /// **'Inspection reminders'**
  String get reminderChannel;

  /// No description provided for @reminderChannelDescription.
  ///
  /// In en, this message translates to:
  /// **'Alerts before inspections start'**
  String get reminderChannelDescription;

  /// No description provided for @biometricReason.
  ///
  /// In en, this message translates to:
  /// **'Unlock Field Inspections'**
  String get biometricReason;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @passwordHelperSignIn.
  ///
  /// In en, this message translates to:
  /// **'Use 8 or more characters'**
  String get passwordHelperSignIn;

  /// No description provided for @capsLockOn.
  ///
  /// In en, this message translates to:
  /// **'Caps Lock is on'**
  String get capsLockOn;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @backendMockServer.
  ///
  /// In en, this message translates to:
  /// **'Connected to the mock server'**
  String get backendMockServer;

  /// No description provided for @backendOfflineDemo.
  ///
  /// In en, this message translates to:
  /// **'Offline demo data (mock server not reachable)'**
  String get backendOfflineDemo;

  /// No description provided for @authErrorCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect.'**
  String get authErrorCredentials;

  /// No description provided for @authErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Check your connection and try again.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorValidation.
  ///
  /// In en, this message translates to:
  /// **'Check the highlighted fields.'**
  String get authErrorValidation;

  /// No description provided for @authErrorUnknown.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get authErrorUnknown;

  /// No description provided for @createAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAccountTitle;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @strengthTooWeak.
  ///
  /// In en, this message translates to:
  /// **'Too weak'**
  String get strengthTooWeak;

  /// No description provided for @strengthWeak.
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get strengthWeak;

  /// No description provided for @strengthFair.
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get strengthFair;

  /// No description provided for @strengthGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get strengthGood;

  /// No description provided for @strengthStrong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get strengthStrong;

  /// No description provided for @passwordStrength.
  ///
  /// In en, this message translates to:
  /// **'Password strength: {strength}'**
  String passwordStrength(String strength);

  /// No description provided for @passwordHelperSignUp.
  ///
  /// In en, this message translates to:
  /// **'8+ characters with a letter and a digit'**
  String get passwordHelperSignUp;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// No description provided for @acceptTerms.
  ///
  /// In en, this message translates to:
  /// **'I accept the terms of use'**
  String get acceptTerms;

  /// No description provided for @haveAccount.
  ///
  /// In en, this message translates to:
  /// **'I already have an account'**
  String get haveAccount;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordTitle;

  /// No description provided for @resetIntro.
  ///
  /// In en, this message translates to:
  /// **'Enter your account\'s email and we\'ll send a reset link.'**
  String get resetIntro;

  /// No description provided for @resetSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for {email}, we sent a link to reset the password. Check your inbox.'**
  String resetSent(String email);

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @unlockWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome back, {name}'**
  String unlockWelcome(String name);

  /// No description provided for @unlockTimedOut.
  ///
  /// In en, this message translates to:
  /// **'The app locked after 5 minutes in the background.'**
  String get unlockTimedOut;

  /// No description provided for @unlockOnStart.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock is on for this app.'**
  String get unlockOnStart;

  /// No description provided for @unlockButton.
  ///
  /// In en, this message translates to:
  /// **'Unlock with biometrics'**
  String get unlockButton;

  /// No description provided for @unlockPrompt.
  ///
  /// In en, this message translates to:
  /// **'Use your fingerprint or face to unlock'**
  String get unlockPrompt;

  /// No description provided for @unlockFailed.
  ///
  /// In en, this message translates to:
  /// **'Not recognised. Try again or use your password.'**
  String get unlockFailed;

  /// No description provided for @usePasswordInstead.
  ///
  /// In en, this message translates to:
  /// **'Use password instead'**
  String get usePasswordInstead;

  /// No description provided for @authTagline.
  ///
  /// In en, this message translates to:
  /// **'Plan, run and report site inspections.'**
  String get authTagline;

  /// No description provided for @authTaglineSub.
  ///
  /// In en, this message translates to:
  /// **'Same account and data on iOS, Android and the web.'**
  String get authTaglineSub;

  /// No description provided for @pocBuild.
  ///
  /// In en, this message translates to:
  /// **'v{version} · PoC build'**
  String pocBuild(String version);

  /// No description provided for @fieldsNeedAttention.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 field needs attention} other{{count} fields need attention}}'**
  String fieldsNeedAttention(int count);

  /// No description provided for @fieldNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'1 field needs attention: {error}'**
  String fieldNeedsAttention(String error);

  /// No description provided for @inProgressLabel.
  ///
  /// In en, this message translates to:
  /// **'{label}, in progress'**
  String inProgressLabel(String label);

  /// No description provided for @valRequired.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get valRequired;

  /// No description provided for @valEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email, like name@example.com'**
  String get valEmail;

  /// No description provided for @valMinLength.
  ///
  /// In en, this message translates to:
  /// **'Use {n} or more characters'**
  String valMinLength(int n);

  /// No description provided for @valMaxLength.
  ///
  /// In en, this message translates to:
  /// **'Use {n} characters or fewer'**
  String valMaxLength(int n);

  /// No description provided for @valInteger.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number'**
  String get valInteger;

  /// No description provided for @valIntRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a number from {min} to {max}'**
  String valIntRange(int min, int max);

  /// No description provided for @valDateInPast.
  ///
  /// In en, this message translates to:
  /// **'Pick today or a later date'**
  String get valDateInPast;

  /// No description provided for @valPasswordsDiffer.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get valPasswordsDiffer;

  /// No description provided for @valPasswordWeak.
  ///
  /// In en, this message translates to:
  /// **'Use 8+ characters with a letter and a digit'**
  String get valPasswordWeak;

  /// No description provided for @valEmailTaken.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists'**
  String get valEmailTaken;

  /// No description provided for @valMustAccept.
  ///
  /// In en, this message translates to:
  /// **'Accept the terms to continue'**
  String get valMustAccept;

  /// No description provided for @valUnknownSite.
  ///
  /// In en, this message translates to:
  /// **'Pick a site from the list'**
  String get valUnknownSite;

  /// No description provided for @valChecklistIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Answer every checklist item'**
  String get valChecklistIncomplete;

  /// No description provided for @valCheckField.
  ///
  /// In en, this message translates to:
  /// **'Check this field'**
  String get valCheckField;

  /// No description provided for @valSiteTooShort.
  ///
  /// In en, this message translates to:
  /// **'Pick a site from the list or add a new one (3+ characters)'**
  String get valSiteTooShort;

  /// No description provided for @valAnswerItem.
  ///
  /// In en, this message translates to:
  /// **'Answer this item'**
  String get valAnswerItem;

  /// No description provided for @valFailureNeedsDetail.
  ///
  /// In en, this message translates to:
  /// **'Add a note or a photo for this failure'**
  String get valFailureNeedsDetail;

  /// No description provided for @valPhotoForFailure.
  ///
  /// In en, this message translates to:
  /// **'Add at least one photo of the failed items'**
  String get valPhotoForFailure;

  /// No description provided for @valTooManyPhotos.
  ///
  /// In en, this message translates to:
  /// **'Use {n} photos or fewer'**
  String valTooManyPhotos(int n);

  /// No description provided for @valFilesTooBig.
  ///
  /// In en, this message translates to:
  /// **'{names}: files must be 20 MB or smaller'**
  String valFilesTooBig(String names);

  /// No description provided for @valBadFileType.
  ///
  /// In en, this message translates to:
  /// **'{names}: use JPG, PNG, HEIC or PDF'**
  String valBadFileType(String names);

  /// No description provided for @valConfirmFindings.
  ///
  /// In en, this message translates to:
  /// **'Confirm the findings before submitting'**
  String get valConfirmFindings;

  /// No description provided for @valChecklistNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'The checklist hasn\'t loaded yet'**
  String get valChecklistNotLoaded;

  /// No description provided for @wizardDraftSaved.
  ///
  /// In en, this message translates to:
  /// **'Draft saved on this device'**
  String get wizardDraftSaved;

  /// No description provided for @wizardProgress.
  ///
  /// In en, this message translates to:
  /// **'Wizard progress'**
  String get wizardProgress;

  /// No description provided for @wizardSteps.
  ///
  /// In en, this message translates to:
  /// **'Wizard steps'**
  String get wizardSteps;

  /// No description provided for @wizardHintSite.
  ///
  /// In en, this message translates to:
  /// **'Choose a site'**
  String get wizardHintSite;

  /// No description provided for @wizardHintDetails.
  ///
  /// In en, this message translates to:
  /// **'Type, date and time'**
  String get wizardHintDetails;

  /// No description provided for @wizardHintChecklist.
  ///
  /// In en, this message translates to:
  /// **'{answered} of {total} answered'**
  String wizardHintChecklist(int answered, int total);

  /// No description provided for @wizardHintPhotos.
  ///
  /// In en, this message translates to:
  /// **'{photos} photos · {files} files'**
  String wizardHintPhotos(int photos, int files);

  /// No description provided for @wizardHintReview.
  ///
  /// In en, this message translates to:
  /// **'Check and send'**
  String get wizardHintReview;

  /// No description provided for @stepStateDone.
  ///
  /// In en, this message translates to:
  /// **'{step}, done'**
  String stepStateDone(String step);

  /// No description provided for @stepStateAttention.
  ///
  /// In en, this message translates to:
  /// **'{step}, needs attention'**
  String stepStateAttention(String step);

  /// No description provided for @stepStateCurrent.
  ///
  /// In en, this message translates to:
  /// **'{step}, current step'**
  String stepStateCurrent(String step);

  /// No description provided for @stepStateUpcoming.
  ///
  /// In en, this message translates to:
  /// **'{step}, not started'**
  String stepStateUpcoming(String step);

  /// No description provided for @wizardLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this inspection to edit it.'**
  String get wizardLoadFailed;

  /// No description provided for @wizardRecoveredPhoto.
  ///
  /// In en, this message translates to:
  /// **'A photo taken before the app closed was added.'**
  String get wizardRecoveredPhoto;

  /// No description provided for @siteLabel.
  ///
  /// In en, this message translates to:
  /// **'Site'**
  String get siteLabel;

  /// No description provided for @siteHelper.
  ///
  /// In en, this message translates to:
  /// **'Search by name or address'**
  String get siteHelper;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @newSite.
  ///
  /// In en, this message translates to:
  /// **'New site: {name}'**
  String newSite(String name);

  /// No description provided for @newSiteHint.
  ///
  /// In en, this message translates to:
  /// **'It will be created when you submit'**
  String get newSiteHint;

  /// No description provided for @addNewSite.
  ///
  /// In en, this message translates to:
  /// **'Add “{name}” as a new site'**
  String addNewSite(String name);

  /// No description provided for @yourLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location'**
  String get yourLocation;

  /// No description provided for @locationServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location is turned off on this device.'**
  String get locationServiceOff;

  /// No description provided for @locationDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was not given. The check is optional.'**
  String get locationDenied;

  /// No description provided for @locationBlocked.
  ///
  /// In en, this message translates to:
  /// **'Location is blocked for this app.'**
  String get locationBlocked;

  /// No description provided for @locationUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Location is not available here.'**
  String get locationUnsupported;

  /// No description provided for @locationError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get a position. Try again outside or near a window.'**
  String get locationError;

  /// No description provided for @locationNotChecked.
  ///
  /// In en, this message translates to:
  /// **'Not checked yet'**
  String get locationNotChecked;

  /// No description provided for @locationOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional: confirms you are on site.'**
  String get locationOptional;

  /// No description provided for @locationAccuracy.
  ///
  /// In en, this message translates to:
  /// **'Accuracy ±{meters} m'**
  String locationAccuracy(String meters);

  /// No description provided for @locationFromSite.
  ///
  /// In en, this message translates to:
  /// **'{distance} from the site'**
  String locationFromSite(String distance);

  /// No description provided for @locationFar.
  ///
  /// In en, this message translates to:
  /// **'You seem to be more than 200 m from the site address.'**
  String get locationFar;

  /// No description provided for @checkLocation.
  ///
  /// In en, this message translates to:
  /// **'Check location'**
  String get checkLocation;

  /// No description provided for @updateLocation.
  ///
  /// In en, this message translates to:
  /// **'Update location'**
  String get updateLocation;

  /// No description provided for @inspectionType.
  ///
  /// In en, this message translates to:
  /// **'Inspection type'**
  String get inspectionType;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @openCalendar.
  ///
  /// In en, this message translates to:
  /// **'Open calendar'**
  String get openCalendar;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start time'**
  String get startTime;

  /// No description provided for @openTimePicker.
  ///
  /// In en, this message translates to:
  /// **'Open time picker'**
  String get openTimePicker;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get priorityNormal;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'Estimated duration (minutes)'**
  String get durationLabel;

  /// No description provided for @durationHelper.
  ///
  /// In en, this message translates to:
  /// **'From 15 to 480'**
  String get durationHelper;

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes for the site manager'**
  String get notesLabel;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @checklistProgress.
  ///
  /// In en, this message translates to:
  /// **'{type} · {answered} of {total} answered'**
  String checklistProgress(String type, int answered, int total);

  /// No description provided for @itemsNeedAttention.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item needs attention} other{{count} items need attention}}'**
  String itemsNeedAttention(int count);

  /// No description provided for @jumpToFirst.
  ///
  /// In en, this message translates to:
  /// **'Jump to the first one'**
  String get jumpToFirst;

  /// No description provided for @checklistLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the checklist.'**
  String get checklistLoadFailed;

  /// No description provided for @answerPass.
  ///
  /// In en, this message translates to:
  /// **'Pass'**
  String get answerPass;

  /// No description provided for @answerFail.
  ///
  /// In en, this message translates to:
  /// **'Fail'**
  String get answerFail;

  /// No description provided for @answerNa.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get answerNa;

  /// No description provided for @severity.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get severity;

  /// No description provided for @severityValue.
  ///
  /// In en, this message translates to:
  /// **'{level} · {label}'**
  String severityValue(int level, String label);

  /// No description provided for @severityMinor.
  ///
  /// In en, this message translates to:
  /// **'Minor'**
  String get severityMinor;

  /// No description provided for @severityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get severityLow;

  /// No description provided for @severityMajor.
  ///
  /// In en, this message translates to:
  /// **'Major'**
  String get severityMajor;

  /// No description provided for @severityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get severityHigh;

  /// No description provided for @severityCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get severityCritical;

  /// No description provided for @severitySemantics.
  ///
  /// In en, this message translates to:
  /// **'Severity {value}'**
  String severitySemantics(String value);

  /// No description provided for @followUpVisit.
  ///
  /// In en, this message translates to:
  /// **'Requires follow-up visit'**
  String get followUpVisit;

  /// No description provided for @whatIsWrong.
  ///
  /// In en, this message translates to:
  /// **'What is wrong?'**
  String get whatIsWrong;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @addPhotoCount.
  ///
  /// In en, this message translates to:
  /// **'Add photo ({count})'**
  String addPhotoCount(int count);

  /// No description provided for @dictateNote.
  ///
  /// In en, this message translates to:
  /// **'Dictate note (not in the PoC)'**
  String get dictateNote;

  /// No description provided for @photoTypeHint.
  ///
  /// In en, this message translates to:
  /// **'Use JPG, PNG or HEIC up to 20 MB.'**
  String get photoTypeHint;

  /// No description provided for @fileRejected.
  ///
  /// In en, this message translates to:
  /// **'{name}: use JPG, PNG, HEIC or PDF up to 20 MB.'**
  String fileRejected(String name);

  /// No description provided for @cameraOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the camera.'**
  String get cameraOpenFailed;

  /// No description provided for @galleryOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the gallery.'**
  String get galleryOpenFailed;

  /// No description provided for @photoN.
  ///
  /// In en, this message translates to:
  /// **'Photo {n}'**
  String photoN(int n);

  /// No description provided for @photoNForFailure.
  ///
  /// In en, this message translates to:
  /// **'Photo {n}, for a failed item'**
  String photoNForFailure(int n);

  /// No description provided for @removePhotoN.
  ///
  /// In en, this message translates to:
  /// **'Remove photo {n}'**
  String removePhotoN(int n);

  /// No description provided for @useCamera.
  ///
  /// In en, this message translates to:
  /// **'Use camera'**
  String get useCamera;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @dropFiles.
  ///
  /// In en, this message translates to:
  /// **'Drop files to upload'**
  String get dropFiles;

  /// No description provided for @dragOrPaste.
  ///
  /// In en, this message translates to:
  /// **'Drag files here, or paste an image'**
  String get dragOrPaste;

  /// No description provided for @fileTypesHint.
  ///
  /// In en, this message translates to:
  /// **'JPG, PNG, HEIC or PDF, up to 20 MB each.'**
  String get fileTypesHint;

  /// No description provided for @photosIntro.
  ///
  /// In en, this message translates to:
  /// **'Add photos of the findings and any documents the site gave you.'**
  String get photosIntro;

  /// No description provided for @cameraOff.
  ///
  /// In en, this message translates to:
  /// **'Camera access is off. You can still choose photos from the gallery.'**
  String get cameraOff;

  /// No description provided for @photosCount.
  ///
  /// In en, this message translates to:
  /// **'Photos · {count}'**
  String photosCount(int count);

  /// No description provided for @filesCount.
  ///
  /// In en, this message translates to:
  /// **'Files · {count}'**
  String filesCount(int count);

  /// No description provided for @attachFile.
  ///
  /// In en, this message translates to:
  /// **'Attach file'**
  String get attachFile;

  /// No description provided for @removeFile.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String removeFile(String name);

  /// No description provided for @fileSavedOnDevice.
  ///
  /// In en, this message translates to:
  /// **'{size} KB · saved on this device'**
  String fileSavedOnDevice(int size);

  /// No description provided for @fileOnServer.
  ///
  /// In en, this message translates to:
  /// **'{size} KB · already sent'**
  String fileOnServer(int size);

  /// No description provided for @noDate.
  ///
  /// In en, this message translates to:
  /// **'No date'**
  String get noDate;

  /// No description provided for @reviewDetails.
  ///
  /// In en, this message translates to:
  /// **'{type} · {when} · {priority} priority · {duration} min'**
  String reviewDetails(String type, String when, String priority, String duration);

  /// No description provided for @reviewChecklist.
  ///
  /// In en, this message translates to:
  /// **'{answered} of {total} answered · {failed} failed'**
  String reviewChecklist(int answered, int total, int failed);

  /// No description provided for @reviewFollowUp.
  ///
  /// In en, this message translates to:
  /// **'follow-up visit needed'**
  String get reviewFollowUp;

  /// No description provided for @reviewOffline.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. The report is saved on this device and sends automatically when you\'re back online.'**
  String get reviewOffline;

  /// No description provided for @submitFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t submit ({code}). Try again.'**
  String submitFailed(String code);

  /// No description provided for @serverRejected.
  ///
  /// In en, this message translates to:
  /// **'The server rejected: {fields}'**
  String serverRejected(String fields);

  /// No description provided for @fixStepsToSubmit.
  ///
  /// In en, this message translates to:
  /// **'Fix the steps marked in red and confirm the findings to submit.'**
  String get fixStepsToSubmit;

  /// No description provided for @reportQueuedTitle.
  ///
  /// In en, this message translates to:
  /// **'Report saved and queued'**
  String get reportQueuedTitle;

  /// No description provided for @reportSubmittedTitle.
  ///
  /// In en, this message translates to:
  /// **'Report submitted'**
  String get reportSubmittedTitle;

  /// No description provided for @reportQueuedBody.
  ///
  /// In en, this message translates to:
  /// **'It sends automatically when you\'re back online.'**
  String get reportQueuedBody;

  /// No description provided for @reportSubmittedBody.
  ///
  /// In en, this message translates to:
  /// **'The site manager gets the report now.'**
  String get reportSubmittedBody;

  /// No description provided for @viewInspection.
  ///
  /// In en, this message translates to:
  /// **'View inspection'**
  String get viewInspection;

  /// No description provided for @sharePdfReport.
  ///
  /// In en, this message translates to:
  /// **'Share PDF report'**
  String get sharePdfReport;

  /// No description provided for @pdfFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t make the PDF report. Try again when you\'re online.'**
  String get pdfFailed;

  /// No description provided for @typesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the inspection types.'**
  String get typesLoadFailed;

  /// No description provided for @archiveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t archive. Try again when you\'re online.'**
  String get archiveFailed;

  /// No description provided for @undoFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t undo. The inspection stays archived.'**
  String get undoFailed;

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied: {link}'**
  String linkCopied(String link);

  /// No description provided for @statusFilter.
  ///
  /// In en, this message translates to:
  /// **'Status filter'**
  String get statusFilter;

  /// No description provided for @noConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get noConnection;

  /// No description provided for @errorCode.
  ///
  /// In en, this message translates to:
  /// **'Error code: {code}'**
  String errorCode(String code);

  /// No description provided for @noMatchAny.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches these filters.'**
  String get noMatchAny;

  /// No description provided for @noMatchStatuses.
  ///
  /// In en, this message translates to:
  /// **'Nothing with status {statuses} matches these filters.'**
  String noMatchStatuses(String statuses);

  /// No description provided for @noMatchSearch.
  ///
  /// In en, this message translates to:
  /// **'Nothing with “{q}” in the name. Try another status or clear the search.'**
  String noMatchSearch(String q);

  /// No description provided for @loadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more.'**
  String get loadMoreFailed;

  /// No description provided for @actionsFor.
  ///
  /// In en, this message translates to:
  /// **'Actions for {id}'**
  String actionsFor(String id);

  /// No description provided for @columnId.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get columnId;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @sortByColumn.
  ///
  /// In en, this message translates to:
  /// **'Sort by {column}'**
  String sortByColumn(String column);

  /// No description provided for @chooseDates.
  ///
  /// In en, this message translates to:
  /// **'Choose dates'**
  String get chooseDates;

  /// No description provided for @rangeEndBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The end date must be on or after the start date'**
  String get rangeEndBeforeStart;

  /// No description provided for @inspectionNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'There is no inspection {id}. It may have been deleted or the link is wrong.'**
  String inspectionNotFoundBody(String id);

  /// No description provided for @loadDetailFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load {id}'**
  String loadDetailFailed(String id);

  /// No description provided for @offlineTryAgain.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Connect and try again.'**
  String get offlineTryAgain;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get somethingWentWrong;

  /// No description provided for @loadingInspection.
  ///
  /// In en, this message translates to:
  /// **'Loading inspection'**
  String get loadingInspection;

  /// No description provided for @loadingInspections.
  ///
  /// In en, this message translates to:
  /// **'Loading inspections'**
  String get loadingInspections;

  /// No description provided for @sitePhotoPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Site photo placeholder'**
  String get sitePhotoPlaceholder;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @inspectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Inspection'**
  String get inspectionTitle;

  /// No description provided for @checklistTemplateItems.
  ///
  /// In en, this message translates to:
  /// **'Checklist template v3 · {total} items'**
  String checklistTemplateItems(int total);

  /// No description provided for @answerToDo.
  ///
  /// In en, this message translates to:
  /// **'To do'**
  String get answerToDo;

  /// No description provided for @noPhotosTitle.
  ///
  /// In en, this message translates to:
  /// **'No photos yet'**
  String get noPhotosTitle;

  /// No description provided for @noPhotosBody.
  ///
  /// In en, this message translates to:
  /// **'Photos taken during the inspection show up here.'**
  String get noPhotosBody;

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{n} selected'**
  String selectedCount(int n);

  /// No description provided for @selectPhotosHint.
  ///
  /// In en, this message translates to:
  /// **'Long-press a photo, or use Select, to choose several.'**
  String get selectPhotosHint;

  /// No description provided for @select.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get select;

  /// No description provided for @shareSelected.
  ///
  /// In en, this message translates to:
  /// **'Share selected'**
  String get shareSelected;

  /// No description provided for @cancelSelection.
  ///
  /// In en, this message translates to:
  /// **'Cancel selection'**
  String get cancelSelection;

  /// No description provided for @openPhotoOf.
  ///
  /// In en, this message translates to:
  /// **'Open photo {n} of {total}'**
  String openPhotoOf(int n, int total);

  /// No description provided for @photoNotFound.
  ///
  /// In en, this message translates to:
  /// **'Photo not found'**
  String get photoNotFound;

  /// No description provided for @photoNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'There is no photo {photo} on {id}.'**
  String photoNotFoundBody(String photo, String id);

  /// No description provided for @closeViewer.
  ///
  /// In en, this message translates to:
  /// **'Close viewer'**
  String get closeViewer;

  /// No description provided for @photoCounter.
  ///
  /// In en, this message translates to:
  /// **'{n} of {total}'**
  String photoCounter(int n, int total);

  /// No description provided for @sharePhoto.
  ///
  /// In en, this message translates to:
  /// **'Share photo'**
  String get sharePhoto;

  /// No description provided for @photoCaption.
  ///
  /// In en, this message translates to:
  /// **'Photo {n}: {caption}'**
  String photoCaption(int n, String caption);

  /// No description provided for @noMapLocation.
  ///
  /// In en, this message translates to:
  /// **'No map location for this site.'**
  String get noMapLocation;

  /// No description provided for @mapsOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open maps.'**
  String get mapsOpenFailed;

  /// No description provided for @noPhoneFor.
  ///
  /// In en, this message translates to:
  /// **'No phone number for {name}.'**
  String noPhoneFor(String name);

  /// No description provided for @callPerson.
  ///
  /// In en, this message translates to:
  /// **'Call {name}: {phone}'**
  String callPerson(String name, String phone);

  /// No description provided for @inspectionNamed.
  ///
  /// In en, this message translates to:
  /// **'Inspection {id}'**
  String inspectionNamed(String id);

  /// No description provided for @sharingUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sharing is not available here; link copied instead.'**
  String get sharingUnavailable;

  /// No description provided for @preparingPdf.
  ///
  /// In en, this message translates to:
  /// **'Preparing the PDF report…'**
  String get preparingPdf;

  /// No description provided for @pdfDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Report downloaded: {file}'**
  String pdfDownloaded(String file);

  /// No description provided for @pdfFooter.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total} | generated {date}'**
  String pdfFooter(int page, int total, String date);

  /// No description provided for @pdfAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get pdfAddress;

  /// No description provided for @pdfType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get pdfType;

  /// No description provided for @pdfSiteManager.
  ///
  /// In en, this message translates to:
  /// **'Site manager'**
  String get pdfSiteManager;

  /// No description provided for @pdfInspector.
  ///
  /// In en, this message translates to:
  /// **'Inspector'**
  String get pdfInspector;

  /// No description provided for @pdfChecklistSummary.
  ///
  /// In en, this message translates to:
  /// **'Checklist: {answered} of {total} answered, {failed} failed'**
  String pdfChecklistSummary(int answered, int total, int failed);

  /// No description provided for @pdfItem.
  ///
  /// In en, this message translates to:
  /// **'Item'**
  String get pdfItem;

  /// No description provided for @pdfResult.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get pdfResult;
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
