# Screenshots & graphic assets

## What's already generated (in `store/`)
- **`play-icon-512.png`** — 512×512 Google Play Store listing icon.
- **`feature-graphic-1024x500.png`** — Google Play feature graphic (required).
- App launcher icons (Android/iOS/web) are generated from
  `assets/images/app_icon.png` via `flutter_launcher_icons`.

## Captured screenshots (in `store/screenshots/`)
Six **1320×2868** (iPhone 17 Pro Max / App Store 6.9") shots, auto-captured from
the running app:
1. `01-home.png` — home with the size-picker dialog open.
2. `02-classic.png` — classic 9×9 gameplay (logic-rating + mistakes pills).
3. `03-explain.png` — the "Explain the solve" walkthrough.
4. `04-killer.png` — Killer board with dashed cages + sum labels.
5. `05-stats.png` — the Statistics sheet.
6. `06-themes.png` — the Themes picker.

The same 6 shots are captured for iPad in `store/screenshots/ipad/` at
**2064×2752** (13" iPad Pro M4/M5 — Apple's current accepted size for that
class).

These same PNGs work for **Google Play** phone screenshots (any portrait phone
ratio is accepted). See "How to regenerate" below to recapture either set.

**Known issue:** emoji (🐠🌊🔥❄️ etc. in the Themes sheet, 📅 on the Daily
Challenge button) render as boxed "?" placeholder glyphs in these captures.
Adding `fontFamilyFallback: ['Apple Color Emoji', 'Noto Color Emoji']` to
`ThemeData` in `lib/main.dart` did not fix it, and Material icons (Stats /
Themes / Achievements tab icons) render fine — both point to this being an iOS
Simulator-only color-emoji rasterization limitation rather than an app bug.
**Verify on a real device before assuming this is fine** — if it also happens
there, the emoji glyphs need a non-emoji fallback (e.g. plain icons).

## How to regenerate / add shots
The capture is automated — edit the shot list in
`integration_test/screenshot_test.dart`, then:

```bash
xcrun simctl boot "iPhone 17 Pro Max"
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  -d "iPhone 17 Pro Max"
```

The test prints a `SHOT:<name>` marker and holds each screen; capture with a
parallel loop that watches the log and runs
`xcrun simctl io booted screenshot store/screenshots/<name>.png` (more reliable
on the Simulator than `binding.takeScreenshot`). Swap the device for an iPad 13"
simulator to get the 2048×2732 iPad shots.

### Required sizes
**Apple (App Store Connect)** — upload at least the largest iPhone; others are
auto-scaled:
- iPhone 6.7"/6.9": **1290 × 2796** (portrait) — required.
- iPad 13" (only if you ship iPad): **2048 × 2732** — required for iPad.

**Google Play**:
- Phone: **1080 × 2400** (or 1080×1920), portrait — min 2, max 8.
- Feature graphic: **1024 × 500** (provided).
- Hi-res icon: **512 × 512** (provided).
- 7"/10" tablet screenshots: optional.

### How to capture
- iOS Simulator: run on an iPhone 16 Pro Max simulator → ⌘S saves a
  1290×2796 PNG.
- Android emulator: a Pixel 8 Pro emulator → the screenshot button yields a
  1080×2400 PNG.
- Or run `flutter run -d chrome`, size the window to the target ratio, and
  capture — quick for a first listing.

(Ask and these can be captured + framed automatically, e.g. with the
`screenshots` / `fastlane snapshot` tooling.)
