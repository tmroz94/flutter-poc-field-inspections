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
| 24 | After a deep link straight to a detail, Back keeps the detail's `?tab=` on the list URL (go_router does not re-run redirects on pop) | Direct links are cleaned by a redirect; the list ignores unknown keys. M1: the detail's back action goes to the list location explicitly | Found on the Android emulator |
