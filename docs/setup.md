# Setup and running

How to set up a macOS, Linux or Windows machine for this project, and how to
run the app on each target: Android, iOS, web, and the macOS, Linux and
Windows desktop apps.

## What builds where

| Target | On macOS | On Linux | On Windows |
|---|---|---|---|
| Android (emulator or phone) | ✓ | ✓ | ✓ |
| iOS (simulator or iPhone) | ✓ | – | – |
| Web (Chrome) | ✓ | ✓ | ✓ |
| macOS app | ✓ | – | – |
| Linux app | – | ✓ | – |
| Windows app | – | – | ✓ |

A desktop app builds only on its own OS (Flutter doesn't cross-compile them).
CI builds all three (`desktop.yml`, see [testing.md](testing.md)).

## Every machine

1. **Git**, and a clone of this repository.
2. **FVM**: the Flutter version is pinned in `.fvmrc` (3.47.8). The per-OS
   install commands are below. Then, from the repository root:

   ```bash
   fvm install
   ```

   This downloads that Flutter into `~/fvm/versions/` and links it into
   `.fvm/` (ignored by git). Use `fvm flutter …` and `fvm dart …` in this
   repository; a separately installed `flutter` may be a different version.

3. **Packages** for the app and the two Dart packages (the quality gate needs
   all three):

   ```bash
   cd app && fvm flutter pub get
   ```

   ```bash
   cd packages/mock_data && fvm dart pub get
   ```

   ```bash
   cd mock_server && fvm dart pub get
   ```

4. **Chrome**, for the web target and the web tests.
5. **Android**: [Android Studio](https://developer.android.com/studio) (or the
   command-line tools) with an SDK, the platform tools and an emulator image.
   Accept the licences with `fvm flutter doctor --android-licenses`.
6. **Python 3**, only for `tool/serve_web.py` (the production-like web
   server). It's `python3` on macOS and Linux, `python` on Windows.

Check the result with `fvm flutter doctor -v`: each target you want should be ✓.

## macOS

```bash
brew install fvm
```

- **Xcode** from the App Store, then select it and finish its first run:

  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  ```

  ```bash
  sudo xcodebuild -runFirstLaunch
  ```

- **iOS simulators**: Xcode › Settings › Components, or
  `xcodebuild -downloadPlatform iOS`. List them with `xcrun simctl list devices available`.
- **The macOS app** needs nothing beyond Xcode.
- **CocoaPods** isn't needed: Flutter 3.47 brings in iOS and macOS plugins
  with Swift Package Manager. If a plugin ever falls back to CocoaPods, use
  `brew install cocoapods` (the system Ruby's copy prints `ffi` and UTF-8
  warnings).
- iOS-specific notes (permissions under Swift Package Manager, signing):
  [platform-setup.md](platform-setup.md).

## Linux (Ubuntu / Debian)

```bash
curl -fsSL https://fvm.app/install.sh | bash
```

- **Linux app build tools** (Flutter's list):

  ```bash
  sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev libstdc++-12-dev
  ```

- File dialogs (Gallery, Attach file, Save PDF) go through
  `xdg-desktop-portal`, which desktop installs of Ubuntu, Fedora and the like
  already have. A bare window manager needs `xdg-desktop-portal-gtk`.
- Android on Linux: the emulator needs KVM (`kvm-ok`; add your user to the
  `kvm` group).

## Windows

In PowerShell as administrator:

```powershell
choco install fvm
```

- **Developer Mode** (Settings › System › For developers): FVM links the SDK
  with a symbolic link, which Windows allows only in Developer Mode.
- **Visual Studio 2022** (not VS Code) with the **Desktop development with
  C++** workload, for the Windows app.
- **PowerShell 7** (`pwsh`) for `tool/check.ps1`.

## Mock API (optional)

Without it the app uses its built-in offline fake, so every target works
without it. With it:

```bash
fvm dart run mock_server/bin/server.dart --port 8080
```

It listens on 127.0.0.1 only; for a phone on the same Wi-Fi start it with
`--host 0.0.0.0` (anyone on that network can then use it, so only on a network
you trust) and pass the PC's address with `API_URL`. On a fresh clone run
`fvm dart pub get` in `mock_server/` once first.

The app looks for it at `http://localhost:8080/api` (on the Android emulator
`http://10.0.2.2:8080/api`, the host's loopback). Force a mode or another address with
`--dart-define=BACKEND=http|fake|auto` and `--dart-define=API_URL=http://host:8080/api`.

Demo account: `anna.nowak@example.com` / `inspect123`, or tap **Use demo account**.

## Run

All from `app/`. `fvm flutter devices` lists what's available.

| Target | Run | Release build |
|---|---|---|
| Android | `fvm flutter run -d emulator-5554` | `fvm flutter build apk` |
| iOS simulator | `fvm flutter run -d <simulator id>` | `fvm flutter build ios --simulator` |
| Web (Chrome) | `fvm flutter run -d chrome` | `fvm flutter build web` (see below) |
| macOS app | `fvm flutter run -d macos` | `fvm flutter build macos` → `build/macos/Build/Products/Release/Field Inspections.app` |
| Linux app | `fvm flutter run -d linux` | `fvm flutter build linux` → `build/linux/x64/release/bundle/field_inspections` |
| Windows app | `fvm flutter run -d windows` | `fvm flutter build windows` → `build\windows\x64\runner\Release\field_inspections.exe` |

Boot an iOS simulator first (`xcrun simctl boot <id>` or open Simulator.app).
`-d` also takes the start of a device name, so `fvm flutter run -d iPhone`
finds a booted iPhone simulator (Flutter asks which one if several match).

### VS Code

Install the Flutter extension (VS Code suggests it from
`.vscode/extensions.json`). `.vscode/settings.json` points it at the FVM SDK,
`.fvm/versions/<version>`: a link FVM makes when it sets up the project (if
it's missing, run `fvm use <the version in .fvmrc>` in the repository root).
FVM also updates that setting when the version changes. The Run and Debug view
then has:

| Configuration | Runs on |
|---|---|
| Web: Chrome, Web: Chrome, WebAssembly | Chrome, debug build (the second with `--wasm`) |
| Desktop: Windows / macOS / Linux | that OS only (Windows needs the Visual Studio workload above) |
| Mobile: Android emulator | the first running emulator; start one from the device picker in the status bar |
| Mobile: iPhone simulator | the first booted simulator named "iPhone…" (Mac only) |
| Mobile: device picked in the status bar | whatever is picked there: a phone on USB, an iPad, any other target |
| Mock API (port 8080) | the mock server, as in "Mock API" above |
| … + mock API | the mock server and the app together; stopping one stops both |

Debug builds are slower than release ones; use the commands in "Web like
production" or the release builds in the table above to judge speed.

### Web like production

`flutter run` doesn't do the SPA rewrite (refreshing a deep link) or serve
`.wasm` with the right type. Build, then serve with the helper (from the
repository root; `python` on Windows). It sends paths without a file extension
to `index.html`, answers a missing file with 404, and listens on 127.0.0.1:

```bash
cd app && fvm flutter build web && cd .. && python3 tool/serve_web.py
```

That serves <http://localhost:5173>. The WebAssembly build (Skwasm renderer;
browsers without WasmGC fall back to JavaScript) with the COOP/COEP headers
it works best with:

```bash
cd app && fvm flutter build web --wasm -o build/web-wasm && cd .. && python3 tool/serve_web.py 5176 build/web-wasm --isolate
```

## What differs on the desktop apps

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

Checked so far (26 October 2026):

- **macOS** (MacBook Pro, macOS 27): the 7 shared integration flows and the
  platform probe pass; the sandboxed app reaches the mock API and loads map
  tiles; Touch ID is available to the lock (enrolled finger found);
  `fieldinspections://` links open the right page in the running app and from
  a cold start. Not yet tried by hand: Touch ID itself, the notification and
  location prompts, file dialogs and Save.
- **Linux** (Ubuntu 24.04 arm64 in a container on the Mac,
  `tool/linux_container/test.sh`): the release build, the 7 flows and the
  probe pass, map tiles load, and links open the right page from a cold start,
  from a second process and through `xdg-open` with the `.desktop` file
  registered.
- **Windows**: not yet built or run anywhere; the `desktop.yml` Windows job
  (by hand) is the first place.

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

## Check

| On | Command |
|---|---|
| macOS, Linux | `tool/check.sh` |
| Windows | `pwsh tool/check.ps1` |

Format, analyze and test for all three packages. Device and browser tests:
[testing.md](testing.md). The integration flows run on any target, one file
per run on desktop:

```bash
cd app && fvm flutter test integration_test/app_test.dart -d macos
```

## Troubleshooting

- **`flutter devices` doesn't list a booted iOS simulator** right after
  booting it: run it again; discovery can lag the boot.
- **The quality gate fails in `mock_data` or `mock_server`** with "can't find
  `package:lints`": run `dart pub get` in both (step 3).
- **CocoaPods prints UTF-8 warnings**: `export LANG=en_US.UTF-8`, or install it
  with Homebrew.
- **FVM on Windows fails to create the link**: turn on Developer Mode.
- **The Linux app shows no file dialog**: install `xdg-desktop-portal-gtk`.
- **"Connectivity unavailable" in the Linux app's log**: there's no system bus
  or NetworkManager (containers, minimal installs). The app assumes it's
  online and carries on.
