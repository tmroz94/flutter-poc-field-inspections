# Testing

Everything below runs from the repo root unless a folder is named. Flutter is
pinned by `.fvmrc`, so commands go through `fvm`.

## Quality gate

```bash
pwsh tool/check.ps1
```

On macOS/Linux use `tool/check.sh`. Both use FVM when it is installed and
`flutter`/`dart` from PATH otherwise. They run every step, even after one
fails, and exit non-zero with the list of failed steps:

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
| `app/test/data/` | Unit | list queries, API client error mapping, outbox sync (`sync_service_test.dart`: one run at a time, rejected and 401 entries, Retry) |
| `app/test/features/` | Widget and unit | auth forms, session restore and the sign-out wipe (`auth_session_test.dart`), lists and filters, detail tabs, every wizard step and its validators, drafts and the offline outbox (`wizard_logic_test.dart`), editing an inspection, notifications, map, shell and reminders, platform integrations through fakes, appearance, results tracker, adaptive widgets, diagnostics |
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

The Linux quality gate skips them, so CI checks them in a separate Windows job,
started by hand (Actions › Golden tests (Windows) › Run workflow,
`.github/workflows/goldens.yml`). On a mismatch it uploads
`app/test/golden/failures/` (expected, actual and diff images) as the
`golden-failures` artifact. The runner's Windows Server version differs from a
Windows 11 PC; if its first run reports differences in text only, compare the
diff images before regenerating anything.

## Device tests

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
files and skips the host-driven tests.

The helper:
- resets a mock API that is already running on :8080 to its fixtures
  (`POST /api/admin/reset`), or starts one (`dart pub get` included);
- accepts only the whitelisted `HOST>` commands, and fails the run when one of
  them, or any `adb` command it needs, fails;
- switches airplane mode off and removes the test GPS provider at the end, also
  when the run is stopped with Ctrl+C (or SIGTERM, a cancelled CI job).

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
helper is Android-only for now. On an iPhone 18 Pro simulator (iOS 27.0,
Xcode 27.1, 26 October 2026) the 7 shared flows pass and the 2 host-driven
ones skip; the first run builds once per file (~45 s, then ~27 s) and the
plugins come in through Swift Package Manager, so there is no Podfile.

### In Chrome

The same `integration_test` files run in Chrome through `flutter drive` and
chromedriver (Chrome for Testing, matching the installed Chrome's major
version; here `D:/tools/chromedriver/chromedriver-win64`):

```bash
D:/tools/chromedriver/chromedriver-win64/chromedriver.exe --port=4444
```

```bash
cd app && fvm flutter drive --driver=test_driver/integration_test.dart --target=integration_test/app_test.dart -d web-server --browser-name=chrome
```

Use `-d web-server --browser-name=chrome` (chromedriver opens the browser);
`-d chrome` hung waiting for its debug connection. The flows adapt to the
layout: the browser window is desktop-sized, so they use the Refresh button,
row menus and "Load more" where phones use pull to refresh, swipe and
infinite scroll. `host_test.dart` is Android-only and skips itself. CI runs
`app_test` and `ui_flows_test` this way, headless.

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

