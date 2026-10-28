# Platform setup

What each platform needed for M3 (platform integrations), and what a real
device would still show (the PoC runs on emulators and simulators only,
decision 117).

## Android (done in the repo)

| Need | Where |
|---|---|
| `compileSdk = 37` (permission_handler_android requires it; Flutter 3.47 defaults to 36) | `android/app/build.gradle.kts` |
| Core library desugaring + `multiDexEnabled` (flutter_local_notifications) | `android/app/build.gradle.kts` |
| `FlutterFragmentActivity` (local_auth) and an AppCompat launch theme (+ `androidx.appcompat`) | `MainActivity.kt`, `res/values*/styles.xml` |
| Permissions: biometric, location, notifications, boot completed. **No `CAMERA`**: image_picker uses the system camera app, and declaring CAMERA would make that intent need the permission | `AndroidManifest.xml` |
| Receivers for scheduled reminders | `AndroidManifest.xml` |
| `<queries>` for https, geo and tel links (package visibility) | `AndroidManifest.xml` |
| Plain HTTP to the mock API in debug builds only (iOS differs, see below) | `src/debug/AndroidManifest.xml` |
| Kotlin incremental compilation off (project on D:, pub cache on C:) | `android/gradle.properties` |
| Release signing: `key.properties`, else `ANDROID_KEYSTORE_*` environment variables, else the debug key with a warning (see below) | `android/app/build.gradle.kts` |

Reminders use inexact alarms (`inexactAllowWhileIdle`): no exact-alarm
permission, but Android may deliver a few minutes late.

### Release signing

Release builds (`flutter build apk`, `flutter build appbundle`, `flutter run
--release`) are signed with the first of these that is set up:

