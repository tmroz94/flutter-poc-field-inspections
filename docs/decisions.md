# Decisions

Gaps and conflicts in the design mocks, and choices made while building the
PoC. Each one is resolved by checking, in order: Material 3 guidelines; platform
conventions (Apple HIG, Android); web standards (WCAG 2.2 AA, WAI-ARIA, HTML
forms); common practice in other design systems (Bootstrap, Tailwind UI) where
M3 says nothing.

| # | Issue | Decision | Source |
|---|---|---|---|
| 1 | Flutter 3.47 moved Material and Cupertino out of the framework into `material_ui` / `cupertino_ui`; go_router 18 already uses them | App imports `package:material_ui` and `package:cupertino_ui`, not `package:flutter/material.dart`. Packages still on the old import get `MaterialUiCompatibilityBridge` only if one turns up (it is deprecated) | material_ui README, go_router 18.0.0 changelog |
| 2 | `material_ui` has its own `ContrastLevel` (token-backed baseline schemes) | Keep the six schemes generated from the canvas tokens (`tool/gen_color_schemes.py`) so colors match the mocks exactly; app enum is `AppContrast` | Canvas `m3-tokens.css` |
| 3 | Mocks use Roboto everywhere | Use the platform font: Roboto on Android and web, SF on iOS. Nothing to download or bundle | Apple HIG typography; M3 type scale unchanged |
| 4 | P06 detail has no navigation bar | Detail stays inside its tab: the bar stays visible on phones and the tab keeps its own back stack | M3 navigation bar: "visible on all top-level and most second-level destinations" |
| 5 | "Forgot password?" link and register flow have no screens | Add `/forgot-password` and `/sign-up` in the P01/D01 style | Mocks link to them |
| 6 | Reset password must not reveal accounts | Always the same "if an account exists…" message; API answers 202 for any email | OWASP account-enumeration guidance |
| 7 | `?from=` return target after sign-in could redirect off-site | Only in-app paths of known, non-auth routes are honoured; else home | OWASP unvalidated redirects |
| 8 | Unknown URLs while signed out | 404 shows without sign-in (it shows no data); "Go to home" then hits the guard | Web convention: 404 does not depend on auth |
| 9 | Filter sheet (P05) and result sheet (P22) are modals | They get URLs (sheet pages) so they deep-link, survive refresh, and close with browser back / Esc / system back | M3 bottom sheets; WAI-ARIA dialog (Esc closes) |
| 10 | Date picker, time picker, unsaved-changes dialog, snackbars | Not URL-addressable: transient, need the current screen's state | M3 dialogs; common web practice |
| 11 | Custom-scheme deep links lose the first path segment as the URI host | Scheme links use host `app`: `fieldinspections://app/inspections/INS-1042` | RFC 3986 URI structure |
| 12 | Riverpod/freezed code generation | M0 uses hand-written providers and models: less tooling for a PoC. Revisit if models grow | Riverpod docs: codegen optional |
| 13 | Desktop/web defaults to compact visual density (smaller targets) | Standard density and padded tap targets everywhere: 48dp (M3), 44pt (HIG) | M3 accessibility; WCAG 2.5.8 |
| 14 | Biometric lock on cold start | Lock when a session is restored with the setting on; web never locks | Board "App resumed" note; P26 |
| 15 | Photo viewer has 5 dots for 8 photos (P08) | One dot per photo; switch to a "3 of 8" counter above 10 photos | M3 carousel / page indicator |
| 16 | "Untested" (P21) vs "Not tested" (D05) | "Not tested" everywhere | Consistency |
| 17 | Mock component CSS (`bundle.css`) is not in the canvas files | Component sizes use Flutter's M3 defaults | — |
| 18 | Motion tokens undefined in the canvas | M3 durations and easing (`Durations.short4`, `Easing.emphasizedDecelerate`) | M3 motion |
| 19 | Maps package "not chosen" | `flutter_map` with OpenStreetMap tiles: no API keys, same code on iOS, Android, web | Coverage board watch-out |
| 20 | Mocks never validate input | Validation rules per form, see the plan's validator table and `lib/core/validation` | — |
| 21 | Web browser back skips the unsaved-changes dialog | `PopScope` + go_router `onExit`, plus `beforeunload` for tab close/reload (M2) | D05 sample note |
| 22 | Web has no pull-to-refresh, swipe actions | Refresh button; row menu (D03 pattern) | Coverage board |
| 23 | No dedicated tablet home board | Phone layout inside the rail shell, cards in a responsive grid | T01 / D02 |
| 24 | After a deep link straight to a detail, Back keeps the detail's `?tab=` on the list URL (go_router does not re-run redirects on pop) | Direct links are cleaned by a redirect; the detail's back button goes to the list location explicitly (keeps filters, drops `tab`). System back still pops; the list ignores unknown keys | Found on the Android emulator |
| 25 | go_router does not put `push`/`replace` locations in the browser URL by default | `GoRouter.optionURLReflectsImperativeAPIs = true`: photo viewer, tabs and sheets always show their real URL | Found in Chrome (M1) |
| 26 | Detail tabs and photo paging change the URL; should browser back step through them? | No: they `replace` the URL, so back leaves the inspection / viewer (one history entry per screen) | Common web practice (Gmail, GitHub tabs) |
| 27 | Opening a row on tablet/desktop lost the list filters | The detail URL carries the list filters (`/inspections/INS-1038?status=overdue`), so the list pane and Back keep them | Found in Chrome (M1) |
| 28 | Table (D03) vs list (T01) on wide screens | Data table from 1200 px, list pane 840–1199; "Load more" button in the table instead of infinite scroll | D03 / T01 boards |
| 29 | "Keep me signed in" in P01 has no defined behaviour | Unchecked: session kept in memory only and ends when the app or tab closes | Common web practice |
| 30 | Swipe-to-archive has no confirmation in the mocks | Archive at once with an Undo snackbar (optimistic; restored if the server refuses) | M3 snackbar guidance: offer undo instead of confirming |
| 31 | Local storage for drafts and the outbox | drift (SQLite) everywhere; on web SQLite runs as WebAssembly (`web/sqlite3.wasm`, `web/drift_worker.js` from the drift 2.35.3 release; host must serve `.wasm` as `application/wasm`) | Plan; user choice |
| 32 | Tab close/reload during the wizard (`beforeunload` in the plan) | Not added: every change autosaves within 0.4 s and reloads restore the draft, so a browser "leave site?" prompt would protect nothing | Autosave covers it |
| 33 | Step guard (`?step=` past an invalid step) | Checked in the wizard once the draft has loaded (the router redirect can't wait for storage); navigates to the first invalid step with a message | — |
| 34 | Browser back inside the wizard | Each step is a history entry (`go`), so back moves to the previous step; leaving the wizard (close, step-1 back, browser back past step 1, links) asks first via `PopScope` + go_router `onExit` | M3 full-screen dialogs; web history |
| 35 | Validation feedback on Next | Inline errors plus a screen-reader announcement; no snackbar (it covered the footer buttons on phones) | Found in widget tests |
| 36 | English locale | en-GB: 24-hour time, day-month dates and Monday-first calendars, matching the boards (P10, P14) | Boards |
| 37 | Success screen route | `/inspections/:id/submitted` sits outside the shell: it replaces the wizard and avoids a framework Hero assertion when the shell was never laid out (cold start into the wizard) | Found in widget tests |
| 38 | Offline submit of a new inspection has no id yet | Queued in the outbox; success screen shows "saved and queued" without an id; Home lists it under "Waiting to send" | P16 note |
| 39 | Camera, gallery and file picking in M2 | Simulated (placeholder photos/files) so the flow and validation are testable; real capture in M3 | Milestone plan |
| 40 | While the stored session loads, the old `/splash?from=` redirect added a browser history entry, so Back after a reload bounced forward again (back-button trap) | The router isn't built during restore; the splash shows at the current URL and the first route parse happens with the session known | Found in Chrome (M2) |
| 41 | Sign-in, sign-up and unlock redirect to the original target as a new history entry, so Back lands on sign-in, which redirects forward again | After success the app navigates to the target inside `Router.neglect`, replacing the sign-in/unlock entry; covered by a test that records browser history updates | Found in Chrome (M2) |
| 42 | A link opened while the app is cold-starting on Android was dropped (the app reopened the task's previous link) | The router's route-information provider is listened to for the app's whole lifetime, so platform links that arrive during the splash are kept | Found on the Android emulator (M2) |
| 43 | Maps package (P18) | flutter_map + OpenStreetMap tiles: same code on all three platforms, no API keys. Production needs a tile provider (OSM usage policy) | Coverage board |
| 44 | Photo bytes for drafts | Stored in the same SQLite database (`blobs` table, schema v2) so they survive reloads on web too; uploaded as metadata only to the mock API | PoC scope |
| 45 | PDF report fonts | Built-in Helvetica; Polish letters are transliterated. Production: bundle a Unicode font (e.g. Noto Sans) in the PDF | pdf package |
| 46 | Android CAMERA permission | Not declared: image_picker uses the system camera app, and declaring CAMERA would make that intent require the permission | image_picker docs |
| 47 | compileSdk | 37 (permission_handler_android needs it); AGP warns it's above its tested 36, builds fine | Build error (M3) |
| 48 | Reminders | 30 min before each open inspection, inexact alarms (no exact-alarm permission); web can't schedule, so the setting is disabled there with an explanation | flutter_local_notifications web limitations |
| 49 | Notification payloads | Always an in-app route, routed through the same `DeepLinks` check as links (foreign payloads ignored); a tap that cold-starts the app becomes the initial location | — |
| 50 | Biometric unlock fallback | Device PIN/pattern allowed (`biometricOnly: false`); "Use password instead" signs out | HIG / Android biometric guidelines |
| 51 | Web "Use webcam" (D04) | The camera button uses the browser's file input with capture; live webcam preview is out of PoC scope | — |
| 52 | Map fixed-size bug | The map was unpositioned in a Stack and laid out at 0×0 (no tiles); fixed with `Positioned.fill` and a size test | Found in Chrome (M3) |
| 53 | Dictate note (speech-to-text) | Not built (stretch goal); the chip is shown disabled | Plan: stretch |
