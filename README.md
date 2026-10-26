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
| `docs/` | `setup.md` (machine setup on macOS, Linux and Windows; running every target), `decisions.md` (how mock gaps were resolved), `deep-links.md`, `platform-setup.md` (Android/iOS/web/desktop specifics, what's verified), `testing.md` (tests, goldens, integration tests, JS vs wasm) |
| `web_e2e/` | Playwright tests of the web builds: browser prompts (notifications, location, camera) and JS vs WebAssembly frame timings |
| `tool/` | `check.ps1` / `check.sh` quality gate, `serve_web.py` (SPA host, optional COOP/COEP), `code_stats.dart` (shared-code ratio for Diagnostics), `android_device_tests.dart` (device tests with adb-driven steps), `linux_container/` (build and test the Linux app in Docker), `gen_color_schemes.py` |

## Setup

Flutter is pinned with [FVM](https://fvm.app) in `.fvmrc` (currently 3.47.8).
Step-by-step setup for macOS, Linux and Windows, what each machine can build,
and how to run every target: **[docs/setup.md](docs/setup.md)**. In short:

```bash
fvm install
```

```bash
cd app && fvm flutter pub get
```

## Run

Mock API (optional; without it the app uses its built-in offline fake). On a
fresh clone, get its packages once:

```bash
cd mock_server && fvm dart pub get && cd ..
```

```bash
fvm dart run mock_server/bin/server.dart --port 8080
```

It listens on 127.0.0.1, which the browser, the iOS simulator, the desktop
apps and the Android emulator (through 10.0.2.2, the host's loopback) can all
reach. For a phone on the same Wi-Fi add `--host 0.0.0.0` and run the app with
`--dart-define=API_URL=http://<pc-ip>:8080/api`; anyone on that network can
then use the mock API, so only do it on a network you trust.

App, from `app/` (`fvm flutter devices` lists the targets):

```bash
fvm flutter run -d chrome
```

Other targets: `-d emulator-5554` (Android), `-d <simulator id>` (iOS, on a
Mac), `-d macos`, `-d linux`, `-d windows` (each on its own OS). Production-like
web builds, release builds and what differs on desktop: [docs/setup.md](docs/setup.md#run).

Demo account: `anna.nowak@example.com` / `inspect123` (mock backend only), or
tap **Use demo account**.

## Check

```bash
pwsh tool/check.ps1
```

Runs format check, analyze and tests for all three packages (unit, widget,
router, accessibility and golden tests). On macOS/Linux: `tool/check.sh`.
Device tests (Android, including airplane mode and GPS steps driven from the host): `fvm dart tool/android_device_tests.dart`. Native UI (permission dialogs, camera, photo picker, share sheet, biometric prompt, notification tap after a kill) with Patrol: `fvm dart tool/android_device_tests.dart --patrol`. Web: the same flows in Chrome via `flutter drive`, and browser prompts plus JS vs WebAssembly timings with Playwright in `web_e2e/` (see `docs/testing.md`).
Details in `docs/testing.md`.

CI (GitHub Actions): the quality gate, both web builds and the Chrome tests run on every push (`.github/workflows/ci.yml`), and so does the Linux app build with the integration flows (`desktop.yml`); the Android emulator, iOS simulator, Windows and macOS app jobs and the Windows golden-test job (`goldens.yml`) run when started by hand from the Actions tab.

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
| M4 | Appearance, EN/PL, a11y, adaptive widgets, diagnostics, results tracker, goldens, integration tests, wasm build | done (iOS: simulator checks done, a physical iPhone still to do) |
| Desktop | macOS, Windows and Linux apps: desktop capabilities (no camera, Save for exports, Linux can't schedule notifications), deep links, Touch ID / Windows Hello, desktop columns in the Results tracker, CI builds | macOS: flows, probe and deep links pass; Linux (container): build, flows, probe and deep links pass; Windows: not yet run |
