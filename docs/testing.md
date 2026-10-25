# Testing

Everything below runs from the repo root unless a folder is named. Flutter is
pinned by `.fvmrc`, so commands go through `fvm`.

## Quality gate

```bash
pwsh tool/check.ps1
```

On macOS/Linux use `tool/check.sh`. It runs, and fails on the first problem in
each step:

1. `dart format` check (page width 140) on all packages.
2. `dart analyze --fatal-infos` for `packages/mock_data` and `mock_server`, then
   `flutter analyze --fatal-infos` for the app.
3. Tests for `packages/mock_data`, `mock_server` and the app (unit, widget,
   router, accessibility and golden tests).

Add `-Coverage` (or `--coverage` to `check.sh`) to write `app/coverage/lcov.info`.

## What the app tests cover

| Folder | Kind | Examples |
|---|---|---|
| `app/test/core/` | Router, guards, deep links, validators, layout | every route opens its screen; guards redirect signed-out users and keep `from`; scheme links; browser history entries |
| `app/test/data/` | Unit | list queries, API client error mapping, outbox and sync |
| `app/test/features/` | Widget | auth forms, lists and filters, detail tabs, every wizard step and its validators, platform integrations through fakes, results tracker, adaptive widgets, diagnostics |
| `app/test/a11y/` | Accessibility | key screens against Flutter's guidelines (48 dp Android and 44 pt iOS tap targets, labelled targets, text contrast); the same screens at 200 % text must not overflow |
| `app/test/golden/` | Golden images | 7 phone screens in light, dark and high contrast; 4 desktop screens in light and dark |
| `app/integration_test/` | On a device | see "Device tests" below |

`app/test/helpers/test_app.dart` pumps the whole app with in-memory stores, a
zero-latency fake backend and fakes for every platform service
(`app/test/helpers/fakes.dart`), at phone, tablet or desktop size, as Android,
iOS or web.

## Golden tests

Reference images live in `app/test/golden/goldens/`. They are made on Windows
and skipped on other systems, because font rasterisation differs per OS. The
tests load Roboto and the icon fonts from the Flutter SDK, draw real shadows and
freeze the clock (Tuesday 20 October 2026, 09:30), so dates and greetings don't
change from day to day.

After an intended UI change, regenerate and review the images:

```bash
cd app && fvm flutter test --update-goldens test/golden
```

## Device tests (Android)

`app/integration_test/` runs on an emulator or phone with the real stores
(shared_preferences, SQLite through drift):

| File | Flows |
|---|---|
| `app_test.dart` | deep link while signed out → sign in → detail → back; session and wizard draft surviving a restart; live re-theme and language switch |
| `ui_flows_test.dart` | full wizard (autocomplete, dropdown, date and time pickers, segmented answers for all 18 items, animated photo grid, success animation); list fling to page 2, pull to refresh, swipe to archive and Undo; Hero and page transitions, and none under reduced motion; keyboard Next/Done actions; filter sheet controls. Prints frame timings for the animated parts |
| `host_test.dart` | needs the host: airplane mode on → offline state → submit queued → airplane mode off → outbox syncs to the mock server; GPS position next to the site and 7 km away (warning) |

Run everything with the host helper, which starts the mock API when needed and
carries out the `HOST>` requests the tests print (airplane mode, location
permission, test GPS positions) with `adb`:

```bash
fvm dart tool/android_device_tests.dart --device emulator-5554
```

`--only ui_flows` (or `app`, `host`) runs one file. Without the helper,
`cd app && fvm flutter test integration_test -d emulator-5554` runs the same
files and skips the host-driven tests. The helper always switches airplane mode
off and removes the test GPS provider at the end.

Limits:
- The photo step uses a fake camera, because the system camera app is native UI
  that `integration_test` can't drive (the Patrol tests below cover it).
- GPS positions come from Android's test location provider. Google Play
  services' fused provider (what the app uses on phones) ignores those, so the
  GPS test reads Android's LocationManager instead; a real-GPS check on a phone
  is still needed.
- Frame timings are from debug builds, which are much slower than release ones.

On the Mac, the same files run on an iOS simulator
(`cd app && fvm flutter test integration_test -d <simulator-id>`); the host
helper is Android-only for now.

## Native UI tests with Patrol (Android)

`app/patrol_test/native_test.dart` uses [Patrol](https://patrol.leancode.co) to
tap system UI that Flutter's own tests can't reach:

| Test | What it drives |
|---|---|
| Location Deny / Allow | the system permission dialog; Deny shows the app's explanation |
| Camera | the system camera app (shutter, done); the photo lands in the wizard's grid |
| Gallery | the system photo picker; the picked photo lands in the grid |
| Export PDF | the system share sheet opens with the PDF; Back returns to the app |
| Biometric unlock | the system prompt when turning the lock on, then again after 5 minutes in the background (the lock's clock is moved forward) |

The host helper also checks **a notification tap after the app was killed**,
with the real app and no test harness: it opens the deep-link tester, signs in,
sends a test notification (15 s), goes Home, kills the process with `am kill`
(as Android does under memory pressure; `force-stop` would cancel the alarm),
taps the notification in the shade and waits for the route's screen.

One-time setup: `fvm dart pub global activate patrol_cli`, and a JDK (the helper
uses `JAVA_HOME`, else Android Studio's bundled one). Then:

```bash
fvm dart tool/android_device_tests.dart --patrol
```

`--only native` or `--only kill` runs one part. For the run, the helper puts a
test photo in Pictures and sets the screen-lock PIN `1111` (the emulator has no
fingerprint enrolled, so the system prompt falls back to the PIN); it removes
both afterwards.

Notes:
- The Allow-location test runs last: clearing app data before the next test
  resets the granted permission, and Android then kills the app's processes,
  which crashed the following test.
- Patrol installs an APK whose entry point is its test bundle, so the
  notification check installs a normal debug build instead.
- Fingerprint enrollment itself isn't automated; the system prompt is the same,
  but the fingerprint path needs a phone or a manual emulator enrollment.

Chrome needs chromedriver running on port 4444, then:

```bash
cd app && fvm flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d chrome
```

This hasn't been run here yet: chromedriver isn't installed on this machine.

## Web: JavaScript vs WebAssembly

Build both and serve them side by side (`.claude/launch.json` has the same
entries as `web-js` and `web-wasm`):

```bash
cd app && fvm flutter build web --release -o build/web-js && fvm flutter build web --release --wasm -o build/web-wasm
```

```bash
python tool/serve_web.py 5174 build/web-js
```

```bash
python tool/serve_web.py 5176 build/web-wasm --isolate
```

`--isolate` sends COOP/COEP headers. The page is then cross-origin isolated, so
Skwasm can render on a worker thread and drift stores SQLite in OPFS.

To compare smoothness, open **Settings › Diagnostics** in each build, tap
**Reset frame stats**, use the screen you want to measure (for example scroll
the inspections table), then come back. Diagnostics shows the frame count,
average build and raster time, and the share of frames over 16 ms. Measure in
a visible, focused window: hidden tabs are throttled.

Measured so far: see "Web builds" in `platform-setup.md`.

## Manual checks

`docs/platform-setup.md` lists what has been verified by hand on each platform.
Record results in the app's **PoC results** tracker (Settings › PoC tools) and
export them as CSV or JSON.
