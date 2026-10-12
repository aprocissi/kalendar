# Milestone 1 — Shell

Spec: `docs/SPEC.md` §3, §4 (shell only), §8.5, §12 (skeleton), §13, §17.1, §18.1, §20.

- [x] Repo: `git init`, `.gitignore`, private GitHub repo `darrinm/kalendar`, push
- [x] `Package.swift`: `KalendarCore` (library), `Kalendar` (executable, Sparkle), `KalendarCoreTests`
- [x] Status item: template calendar glyph with today's day number, redrawn on day change; left‑click toggles popover; right‑click menu (Settings…, Check for Updates…, About Kalendar, Quit)
- [x] Popover: 320×600, transient, input row focused on open, Esc closes when empty; signed‑out row; "Sign in again" row
- [ ] Nested‑popover prototype: built (account row → detail popover). **Not verified**: needs a signed‑in account and a real click
- [x] Global hotkey ⌃⌥Space toggles the popover (Carbon). Not verified by hand; another app may hold the same shortcut
- [x] Google sign‑in: PKCE + `ASWebAuthenticationSession`, iOS client, all 7 scopes, granted‑scope check, refresh, revoke on sign‑out, Keychain storage, per‑account `needsReauth`. **Not verified against Google**: needs the user to grant consent
- [x] Settings window: General (Launch at login, Show alerts, Check for updates automatically), Accounts (list with calendar count, Add Account…, Sign In…, Sign Out), placeholder tabs Appearance / Events & Tasks / Calendars
- [x] Launch at login via `SMAppService.mainApp`, on by default at first launch
- [x] `UpdaterController` (Sparkle), started at launch
- [x] `scripts/bundle.sh`, `.github/workflows/release.yml`, `.github/workflows/ci.yml`, `docs/RELEASING.md`, `THIRD-PARTY-NOTICES.md`
- [x] Sparkle EdDSA key pair (`--account kalendar`, public key `IvzRqsKBac2QL1HlpQYED6iLxr+RZ5m/+RSwGEBj7J4=`)
- [ ] Repo secrets: 5 of 7 set. Missing `APPLE_ID`, `APPLE_APP_PASSWORD` (not stored on this Mac)
- [x] Tests: PKCE (RFC 7636 vector), auth URL, callback parsing, token request/response parsing, missing‑scope detection, id_token email, invalid_grant, AccountStore sign‑in/refresh/reauth/sign‑out (15 tests)
- [ ] Verify end to end: sign in to both accounts, see calendar counts, open the detail popover, hotkey

## Review

- `swift build -Xswiftc -warnings-as-errors`, `swift test` (15 pass), `scripts/bundle.sh`, and GitHub CI all pass.
- The bundled app launches, shows the status item, and opens the popover (screenshot checked: month title, sign‑in row, settings button).
- At launch the status item has no on‑screen position for a moment, and `NSPopover.show` silently does nothing against it. Only the `-openPopoverAtLaunch` test path hits this; it waits 1 s.
- cua‑driver's synthetic clicks don't reach SwiftUI buttons in the popover while Kalendar is not the active app, so sign‑in and the nested popover need a manual check.
- The original spec and its screenshots stay on disk in `reference-spec/` (gitignored). `docs/SPEC.md` is the redacted copy in the repo.
