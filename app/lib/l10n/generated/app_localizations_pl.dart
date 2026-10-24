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
}
