# Flutter PoC – Field Inspections

One Flutter codebase for **iOS, Android, Web, macOS, Windows and Linux**, built to find out how well
a single codebase covers common app scenarios: navigation, deep links, forms,
lists, animations, offline data and platform integrations. The design is the
Claude Design canvas "Flutter PoC – Field Inspections" (Material 3).

| Folder | What |
|---|---|
| `app/` | Flutter app (android, ios, web, macos, linux, windows) |
| `packages/mock_data/` | Pure-Dart fixtures + in-memory backend, shared by the server and the app's offline fake |
| `mock_server/` | Local REST mock API (shelf): CORS, latency and failure injection |
| `design/` | Design tokens copied from the canvas |
| `docs/` | `decisions.md` (how mock gaps were resolved), `deep-links.md`, `platform-setup.md` (per-platform specifics, what differs on desktop, what's verified), `testing.md` (tests, goldens, integration tests, JS vs wasm) |
| `web_e2e/` | Playwright tests of the web builds: browser prompts (notifications, location, camera) and JS vs WebAssembly frame timings |
| `tool/` | `check.ps1` / `check.sh` quality gate, `serve_web.py` (SPA host, optional COOP/COEP), `code_stats.dart` (shared-code ratio for Diagnostics), `android_device_tests.dart` (device tests with adb-driven steps), `linux_container/` (build and test the Linux app in Docker), `gen_color_schemes.py` |

## What builds where

| Target | On Windows | On macOS | On Linux |
|---|---|---|---|
| Android (emulator or phone) | ✓ | ✓ | ✓ |
| Web (Chrome) | ✓ | ✓ | ✓ |
| Windows app | ✓ | – | – |
| Linux app | ✓ in WSL 2 (window shown by WSLg) | – | ✓ |
| macOS app | – | ✓ | – |
| iOS (simulator or iPhone) | – | ✓ | – |

Flutter doesn't cross-compile desktop apps: each one builds on its own OS
(on Windows, the Linux app builds inside WSL). CI (`desktop.yml`) builds the
Linux app on pushes to main and pull requests; the Windows and macOS jobs run
when started by hand.

## Setup

### 1. Every machine

1. **Git**, and a clone of this repository:

   ```bash
   git clone https://github.com/tmroz94/flutter-poc-field-inspections.git
   ```

2. **FVM** (install commands per OS below). The Flutter version is pinned in
   `.fvmrc` (3.47.8); from the repository root:

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

4. **Chrome**, for the web target and the web tests. The integration flows in
   Chrome also need **chromedriver** of the same major version (from
   [Chrome for Testing](https://googlechromelabs.github.io/chrome-for-testing/));
   see [docs/testing.md](docs/testing.md#in-chrome).
5. **Android** (see "Android" below).
6. Optional: **Python 3** for `tool/serve_web.py` (production-like web server;
   `python3` on macOS and Linux, `python` on Windows), and **Node.js** for the
   Playwright tests in `web_e2e/`.

Then check with `fvm flutter doctor -v`: each target you want should be ✓.

### 2. Windows

In PowerShell as administrator:

```powershell
choco install fvm
```

(Or download `fvm-<version>-windows-x64.zip` from the
[FVM releases](https://github.com/leoafarias/fvm/releases) and put `fvm.exe` on
`PATH`.)

- **Developer Mode** (Settings › System › For developers): FVM links the SDK
  with a symbolic link, and Flutter's plugin builds need symlinks too; Windows
  allows them only in Developer Mode.
- **Visual Studio 2022 or 2026** (not VS Code) with the **Desktop development
  with C++** workload, for the Windows app. Visual Studio 2026 18.6 and later
  rejects a compiler flag two plugins still use; `app/windows/CMakeLists.txt`
  works around it (decision 109), so nothing to do here.
- **PowerShell 7** (`pwsh`) for `tool/check.ps1`.

### 3. Linux app on Windows (WSL)

The Linux app builds and runs inside WSL 2; on Windows 11 its window opens on
the Windows desktop through WSLg. One time, in PowerShell as administrator
(restart if asked):

```powershell
wsl --install -d Ubuntu
```

Then in the Ubuntu shell:

1. Build tools (Flutter's list for Linux, plus what a fresh Ubuntu lacks):

   ```bash
   sudo apt-get update && sudo apt-get install -y curl git unzip zip xz-utils clang cmake ninja-build pkg-config libgtk-3-dev g++ libglu1-mesa
   ```

2. FVM, then put it on `PATH` for new shells:

   ```bash
   curl -fsSL https://fvm.app/install.sh | bash
   ```

   ```bash
   echo 'export PATH="$HOME/fvm/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
   ```

3. A **separate clone on the Linux filesystem** (not under `/mnt/c` or
   `/mnt/d`): sharing the Windows checkout breaks both sides, because
   `pub get` writes absolute package paths into `app/.dart_tool/`, and builds
   over the `/mnt` bridge are slow. Clone from GitHub, or from the Windows
   checkout to test commits that aren't pushed yet (`git pull` then brings
   later commits across):

   ```bash
   git clone https://github.com/tmroz94/flutter-poc-field-inspections.git ~/flutter-mcp
   ```

   or, with the Windows checkout at `D:\projects\flutter-mcp`:

   ```bash
   git clone /mnt/d/projects/flutter-mcp ~/flutter-mcp
   ```

   Then the Flutter version and packages, as in step 1:

   ```bash
   cd ~/flutter-mcp && fvm install && cd app && fvm flutter pub get
   ```

4. `fvm flutter doctor` should show **Linux toolchain** ✓ and a `linux`
   device. Android and Chrome ✗ inside WSL are fine: those targets run on the
   Windows side.

Notes:

- WSL adds the Windows `PATH`, so a plain `flutter` or `dart` in Ubuntu may be
  the Windows SDK; always use `fvm flutter` / `fvm dart`.
- Flutter warns when run as root (WSL's default user if none was created at
  install); it works, but a normal user is better for a new setup.
- `doctor` may say it can't run `eglinfo`; that's only a hint
  (`sudo apt-get install mesa-utils` silences it).
- The mock API on the Windows side isn't reachable from WSL; run it inside
  WSL too ("Mock API" below).
- Deep links: pass the link to the binary
  (`build/linux/x64/release/bundle/field_inspections fieldinspections://app/inspections/INS-1042`);
  a second call hands it to the running window. `xdg-open` needs `xdg-utils`
  and the `.desktop` file registered ([docs/platform-setup.md](docs/platform-setup.md#desktop-deep-links)).
- Location and biometrics aren't offered on Linux (no plugins); see "What
  differs on the desktop apps" in [docs/platform-setup.md](docs/platform-setup.md#what-differs-on-the-desktop-apps).

### 4. macOS

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
- iOS signing and permissions: [docs/platform-setup.md](docs/platform-setup.md).

### 5. Linux (Ubuntu / Debian)

```bash
curl -fsSL https://fvm.app/install.sh | bash
```

It installs to `~/fvm/bin`; add that to `PATH` as the installer prints (the
same `echo … >> ~/.bashrc` line as in the WSL steps above).

- **Linux app build tools**:

  ```bash
  sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev g++
  ```

- File dialogs (Gallery, Attach file, Save PDF) go through
  `xdg-desktop-portal`, which desktop installs of Ubuntu, Fedora and the like
  already have. A bare window manager needs `xdg-desktop-portal-gtk`.
- Android on Linux: the emulator needs KVM (`kvm-ok`; add your user to the
  `kvm` group).

### 6. Android (any OS)

1. [Android Studio](https://developer.android.com/studio). In its SDK Manager
   install **Android SDK Platform 37** (the app compiles against it), the
   platform tools, the emulator, and a system image. Flutter uses Android
   Studio's bundled JDK.
2. Accept the licences:

   ```bash
   fvm flutter doctor --android-licenses
   ```

3. An emulator: Android Studio › Device Manager › Create (for example a Medium
   Phone with API 37), or a phone with USB debugging on. Start an emulator
   from Device Manager, VS Code's device picker, or:

   ```bash
   fvm flutter emulators --launch Medium_Phone_API_37.0
   ```

## Run

### Mock API (optional)

Without it the app uses its built-in offline fake, so every target works
without it. With it (from the repository root):

```bash
fvm dart run mock_server/bin/server.dart --port 8080
```

It listens on 127.0.0.1, which the browser, the iOS simulator, the desktop
apps and the Android emulator (through 10.0.2.2, the host's loopback) can all
reach. The Linux app in WSL can't reach a server on the Windows side (WSL's
default NAT networking), so for it run the same command inside WSL, in
`~/flutter-mcp`. For a phone on the same Wi-Fi add `--host 0.0.0.0` and run the
app with `--dart-define=API_URL=http://<pc-ip>:8080/api`; anyone on that
network can then use the mock API, so only do it on a network you trust.
Browsers may call it only from this machine's pages (`localhost`,
`127.0.0.1`, `[::1]`, `*.localhost`); to open the web build from another
device, add `--allow-origin http://<pc-ip>:<port>`. Bound to 127.0.0.1 it also
answers only requests for this machine's names (and the emulator's 10.0.2.2),
decision 120; with `--host 0.0.0.0` that check is off.

Force a mode with `--dart-define=BACKEND=http|fake|auto` (default `auto`: the
mock API when it answers, else the fake).

Demo account: `anna.nowak@example.com` / `inspect123` (mock backend only), or
tap **Use demo account**.

### The app

All from `app/`. `fvm flutter devices` lists what's available.

| Target | Run | Release build |
|---|---|---|
| Android | `fvm flutter run -d emulator-5554` | `fvm flutter build apk` |
| Web (Chrome) | `fvm flutter run -d chrome` | `fvm flutter build web` (see below) |
| Windows app | `fvm flutter run -d windows` | `fvm flutter build windows` → `build\windows\x64\runner\Release\field_inspections.exe` |
| Linux app (also in WSL) | `fvm flutter run -d linux` | `fvm flutter build linux` → `build/linux/x64/release/bundle/field_inspections` |
| macOS app | `fvm flutter run -d macos` | `fvm flutter build macos` → `build/macos/Build/Products/Release/Field Inspections.app` |
| iOS simulator | `fvm flutter run -d <simulator id>` | `fvm flutter build ios --simulator` |

Boot an iOS simulator first (`xcrun simctl boot <id>` or open Simulator.app).
`-d` also takes the start of a device name, so `fvm flutter run -d iPhone`
finds a booted iPhone simulator. Debug builds are much slower than release
ones; judge speed on a release build.

### Web like production

`flutter run` doesn't do the SPA rewrite (refreshing a deep link) or serve
`.wasm` with the right type. Build, then serve with the helper from the
repository root (`python` on Windows). It sends paths without a file extension
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

### VS Code

Install the Flutter extension (VS Code suggests it from
`.vscode/extensions.json`). `.vscode/settings.json` points it at the FVM SDK,
`.fvm/versions/<version>`: a link FVM makes when it sets up the project (if
it's missing, run `fvm use <the version in .fvmrc>` in the repository root;
`fvm use` also updates this path when the version changes).
The Run and Debug view then has:

| Configuration | Runs on |
|---|---|
| Web: Chrome, Web: Chrome, WebAssembly | Chrome, debug build (the second with `--wasm`) |
| Desktop: Windows / macOS / Linux | that OS only. For Linux on Windows, open the WSL clone with VS Code's WSL extension (`code .` in `~/flutter-mcp`) and install the Flutter extension in WSL when VS Code suggests it |
| Mobile: Android emulator | the first running emulator; start one from the device picker in the status bar |
| Mobile: iPhone simulator | the first booted simulator named "iPhone…" (Mac only) |
| Mobile: device picked in the status bar | whatever is picked there: a phone on USB, an iPad, any other target |
| Mock API (port 8080) | the mock server, as in "Mock API" above |
| … + mock API | the mock server and the app together; stopping one stops both |

## Check and test

| On | Quality gate (format, analyze, tests for all three packages) |
|---|---|
| Windows | `pwsh tool/check.ps1` |
| macOS, Linux, WSL | `tool/check.sh` |

Golden tests run only on Windows (the reference images are made there) and
skip elsewhere.

The integration flows in `app/integration_test/` run on a real target, one
file per run on desktop (a second app launch in the same run can lose its
debug connection):

```bash
cd app && fvm flutter test integration_test/app_test.dart -d windows
```

The same with `ui_flows_test.dart` and `platform_probe_test.dart` (asks the
real plugins what they can do), and `-d linux` (in WSL), `-d macos` or an
emulator id. More, all in [docs/testing.md](docs/testing.md):

- Android device tests, including airplane mode and GPS steps driven from the
  host: `fvm dart tool/android_device_tests.dart`; native UI (permission
  dialogs, camera, photo picker, share sheet, biometric prompt) with Patrol:
  `--patrol`.
- Chrome: the same flows through `flutter drive` and chromedriver; browser
  prompts and JS vs WebAssembly timings with Playwright in `web_e2e/`.

CI (GitHub Actions): the quality gate, both web builds and the Chrome tests run
on pushes to main and on every pull request (`ci.yml`), and so does the Linux
app build with the integration flows (`desktop.yml`); the Android emulator, iOS simulator, Windows and macOS
app jobs and the Windows golden-test job (`goldens.yml`) run when started by
hand from the Actions tab.

## Troubleshooting

- **FVM on Windows fails to create the link**, or Flutter says building with
  plugins needs symlink support: turn on Developer Mode.
- **`error STL1011` … `/await` building the Windows app**: a plugin other
  than the two that `app/windows/CMakeLists.txt` already handles uses the old
  coroutine flag. Handle its target there the same way: drop `/await`, or, if
  it then fails with C3773, keep the flag and define
  `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` for it.
- **The Android emulator on Windows says hardware acceleration isn't
  available** (often right after installing WSL): turn on **Windows Hypervisor
  Platform** in Windows features. With WSL 2 (Hyper-V) on, the emulator has to
  use it rather than Android's own hypervisor driver; `emulator -accel-check`
  (in the SDK's `emulator` folder) should report WHPX as usable.
- **The quality gate fails in `mock_data` or `mock_server`** with "can't find
  `package:lints`": run `pub get` in both (Setup, step 1.3).
- **`flutter devices` doesn't list a booted iOS simulator** right after
  booting it: run it again; discovery can lag the boot.
- **CocoaPods prints UTF-8 warnings**: `export LANG=en_US.UTF-8`, or install it
  with Homebrew.
- **The Linux build fails with `cannot find -lstdc++`** (or `'type_traits' file
  not found`): clang picked the newest GCC under `/usr/lib/gcc/x86_64-linux-gnu/`
  but its C++ headers are missing; install the matching `libstdc++-<N>-dev`.
- **The Linux app shows no file dialog**: install `xdg-desktop-portal-gtk`.
- **"Connectivity unavailable" in the Linux app's log**: there's no system bus
  or NetworkManager (containers, minimal installs, WSL). The app assumes it's
  online and carries on.
- **In WSL, `flutter` runs the Windows SDK** or fails on Windows paths: use
  `fvm flutter`, and work in the clone under `~`, not under `/mnt`.

## PoC tools (Settings › PoC tools)

- **Results tracker**: pass / partial / fail per scenario and platform, with
  notes; starts with the findings verified so far; export CSV/JSON, import JSON.
- **Adaptive widgets**: Material vs Cupertino side by side.
- **Diagnostics**: versions, renderer, device, storage, permissions, shared-code
  ratio and frame timings; Copy report.
- **Deep-link tester**: every route, open it or send it as a notification.

## Status

| Milestone | Scope | State |
|---|---|---|
| M0 | Toolchain, mock API, theme, router with every route and guard, tests | done |
| M1 | Shell, auth screens, lists, detail, list-detail, photo viewer | done |
| M2 | Wizard, validators, drafts, outbox | done |
| M3 | Camera, files, maps, notifications, biometrics, permissions | done |
| M4 | Appearance, EN/PL, a11y, adaptive widgets, diagnostics, results tracker, goldens, integration tests, wasm build | done (iOS on the iPhone and iPad simulators; no physical devices, decision 117) |
| Desktop | macOS, Windows and Linux apps: desktop capabilities (no camera, Save for exports, Linux can't schedule notifications), deep links, Touch ID / Windows Hello, desktop columns in the Results tracker, CI builds | macOS: flows, probe and deep links pass; Windows: build, flows, probe and deep links pass; Linux (container, and WSL on Windows): build, flows, probe and deep links pass |
