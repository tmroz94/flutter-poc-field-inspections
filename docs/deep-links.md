# Deep links and navigation

Every screen has a URL (see `app/lib/core/router/routes.dart`, `RouteTable.all`).
The same location works from:

| Source | Example |
|---|---|
| Web address bar | `http://localhost:5173/inspections/INS-1042?tab=photos` |
| Custom scheme (iOS, Android, macOS, Windows, Linux) | `fieldinspections://app/inspections/INS-1042?tab=photos` |
| Universal / app link (once hosted, see the [hosting checklist](#hosting-checklist-not-needed-for-local-testing)) | `https://fieldinspections.example/inspections/INS-1042?tab=photos` |
| Notification payload (the route itself) | `/inspections/INS-1042?tab=checklist` |

`DeepLinks.toLocation` normalises all of these. A link from another site or
scheme that reaches the router goes to Home; a notification payload that isn't
an in-app route is ignored. The parser already accepts the universal-link host,
but no app has its Associated Domains or verified `https` intent filter yet
([platform-setup.md](platform-setup.md)).

## Guards (in order)

1. Session still restoring → no redirect: the splash screen shows in place of
   the router at the current URL, and the router is built (and parses the
   link) once the session is known, so a cold-start link is not lost and no
   extra history entry is added.
2. Signed out on a guarded path → `/sign-in?from=<target>`; after sign-in → target.
   "Use password instead" on the lock screen keeps its `from` the same way.
3. Signed in and locked (biometric lock on: iOS, Android, macOS, Windows) → `/unlock?from=<target>`.
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
[platform-setup.md](platform-setup.md#desktop-deep-links).

## Hosting checklist (not needed for local testing)

- SPA rewrite: every path that is not a file → `/index.html` (Firebase `rewrites`, Netlify `_redirects`, nginx `try_files $uri /index.html`). Better still, rewrite only paths without a file extension, so a missing asset is a 404 rather than HTML (what `tool/serve_web.py` does).
- iOS universal links: host `/.well-known/apple-app-site-association` and add the Associated Domains entitlement.
- Android app links: host `/.well-known/assetlinks.json` with the signing certificate fingerprint and add an `autoVerify` intent filter.