One-time setup: `fvm dart pub global activate patrol_cli 4.8.0` (patrol_cli
4.7.0 and later work with the app's `patrol` 4.10; see Patrol's compatibility
table before changing either), and a JDK (the helper uses `JAVA_HOME`, else
Android Studio's bundled one). Then:

```bash
fvm dart tool/android_device_tests.dart --patrol
```

`--only native` or `--only kill` runs one part. For the run, the helper puts a
test photo in Pictures and sets the screen-lock PIN `1111` (the emulator has no
fingerprint enrolled, so the system prompt falls back to the PIN); it removes
both afterwards, also on Ctrl+C. Setting the PIN fails, and so does the run,
when the device already has a screen lock: the helper never clears a lock it
didn't set.

Notes:
- The Allow-location test runs last: clearing app data before the next test
  resets the granted permission, and Android then kills the app's processes,
  which crashed the following test.
- Patrol installs an APK whose entry point is its test bundle, so the
  notification check installs a normal debug build instead.
- Fingerprint enrollment itself isn't automated; the system prompt is the same,
  but the fingerprint path needs a phone or a manual emulator enrollment.

## Web: browser prompts and JS vs WebAssembly (Playwright)

`web_e2e/` holds Playwright tests that drive the release web builds in the
installed Chrome (no browser download; `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` when
installing). They find widgets through Flutter's accessibility tree, which the
helper switches on (`web_e2e/tests/flutter.ts`).

| Spec | What it checks |
|---|---|
| `prompts.spec.ts` | a test notification is shown by the plugin's service worker and a click opens its route; with the tab closed, the worker's own click handler (with `clients` stubbed, since only a real click may open a window) builds a URL that leads to the route; location granted (distance, then 7 km away with the warning) and denied; "Use camera" opens the browser file input and the photo lands in the grid |
| `perf.spec.ts` | the JS and WebAssembly builds side by side: cold load to the first frame, frame pacing while scrolling the table, and the app's own engine timings from Diagnostics; 3 runs each, results in `web_e2e/perf-results/perf.json` (kept between runs, git-ignored); a measurement with only loose sanity checks |

Build both variants, then run:

```bash
cd app && fvm flutter build web --release -o build/web-js && fvm flutter build web --release --wasm -o build/web-wasm
```

```bash
cd web_e2e && npm install && npx playwright test
```

Playwright starts `tool/serve_web.py` for both builds (JS on 5174, WebAssembly
on 5176 with `--isolate`). The `perf` project opens a visible Chrome window,
because hidden or occluded windows are throttled; the `prompts` project runs
headless. Results so far: "Web builds" in `platform-setup.md`.

To compare by hand instead, open **Settings › Diagnostics** in each build, tap
**Reset frame stats**, use the screen you want to measure, then come back.

## Desktop apps

The shared flows (`app_test`, `ui_flows_test`) run on the desktop apps too, one
file per run (a second launch in the same `flutter test` call can lose its
debug connection):

```bash
cd app && fvm flutter test integration_test/app_test.dart -d macos
```

`integration_test/platform_probe_test.dart` asks the real plugins what they can
do, without showing system prompts, and prints a `PROBE` line for each: device
info, notification and location permission state, the biometrics the lock
could use, and map tiles loaded over the network. It runs on any target and
fails only when a plugin is missing or broken.

The Linux app can be built and tested from a Mac with Docker running:

```bash
tool/linux_container/test.sh
```

It builds the image in `tool/linux_container/` (Ubuntu 24.04, Flutter from
`.fvmrc`, a virtual display and a session bus), copies the tracked files in,
builds the release app and runs both flow files and the probe. On Apple
silicon the container is arm64, so it checks the Linux code rather than CI's
x64 binary.

## CI (GitHub Actions)

| Workflow | When | What |
|---|---|---|
| `ci.yml` | every push and pull request | quality gate (`tool/check.sh --coverage`; goldens skip on Linux), both web builds as artifacts, the integration flows in headless Chrome (`flutter drive`), the Playwright prompt tests |
| `android.yml` | by hand only | emulator with the local image (API 37, Google Play): `tool/android_device_tests.dart` (including airplane mode and GPS), then `--patrol` (native UI, notification after kill) |
| `ios.yml` | by hand only | iPhone simulator on a macOS runner: builds for iOS and runs the integration flows |
| `desktop.yml` | Linux: every push and pull request; Windows and macOS: by hand | builds each desktop app (Linux bundle and Windows release as artifacts) and runs `app_test`, `ui_flows_test` and the platform probe on it, one file per run (Linux under `xvfb-run` with a session bus) |
| `goldens.yml` | by hand only | golden image tests on a Windows runner (the OS the reference images are made on); diff images as an artifact on failure |

Every job installs the Flutter version from `.fvmrc`; `tool/check.sh`,
`tool/check.ps1` and the host helper use FVM when it's installed and the plain
`flutter`/`dart` on PATH otherwise. The repository is private, so the jobs use
Actions minutes from the account's allowance (Windows minutes count 2×, macOS 10×).

- The workflows' token is read-only (`permissions: contents: read`).
- Third-party actions (`subosito/flutter-action`,
  `reactivecircus/android-emulator-runner`) are pinned to a commit SHA with the
  release in a comment; to update one, look up the new tag's commit
  (`gh api repos/<owner>/<repo>/commits/<tag> --jq .sha`) and change both.
- `android.yml` pins patrol_cli (4.8.0) and gives Gradle a 3 GB heap through
  `~/.gradle/gradle.properties`, since the runner shares its memory with the
  emulator (the project's `gradle.properties` asks for 8 GB, for local builds).
- `ios.yml` logs which `PERMISSION_*` macros permission_handler compiled in
  (see `platform-setup.md`).
- On CI, Playwright retries a failed test once, fails on a stray `test.only`
  and always starts its own web servers.

## Manual checks

`docs/platform-setup.md` lists what has been verified by hand on each platform.
Record results in the app's **PoC results** tracker (Settings › PoC tools) and
export them as CSV or JSON.
