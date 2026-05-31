# Screenshots & graphic assets

## What's already generated (in `store/`)
- **`play-icon-512.png`** — 512×512 Google Play Store listing icon.
- **`feature-graphic-1024x500.png`** — Google Play feature graphic (required).
- App launcher icons (Android/iOS/web) are generated from
  `assets/images/app_icon.png` via `flutter_launcher_icons`.

## Captured screenshots (in `store/screenshots/`)
Five **1320×2868** (iPhone 17 Pro Max / App Store 6.9") shots, auto-captured from
the running app:
1. `01-home.png` — home with the variant chooser (Classic / Sudoku-X / Killer).
2. `02-classic.png` — classic 9×9 gameplay (logic-rating + mistakes pills).
3. `03-killer.png` — Killer board with dashed cages + sum labels (headline variant).
4. `04-stats.png` — the Statistics sheet.
5. `05-themes.png` — the Themes picker.

These same PNGs work for **Google Play** phone screenshots (any portrait phone
ratio is accepted). Capture a couple more if you want (e.g. Explain-the-solve,
Sudoku-X diagonals) — see "How to regenerate".

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
