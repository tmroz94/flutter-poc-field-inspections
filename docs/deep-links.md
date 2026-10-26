# Deep links and navigation

Every screen has a URL (see `app/lib/core/router/routes.dart`, `RouteTable.all`).
The same location works from:

| Source | Example |
|---|---|
| Web address bar | `http://localhost:5173/inspections/INS-1042?tab=photos` |
| Custom scheme (iOS, Android) | `fieldinspections://app/inspections/INS-1042?tab=photos` |
| Universal / app link | `https://fieldinspections.example/inspections/INS-1042?tab=photos` |
| Notification payload | `{"route": "/inspections/INS-1042?tab=checklist"}` |

`DeepLinks.toLocation` normalises all of these; anything foreign is ignored.

## Guards (in order)

1. Session still restoring → `/splash?from=<target>` (a cold-start link is not lost).
2. Signed out on a guarded path → `/sign-in?from=<target>`; after sign-in → target.
3. Signed in and locked (iOS/Android, biometric lock on) → `/unlock?from=<target>`.
4. Signed in on `/sign-in`, `/sign-up`, `/forgot-password` or `/unlock` → `from` or `/home`.
5. Wizard `?step=` outside 1–5 → step 1. (M2: an earlier invalid step → first invalid step.)
6. Unknown path → 404 screen showing the path. Unknown inspection id → "not found" state on the detail screen (M1).

`from` is honoured only for known, non-auth, in-app paths (no open redirects).

Deep entry builds the back stack from the URL nesting: opening
`/inspections/INS-1042` on a phone and pressing back goes to `/inspections`.

## Testing deep links

Android emulator (app installed, any state: running, background, killed):

```bash
adb shell am start -a android.intent.action.VIEW -d "'fieldinspections://app/inspections?status=overdue,scheduled'"
```

Keep the inner single quotes: the URI goes through the device shell, which
would otherwise split or glob `?`, `&` and `,`. From PowerShell the same
double-then-single quoting works.

iOS simulator (on the Mac):

```bash
xcrun simctl openurl booted "fieldinspections://app/inspections/INS-1042?tab=photos"
```

Web: open or refresh any URL on a host that rewrites unknown paths to
`index.html`. Locally: `fvm flutter build web` then `python tool/serve_web.py`.
`/settings/poc/deep-links` in the app lists every route and opens it.

### Desktop apps

macOS, Windows and Linux open `fieldinspections://` links through `app_links`
(Linux needs its `.desktop` file registered first). Setup and commands:
[setup.md](setup.md#desktop-deep-links).

## Hosting checklist (not needed for local testing)

- SPA rewrite: every path that is not a file → `/index.html` (Firebase `rewrites`, Netlify `_redirects`, nginx `try_files $uri /index.html`).
- iOS universal links: host `/.well-known/apple-app-site-association` and add the Associated Domains entitlement.
- Android app links: host `/.well-known/assetlinks.json` with the signing certificate fingerprint and add an `autoVerify` intent filter.
