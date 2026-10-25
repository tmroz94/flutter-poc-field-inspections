import 'package:field_inspections/core/storage/key_value_store.dart';
import 'package:field_inspections/data/local/local_store.dart';
import 'package:field_inspections/data/models/draft.dart';
import 'package:field_inspections/features/auth/auth_screens.dart';
import 'package:field_inspections/features/home/home_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  group('sign in (P01/D01)', () {
    testWidgets('empty submit shows errors and focuses the first invalid field', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Required'), findsNWidgets(2));
      final email = tester.widget<EditableText>(find.descendant(of: field('Email'), matching: find.byType(EditableText)));
      expect(email.focusNode.hasFocus, isTrue);
    });

    testWidgets('validates email format and password length', (tester) async {
      await pumpApp(tester);
      await tester.enterText(field('Email'), 'anna');
      await tester.enterText(field('Password'), 'abc12');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email, like name@example.com'), findsOneWidget);
      expect(find.text('Use 8 or more characters'), findsWidgets);
    });

    testWidgets('wrong password shows a form error and stays', (tester) async {
      await pumpApp(tester);
      await tester.enterText(field('Email'), 'anna.nowak@example.com');
      await tester.enterText(field('Password'), 'wrongpass1');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      expect(find.byType(SignInScreen), findsOneWidget);
    });

    testWidgets('correct credentials sign in and persist the session', (tester) async {
      final app = await pumpApp(tester);
      await tester.enterText(field('Email'), 'anna.nowak@example.com');
      await tester.enterText(field('Password'), 'inspect123');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect((app.container.read(keyValueStoreProvider) as MemoryStore).values.containsKey('session'), isTrue);
    });

    testWidgets('"Keep me signed in" off keeps the session in memory only', (tester) async {
      final app = await pumpApp(tester);
      await tester.tap(find.text('Keep me signed in'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Use demo account'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect((app.container.read(keyValueStoreProvider) as MemoryStore).values.containsKey('session'), isFalse);
    });

    testWidgets('password visibility toggle', (tester) async {
      await pumpApp(tester);
      EditableText pw() => tester.widget(find.descendant(of: field('Password'), matching: find.byType(EditableText)));
      expect(pw().obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(pw().obscureText, isFalse);
    });

    testWidgets('desktop shows the brand panel (D01)', (tester) async {
      await pumpApp(tester, size: desktopSize);
      expect(find.text('Plan, run and report site inspections.'), findsOneWidget);
    });
  });

  group('sign up', () {
    Future<void> fill(
      WidgetTester tester, {
      String name = 'Jan Kowalski',
      String email = 'jan@example.com',
      String pw = 'abcd1234',
      String? confirm,
    }) async {
      await tester.enterText(field('Full name'), name);
      await tester.enterText(field('Email'), email);
      await tester.enterText(field('Password'), pw);
      await tester.enterText(field('Confirm password'), confirm ?? pw);
    }

    Future<void> submit(WidgetTester tester) async {
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Create account'));
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();
    }

    testWidgets('weak password, mismatch and terms are enforced', (tester) async {
      final app = await pumpApp(tester);
      await app.go('/sign-up');
      await fill(tester, pw: 'password', confirm: 'different');
      await submit(tester);
      expect(find.text('Use 8+ characters with a letter and a digit'), findsOneWidget);
      expect(find.text("Passwords don't match"), findsOneWidget);
      expect(find.text('Accept the terms to continue'), findsOneWidget);
      expect(find.byType(SignUpScreen), findsOneWidget);
    });

    testWidgets('an email that is already registered is rejected', (tester) async {
      final app = await pumpApp(tester);
      await app.go('/sign-up');
      await fill(tester, email: 'anna.nowak@example.com');
      await tester.tap(find.text('I accept the terms of use'));
      await submit(tester);
      expect(find.text('An account with this email already exists'), findsOneWidget);
    });

    testWidgets('valid form creates the account and signs in', (tester) async {
      final app = await pumpApp(tester);
      await app.go('/sign-up');
      await fill(tester);
      await tester.tap(find.text('I accept the terms of use'));
      await submit(tester);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.textContaining('Jan'), findsWidgets);
    });
  });

  testWidgets('forgot password always shows the same neutral message', (tester) async {
    final app = await pumpApp(tester);
    await app.go('/forgot-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);
    await tester.enterText(field('Email'), 'nobody@example.com');
    await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
    await tester.pumpAndSettle();
    expect(find.textContaining('If an account exists for nobody@example.com'), findsOneWidget);
  });

  group('sign out (P19)', () {
    testWidgets('lists unsent work and deletes it on confirm', (tester) async {
      final local = MemoryLocalStore();
      await local.saveDraft('new', const InspectionDraft(siteName: 'Depot', notes: 'n'));
      await local.enqueue(kind: 'create', site: 'Depot', body: {'site': 'Depot'});
      // Desktop: the whole settings list fits, nothing to scroll past.
      final app = await pumpApp(tester, store: signedInStore(), localStore: local, initialLocation: '/settings', size: desktopSize);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      expect(find.descendant(of: dialog, matching: find.textContaining('1 report not sent yet')), findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.textContaining('1 draft')), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(app.location, '/settings', reason: 'Cancel keeps the session');

      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out and delete'));
      await tester.pumpAndSettle();
      expect(app.location, startsWith('/sign-in'));
      expect(local.drafts, isEmpty);
      expect(local.entries, isEmpty);
    });

    testWidgets('signs out at once when nothing is waiting', (tester) async {
      final app = await pumpApp(tester, store: signedInStore(), initialLocation: '/settings', size: desktopSize);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(app.location, startsWith('/sign-in'));
    });
  });
}
