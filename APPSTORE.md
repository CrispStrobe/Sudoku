# App Store release runbook — CrispSudoku

How to cut an iOS App Store release for CrispSudoku entirely from the CLI. The
CI does the build+sign+upload; a small API client (`.appstoreconnect/asc.py`)
does the App Store Connect side (attach build, notes, submit).

| | |
|-------|-------|
| App name | **CrispSudoku** |
| Bundle ID | `com.crispstrobe.sudoku` |
| Apple App ID | `6788990894` |
| Team ID | `N9XSJ4M3GT` |
| ASC API key id | `9RMU3C7422` (shared team key) |

## Current status

- **1.0** (build 3) — `READY_FOR_SALE` (live on the App Store).
- **1.0.1** (build 5) — `WAITING_FOR_REVIEW`. Ships the number-pad scaling fix.

Run `python3 .appstoreconnect/asc.py status` for the live picture.

## The one rule that bites: version numbers

`pubspec.yaml` holds `version: X.Y.Z+BUILD`:

- **`X.Y.Z`** → `CFBundleShortVersionString` (the *marketing* version). Apple
  requires each submitted binary to declare a version **strictly higher** than
  the last **approved** one. Bump this for every new App Store version.
- **`+BUILD`** → `CFBundleVersion`. Must be unique/higher for **every** upload,
  even re-uploads of the same marketing version. Apple rejects duplicates.

> ⚠️ Labeling the App Store Connect *version* "1.0.1" does **not** change the
> binary. If the binary still says `1.0.0`, Apple rejects it with **ITMS-90062**
> ("must contain a higher version than the previously approved version"). Bump
> `X.Y.Z` in `pubspec.yaml`, not just `+BUILD`. (This is exactly why build 4 was
> rejected and rebuilt as `1.0.1+5`.)

## Release steps

1. **Bump the version** in `pubspec.yaml` (e.g. `1.0.0+3` → `1.0.1+5`). New
   store version ⇒ bump `X.Y.Z` **and** `+BUILD`. Same version re-upload ⇒ bump
   `+BUILD` only.

2. **Update release notes** — `fastlane/metadata/en-US/release_notes.txt`
   (this becomes "What's New"; required for updates, not the first version).

3. **Commit and tag** — pushing a `v*` tag triggers the CI workflow
   (`.github/workflows/ios-release.yml`), which builds, signs, and uploads the
   IPA to App Store Connect. (Pushing to `main` alone does nothing.)
   ```sh
   git commit -am "Bump to 1.0.1+5: <why>"
   git push origin main
   git tag -a "v1.0.1+5" -m "App Store build 5: <summary>"
   git push origin "v1.0.1+5"
   ```
   Optional safe dry-run first (build+sign, **no** upload):
   ```sh
   gh workflow run ios-release.yml -f dry_run=true --ref main
   ```
   Watch: `gh run watch <run-id> --exit-status`.

4. **Wait for Apple to process the build** (a few minutes). Poll until VALID:
   ```sh
   python3 .appstoreconnect/asc.py status   # look for "build N  VALID"
   ```

5. **Wire it up and submit** — attach the build to the editable version, set the
   notes, and submit for review:
   ```sh
   python3 .appstoreconnect/asc.py attach    # newest VALID build → editable version
   python3 .appstoreconnect/asc.py notes     # push release_notes.txt as whatsNew
   python3 .appstoreconnect/asc.py submit     # create reviewSubmission + submit
   ```
   For a first version (never approved before), the version won't exist yet —
   create it: `python3 .appstoreconnect/asc.py newversion 1.0.1`.
   To release an already-approved version sitting in `PENDING_DEVELOPER_RELEASE`:
   `python3 .appstoreconnect/asc.py release-pending`.

## `.appstoreconnect/asc.py` command reference

Minimal App Store Connect v1 API client (JWT/ES256 with the shared team key).
**Untracked** — its directory is gitignored because it holds the signing key.

| Command | Does |
|---------|------|
| `status` | app, versions, builds and their states |
| `newversion <X.Y.Z>` | create (or reuse) an editable iOS version |
| `attach` | attach newest VALID build to the editable version |
| `notes` | push `release_notes.txt` as "What's New" per locale |
| `compliance` | set `usesNonExemptEncryption=false` on newest build |
| `submit` | create a reviewSubmission, add the version, submit |
| `release-pending` | release a version in `PENDING_DEVELOPER_RELEASE` |
| `release` | `attach` + `notes` + `submit` in one go |

Key/issuer/bundle are constants at the top of the script; the `.p8` is found in
`.appstoreconnect/`, `~/Downloads/`, or `~/.appstoreconnect/private_keys/`.

## Gotchas seen in practice

- **Export compliance** — submitting fails with a `usesNonExemptEncryption`
  required error unless answered. The app uses no non-exempt encryption, so
  `ios/Runner/Info.plist` now declares `ITSAppUsesNonExemptEncryption = false`,
  which auto-answers it on every build. (`asc.py compliance` sets it via API for
  a build that predates that key.)
- **Stale review submission blocks resubmit** — after a rejection the version
  can stay attached to the old `reviewSubmission` (`ITEM_PART_OF_ANOTHER_SUBMISSION`
  / "not in valid state"). Cancel the old submission (PATCH `canceled: true`);
  once it finalizes to `COMPLETE` the version frees up and `submit` works.
- **Apple blocks `POST /v1/apps`** — the initial app record is browser-only.
  Everything after (metadata, builds, submission) is API-scriptable.

## Local iOS/macOS builds (developer machine)

CI is self-contained; local builds are only needed to *see* the app. As of this
writing local CocoaPods is broken: Homebrew bumped Ruby to 4.0.5, which breaks
Homebrew CocoaPods 1.17.0 (missing the `nkf` gem Ruby 4.0 dropped). Work around
it with the `chruby` Ruby 3.1.3 + CocoaPods 1.16.2 that still work:

```sh
export PATH="$HOME/.rubies/ruby-3.1.3/bin:$HOME/.gem/ruby/3.1.3/bin:$PATH"
unset GEM_HOME GEM_PATH RUBYOPT
flutter run -d macos --release
```

## Related docs

- `store/README.md` — listing metadata, field-length limits, asset locations.
- `store/privacy-policy.md`, `store/data-safety.md` — privacy answers.
- `store/screenshots.md` — screenshot sizes and shot list.
