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

  @override
  String outboxQueued(String time) {
    return 'Queued $time · sends when online';
  }

  @override
  String outboxRejected(String reason) {
    return 'Rejected by the server: $reason';
  }

  @override
  String get outboxOptions => 'Report options';

  @override
  String get delete => 'Delete';

  @override
  String get outboxEditBusy => 'Finish or discard the open draft for this inspection first.';

  @override
  String get outboxDeleteTitle => 'Delete this report?';

  @override
  String get outboxDeleteBody => 'It never reached the server, so it can\'t be recovered.';

  @override
  String get signOutTitle => 'Sign out?';

  @override
  String get signOutLocalData => 'These are saved only on this device and will be deleted:';

  @override
  String signOutUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count reports not sent yet', one: '1 report not sent yet');
    return '$_temp0';
  }

  @override
  String signOutDrafts(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count drafts', one: '1 draft');
    return '$_temp0';
  }

  @override
  String get signOutConfirm => 'Sign out and delete';

  @override
  String get remindersBlocked => 'Notifications are blocked for this app. Allow them in the system settings.';

  @override
  String get remindersScheduleFailed =>
      'Reminders are on, but they couldn\'t be scheduled yet. They\'ll be set up when the inspections load.';

  @override
  String get biometricNotSetUp => 'Set up a fingerprint, face or screen lock on this device first.';

  @override
  String reminderTitle(String site, String time) {
    return '$site at $time';
  }

  @override
  String get reminderBody => 'Starts in 30 minutes';

  @override
  String get reminderChannel => 'Inspection reminders';

  @override
  String get reminderChannelDescription => 'Alerts before inspections start';

  @override
  String get biometricReason => 'Unlock Field Inspections';

  @override
  String get loading => 'Loading';

  @override
  String get passwordHelperSignIn => 'Use 8 or more characters';

  @override
  String get capsLockOn => 'Caps Lock is on';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get backendMockServer => 'Connected to the mock server';

  @override
  String get backendOfflineDemo => 'Offline demo data (mock server not reachable)';

  @override
  String get authErrorCredentials => 'Email or password is incorrect.';

  @override
  String get authErrorNetwork => 'Can\'t reach the server. Check your connection and try again.';

  @override
  String get authErrorValidation => 'Check the highlighted fields.';

  @override
  String get authErrorUnknown => 'Something went wrong. Try again.';

  @override
  String get createAccountTitle => 'Create account';

  @override
  String get fullName => 'Full name';

  @override
  String get strengthTooWeak => 'Too weak';

  @override
  String get strengthWeak => 'Weak';

  @override
  String get strengthFair => 'Fair';

  @override
  String get strengthGood => 'Good';

  @override
  String get strengthStrong => 'Strong';

  @override
  String passwordStrength(String strength) {
    return 'Password strength: $strength';
  }

  @override
  String get passwordHelperSignUp => '8+ characters with a letter and a digit';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get acceptTerms => 'I accept the terms of use';

  @override
  String get haveAccount => 'I already have an account';

  @override
  String get resetPasswordTitle => 'Reset password';

  @override
  String get resetIntro => 'Enter your account\'s email and we\'ll send a reset link.';

  @override
  String resetSent(String email) {
    return 'If an account exists for $email, we sent a link to reset the password. Check your inbox.';
  }

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String unlockWelcome(String name) {
    return 'Welcome back, $name';
  }

  @override
  String get unlockTimedOut => 'The app locked after 5 minutes in the background.';

  @override
  String get unlockOnStart => 'Biometric unlock is on for this app.';

  @override
  String get unlockButton => 'Unlock with biometrics';

  @override
  String get unlockPrompt => 'Use your fingerprint or face to unlock';

  @override
  String get unlockFailed => 'Not recognised. Try again or use your password.';

  @override
  String get usePasswordInstead => 'Use password instead';

  @override
  String get authTagline => 'Plan, run and report site inspections.';

  @override
  String get authTaglineSub => 'Same account and data on iOS, Android and the web.';

  @override
  String pocBuild(String version) {
    return 'v$version · PoC build';
  }

  @override
  String fieldsNeedAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count fields need attention', one: '1 field needs attention');
    return '$_temp0';
  }

  @override
  String fieldNeedsAttention(String error) {
    return '1 field needs attention: $error';
  }

  @override
  String inProgressLabel(String label) {
    return '$label, in progress';
  }

  @override
  String get valRequired => 'Required';

  @override
  String get valEmail => 'Enter a valid email, like name@example.com';

  @override
  String valMinLength(int n) {
    return 'Use $n or more characters';
  }

  @override
  String valMaxLength(int n) {
    return 'Use $n characters or fewer';
  }

  @override
  String get valInteger => 'Enter a whole number';

  @override
  String valIntRange(int min, int max) {
    return 'Enter a number from $min to $max';
  }

  @override
  String get valDateInPast => 'Pick today or a later date';

  @override
  String get valPasswordsDiffer => 'Passwords don\'t match';

  @override
  String get valPasswordWeak => 'Use 8+ characters with a letter and a digit';

  @override
  String get valEmailTaken => 'An account with this email already exists';

  @override
  String get valMustAccept => 'Accept the terms to continue';

  @override
  String get valUnknownSite => 'Pick a site from the list';

  @override
  String get valChecklistIncomplete => 'Answer every checklist item';

  @override
  String get valCheckField => 'Check this field';

  @override
  String get valSiteTooShort => 'Pick a site from the list or add a new one (3+ characters)';

  @override
  String get valAnswerItem => 'Answer this item';

  @override
  String get valFailureNeedsDetail => 'Add a note or a photo for this failure';

  @override
  String get valPhotoForFailure => 'Add at least one photo of the failed items';

  @override
  String valTooManyPhotos(int n) {
    return 'Use $n photos or fewer';
  }

  @override
  String valFilesTooBig(String names) {
    return '$names: files must be 20 MB or smaller';
  }

  @override
  String valBadFileType(String names) {
    return '$names: use JPG, PNG, HEIC or PDF';
  }

  @override
  String get valConfirmFindings => 'Confirm the findings before submitting';

  @override
  String get valChecklistNotLoaded => 'The checklist hasn\'t loaded yet';

  @override
  String get wizardDraftSaved => 'Draft saved on this device';

  @override
  String get wizardProgress => 'Wizard progress';

  @override
  String get wizardSteps => 'Wizard steps';

  @override
  String get wizardHintSite => 'Choose a site';

  @override
  String get wizardHintDetails => 'Type, date and time';

  @override
  String wizardHintChecklist(int answered, int total) {
    return '$answered of $total answered';
  }

  @override
  String wizardHintPhotos(int photos, int files) {
    return '$photos photos · $files files';
  }

  @override
  String get wizardHintReview => 'Check and send';

  @override
  String stepStateDone(String step) {
    return '$step, done';
  }

  @override
  String stepStateAttention(String step) {
    return '$step, needs attention';
  }

  @override
  String stepStateCurrent(String step) {
    return '$step, current step';
  }

  @override
  String stepStateUpcoming(String step) {
    return '$step, not started';
  }

  @override
  String get wizardLoadFailed => 'Couldn\'t load this inspection to edit it.';

  @override
  String get wizardRecoveredPhoto => 'A photo taken before the app closed was added.';

  @override
  String get siteLabel => 'Site';

  @override
  String get siteHelper => 'Search by name or address';

  @override
  String get clear => 'Clear';

  @override
  String newSite(String name) {
    return 'New site: $name';
  }

  @override
  String get newSiteHint => 'It will be created when you submit';

  @override
  String addNewSite(String name) {
    return 'Add “$name” as a new site';
  }

  @override
  String get yourLocation => 'Your location';

  @override
  String get locationServiceOff => 'Location is turned off on this device.';

  @override
  String get locationDenied => 'Location permission was not given. The check is optional.';

  @override
  String get locationBlocked => 'Location is blocked for this app.';

  @override
  String get locationUnsupported => 'Location is not available here.';

  @override
  String get locationError => 'Couldn\'t get a position. Try again outside or near a window.';

  @override
  String get locationNotChecked => 'Not checked yet';

  @override
  String get locationOptional => 'Optional: confirms you are on site.';

  @override
  String locationAccuracy(String meters) {
    return 'Accuracy ±$meters m';
  }

  @override
  String locationFromSite(String distance) {
    return '$distance from the site';
  }

  @override
  String get locationFar => 'You seem to be more than 200 m from the site address.';

  @override
  String get checkLocation => 'Check location';

  @override
  String get updateLocation => 'Update location';

  @override
  String get inspectionType => 'Inspection type';

  @override
  String get dateLabel => 'Date';

  @override
  String get openCalendar => 'Open calendar';

  @override
  String get startTime => 'Start time';

  @override
  String get openTimePicker => 'Open time picker';

  @override
  String get priority => 'Priority';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityNormal => 'Normal';

  @override
  String get priorityHigh => 'High';

  @override
  String get durationLabel => 'Estimated duration (minutes)';

  @override
  String get durationHelper => 'From 15 to 480';

  @override
  String get notesLabel => 'Notes for the site manager';

  @override
  String get optional => 'Optional';

  @override
  String checklistProgress(String type, int answered, int total) {
    return '$type · $answered of $total answered';
  }

  @override
  String itemsNeedAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count items need attention', one: '1 item needs attention');
    return '$_temp0';
  }

  @override
  String get jumpToFirst => 'Jump to the first one';

  @override
  String get checklistLoadFailed => 'Couldn\'t load the checklist.';

  @override
  String get answerPass => 'Pass';

  @override
  String get answerFail => 'Fail';

  @override
  String get answerNa => 'N/A';

  @override
  String get severity => 'Severity';

  @override
  String severityValue(int level, String label) {
    return '$level · $label';
  }

  @override
  String get severityMinor => 'Minor';

  @override
  String get severityLow => 'Low';

  @override
  String get severityMajor => 'Major';

  @override
  String get severityHigh => 'High';

  @override
  String get severityCritical => 'Critical';

  @override
  String severitySemantics(String value) {
    return 'Severity $value';
  }

  @override
  String get followUpVisit => 'Requires follow-up visit';

  @override
  String get whatIsWrong => 'What is wrong?';

  @override
  String get addPhoto => 'Add photo';

  @override
  String addPhotoCount(int count) {
    return 'Add photo ($count)';
  }

  @override
  String get dictateNote => 'Dictate note (not in the PoC)';

  @override
  String get photoTypeHint => 'Use JPG, PNG or HEIC up to 20 MB.';

  @override
  String fileRejected(String name) {
    return '$name: use JPG, PNG, HEIC or PDF up to 20 MB.';
  }

  @override
  String get cameraOpenFailed => 'Couldn\'t open the camera.';

  @override
  String get galleryOpenFailed => 'Couldn\'t open the gallery.';

  @override
  String photoN(int n) {
    return 'Photo $n';
  }

  @override
  String photoNForFailure(int n) {
    return 'Photo $n, for a failed item';
  }

  @override
  String removePhotoN(int n) {
    return 'Remove photo $n';
  }

  @override
  String get useCamera => 'Use camera';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get gallery => 'Gallery';

  @override
  String get dropFiles => 'Drop files to upload';

  @override
  String get dragOrPaste => 'Drag files here, or paste an image';

  @override
  String get fileTypesHint => 'JPG, PNG, HEIC or PDF, up to 20 MB each.';

  @override
  String get photosIntro => 'Add photos of the findings and any documents the site gave you.';

  @override
  String get cameraOff => 'Camera access is off. You can still choose photos from the gallery.';

  @override
  String photosCount(int count) {
    return 'Photos · $count';
  }

  @override
  String filesCount(int count) {
    return 'Files · $count';
  }

  @override
  String get attachFile => 'Attach file';

  @override
  String removeFile(String name) {
    return 'Remove $name';
  }

  @override
  String fileSavedOnDevice(int size) {
    return '$size KB · saved on this device';
  }

  @override
  String fileOnServer(int size) {
    return '$size KB · already sent';
  }

  @override
  String get noDate => 'No date';

  @override
  String reviewDetails(String type, String when, String priority, String duration) {
    return '$type · $when · $priority priority · $duration min';
  }

  @override
  String reviewChecklist(int answered, int total, int failed) {
    return '$answered of $total answered · $failed failed';
  }

  @override
  String get reviewFollowUp => 'follow-up visit needed';

  @override
  String get reviewOffline => 'You\'re offline. The report is saved on this device and sends automatically when you\'re back online.';

  @override
  String submitFailed(String code) {
    return 'Couldn\'t submit ($code). Try again.';
  }

  @override
  String serverRejected(String fields) {
    return 'The server rejected: $fields';
  }

  @override
  String get fixStepsToSubmit => 'Fix the steps marked in red and confirm the findings to submit.';

  @override
  String get reportQueuedTitle => 'Report saved and queued';

  @override
  String get reportSubmittedTitle => 'Report submitted';

  @override
  String get reportQueuedBody => 'It sends automatically when you\'re back online.';

  @override
  String get reportSubmittedBody => 'The site manager gets the report now.';

  @override
  String get viewInspection => 'View inspection';

  @override
  String get sharePdfReport => 'Share PDF report';

  @override
  String get pdfFailed => 'Couldn\'t make the PDF report. Try again when you\'re online.';

  @override
  String get typesLoadFailed => 'Couldn\'t load the inspection types.';

  @override
  String get archiveFailed => 'Couldn\'t archive. Try again when you\'re online.';

  @override
  String get undoFailed => 'Couldn\'t undo. The inspection stays archived.';

  @override
  String linkCopied(String link) {
    return 'Link copied: $link';
  }

  @override
  String get statusFilter => 'Status filter';

  @override
  String get noConnection => 'No connection';

  @override
  String errorCode(String code) {
    return 'Error code: $code';
  }

  @override
  String get noMatchAny => 'Nothing matches these filters.';

  @override
  String noMatchStatuses(String statuses) {
    return 'Nothing with status $statuses matches these filters.';
  }

  @override
  String noMatchSearch(String q) {
    return 'Nothing with “$q” in the name. Try another status or clear the search.';
  }

  @override
  String get loadMoreFailed => 'Couldn\'t load more.';

  @override
  String actionsFor(String id) {
    return 'Actions for $id';
  }

  @override
  String get columnId => 'ID';

  @override
  String get statusLabel => 'Status';

  @override
  String sortByColumn(String column) {
    return 'Sort by $column';
  }

  @override
  String get chooseDates => 'Choose dates';

  @override
  String get rangeEndBeforeStart => 'The end date must be on or after the start date';

  @override
  String inspectionNotFoundBody(String id) {
    return 'There is no inspection $id. It may have been deleted or the link is wrong.';
  }

  @override
  String loadDetailFailed(String id) {
    return 'Couldn\'t load $id';
  }

  @override
  String get offlineTryAgain => 'You\'re offline. Connect and try again.';

  @override
  String get somethingWentWrong => 'Something went wrong.';

  @override
  String get loadingInspection => 'Loading inspection';

  @override
  String get loadingInspections => 'Loading inspections';

  @override
  String get sitePhotoPlaceholder => 'Site photo placeholder';

  @override
  String get moreOptions => 'More options';

  @override
  String get inspectionTitle => 'Inspection';

  @override
  String checklistTemplateItems(int total) {
    return 'Checklist template v3 · $total items';
  }

  @override
  String get answerToDo => 'To do';

  @override
  String get noPhotosTitle => 'No photos yet';

  @override
  String get noPhotosBody => 'Photos taken during the inspection show up here.';

  @override
  String selectedCount(int n) {
    return '$n selected';
  }

  @override
  String get selectPhotosHint => 'Long-press a photo, or use Select, to choose several.';

  @override
  String get select => 'Select';

  @override
  String get shareSelected => 'Share selected';

  @override
  String get cancelSelection => 'Cancel selection';

  @override
  String openPhotoOf(int n, int total) {
    return 'Open photo $n of $total';
  }

  @override
  String get photoNotFound => 'Photo not found';

  @override
  String photoNotFoundBody(String photo, String id) {
    return 'There is no photo $photo on $id.';
  }

  @override
  String get closeViewer => 'Close viewer';

  @override
  String photoCounter(int n, int total) {
    return '$n of $total';
  }

  @override
  String get sharePhoto => 'Share photo';

  @override
  String photoCaption(int n, String caption) {
    return 'Photo $n: $caption';
  }

  @override
  String get noMapLocation => 'No map location for this site.';

  @override
  String get mapsOpenFailed => 'Couldn\'t open maps.';

  @override
  String noPhoneFor(String name) {
    return 'No phone number for $name.';
  }

  @override
  String callPerson(String name, String phone) {
    return 'Call $name: $phone';
  }

  @override
  String inspectionNamed(String id) {
    return 'Inspection $id';
  }

  @override
  String get sharingUnavailable => 'Sharing is not available here; link copied instead.';

  @override
  String get preparingPdf => 'Preparing the PDF report…';

  @override
  String pdfDownloaded(String file) {
    return 'Report downloaded: $file';
  }

  @override
  String pdfFooter(int page, int total, String date) {
    return 'Page $page of $total | generated $date';
  }

  @override
  String get pdfAddress => 'Address';

  @override
  String get pdfType => 'Type';

  @override
  String get pdfSiteManager => 'Site manager';

  @override
  String get pdfInspector => 'Inspector';

  @override
  String pdfChecklistSummary(int answered, int total, int failed) {
    return 'Checklist: $answered of $total answered, $failed failed';
  }

  @override
  String get pdfItem => 'Item';

  @override
  String get pdfResult => 'Result';

  @override
  String get todaySection => 'Today';

  @override
  String get noNotificationsTitle => 'No notifications';

  @override
  String get noNotificationsBody => 'You\'re all caught up.';

  @override
  String get notificationsLoadFailed => 'Couldn\'t load notifications.';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get unread => 'Unread';

  @override
  String get remindersOnMessage => 'Reminders are on: 30 minutes before each inspection.';

  @override
  String get remindersWebTest => 'Browsers can’t schedule notifications. Test ones work from the deep-link tester while this tab is open.';

  @override
  String get mapLocationDenied => 'Location permission was not given.';

  @override
  String get mapLocationBlocked => 'Location is blocked for this app. Turn it on in settings.';

  @override
  String get mapLocationErrorWeb => 'Couldn\'t get your location. The browser needs HTTPS and your permission.';

  @override
  String get mapLocationError => 'Couldn\'t get your location.';

  @override
  String noSiteMatches(String q) {
    return 'No site matches “$q”.';
  }

  @override
  String get searchSites => 'Search sites';

  @override
  String get showMyLocation => 'Show my location';

  @override
  String distanceAway(String distance) {
    return '$distance away';
  }

  @override
  String get openInspection => 'Open inspection';

  @override
  String get mapLoadFailed => 'Couldn\'t load the inspections for the map.';

  @override
  String get goHome => 'Go to home';

  @override
  String get pageNotFound => 'Page not found';

  @override
  String get pageNotFoundBody => 'Nothing lives at this address. The link may be old, or the inspection was deleted.';

  @override
  String get openInspections => 'Open inspections';

  @override
  String pdfSaved(String file) {
    return 'Report saved: $file';
  }

  @override
  String get remindersUnsupported => 'This platform can’t schedule notifications, so reminders are off here.';

  @override
  String get remindersOffLinux => 'Linux shows notifications only while the app is open and can’t schedule them.';

  @override
  String get remindersLinuxTest => 'Linux can’t schedule notifications. Test ones work from the deep-link tester while the app is open.';

  @override
  String get dragFiles => 'Drag files here';
}
