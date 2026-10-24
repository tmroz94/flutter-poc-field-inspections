# Flutter PoC – Field Inspections

One Flutter codebase for **iOS, Android and Web**, built to find out how well
a single codebase covers common app scenarios: navigation, deep links, forms,
lists, animations, offline data and platform integrations. The design is the
Claude Design canvas "Flutter PoC – Field Inspections" (Material 3).

| Folder | What |
|---|---|
| `app/` | Flutter app (android, ios, web) |
| `packages/mock_data/` | Pure-Dart fixtures + in-memory backend, shared by the server and the app's offline fake |
| `mock_server/` | Local REST mock API (shelf): CORS, latency and failure injection |
| `design/` | Design tokens copied from the canvas |
| `docs/` | `decisions.md` (how mock gaps were resolved), `deep-links.md`, `platform-setup.md` (Android/iOS/web specifics, Mac steps) |
| `tool/` | `check.ps1` / `check.sh` quality gate, `serve_web.py`, `gen_color_schemes.py` |

## Setup

Flutter is pinned with [FVM](https://fvm.app) in `.fvmrc` (currently 3.47.8).

```bash
fvm install
```

On Windows FVM needs Developer Mode (Settings › System › For developers) to
create its SDK link. iOS builds need a Mac with Xcode; use the same `.fvmrc`.

## Run

Mock API (optional; without it the app uses its built-in offline fake):

```bash
fvm dart run mock_server/bin/server.dart --port 8080
```

App:

```bash
cd app && fvm flutter run -d chrome
```

```bash
cd app && fvm flutter run -d emulator-5554
```

On the Mac: `cd app && fvm flutter run -d ios`.

Demo account: `anna.nowak@example.com` / `inspect123` (mock backend only), or
tap **Use demo account**.

Web like production (SPA rewrite, so deep-link refresh works; serves `.wasm` as
`application/wasm` for SQLite on the web):

```bash
cd app && fvm flutter build web && cd .. && python tool/serve_web.py
```

## Check

```bash
pwsh tool/check.ps1
```

Runs format check, analyze and tests for all three packages. On macOS/Linux:
`tool/check.sh`.

## Status

| Milestone | Scope | State |
|---|---|---|
| M0 | Toolchain, mock API, theme, router with every route and guard, tests | done |
| M1 | Shell, auth screens, lists, detail, list-detail, photo viewer | done |
| M2 | Wizard, validators, drafts, outbox | done |
| M3 | Camera, files, maps, notifications, biometrics, permissions | done |
| M4 | Appearance, l10n, a11y, adaptive widgets, diagnostics, results tracker | next |
