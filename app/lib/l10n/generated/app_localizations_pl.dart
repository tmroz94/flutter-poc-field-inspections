// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get appName => 'Inspekcje terenowe';

  @override
  String get navHome => 'Start';

  @override
  String get navInspections => 'Inspekcje';

  @override
  String get navMap => 'Mapa';

  @override
  String get navSettings => 'Ustawienia';

  @override
  String get navPocResults => 'Wyniki PoC';

  @override
  String get newInspection => 'Nowa inspekcja';

  @override
  String get newShort => 'Nowa';

  @override
  String get cancel => 'Anuluj';

  @override
  String get save => 'Zapisz';

  @override
  String get back => 'Wstecz';

  @override
  String get next => 'Dalej';

  @override
  String get retry => 'Ponów';

  @override
  String get tryAgain => 'Spróbuj ponownie';

  @override
  String get close => 'Zamknij';

  @override
  String get seeAll => 'Pokaż wszystkie';

  @override
  String get openSettings => 'Otwórz ustawienia';

  @override
  String get syncNow => 'Synchronizuj';

  @override
  String get signOut => 'Wyloguj się';

  @override
  String get undo => 'Cofnij';

  @override
  String get edit => 'Edytuj';

  @override
  String get statusAll => 'Wszystkie';

  @override
  String get statusScheduled => 'Zaplanowana';

  @override
  String get statusInProgress => 'W toku';

  @override
  String get statusDraft => 'Szkic';

  @override
  String get statusOverdue => 'Po terminie';

  @override
  String get statusSubmitted => 'Wysłana';

  @override
  String todayAt(String time) {
    return 'Dziś $time';
  }

  @override
  String yesterdayAt(String time) {
    return 'Wczoraj $time';
  }

  @override
  String tomorrowAt(String time) {
    return 'Jutro $time';
  }

  @override
  String greetingMorning(String name) {
    return 'Dzień dobry, $name';
  }

  @override
  String greetingAfternoon(String name) {
    return 'Dzień dobry, $name';
  }

  @override
  String greetingEvening(String name) {
    return 'Dobry wieczór, $name';
  }

  @override
  String get homeToday => 'Dziś';

  @override
  String get homeDueThisWeek => 'W tym tygodniu';

  @override
  String get homeNothingToday => 'Na dziś nic nie zaplanowano.';

  @override
  String get homeNothingWeek => 'Nic więcej w tym tygodniu.';

  @override
  String overdueByDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Po terminie o $count dnia',
      many: 'Po terminie o $count dni',
      few: 'Po terminie o $count dni',
      one: 'Po terminie o 1 dzień',
    );
    return '$_temp0';
  }

  @override
  String get draftNotSynced => 'Szkic · niezsynchronizowany';

  @override
  String get homeDraftsOnDevice => 'Szkice na tym urządzeniu';

  @override
  String get homeWaitingToSend => 'Czeka na wysłanie';

  @override
  String stepOf(int step, int total) {
    return 'Krok $step z $total';
  }

  @override
  String savedAt(String time) {
    return 'zapisano $time';
  }

  @override
  String get offlineTitle => 'Jesteś offline';

  @override
  String get offlineConnect => 'Połącz się, aby wczytać inspekcje.';

  @override
  String offlineReportsWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count raportu zostanie wysłane po powrocie sieci',
      many: '$count raportów zostanie wysłanych po powrocie sieci',
      few: '$count raporty zostaną wysłane po powrocie sieci',
      one: '1 raport zostanie wysłany po powrocie sieci',
    );
    return '$_temp0';
  }

  @override
  String get accountAndSettings => 'Konto i ustawienia';

  @override
  String notificationsUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Powiadomienia, $count nieprzeczytanego',
      many: 'Powiadomienia, $count nieprzeczytanych',
      few: 'Powiadomienia, $count nieprzeczytane',
      one: 'Powiadomienia, 1 nieprzeczytane',
      zero: 'Powiadomienia',
    );
    return '$_temp0';
  }

  @override
  String get inspectionsTitle => 'Inspekcje';

  @override
  String get searchSiteOrId => 'Szukaj obiektu lub ID';

  @override
  String get clearSearch => 'Wyczyść wyszukiwanie';

  @override
  String get filterAndSort => 'Filtruj i sortuj';

  @override
  String filterAndSortActive(int count) {
    return 'Filtruj i sortuj, aktywne: $count';
  }

  @override
  String get refreshList => 'Odśwież listę';

  @override
  String get noMatchTitle => 'Brak pasujących inspekcji';

  @override
  String get clearFilters => 'Wyczyść filtry';

  @override
  String get loadErrorTitle => 'Nie udało się wczytać inspekcji';

  @override
  String get loadErrorOffline => 'Jesteś offline, a na tym urządzeniu nic jeszcze nie zapisano. Połącz się i spróbuj ponownie.';

  @override
  String get loadErrorServer => 'Serwer ma problem. Spróbuj za chwilę.';

  @override
  String get loadingMore => 'Wczytywanie';

  @override
  String archived(String id) {
    return 'Zarchiwizowano $id';
  }

  @override
  String get archive => 'Archiwizuj';

  @override
  String get copyLink => 'Kopiuj link';

  @override
  String get showOnMap => 'Pokaż na mapie';

  @override
  String get selectInspection => 'Wybierz inspekcję';

  @override
  String get selectInspectionHint => 'Wybierz ją z listy, aby zobaczyć szczegóły.';

  @override
  String get loadMore => 'Wczytaj więcej';

  @override
  String showResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pokaż $count wyniku',
      many: 'Pokaż $count wyników',
      few: 'Pokaż $count wyniki',
      one: 'Pokaż 1 wynik',
    );
    return '$_temp0';
  }

  @override
  String get reset => 'Resetuj';

  @override
  String get sortBy => 'Sortuj według';

  @override
  String get due => 'Termin';

  @override
  String get status => 'Status';

  @override
  String get tabOverview => 'Przegląd';

  @override
  String get tabChecklist => 'Lista kontrolna';

  @override
  String get tabPhotos => 'Zdjęcia';

  @override
  String get tabHistory => 'Historia';

  @override
  String get directions => 'Trasa';

  @override
  String get callSite => 'Zadzwoń';

  @override
  String get exportPdf => 'Eksport PDF';

  @override
  String get shareReport => 'Udostępnij raport';

  @override
  String get continueAction => 'Kontynuuj';

  @override
  String checkedOf(int answered, int total) {
    return 'Sprawdzono $answered z $total';
  }

  @override
  String failedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count niezgodności',
      many: '$count niezgodności',
      few: '$count niezgodności',
      one: '1 niezgodność',
    );
    return '$_temp0';
  }

  @override
  String get inspectionNotFound => 'Nie znaleziono inspekcji';

  @override
  String get backToInspections => 'Wróć do inspekcji';

  @override
  String get notificationsTitle => 'Powiadomienia';

  @override
  String get markAllRead => 'Oznacz wszystkie jako przeczytane';

  @override
  String get remindersOff => 'Przypomnienia są wyłączone na tym urządzeniu';

  @override
  String get remindersOffBody => 'Włącz je, aby dostać alert 30 minut przed każdą inspekcją.';

  @override
  String get remindersOffWeb => 'Przeglądarki pokazują powiadomienia tylko przy otwartej aplikacji i nie umieją ich planować.';

  @override
  String get turnOn => 'Włącz';

  @override
  String get notificationDismissed => 'Usunięto powiadomienie';

  @override
  String get earlier => 'Wcześniej';

  @override
  String get settingsTitle => 'Ustawienia';

  @override
  String get appearanceAndLanguage => 'Wygląd i język';

  @override
  String get appearanceSubtitle => 'Motyw, kontrast, rozmiar tekstu, język';

  @override
  String get inspectionReminders => 'Przypomnienia o inspekcjach';

  @override
  String get remindersSubtitle => '30 minut przed rozpoczęciem';

  @override
  String get remindersWebSubtitle => 'Niedostępne w przeglądarce';

  @override
  String get remindersLinuxSubtitle => 'Niedostępne w systemie Linux';

  @override
  String get biometricUnlock => 'Odblokowanie biometryczne';

  @override
  String get biometricSubtitle => 'Blokada po 5 minutach w tle';

  @override
  String get offlineData => 'Dane offline';

  @override
  String offlineDataSubtitle(int drafts, int waiting) {
    String _temp0 = intl.Intl.pluralLogic(
      drafts,
      locale: localeName,
      other: '$drafts szkicu',
      many: '$drafts szkiców',
      few: '$drafts szkice',
      one: '1 szkic',
    );
    return '$_temp0 · czeka na wysłanie: $waiting';
  }

  @override
  String get pocTools => 'Narzędzia PoC';

  @override
  String get resultsTracker => 'Wyniki testów';

  @override
  String get resultsTrackerSubtitle => 'Zaliczone, niezaliczone i notatki dla platform';

  @override
  String get adaptiveWidgets => 'Widżety adaptacyjne';

  @override
  String get diagnostics => 'Diagnostyka';

  @override
  String get deepLinkTester => 'Tester linków';

  @override
  String get theme => 'Motyw';

  @override
  String get themeSystem => 'Systemowy';

  @override
  String get themeLight => 'Jasny';

  @override
  String get themeDark => 'Ciemny';

  @override
  String get contrast => 'Kontrast';

  @override
  String get contrastStandard => 'Standardowy';

  @override
  String get contrastMedium => 'Średni';

  @override
  String get contrastHigh => 'Wysoki';

  @override
  String get textSize => 'Rozmiar tekstu';

  @override
  String get textSizeHint => 'Zgodny z ustawieniem systemu, dopóki go tu nie zmienisz';

  @override
  String get useSystemSize => 'Rozmiar systemowy';

  @override
  String get reduceMotion => 'Ogranicz animacje';

  @override
  String get reduceMotionHint => 'Mniej animacji; zmiana ekranów bez ruchu';

  @override
  String get language => 'Język';

  @override
  String get languageSystem => 'Język urządzenia';

  @override
  String get preview => 'Podgląd';

  @override
  String get previewSite => 'Magazyn A – rampa załadunkowa';

  @override
  String inspectionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inspekcji',
      many: '$count inspekcji',
      few: '$count inspekcje',
      one: '1 inspekcja',
    );
    return '$_temp0';
  }

  @override
  String get saveDraft => 'Zapisz szkic';

  @override
  String editInspection(String id) {
    return 'Edycja $id';
  }

  @override
  String get stepSite => 'Obiekt';

  @override
  String get stepDetails => 'Szczegóły';

  @override
  String get stepChecklist => 'Lista kontrolna';

  @override
  String get stepPhotos => 'Zdjęcia i pliki';

  @override
  String get stepReview => 'Podsumowanie i wysyłka';

  @override
  String nextStep(String step) {
    return 'Dalej: $step';
  }

  @override
  String draftSavedAt(String time) {
    return 'Szkic zapisany na tym urządzeniu · $time';
  }

  @override
  String get leaveTitle => 'Wyjść bez wysyłania?';

  @override
  String get leaveBody => 'Odpowiedzi są zapisane jako szkic na tym urządzeniu. Możesz dokończyć później z ekranu Start.';

  @override
  String get discardDraft => 'Usuń szkic';

  @override
  String get stay => 'Zostań';

  @override
  String get leave => 'Wyjdź';

  @override
  String get submit => 'Wyślij';

  @override
  String get confirmFindings => 'Potwierdzam, że ustalenia są prawidłowe';

  @override
  String get signIn => 'Zaloguj się';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Hasło';

  @override
  String get keepSignedIn => 'Nie wylogowuj mnie';

  @override
  String get forgotPassword => 'Nie pamiętasz hasła?';

  @override
  String get useDemoAccount => 'Użyj konta demo';

  @override
  String get createAnAccount => 'Załóż konto';

  @override
  String get resultsTitle => 'Wyniki PoC';

  @override
  String get sampleData => 'Dane przykładowe';

  @override
  String get filterAll => 'Wszystkie';

  @override
  String get filterFailing => 'Problemy';

  @override
  String get filterNotTested => 'Nieprzetestowane';

  @override
  String get resultPass => 'Zaliczone';

  @override
  String get resultPartial => 'Częściowo';

  @override
  String get resultFail => 'Niezaliczone';

  @override
  String get resultNotTested => 'Nieprzetestowane';

  @override
  String get resultNa => 'N/D';

  @override
  String testedOf(int tested, int total) {
    return 'Przetestowano $tested z $total';
  }

  @override
  String get exportResults => 'Eksportuj wyniki';

  @override
  String get importResults => 'Importuj';

  @override
  String get device => 'Urządzenie i wersja';

  @override
  String get notes => 'Notatki';

  @override
  String get platform => 'Platforma';

  @override
  String get dueAny => 'Dowolny';

  @override
  String get dueToday => 'Dziś';

  @override
  String get dueWeek => 'Tydzień';

  @override
  String get dueCustom => 'Własny';

  @override
  String get sortDueAsc => 'Termin, najbliższe najpierw';

  @override
  String get sortDueDesc => 'Termin, najdalsze najpierw';

  @override
  String get sortSiteAsc => 'Nazwa obiektu, A–Z';

  @override
  String get selectAtLeastOneStatus => 'Wybierz co najmniej jeden status';

  @override
  String completeStepFirst(String step) {
    return 'Najpierw uzupełnij „$step”';
  }

  @override
  String get showResultsPlain => 'Pokaż wyniki';

  @override
  String outboxQueued(String time) {
    return 'W kolejce od $time · wyśle się po połączeniu';
  }

  @override
  String outboxRejected(String reason) {
    return 'Odrzucony przez serwer: $reason';
  }

  @override
  String get outboxOptions => 'Opcje raportu';

  @override
  String get delete => 'Usuń';

  @override
  String get outboxEditBusy => 'Najpierw dokończ lub odrzuć otwarty szkic tej inspekcji.';

  @override
  String get outboxDeleteTitle => 'Usunąć ten raport?';

  @override
  String get outboxDeleteBody => 'Nie dotarł na serwer, więc nie da się go odzyskać.';

  @override
  String get signOutTitle => 'Wylogować się?';

  @override
  String get signOutLocalData => 'Te dane są zapisane tylko na tym urządzeniu i zostaną usunięte:';

  @override
  String signOutUnsent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count niewysłanego raportu',
      many: '$count niewysłanych raportów',
      few: '$count niewysłane raporty',
      one: '1 niewysłany raport',
    );
    return '$_temp0';
  }

  @override
  String signOutDrafts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count szkicu',
      many: '$count szkiców',
      few: '$count szkice',
      one: '1 szkic',
    );
    return '$_temp0';
  }

  @override
  String get signOutConfirm => 'Wyloguj i usuń';

  @override
  String get remindersBlocked => 'Powiadomienia są zablokowane dla tej aplikacji. Zezwól na nie w ustawieniach systemu.';

  @override
  String get remindersScheduleFailed =>
      'Przypomnienia są włączone, ale nie udało się ich jeszcze zaplanować. Zostaną ustawione po wczytaniu inspekcji.';

  @override
  String get biometricNotSetUp => 'Najpierw ustaw na tym urządzeniu odcisk palca, twarz lub blokadę ekranu.';

  @override
  String reminderTitle(String site, String time) {
    return '$site o $time';
  }

  @override
  String get reminderBody => 'Zaczyna się za 30 minut';

  @override
  String get reminderChannel => 'Przypomnienia o inspekcjach';

  @override
  String get reminderChannelDescription => 'Alerty przed rozpoczęciem inspekcji';

  @override
  String get notificationOpenAction => 'Otwórz';

  @override
  String get biometricReason => 'Odblokuj Inspekcje terenowe';

  @override
  String get loading => 'Wczytywanie';

  @override
  String get passwordHelperSignIn => 'Użyj co najmniej 8 znaków';

  @override
  String get capsLockOn => 'Caps Lock jest włączony';

  @override
  String get showPassword => 'Pokaż hasło';

  @override
  String get hidePassword => 'Ukryj hasło';

  @override
  String get backendMockServer => 'Połączono z serwerem testowym';

  @override
  String get backendOfflineDemo => 'Dane demonstracyjne offline (serwer testowy niedostępny)';

  @override
  String get authErrorCredentials => 'Nieprawidłowy e-mail lub hasło.';

  @override
  String get authErrorNetwork => 'Nie można połączyć się z serwerem. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get authErrorValidation => 'Sprawdź zaznaczone pola.';

  @override
  String get authErrorUnknown => 'Coś poszło nie tak. Spróbuj ponownie.';

  @override
  String get createAccountTitle => 'Utwórz konto';

  @override
  String get fullName => 'Imię i nazwisko';

  @override
  String get strengthTooWeak => 'Zbyt słabe';

  @override
  String get strengthWeak => 'Słabe';

  @override
  String get strengthFair => 'Średnie';

  @override
  String get strengthGood => 'Dobre';

  @override
  String get strengthStrong => 'Silne';

  @override
  String passwordStrength(String strength) {
    return 'Siła hasła: $strength';
  }

  @override
  String get passwordHelperSignUp => '8+ znaków, w tym litera i cyfra';

  @override
  String get confirmPassword => 'Powtórz hasło';

  @override
  String get acceptTerms => 'Akceptuję warunki korzystania';

  @override
  String get haveAccount => 'Mam już konto';

  @override
  String get resetPasswordTitle => 'Resetowanie hasła';

  @override
  String get resetIntro => 'Podaj e-mail swojego konta, a wyślemy link do zresetowania hasła.';

  @override
  String resetSent(String email) {
    return 'Jeśli istnieje konto dla $email, wysłaliśmy link do zresetowania hasła. Sprawdź skrzynkę.';
  }

  @override
  String get sendResetLink => 'Wyślij link';

  @override
  String get backToSignIn => 'Wróć do logowania';

  @override
  String unlockWelcome(String name) {
    return 'Witaj ponownie, $name';
  }

  @override
  String get unlockTimedOut => 'Aplikacja zablokowała się po 5 minutach w tle.';

  @override
  String get unlockOnStart => 'Odblokowanie biometryczne jest włączone dla tej aplikacji.';

  @override
  String get unlockButton => 'Odblokuj biometrią';

  @override
  String get unlockPrompt => 'Użyj odcisku palca lub twarzy, aby odblokować';

  @override
  String get unlockPromptFaceId => 'Użyj Face ID, aby odblokować';

  @override
  String get unlockPromptTouchId => 'Użyj Touch ID, aby odblokować';

  @override
  String get unlockPromptFace => 'Użyj twarzy, aby odblokować';

  @override
  String get unlockPromptFingerprint => 'Użyj odcisku palca, aby odblokować';

  @override
  String get unlockFailed => 'Nie rozpoznano. Spróbuj ponownie lub użyj hasła.';

  @override
  String get usePasswordInstead => 'Użyj hasła';

  @override
  String get authTagline => 'Planuj, prowadź i raportuj inspekcje w terenie.';

  @override
  String get authTaglineSub => 'To samo konto i dane na iOS, Androidzie i w przeglądarce.';

  @override
  String pocBuild(String version) {
    return 'v$version · wersja PoC';
  }

  @override
  String fieldsNeedAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pola wymaga uwagi',
      many: '$count pól wymaga uwagi',
      few: '$count pola wymagają uwagi',
      one: '1 pole wymaga uwagi',
    );
    return '$_temp0';
  }

  @override
  String fieldNeedsAttention(String error) {
    return '1 pole wymaga uwagi: $error';
  }

  @override
  String inProgressLabel(String label) {
    return '$label, w toku';
  }

  @override
  String get valRequired => 'Pole wymagane';

  @override
  String get valEmail => 'Podaj poprawny e-mail, np. imie@example.com';

  @override
  String valMinLength(int n) {
    return 'Użyj co najmniej $n znaków';
  }

  @override
  String valMaxLength(int n) {
    return 'Użyj najwyżej $n znaków';
  }

  @override
  String get valInteger => 'Podaj liczbę całkowitą';

  @override
  String valIntRange(int min, int max) {
    return 'Podaj liczbę od $min do $max';
  }

  @override
  String get valDateInPast => 'Wybierz dzisiejszą lub późniejszą datę';

  @override
  String get valPasswordsDiffer => 'Hasła się różnią';

  @override
  String get valPasswordWeak => 'Użyj 8+ znaków, w tym litery i cyfry';

  @override
  String get valEmailTaken => 'Konto z tym adresem już istnieje';

  @override
  String get valMustAccept => 'Zaakceptuj warunki, aby kontynuować';

  @override
  String get valUnknownSite => 'Wybierz obiekt z listy';

  @override
  String get valChecklistIncomplete => 'Odpowiedz na każdy punkt listy kontrolnej';

  @override
  String get valCheckField => 'Sprawdź to pole';

  @override
  String get valSiteTooShort => 'Wybierz obiekt z listy lub dodaj nowy (min. 3 znaki)';

  @override
  String get valAnswerItem => 'Odpowiedz na ten punkt';

  @override
  String get valFailureNeedsDetail => 'Dodaj notatkę lub zdjęcie do tej niezgodności';

  @override
  String get valPhotoForFailure => 'Dodaj co najmniej jedno zdjęcie niespełnionych punktów';

  @override
  String valTooManyPhotos(int n) {
    return 'Dodaj najwyżej $n zdjęć';
  }

  @override
  String valFilesTooBig(String names) {
    return '$names: pliki mogą mieć najwyżej 20 MB';
  }

  @override
  String valBadFileType(String names) {
    return '$names: użyj JPG, PNG, HEIC lub PDF';
  }

  @override
  String get valConfirmFindings => 'Potwierdź ustalenia przed wysłaniem';

  @override
  String get valChecklistNotLoaded => 'Lista kontrolna jeszcze się nie wczytała';

  @override
  String get wizardDraftSaved => 'Szkic zapisany na tym urządzeniu';

  @override
  String get wizardProgress => 'Postęp kreatora';

  @override
  String get wizardSteps => 'Kroki kreatora';

  @override
  String get wizardHintSite => 'Wybierz obiekt';

  @override
  String get wizardHintDetails => 'Rodzaj, data i godzina';

  @override
  String wizardHintChecklist(int answered, int total) {
    return 'Odpowiedzi: $answered z $total';
  }

  @override
  String wizardHintPhotos(int photos, int files) {
    return 'Zdjęcia: $photos · pliki: $files';
  }

  @override
  String get wizardHintReview => 'Sprawdź i wyślij';

  @override
  String stepStateDone(String step) {
    return '$step, gotowe';
  }

  @override
  String stepStateAttention(String step) {
    return '$step, wymaga uwagi';
  }

  @override
  String stepStateCurrent(String step) {
    return '$step, bieżący krok';
  }

  @override
  String stepStateUpcoming(String step) {
    return '$step, nierozpoczęty';
  }

  @override
  String get wizardLoadFailed => 'Nie udało się wczytać tej inspekcji do edycji.';

  @override
  String get wizardRecoveredPhoto => 'Dodano zdjęcie zrobione przed zamknięciem aplikacji.';

  @override
  String get siteLabel => 'Obiekt';

  @override
  String get siteHelper => 'Szukaj po nazwie lub adresie';

  @override
  String get clear => 'Wyczyść';

  @override
  String newSite(String name) {
    return 'Nowy obiekt: $name';
  }

  @override
  String get newSiteHint => 'Zostanie utworzony po wysłaniu';

  @override
  String addNewSite(String name) {
    return 'Dodaj „$name” jako nowy obiekt';
  }

  @override
  String get yourLocation => 'Twoja lokalizacja';

  @override
  String get locationServiceOff => 'Lokalizacja jest wyłączona na tym urządzeniu.';

  @override
  String get locationDenied => 'Nie udzielono zgody na lokalizację. Sprawdzenie jest opcjonalne.';

  @override
  String get locationBlocked => 'Lokalizacja jest zablokowana dla tej aplikacji.';

  @override
  String get locationUnsupported => 'Lokalizacja nie jest tu dostępna.';

  @override
  String get locationError => 'Nie udało się ustalić pozycji. Spróbuj na zewnątrz lub przy oknie.';

  @override
  String get locationNotChecked => 'Jeszcze nie sprawdzono';

  @override
  String get locationOptional => 'Opcjonalnie: potwierdza, że jesteś na miejscu.';

  @override
  String locationAccuracy(String meters) {
    return 'Dokładność ±$meters m';
  }

  @override
  String locationFromSite(String distance) {
    return '$distance od obiektu';
  }

  @override
  String get locationFar => 'Wygląda na to, że jesteś ponad 200 m od adresu obiektu.';

  @override
  String get checkLocation => 'Sprawdź lokalizację';

  @override
  String get updateLocation => 'Odśwież lokalizację';

  @override
  String get inspectionType => 'Rodzaj inspekcji';

  @override
  String get dateLabel => 'Data';

  @override
  String get openCalendar => 'Otwórz kalendarz';

  @override
  String get startTime => 'Godzina rozpoczęcia';

  @override
  String get openTimePicker => 'Wybierz godzinę';

  @override
  String get priority => 'Priorytet';

  @override
  String get priorityLow => 'Niski';

  @override
  String get priorityNormal => 'Normalny';

  @override
  String get priorityHigh => 'Wysoki';

  @override
  String get durationLabel => 'Szacowany czas (minuty)';

  @override
  String get durationHelper => 'Od 15 do 480';

  @override
  String get notesLabel => 'Uwagi dla kierownika obiektu';

  @override
  String get optional => 'Opcjonalnie';

  @override
  String checklistProgress(String type, int answered, int total) {
    return '$type · odpowiedzi: $answered z $total';
  }

  @override
  String itemsNeedAttention(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count punktu wymaga uwagi',
      many: '$count punktów wymaga uwagi',
      few: '$count punkty wymagają uwagi',
      one: '1 punkt wymaga uwagi',
    );
    return '$_temp0';
  }

  @override
  String get jumpToFirst => 'Przejdź do pierwszego';

  @override
  String get checklistLoadFailed => 'Nie udało się wczytać listy kontrolnej.';

  @override
  String get answerPass => 'Spełnia';

  @override
  String get answerFail => 'Nie spełnia';

  @override
  String get answerNa => 'Nie dotyczy';

  @override
  String get severity => 'Waga';

  @override
  String severityValue(int level, String label) {
    return '$level · $label';
  }

  @override
  String get severityMinor => 'Drobna';

  @override
  String get severityLow => 'Niska';

  @override
  String get severityMajor => 'Istotna';

  @override
  String get severityHigh => 'Wysoka';

  @override
  String get severityCritical => 'Krytyczna';

  @override
  String severitySemantics(String value) {
    return 'Waga $value';
  }

  @override
  String get followUpVisit => 'Wymaga ponownej wizyty';

  @override
  String get whatIsWrong => 'Co jest nie tak?';

  @override
  String get addPhoto => 'Dodaj zdjęcie';

  @override
  String addPhotoCount(int count) {
    return 'Dodaj zdjęcie ($count)';
  }

  @override
  String get dictateNote => 'Dyktuj notatkę (poza PoC)';

  @override
  String get photoTypeHint => 'Użyj JPG, PNG lub HEIC do 20 MB.';

  @override
  String fileRejected(String name) {
    return '$name: użyj JPG, PNG, HEIC lub PDF do 20 MB.';
  }

  @override
  String get cameraOpenFailed => 'Nie udało się otworzyć aparatu.';

  @override
  String get galleryOpenFailed => 'Nie udało się otworzyć galerii.';

  @override
  String photoN(int n) {
    return 'Zdjęcie $n';
  }

  @override
  String photoNForFailure(int n) {
    return 'Zdjęcie $n, do niespełnionego punktu';
  }

  @override
  String removePhotoN(int n) {
    return 'Usuń zdjęcie $n';
  }

  @override
  String get useCamera => 'Użyj kamery';

  @override
  String get takePhoto => 'Zrób zdjęcie';

  @override
  String get gallery => 'Galeria';

  @override
  String get dropFiles => 'Upuść pliki, aby je dodać';

  @override
  String get dragOrPaste => 'Przeciągnij tu pliki lub wklej obraz';

  @override
  String get fileTypesHint => 'JPG, PNG, HEIC lub PDF, do 20 MB każdy.';

  @override
  String get photosIntro => 'Dodaj zdjęcia ustaleń i dokumenty otrzymane na obiekcie.';

  @override
  String get cameraOff => 'Dostęp do aparatu jest wyłączony. Nadal możesz wybrać zdjęcia z galerii.';

  @override
  String get photoLibraryOff => 'Dostęp do zdjęć jest wyłączony. Możesz go włączyć w Ustawieniach.';

  @override
  String photosCount(int count) {
    return 'Zdjęcia · $count';
  }

  @override
  String filesCount(int count) {
    return 'Pliki · $count';
  }

  @override
  String get attachFile => 'Dołącz plik';

  @override
  String removeFile(String name) {
    return 'Usuń $name';
  }

  @override
  String fileSavedOnDevice(int size) {
    return '$size KB · zapisano na tym urządzeniu';
  }

  @override
  String fileOnServer(int size) {
    return '$size KB · już wysłany';
  }

  @override
  String get noDate => 'Brak daty';

  @override
  String reviewDetails(String type, String when, String priority, String duration) {
    return '$type · $when · priorytet: $priority · $duration min';
  }

  @override
  String reviewChecklist(int answered, int total, int failed) {
    return 'Odpowiedzi: $answered z $total · niespełnione: $failed';
  }

  @override
  String get reviewFollowUp => 'potrzebna ponowna wizyta';

  @override
  String get reviewOffline => 'Jesteś offline. Raport zostanie zapisany na tym urządzeniu i wysłany automatycznie po powrocie sieci.';

  @override
  String submitFailed(String code) {
    return 'Nie udało się wysłać ($code). Spróbuj ponownie.';
  }

  @override
  String serverRejected(String fields) {
    return 'Serwer odrzucił: $fields';
  }

  @override
  String get fixStepsToSubmit => 'Popraw kroki oznaczone na czerwono i potwierdź ustalenia, aby wysłać.';

  @override
  String get reportQueuedTitle => 'Raport zapisany w kolejce';

  @override
  String get reportSubmittedTitle => 'Raport wysłany';

  @override
  String get reportQueuedBody => 'Zostanie wysłany automatycznie po powrocie sieci.';

  @override
  String get reportSubmittedBody => 'Kierownik obiektu otrzymuje teraz raport.';

  @override
  String get viewInspection => 'Zobacz inspekcję';

  @override
  String get sharePdfReport => 'Udostępnij raport PDF';

  @override
  String get pdfFailed => 'Nie udało się utworzyć raportu PDF. Spróbuj ponownie, gdy będziesz online.';

  @override
  String get typesLoadFailed => 'Nie udało się wczytać rodzajów inspekcji.';

  @override
  String get archiveFailed => 'Nie udało się zarchiwizować. Spróbuj ponownie, gdy będziesz online.';

  @override
  String get undoFailed => 'Nie udało się cofnąć. Inspekcja pozostaje w archiwum.';

  @override
  String linkCopied(String link) {
    return 'Skopiowano link: $link';
  }

  @override
  String get statusFilter => 'Filtr statusu';

  @override
  String get noConnection => 'Brak połączenia';

  @override
  String errorCode(String code) {
    return 'Kod błędu: $code';
  }

  @override
  String get noMatchAny => 'Nic nie pasuje do tych filtrów.';

  @override
  String noMatchStatuses(String statuses) {
    return 'Nic ze statusem $statuses nie pasuje do tych filtrów.';
  }

  @override
  String noMatchSearch(String q) {
    return 'Nic z „$q” w nazwie. Wybierz inny status lub wyczyść wyszukiwanie.';
  }

  @override
  String get loadMoreFailed => 'Nie udało się wczytać kolejnych.';

  @override
  String actionsFor(String id) {
    return 'Akcje dla $id';
  }

  @override
  String get columnId => 'ID';

  @override
  String get statusLabel => 'Status';

  @override
  String sortByColumn(String column) {
    return 'Sortuj według: $column';
  }

  @override
  String get chooseDates => 'Wybierz daty';

  @override
  String get rangeEndBeforeStart => 'Data końcowa nie może być wcześniejsza niż początkowa';

  @override
  String inspectionNotFoundBody(String id) {
    return 'Nie ma inspekcji $id. Mogła zostać usunięta albo link jest błędny.';
  }

  @override
  String loadDetailFailed(String id) {
    return 'Nie udało się wczytać $id';
  }

  @override
  String get offlineTryAgain => 'Jesteś offline. Połącz się i spróbuj ponownie.';

  @override
  String get somethingWentWrong => 'Coś poszło nie tak.';

  @override
  String get loadingInspection => 'Wczytywanie inspekcji';

  @override
  String get loadingInspections => 'Wczytywanie inspekcji';

  @override
  String get sitePhotoPlaceholder => 'Miejsce na zdjęcie obiektu';

  @override
  String get moreOptions => 'Więcej opcji';

  @override
  String get inspectionTitle => 'Inspekcja';

  @override
  String checklistTemplateItems(int total) {
    return 'Szablon listy kontrolnej v3 · punkty: $total';
  }

  @override
  String get answerToDo => 'Do zrobienia';

  @override
  String get noPhotosTitle => 'Brak zdjęć';

  @override
  String get noPhotosBody => 'Tu pojawią się zdjęcia zrobione podczas inspekcji.';

  @override
  String selectedCount(int n) {
    return 'Zaznaczono: $n';
  }

  @override
  String get selectPhotosHint => 'Przytrzymaj zdjęcie lub użyj „Zaznacz”, aby wybrać kilka.';

  @override
  String get select => 'Zaznacz';

  @override
  String get shareSelected => 'Udostępnij zaznaczone';

  @override
  String get cancelSelection => 'Anuluj zaznaczenie';

  @override
  String openPhotoOf(int n, int total) {
    return 'Otwórz zdjęcie $n z $total';
  }

  @override
  String get photoNotFound => 'Nie znaleziono zdjęcia';

  @override
  String photoNotFoundBody(String photo, String id) {
    return 'Inspekcja $id nie ma zdjęcia $photo.';
  }

  @override
  String get closeViewer => 'Zamknij podgląd';

  @override
  String photoCounter(int n, int total) {
    return '$n z $total';
  }

  @override
  String get sharePhoto => 'Udostępnij zdjęcie';

  @override
  String photoCaption(int n, String caption) {
    return 'Zdjęcie $n: $caption';
  }

  @override
  String get noMapLocation => 'Brak lokalizacji tego obiektu na mapie.';

  @override
  String get mapsOpenFailed => 'Nie udało się otworzyć map.';

  @override
  String noPhoneFor(String name) {
    return 'Brak numeru telefonu: $name.';
  }

  @override
  String callPerson(String name, String phone) {
    return 'Zadzwoń: $name, $phone';
  }

  @override
  String inspectionNamed(String id) {
    return 'Inspekcja $id';
  }

  @override
  String get sharingUnavailable => 'Udostępnianie nie jest tu dostępne; skopiowano link.';

  @override
  String get preparingPdf => 'Przygotowuję raport PDF…';

  @override
  String pdfDownloaded(String file) {
    return 'Pobrano raport: $file';
  }

  @override
  String pdfFooter(int page, int total, String date) {
    return 'Strona $page z $total | utworzono $date';
  }

  @override
  String get pdfAddress => 'Adres';

  @override
  String get pdfType => 'Rodzaj';

  @override
  String get pdfSiteManager => 'Kierownik obiektu';

  @override
  String get pdfInspector => 'Inspektor';

  @override
  String pdfChecklistSummary(int answered, int total, int failed) {
    return 'Lista kontrolna: odpowiedzi $answered z $total, niespełnione: $failed';
  }

  @override
  String get pdfItem => 'Punkt';

  @override
  String get pdfResult => 'Wynik';

  @override
  String get todaySection => 'Dzisiaj';

  @override
  String get noNotificationsTitle => 'Brak powiadomień';

  @override
  String get noNotificationsBody => 'Wszystko przeczytane.';

  @override
  String get notificationsLoadFailed => 'Nie udało się wczytać powiadomień.';

  @override
  String get dismiss => 'Odrzuć';

  @override
  String get unread => 'Nieprzeczytane';

  @override
  String get remindersOnMessage => 'Przypomnienia włączone: 30 minut przed każdą inspekcją.';

  @override
  String get remindersWebTest => 'Przeglądarki nie planują powiadomień. Testowe działają z testera linków, gdy ta karta jest otwarta.';

  @override
  String get mapLocationDenied => 'Nie udzielono zgody na lokalizację.';

  @override
  String get mapLocationBlocked => 'Lokalizacja jest zablokowana dla tej aplikacji. Włącz ją w ustawieniach.';

  @override
  String get mapLocationErrorWeb => 'Nie udało się ustalić lokalizacji. Przeglądarka wymaga HTTPS i twojej zgody.';

  @override
  String get mapLocationError => 'Nie udało się ustalić lokalizacji.';

  @override
  String noSiteMatches(String q) {
    return 'Żaden obiekt nie pasuje do „$q”.';
  }

  @override
  String get searchSites => 'Szukaj obiektów';

  @override
  String get showMyLocation => 'Pokaż moją lokalizację';

  @override
  String distanceAway(String distance) {
    return '$distance stąd';
  }

  @override
  String get openInspection => 'Otwórz inspekcję';

  @override
  String get mapLoadFailed => 'Nie udało się wczytać inspekcji na mapę.';

  @override
  String get goHome => 'Przejdź do strony głównej';

  @override
  String get pageNotFound => 'Nie znaleziono strony';

  @override
  String get pageNotFoundBody => 'Pod tym adresem nic nie ma. Link może być nieaktualny albo inspekcja została usunięta.';

  @override
  String get openInspections => 'Otwórz inspekcje';

  @override
  String pdfSaved(String file) {
    return 'Zapisano raport: $file';
  }

  @override
  String get remindersUnsupported => 'Ta platforma nie planuje powiadomień, więc przypomnienia są tu wyłączone.';

  @override
  String get remindersOffLinux => 'Linux pokazuje powiadomienia tylko przy otwartej aplikacji i nie umie ich planować.';

  @override
  String get remindersLinuxTest => 'Linux nie planuje powiadomień. Testowe działają z testera linków, gdy aplikacja jest otwarta.';

  @override
  String get dragFiles => 'Przeciągnij tu pliki';

  @override
  String get mapLabel => 'Mapa obiektów inspekcji';
}
