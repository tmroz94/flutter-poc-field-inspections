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

With Swift Package Manager (Flutter's default on newer versions) no Podfile
is generated; check permission_handler's README for its SPM instructions.

Things to verify on iOS (record them in the Results tracker):

- Camera denied → the P12 banner and "Open settings" (Settings › Field Inspections › Camera).
- Face ID / Touch ID on the unlock screen; the simulator can simulate enrolled biometrics (Features › Face ID).
- Reminder notifications while the app is open (shown by the delegate), in the background and after it was closed.
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

## Verified so far

| Check | Android emulator | Chrome | iOS |
|---|---|---|---|
| Map tiles, pins, `?site=` deep link | ✓ | ✓ | – |
| PDF export | builds; share sheet not opened in tests | ✓ downloaded | – |
| Test notification → tap opens its route (app in background) | ✓ | – (pane blocks prompts) | – |
| Notification tap after the app was killed | not confirmed (process wasn't killed) | n/a | – |
| Biometric unlock | needs an enrolled fingerprint on the emulator | n/a | – |
| Camera / gallery / files | tests with fakes | tests with fakes | – |
| Results tracker, adaptive widgets (Material and Cupertino dialog), diagnostics | ✓ | ✓ (wasm build) | – |
| Device tests (`integration_test/`, 9 flows incl. airplane mode and GPS) | ✓ all pass | needs chromedriver | – |
| Offline submit → sync when back online (airplane mode) | ✓ | – | – |
| GPS distance and far-away warning | ✓ via LocationManager test positions; fused provider needs a real phone | – | – |
| Pickers, swipe, pull to refresh, Hero, animated grid, reduce motion | ✓ | partly (widget tests) | – |
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

Both builds start in well under a second from localhost. Frame-time comparison
needs a visible, focused browser window (hidden tabs are throttled), so it
wasn't measured here: use Diagnostics › Reset frame stats on each build (see
`testing.md`). Debug builds report much slower frames than release ones.
