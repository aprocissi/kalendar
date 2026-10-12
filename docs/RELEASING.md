# Releasing Kalendar

A release is a git tag. `.github/workflows/release.yml` does the rest: builds, signs with
Developer ID, packages a DMG, notarizes and staples it, signs the update for Sparkle, and
publishes both `Kalendar.dmg` and `appcast.xml` to the GitHub release. The app's `SUFeedURL` is
`https://github.com/darrinm/kalendar/releases/latest/download/appcast.xml`.

```sh
git tag v0.2.0
git push origin v0.2.0
```

**The repository must be public before the first release.** Installed copies download the
appcast and the DMG from GitHub without signing in, which only works for a public repository.

## One-time setup

Seven repository secrets. The workflow builds on a clean runner and needs nothing else.

### Signing certificate

The Developer ID Application certificate is the one Kapture uses (team HTBMTPEP6H). Its `.p12`
and export password are in `~/src/kapture/.kapture-signing/`.

- `DEVELOPER_ID_P12` — `base64 -i developer-id.p12`
- `DEVELOPER_ID_P12_PASSWORD` — the export password

An *Apple Development* certificate is not enough. Local `bundle.sh` builds use it, but macOS
refuses a downloaded app signed with it.

### Notarization

- `APPLE_ID` — the Apple ID of the developer account
- `APPLE_TEAM_ID` — `HTBMTPEP6H`
- `APPLE_APP_PASSWORD` — an app-specific password from appleid.apple.com, *not* the account
  password

### Sparkle update keys

Kalendar has its own key pair, stored in the login Keychain under the account name `kalendar` so
it is separate from Kapture's:

```sh
.build/artifacts/sparkle/Sparkle/bin/generate_keys --account kalendar          # prints the public key
.build/artifacts/sparkle/Sparkle/bin/generate_keys --account kalendar -x private.key
```

Put the contents of `private.key` in `SPARKLE_PRIVATE_KEY` and the public key in
`SPARKLE_PUBLIC_KEY`, then delete `private.key`.

The public key is baked into `Info.plist` as `SUPublicEDKey` at bundle time. A build without it
(any local `bundle.sh` run) has its updater disabled; "Check for Updates…" opens the releases page
instead.

**Do not rotate the private key.** Installed copies trust only the public key they shipped with.
A new key means those copies stop seeing updates and must be reinstalled by hand.

## What each release must pass

The workflow fails rather than publishing if any of these fail:

- `codesign --verify --deep --strict` passes, the identity is Developer ID, and the app has no
  entitlements
- `notarytool submit --wait` is accepted and `stapler staple` succeeds
- `spctl -a -t open` accepts the DMG
- the generated appcast parses as XML

## Version numbers

`CFBundleShortVersionString` comes from the tag (`v0.2.0` → `0.2.0`) and `CFBundleVersion` from
the workflow run number, which only increases. Sparkle compares `CFBundleVersion`, so re-running
an older tag never produces a build that looks newer than a later release.
