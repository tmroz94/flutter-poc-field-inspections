import 'package:field_inspections/core/router/guards.dart';
import 'package:field_inspections/features/auth/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? redirect(String location, AuthStatus auth, {bool locked = false}) =>
      resolveRedirect(Uri.parse(location), GuardInput(auth: auth, locked: locked));

  group('while the session is restoring', () {
    test('stays put: the app shows a splash without changing the URL', () {
      expect(redirect('/inspections/INS-1042?tab=photos', AuthStatus.restoring), isNull);
      expect(redirect('/home', AuthStatus.restoring), isNull);
      expect(redirect('/sign-in', AuthStatus.restoring), isNull);
    });
  });

  group('signed out', () {
    test('guarded paths go to sign-in with from', () {
      expect(redirect('/inspections/INS-1038', AuthStatus.signedOut), '/sign-in?from=%2Finspections%2FINS-1038');
      expect(redirect('/settings/poc/results/maps', AuthStatus.signedOut), '/sign-in?from=%2Fsettings%2Fpoc%2Fresults%2Fmaps');
    });
    test('home goes to sign-in without a from', () => expect(redirect('/home', AuthStatus.signedOut), '/sign-in'));
    test('public pages are allowed', () {
      expect(redirect('/sign-in', AuthStatus.signedOut), isNull);
      expect(redirect('/sign-up', AuthStatus.signedOut), isNull);
      expect(redirect('/forgot-password', AuthStatus.signedOut), isNull);
    });
    test('unlock is not reachable', () => expect(redirect('/unlock', AuthStatus.signedOut), '/sign-in'));
    test('splash resolves to the target, which then needs sign-in', () {
      expect(redirect('/splash?from=/map', AuthStatus.signedOut), '/sign-in?from=%2Fmap');
      expect(redirect('/splash', AuthStatus.signedOut), '/sign-in');
    });
  });

  group('signed in', () {
    test('guarded paths are allowed', () {
      expect(redirect('/inspections/INS-1042', AuthStatus.signedIn), isNull);
      expect(redirect('/notifications', AuthStatus.signedIn), isNull);
    });
    test('sign-in, sign-up and forgot-password are blocked', () {
      expect(redirect('/sign-in', AuthStatus.signedIn), '/home');
      expect(redirect('/sign-up', AuthStatus.signedIn), '/home');
      expect(redirect('/forgot-password', AuthStatus.signedIn), '/home');
    });
    test('sign-in returns to a safe from', () {
      expect(redirect('/sign-in?from=%2Finspections%2FINS-1042%3Ftab%3Dphotos', AuthStatus.signedIn), '/inspections/INS-1042?tab=photos');
    });
    test('sign-in ignores unsafe or unknown from values', () {
      for (final from in ['https://evil.example/x', '//evil.example', r'/\evil', '/sign-up', '/unlock', '/no-such-page', 'inspections']) {
        expect(redirect('/sign-in?from=${Uri.encodeComponent(from)}', AuthStatus.signedIn), '/home', reason: from);
      }
    });
    test('splash and root go to the target or home', () {
      expect(redirect('/splash?from=%2Fmap%3Fsite%3Ds-1', AuthStatus.signedIn), '/map?site=s-1');
      expect(redirect('/splash', AuthStatus.signedIn), '/home');
      expect(redirect('/', AuthStatus.signedIn), '/home');
    });
    test('unlock is left once unlocked', () {
      expect(redirect('/unlock?from=%2Fsettings', AuthStatus.signedIn), '/settings');
      expect(redirect('/unlock', AuthStatus.signedIn), '/home');
    });
  });

  group('signed in and locked', () {
    test('everything goes to unlock with from', () {
      expect(redirect('/inspections/INS-1042', AuthStatus.signedIn, locked: true), '/unlock?from=%2Finspections%2FINS-1042');
      expect(redirect('/home', AuthStatus.signedIn, locked: true), '/unlock');
    });
    test('unlock stays', () => expect(redirect('/unlock?from=%2Fmap', AuthStatus.signedIn, locked: true), isNull));
    test('a cold-start target survives splash then lock', () {
      expect(redirect('/splash?from=%2Fnotifications', AuthStatus.signedIn, locked: true), '/unlock?from=%2Fnotifications');
    });
  });

  group('platform deep links with a scheme', () {
    test('custom scheme becomes an in-app path, then the guards apply', () {
      expect(redirect('fieldinspections://app/inspections/INS-1042?tab=photos', AuthStatus.signedIn), '/inspections/INS-1042?tab=photos');
      expect(
        redirect('fieldinspections://app/inspections/INS-1042?tab=photos', AuthStatus.signedOut),
        '/sign-in?from=%2Finspections%2FINS-1042%3Ftab%3Dphotos',
      );
      expect(redirect('fieldinspections://app/map', AuthStatus.restoring), '/map');
    });
    test('universal/app links on the web host work the same way', () {
      expect(redirect('https://fieldinspections.example/notifications', AuthStatus.signedIn), '/notifications');
    });
    test('foreign links go home', () {
      expect(redirect('https://evil.example/inspections', AuthStatus.signedIn), '/home');
      expect(redirect('fieldinspections://other/inspections', AuthStatus.signedOut), '/sign-in');
    });
  });

  test('unknown paths are never redirected, so the 404 shows', () {
    for (final auth in AuthStatus.values) {
      expect(redirect('/nope/here', auth), isNull);
      expect(redirect('/inspections/INS-1/unknown', auth), isNull);
    }
  });
}