1. `app/android/key.properties` (Flutter's format, git-ignored).
2. The environment variables `ANDROID_KEYSTORE_PATH`,
   `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`,
   used only when `key.properties` doesn't exist (CI).
3. Neither: the debug key, and the build prints `WARNING: the release build is
   debug-signed`. Fine for trying a release build on your own device; such an
   APK can't update a properly signed install, and Google Play rejects it.

A half-filled setup (a `key.properties` without a password, only some of the
variables, a keystore path that doesn't exist) fails release builds with a
message naming what's missing; debug builds are never affected.

Create an upload keystore once, back it up, and keep it and its passwords out
of the repository. `keytool` comes with any JDK, including Android Studio's
(`C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe` on Windows):

```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Then `app/android/key.properties`:

```properties
storePassword=<keystore password>
keyPassword=<key password>
keyAlias=upload
storeFile=/Users/<you>/upload-keystore.jks
```

On Windows write the path with doubled backslashes or forward slashes
(`storeFile=C:\\Users\\<you>\\upload-keystore.jks`). A relative `storeFile`
is resolved against `app/android/app`. `key.properties`, `*.jks` and
`*.keystore` are git-ignored, in `app/android` and in the rest of the repo.

On CI, store the keystore as a base64 secret and the passwords as secrets,
then export them for the build step, for example in GitHub Actions:

```yaml
- name: Release keystore
  env:
    KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
  run: echo "$KEYSTORE_BASE64" | base64 --decode > "$RUNNER_TEMP/upload-keystore.jks"
- name: Build the app bundle
  working-directory: app
  env:
    ANDROID_KEYSTORE_PATH: ${{ runner.temp }}/upload-keystore.jks
    ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
    ANDROID_KEY_ALIAS: upload
    ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
  run: flutter build appbundle --release
```

No workflow builds a signed release yet; the device-test workflow uses debug
builds.

## iOS (on the Mac)

Already in the repo: `Info.plist` usage strings (camera, photo library,
location when in use, Face ID), the `fieldinspections` URL scheme, local
networking for the mock API, `LSApplicationQueriesSchemes` (https, tel, maps),
and the notification delegate in `AppDelegate.swift`.

Plain HTTP: `NSAllowsLocalNetworking` is set for every build, release
included, unlike Android's debug-only cleartext. It is kept on purpose: it
exempts only unqualified host names (`localhost`), `.local` names and literal
IP addresses (which iOS 17+ otherwise blocks over HTTP), so the simulator and
a phone pointed at `http://<pc-ip>:8080` reach the mock API, while named
internet hosts still need HTTPS. A production build that talks to a real API
over HTTPS doesn't need it and should drop it.

On the Mac:

```bash
fvm install
```

```bash
cd app && fvm flutter run -d ios
```

If the build uses CocoaPods (an `ios/Podfile` appears after the first build),
permission_handler only compiles the permissions you enable. Add this to the
`post_install` block of `ios/Podfile`, then run `pod install` in `app/ios`:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
        'PERMISSION_PHOTOS=1',
        'PERMISSION_LOCATION_WHENINUSE=1',
        'PERMISSION_NOTIFICATIONS=1',
      ]
    end
  end
end
```

With Swift Package Manager (Flutter's default on newer versions, and what
this app builds with on 3.47.8) no Podfile is generated and nothing needs
setting up: permission_handler's package manifest reads `ios/Runner/Info.plist`
and turns on each permission whose usage description is there (camera,
photos, location when in use; notifications are on by default). Two catches:

- It finds the app through the working directory, so builds started from
  `flutter run`/`flutter build`/`flutter test` work, but builds started from
  Xcode.app compile every permission out and report them as denied. For
  those, `launchctl setenv PERMISSION_HANDLER_INFO_PLIST "$PWD/ios/Runner/Info.plist"`
  (from `app/`) once.
- The manifest result is cached. After adding or removing a usage description,
  `rm -rf ~/Library/Developer/Xcode/DerivedData` before the next build.

To see what it resolved, from `app/`:

```bash
PERMISSION_HANDLER_VERBOSE=1 swift package --package-path ~/.pub-cache/hosted/pub.dev/permission_handler_apple-9.6.4/ios/permission_handler_apple dump-package > /dev/null
```

Checked on the iPhone 18 Pro simulator (iOS 27.0) on 26 October 2026 and
again on 28 October 2026 (after the strings, wizard, notification and lock
changes: the 7 flows and the probe pass, and the checks marked 28 Oct below);
results in "Verified so far" below. The Results tracker's iOS column is filled
from them (`iosFindings` in `lib/features/poc/results_model.dart`). How to drive the simulator for these:

- Face ID: `xcrun simctl spawn <udid> notifyutil -s com.apple.BiometricKit.enrollmentChanged 1`
  then `-p com.apple.BiometricKit.enrollmentChanged` to enroll; while the Face ID
  panel is up, `-p com.apple.BiometricKit_Sim.pearl.match` (or `.nomatch`).
- Denied permissions: `xcrun simctl privacy <udid> revoke camera dev.flutterpoc.fieldInspections`
  (also `location`, `grant`, `reset`); granting while the app is in the background doesn't restart it.
- Notifications: the deep-link tester schedules one 15 s ahead; `simctl terminate`
  covers "after it was closed". Banners and Notification Center rows didn't
  react to synthetic taps; swiping a row right and pressing Open did.
- Photos: `xcrun simctl addmedia <udid> photo.jpg`. Files: copy into the
  `group.com.apple.FileProvider.LocalStorage` app group's `File Provider Storage`
  folder under the simulator's data, and it shows in On My iPhone.

On the iPad simulators (iPad Pro 13-inch and iPad mini, iPadOS 26.5, 28 October
2026) the 7 flows and the probe pass too. Driven by hand on the iPad Pro
against the mock API: the rail in portrait (1032 pt) and the extended rail
with New inspection in landscape (1376 pt); the list with the detail beside it
(a `?tab=` link opens there), and in landscape the desktop table (D03);
Settings with Appearance beside it; the two-pane sign-in card; the wizard's
step bar; the Results tracker's wide grid. Diagnostics names the iPad mini
(device_info_plus doesn't know it; the device's name stands in).

Not checked, since the PoC has no physical devices (decision 117):

- "Open settings" should land on Settings › Field Inspections; on the simulator it opened the top of Settings.
- The camera itself, real GPS and real Face ID (the simulator showed no separate "allow Face ID" alert).
- Universal links need an Apple developer team and the Associated Domains entitlement (docs/deep-links.md); the custom scheme works without them.

## Web

- No setup for notifications; the browser asks on "Turn on". Browsers can't
  schedule notifications, so reminders are mobile-only; test notifications
  show from a timer while the tab is open.
- Geolocation needs HTTPS (localhost counts) and the browser's permission prompt.
- Camera opens the browser's file input with `capture`; on desktop that is a
  file dialog, on phones the camera. Drag and drop and paste (Ctrl/Cmd+V) of
  images work in the photos step.
- PDF export downloads the file; on mobile it opens the share sheet.
- Share uses the Web Share API where the browser has it, else copies the link.
- OpenStreetMap tiles: fine for a PoC; production needs a tile provider or
  your own server (OSM tile usage policy).

## Desktop apps (macOS, Windows, Linux)

Added after M4 from the same codebase (`flutter create --platforms=macos,linux,windows`).
Machine setup and run commands: [README](../README.md#setup).

### What differs on the desktop apps

One codebase, with these platform differences (all in
`lib/core/platform/capabilities.dart`):

| | macOS | Windows | Linux |
|---|---|---|---|
| Layout | desktop (opens at 1280 × 720; narrower windows get the tablet and phone layouts) | same | same |
| Photos | Gallery (file dialog) and drag and drop; no camera | same | same |
| Export PDF | Save dialog | same | same |
| Notifications | ✓ (asks for permission) | ✓ | shown, but can't be scheduled: reminders are off, test notifications use a timer |
| Location | ✓ (asks for permission) | ✓ (Windows location services) | not available (geolocator has no Linux plugin) |
| Biometric lock | Touch ID (or the Mac's password) | Windows Hello | not offered (local_auth has no Linux plugin) |
| Deep links (`fieldinspections://`) | ✓ via `app_links` (scheme in `Info.plist`) | ✓ via `app_links` (the app registers the scheme for the user at start) | ✓ via `app_links` once the `.desktop` file is registered (below) |

The macOS app runs in the App Sandbox; `macos/Runner/*.entitlements` allow
outgoing network (map tiles, mock API), user-selected files (pickers, Save)
and location.

### Desktop deep links

Phones get links from Flutter's own deep linking; the desktop apps get them
from `app_links` (`lib/core/platform/desktop_links.dart`). A link that starts
the app opens its page directly; one that arrives while the app runs goes to
the open window (Windows and Linux forward it from the second process, which
then exits).

- **macOS**: nothing to do; the scheme is in `macos/Runner/Info.plist`. Try
  `open "fieldinspections://app/inspections/INS-1042"`.
- **Windows**: each start writes `HKEY_CURRENT_USER\Software\Classes\fieldinspections`
  pointing at the running `.exe` (`windows/runner/main.cpp`). Try
  `start fieldinspections://app/inspections/INS-1042` in `cmd`. An MSIX package
  would declare the scheme instead.
- **Linux**: register `linux/dev.flutterpoc.field_inspections.desktop` once,
  with `Exec=` set to the built binary's absolute path:

  ```bash
  cp app/linux/dev.flutterpoc.field_inspections.desktop ~/.local/share/applications/
  ```

  ```bash
  xdg-mime default dev.flutterpoc.field_inspections.desktop x-scheme-handler/fieldinspections
  ```

  Then `xdg-open fieldinspections://app/inspections/INS-1042`.

### In the repo

| Need | Where |
|---|---|
| App Sandbox entitlements: outgoing network, user-selected files (read/write), location | `macos/Runner/DebugProfile.entitlements`, `Release.entitlements` |
| Location usage strings, local networking for the mock API | `macos/Runner/Info.plist` |
| App and window name "Field Inspections" | `macos/Runner/Configs/AppInfo.xcconfig`, `linux/runner/my_application.cc`, `windows/runner/main.cpp`, `Runner.rc` |
| macOS window opens at 1280 × 720 like the other two, with restoration off (it otherwise brought back the template's 800 × 600) | `macos/Runner/MainFlutterWindow.swift` |
| Notification settings for macOS, Linux and Windows (Windows needs an app ID and a GUID) | `lib/core/platform/notification_service.dart` |
| Deep links through `app_links`: macOS `fieldinspections` scheme; Windows registers the scheme for the user at start and forwards links to the open window; Linux runs single-instance and passes links on, plus a `.desktop` file to register | `macos/Runner/Info.plist`, `windows/runner/main.cpp`, `linux/runner/my_application.cc`, `linux/dev.flutterpoc.field_inspections.desktop` |
| Biometric lock: Touch ID (macOS) and Windows Hello through local_auth; not on Linux | `lib/core/platform/capabilities.dart` |

Verified on macOS 27 (Apple silicon; again on 28 October 2026 on macOS 27.0.1,
with Touch ID enrolled and 21 map tiles in the probe, and by hand-started
GitHub Actions on `macos-latest`): the 7 shared integration flows pass
(`app_test` and `ui_flows_test`, one file per `flutter test` run: a second
launch in the same run lost its debug connection), and so does the platform
probe (`platform_probe_test`: device info, notification and location state,
Touch ID available with a finger enrolled, 21 map tiles from OSM inside the
sandbox). `fieldinspections://` links open the right page in the running app
and from a cold start (release build). Against the mock API (28 October): a
restored session, lists, search and filters; the table-shaped loading
skeleton, an empty search, and with the server stopped the offline banner and
error with Try again. Not tried by hand yet: Touch ID itself,
the notification and location prompts, file dialogs and Save (they need clicks
in system UI).

Verified on Linux (Ubuntu 24.04 arm64 in a container on the Mac,
`tool/linux_container/test.sh`; again on 28 October 2026 after the review
fixes, with the Flutter version now read from `.fvmrc`): release build, the 7 flows, the probe
(notifications on, no location plugin, no biometrics, map tiles drawn), and
links from a cold start, from a second process and through `xdg-open` with the
`.desktop` file registered. Running there turned up three things, now fixed:
drift kept the database in the Documents folder (moved to the app's support
folder on desktop), connectivity_plus throws an uncaught error when there's no
system bus (the first check now runs in its own error zone; the app assumes
it's online), and the Linux notification plugin can't report a launch from a
notification (no longer asked).

Verified on Windows 11 (x64 PC, Visual Studio Community 2026 18.11, 27 October
2026): release and debug builds, the 7 flows and the probe (notifications
granted, location service on with permission while in use, Windows Hello
supported with biometrics enrolled, map tiles drawn). The release `.exe`
registers `fieldinspections://` for the user at start; a link opened with
`start` goes to the running window (the second process exits) and one that
starts the app opens its page directly. The first build failed: MSVC 14.51
rejects the `/await` flag that `permission_handler_windows` and
`local_auth_windows` still use (STL1011); `windows/CMakeLists.txt` now drops
the flag from the first and silences the error for the second. Not tried by
hand yet: Windows Hello itself, the notification and location prompts, file
dialogs and Save.

Verified on Linux x64 in WSL 2 (Ubuntu 26.04 on the same PC, window through
WSLg, 27 October 2026): release build, the quality gate (`tool/check.sh`), the
7 flows and the probe (notifications granted, no location plugin, no
biometrics, map tiles drawn), and links from a cold start and from a second
process (passed to the running window). WSL has no NetworkManager (the app
logs "Connectivity unavailable" and assumes it's online) and, out of the box,
no notification daemon or desktop portal, so notifications and file dialogs
weren't tried there.

Adding `app_links` didn't change the phones: on the iPhone simulator a link
still opens its page while the app runs, after sign-in and from a cold start
(the plugin reports iOS links as unhandled, so Flutter's deep linking keeps
them). On Android, Flutter pushes the intent's route whatever plugins return
(read in the embedding's source, not run: no emulator on the Mac).

## Verified so far

| Check | Android emulator | Chrome | iOS |
|---|---|---|---|
| Map tiles, pins, `?site=` deep link | ✓ | ✓ | tiles, pins and my location ✓; `?site=` from a cold start while signed out lands on the site after sign-in (simulator, 28 Oct) |
| PDF export | builds; share sheet not opened in tests | ✓ downloaded | ✓ 2 pages, same content (Polish letters transliterated, as everywhere) |
| Notification while the app is open | ✓ | ✓ | ✓ banner over the app (the `AppDelegate` delegate answers `willPresent`) |
| Test notification → tap opens its route (app in background) | ✓ | ✓ shown by the service worker, click opens the route; tab closed too (Playwright) | ✓ banner on the home screen; opened from Notification Center onto the route (again 28 Oct) |
| Notification tap after the app was killed | ✓ cold start on the route (host helper; a dropped-tap bug fixed) | n/a | ✓ cold start on the route (`simctl terminate`, then opened from Notification Center) |
| Biometric unlock | ✓ system prompt with the device PIN (Patrol); fingerprint not enrolled | n/a | ✓ simulated Face ID (turning it on, cold-start lock and match again 28 Oct): turning it on asks once, cold start locks, no match shows iOS's "Face Not Recognised" and stays locked, match opens Home. After the review fixes (28 Oct): the unlock screen says "Use Face ID to unlock" with a face icon, and a lock that hits while the wizard holds a draft goes straight to Unlock (no "Leave?"), saves the draft and returns to it after the match |
| Camera / gallery / files | ✓ camera app and photo picker (Patrol); file picker with fakes | tests with fakes | camera prompt ✓, then "Camera not available" (the simulator has none); gallery through iOS's private picker (no Photos permission needed) ✓; PDF from Files › On My iPhone ✓ |
| Permission dialogs (location Allow/Deny, notifications) | ✓ (Patrol) | ✓ granted and denied (Playwright) | location, camera and notification prompts with the Info.plist texts, Allow ✓; Diagnostics then shows Granted (simulator) |
| Denied camera / location → banner or snackbar with Settings | ✓ (Patrol) | n/a | ✓ banner (Take photo disabled) and snackbar; "Open settings" opens the Settings app but at its top page, not the app's (simulator; recheck on a phone). Diagnostics updates on return without a restart. After the review fixes (28 Oct): with the camera revoked, a checklist item's Add photo says camera access is off and offers Open settings |
| Share sheet (Export PDF) | ✓ (Patrol) | download ✓ | ✓ iOS share sheet; Save to Files gives `inspection-INS-1042.pdf` |
| Results tracker, adaptive widgets (Material and Cupertino dialog), diagnostics | ✓ | ✓ (wasm build) | diagnostics ✓; tracker opened from a link (summaries and grid; editing not tried); adaptive widgets in Cupertino by default, CupertinoAlertDialog ✓ (28 Oct) |
| Device tests (`integration_test/`, 9 flows incl. airplane mode and GPS) | ✓ all pass | ✓ 7 shared flows via `flutter drive` (host-driven ones are Android-only) | ✓ 7 shared flows and the platform probe (Face ID enrolled, location service on, map tiles), iPhone 18 Pro simulator (iOS 27.0, Xcode 27.1); again on the iPad Pro 13-inch and iPad mini simulators (iPadOS 26.5, 28 Oct) |
| Tablet layouts (rail, list and detail side by side, two-pane Settings) | – | ✓ at tablet widths in Chrome | ✓ iPad Pro 13-inch simulator in portrait and landscape (desktop table in landscape), iPad mini in the flows (28 Oct) |
| Against the mock API (not the in-app fake) | ✓ via 10.0.2.2 | ✓ with CORS | ✓ iPhone and iPad Pro simulators: sign-in, lists and paging, detail, notifications, reference data (28 Oct) |
| List states: loading, empty, error | offline state seen; others in widget tests | skeleton seen; others in widget tests | ✓ iPhone simulator against the mock API: skeleton (server slowed to 3 s), empty search, offline banner and error with Try again (server stopped), recovery (28 Oct) |
| Camera (browser file input), geolocation in the browser | n/a | ✓ (Playwright) | – |
| Offline submit → sync when back online (airplane mode) | ✓ | – | – |
| GPS distance and far-away warning | ✓ via LocationManager test positions; fused provider needs a real phone | – | – |
| Pickers, swipe, pull to refresh, Hero, animated grid, reduce motion | ✓ | partly (widget tests) | ✓ simulator; the edge swipe back follows the finger (28 Oct) |
| WebAssembly build (Skwasm, cross-origin isolated, drift on OPFS) | n/a | ✓ | n/a |

## Web builds

Measured on Windows 11 with Flutter 3.47.8, release builds of the same commit:

| | JavaScript (CanvasKit) | WebAssembly (Skwasm) |
|---|---|---|
| Build time | ~70 s | ~75 s |
| App code | `main.dart.js` 7.2 MB (1.8 MB gzipped) | `main.dart.wasm` 5.1 MB (1.8 MB gzipped) + 54 KB loader |
| Renderer download | CanvasKit from the Flutter CDN | Skwasm from the Flutter CDN |
| Local storage (drift) | IndexedDB | OPFS when served with `--isolate`, else IndexedDB |
| Fallback | – | the JS build, for browsers without WasmGC (Safari before 18.2, Firefox before 120) |

Measured with `web_e2e/tests/perf.spec.ts` (Playwright, installed Chrome 156,
visible window, 1280×860, a 165 Hz display, served from localhost; median of 3
runs each, 25 October 2026):

| | JavaScript (CanvasKit) | WebAssembly (Skwasm) |
|---|---|---|
| Cold load to the first frame | 1176 ms | 814 ms |
| Scrolling the inspections table (wheel) | 163 fps, p95 6 ms, 0% of frames over 25 ms | 164 fps, p95 6 ms, 0% over 25 ms |
| App engine timings (Diagnostics) | build 1.7–1.9 ms, raster 0.9–1.1 ms, 1.5–2.2% of frames over 16 ms | build 0.9–1.9 ms, raster 1.8–5.5 ms (first run), 1.9–7.7% over 16 ms (first run) |

Both are smooth on this PC. WebAssembly reaches the first frame about 30%
sooner and runs Dart (build) faster; its raster time is a little higher and the
first run after a cold start shows more slow frames while it warms up. The
renderer files come from the Flutter CDN, so load times include that download.
Slower devices will show bigger differences; run the same spec there.
