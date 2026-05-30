# Screenshots & graphic assets

## What's already generated (in `store/`)
- **`play-icon-512.png`** — 512×512 Google Play Store listing icon.
- **`feature-graphic-1024x500.png`** — Google Play feature graphic (required).
- App launcher icons (Android/iOS/web) are generated from
  `assets/images/app_icon.png` via `flutter_launcher_icons`.

## Screenshots still to capture (from the running app)
1–8 per device. Recommended shot list (the screens that sell the app):
1. **Home** — shows the variant/mode buttons and Daily Challenge.
2. **Classic 9×9 mid-game** — board, number pad, mistakes/logic pills.
3. **Killer** — a board with dashed cages + sum labels (the headline variant).
4. **Explain the solve** — the step-by-step walkthrough with a technique caption.
5. **Next logical step hint** — the explanation dialog.
6. **Statistics** sheet.
7. **Themes** picker.
8. **Sudoku-X** — a board with the highlighted diagonals.

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
