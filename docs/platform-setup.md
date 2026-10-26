# Platform setup

What each platform needed for M3 (platform integrations), and what to check
on a real device.

## Android (done in the repo)

| Need | Where |
|---|---|
| `compileSdk = 37` (permission_handler_android requires it; Flutter 3.47 defaults to 36) | `android/app/build.gradle.kts` |
| Core library desugaring + `multiDexEnabled` (flutter_local_notifications) | `android/app/build.gradle.kts` |
| `FlutterFragmentActivity` (local_auth) and an AppCompat launch theme (+ `androidx.appcompat`) | `MainActivity.kt`, `res/values*/styles.xml` |
| Permissions: biometric, location, notifications, boot completed. **No `CAMERA`**: image_picker uses the system camera app, and declaring CAMERA would make that intent need the permission | `AndroidManifest.xml` |
| Receivers for scheduled reminders | `AndroidManifest.xml` |
| `<queries>` for https, geo and tel links (package visibility) | `AndroidManifest.xml` |
| Plain HTTP to the mock API in debug builds only | `src/debug/AndroidManifest.xml` |
| Kotlin incremental compilation off (project on D:, pub cache on C:) | `android/gradle.properties` |

Reminders use inexact alarms (`inexactAllowWhileIdle`): no exact-alarm
permission, but Android may deliver a few minutes late.

## iOS (on the Mac)

Already in the repo: `Info.plist` usage strings (camera, photo library,
location when in use, Face ID), the `fieldinspections` URL scheme, local
networking for the mock API, `LSApplicationQueriesSchemes` (https, tel, maps),
and the notification delegate in `AppDelegate.swift`.

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

Checked on the iPhone 18 Pro simulator (iOS 27.0) on 26 October 2026; results
in "Verified so far" below. How to drive the simulator for these:

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

