# Store metadata — CrispSudoku

Everything needed to submit CrispSudoku to the **Apple App Store** and **Google
Play**, ready to paste/upload.

## At a glance
| Field | Value |
|-------|-------|
| App name | **CrispSudoku** |
| Bundle / application ID | `com.crispstrobe.sudoku` |
| Version | `1.0.1` (build `5`) — see `../APPSTORE.md` for the release runbook |
| Price | Free |
| In-app purchases | None (see privacy policy if added later) |
| Category | Games → **Puzzle** (Apple secondary: Board) |
| Age rating | Apple **4+** · Google Play **Everyone** (IARC) |
| Data collection | **None** — see `data-safety.md` |
| Copyright | © 2026 Christian Ströbele |
| Languages | English (en-US) |

## URLs
- Support: `https://crispstro.be`
- Marketing: `https://sudoku-lac-five.vercel.app`
- Privacy policy: `https://sudoku-lac-five.vercel.app/privacy`
  (source: `web/privacy.html` / `store/privacy-policy.md`)

## Where everything lives
- **Listing text** (uploadable via Fastlane `deliver`/`supply`):
  - Apple: `fastlane/metadata/en-US/` — `name`, `subtitle`, `promotional_text`,
    `description`, `keywords`, `release_notes`, `support_url`, `marketing_url`,
    `privacy_url`.
  - Play: `fastlane/metadata/android/en-US/` — `title`, `short_description`,
    `full_description`, `changelogs/default.txt`.
- **Graphics**: `store/play-icon-512.png` (Play hi-res icon),
  `store/feature-graphic-1024x500.png` (Play feature graphic). Launcher icons are
  generated from `assets/images/app_icon.png`.
- **Privacy**: `web/privacy.html` (hosted policy), `store/privacy-policy.md`,
  `store/data-safety.md` (questionnaire answers), and Apple's
  `ios/Runner/PrivacyInfo.xcprivacy` privacy manifest.
- **Screenshots**: see `store/screenshots.md` (sizes + shot list — still to
  capture from the running app).

## Field length check (limits)
| Field | Used | Limit |
|-------|------|-------|
| Apple name | 11 | 30 |
| Apple subtitle | 27 | 30 |
| Apple promotional text | 139 | 170 |
| Apple keywords | 98 | 100 |
| Apple/Play description | 1263 | 4000 |
| Play title | 27 | 30 |
| Play short description | 76 | 80 |

## Submission checklist
- [x] App name, bundle ID, icon, About screen, license + NOTICE
- [x] Listing copy, keywords, descriptions, release notes (this folder)
- [x] Privacy policy (hosted) + data-safety answers + iOS privacy manifest
- [x] Play feature graphic + 512 icon
- [ ] **Add `ios/Runner/PrivacyInfo.xcprivacy` to the Runner target in Xcode**
      (drag it into the Runner group, tick the Runner target) so it ships in the
      bundle.
- [x] **Screenshots** — 5 captured at 1320×2868 (`store/screenshots/`); see `screenshots.md` to add more or capture iPad sizes
- [ ] **iOS signing** — Team, distribution certificate, provisioning profile
- [ ] **Apple privacy** — answer "Data Not Collected"; **Play Data Safety** — "No
      data collected" (answers in `data-safety.md`)
- [ ] **Age rating** questionnaires (no objectionable content → 4+ / Everyone)
- [ ] Build & upload (`flutter build ipa` / `flutter build appbundle`)