Still to check on a physical iPhone:

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
What differs from the phones is in `Capabilities` and summed up in
[setup.md](setup.md#what-differs-on-the-desktop-apps). In the repo:

| Need | Where |
|---|---|
| App Sandbox entitlements: outgoing network, user-selected files (read/write), location | `macos/Runner/DebugProfile.entitlements`, `Release.entitlements` |
| Location usage strings, local networking for the mock API | `macos/Runner/Info.plist` |
| App and window name "Field Inspections" | `macos/Runner/Configs/AppInfo.xcconfig`, `linux/runner/my_application.cc`, `windows/runner/main.cpp`, `Runner.rc` |
| macOS window opens at 1280 × 720 like the other two, with restoration off (it otherwise brought back the template's 800 × 600) | `macos/Runner/MainFlutterWindow.swift` |
| Notification settings for macOS, Linux and Windows (Windows needs an app ID and a GUID) | `lib/core/platform/notification_service.dart` |
| Deep links through `app_links`: macOS `fieldinspections` scheme; Windows registers the scheme for the user at start and forwards links to the open window; Linux runs single-instance and passes links on, plus a `.desktop` file to register | `macos/Runner/Info.plist`, `windows/runner/main.cpp`, `linux/runner/my_application.cc`, `linux/dev.flutterpoc.field_inspections.desktop` |
| Biometric lock: Touch ID (macOS) and Windows Hello through local_auth; not on Linux | `lib/core/platform/capabilities.dart` |

Verified on macOS 27 (Apple silicon): the 7 shared integration flows pass
(`app_test` and `ui_flows_test`, one file per `flutter test` run: a second
launch in the same run lost its debug connection), and so does the platform
probe (`platform_probe_test`: device info, notification and location state,
Touch ID available with a finger enrolled, 21 map tiles from OSM inside the
sandbox). `fieldinspections://` links open the right page in the running app
and from a cold start (release build). Not tried by hand yet: Touch ID itself,
the notification and location prompts, file dialogs and Save (they need clicks
in system UI).

Verified on Linux (Ubuntu 24.04 arm64 in a container on the Mac,
`tool/linux_container/test.sh`): release build, the 7 flows, the probe
(notifications on, no location plugin, no biometrics, map tiles drawn), and
links from a cold start, from a second process and through `xdg-open` with the
`.desktop` file registered. Running there turned up three things, now fixed:
drift kept the database in the Documents folder (moved to the app's support
folder on desktop), connectivity_plus throws an uncaught error when there's no
system bus (the first check now runs in its own error zone; the app assumes
it's online), and the Linux notification plugin can't report a launch from a
notification (no longer asked). Windows: not yet run.

Adding `app_links` didn't change the phones: on the iPhone simulator a link
still opens its page while the app runs, after sign-in and from a cold start
(the plugin reports iOS links as unhandled, so Flutter's deep linking keeps
them). On Android, Flutter pushes the intent's route whatever plugins return
(read in the embedding's source, not run: no emulator on the Mac).

## Verified so far

| Check | Android emulator | Chrome | iOS |
|---|---|---|---|
| Map tiles, pins, `?site=` deep link | ✓ | ✓ | tiles, pins and my location ✓ (simulator) |
| PDF export | builds; share sheet not opened in tests | ✓ downloaded | ✓ 2 pages, same content (Polish letters transliterated, as everywhere) |
| Notification while the app is open | ✓ | ✓ | ✓ banner over the app (the `AppDelegate` delegate answers `willPresent`) |
| Test notification → tap opens its route (app in background) | ✓ | ✓ shown by the service worker, click opens the route; tab closed too (Playwright) | ✓ banner on the home screen; opened from Notification Center onto the route |
| Notification tap after the app was killed | ✓ cold start on the route (host helper; a dropped-tap bug fixed) | n/a | ✓ cold start on the route (`simctl terminate`, then opened from Notification Center) |
| Biometric unlock | ✓ system prompt with the device PIN (Patrol); fingerprint not enrolled | n/a | ✓ simulated Face ID: turning it on asks once, cold start locks, no match shows iOS's "Face Not Recognised" and stays locked, match opens Home |
| Camera / gallery / files | ✓ camera app and photo picker (Patrol); file picker with fakes | tests with fakes | camera prompt ✓, then "Camera not available" (the simulator has none); gallery through iOS's private picker (no Photos permission needed) ✓; PDF from Files › On My iPhone ✓ |
| Permission dialogs (location Allow/Deny, notifications) | ✓ (Patrol) | ✓ granted and denied (Playwright) | location, camera and notification prompts with the Info.plist texts, Allow ✓; Diagnostics then shows Granted (simulator) |
| Denied camera / location → banner or snackbar with Settings | ✓ (Patrol) | n/a | ✓ banner (Take photo disabled) and snackbar; "Open settings" opens the Settings app but at its top page, not the app's (simulator; recheck on a phone). Diagnostics updates on return without a restart |
| Share sheet (Export PDF) | ✓ (Patrol) | download ✓ | ✓ iOS share sheet; Save to Files gives `inspection-INS-1042.pdf` |
| Results tracker, adaptive widgets (Material and Cupertino dialog), diagnostics | ✓ | ✓ (wasm build) | diagnostics ✓ (tracker and adaptive widgets not opened yet) |
| Device tests (`integration_test/`, 9 flows incl. airplane mode and GPS) | ✓ all pass | ✓ 7 shared flows via `flutter drive` (host-driven ones are Android-only) | ✓ 7 shared flows, iPhone 18 Pro simulator (iOS 27.0, Xcode 27.1) |
| Camera (browser file input), geolocation in the browser | n/a | ✓ (Playwright) | – |
| Offline submit → sync when back online (airplane mode) | ✓ | – | – |
| GPS distance and far-away warning | ✓ via LocationManager test positions; fused provider needs a real phone | – | – |
| Pickers, swipe, pull to refresh, Hero, animated grid, reduce motion | ✓ | partly (widget tests) | ✓ simulator |
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
