# CrispSudoku

A Flutter Sudoku game with classic, **jigsaw** (irregular-region), **Sudoku-X**
(diagonal) and **Killer** (summed-cage) variants across six grid sizes (4×4, 6×6,
8×8, 9×9, 10×10, 12×12) and four difficulties. Features
a **daily challenge** (same board for everyone each day), a **logic difficulty
rating** and a step-by-step **"explain the solve"** walkthrough (both powered by a
human-technique solver), smart hints (a board-wide **"next logical step"** plus a
per-difficulty **hint budget**), pencil-mark **notes**, **undo**, live conflict
highlighting, a **mistake limit** (lose path) that scales with difficulty, themes,
achievements, a **statistics** screen, persisted stats, and a celebratory particle
layer.

## Architecture

- **`lib/sudoku_game.dart`** — the pure-Dart engine (no Flutter widget deps):
  enums, `PuzzleBlueprint`, `SmartHint`, and the `SudokuGame` class (generation,
  uniqueness-preserving hole digging, validation, hints). Fully unit-testable.
- **`lib/main.dart`** — the UI: screens, theming, particle overlay, the puzzle
  cache, on-disk storage of solved blueprints, and persisted player stats
  (`stats.json`: solved count, current/longest streak, games lost, daily-puzzle
  completion, best time, achievements, unlocked themes).
- **`lib/technique_solver.dart`** — a pure-Dart human-technique logical solver
  (naked/hidden singles, locked candidates, naked/hidden pairs/triples, X-wing)
  over rows/columns/regions (plus diagonals for Sudoku-X), so it works for every
  variant. Powers the logic difficulty rating, the "next logical step" hint, and
  the explain-the-solve mode.
- **`lib/variant_engine.dart`** — the **Killer** engine, built on the pure-Dart
  `dart_csp` constraint solver: `KillerCage`/`KillerPuzzle`, cage validation, and
  `VariantEngine.solveKiller`/`killerHasUniqueSolution`/`generateKiller`.
  Generation reuses the bitmask engine for the base solution and only uses the CSP
  solver for cage-sum uniqueness, so a 9×9 Killer generates in ~100ms.
- **`lib/sudoku_game.g.dart`** — generated `json_serializable` code for
  `PuzzleBlueprint`. Regenerate with build_runner (below).

### How generation works

A complete grid is solved with MRV backtracking over **incremental row/column/
region bitmasks** (O(1) safety checks — this keeps even irregular 10×10/12×12
jigsaw layouts sub-second). Cells are then removed one at a time, each kept **only
if the puzzle still has exactly one solution** (bounded by a time budget). On
native platforms generation runs in a **killable background isolate**; the web has
no `Isolate.spawn`, so it generates inline (fast enough for all sizes).

### Small-screen layout

The game screen derives its chrome — outer padding, the gaps between blocks,
the number-pad tile size and the control row's button diameter — from the
viewport rather than from constants, and treats a small/old iPhone (a 320×568
SE, a 375×667 6/7/8) as its own case. There the chrome yields: on a 320pt
screen the board went from roughly half the screen width to filling it, because
the pad no longer claims 42% of the body and the hint button's label scales down
instead of wrapping one character per line. `test/board_layout_test.dart` pins
the floor for each phone class.

In landscape the stacked layout is the wrong shape entirely: the board and the
chrome compete for height, the scarce axis, while width sits empty either side.
There the chrome moves into a panel beside the board, sized from whatever width
the (height-bound, square) board leaves over — on a 568×320 phone that takes the
board from about 90pt to 244pt and the number pad from 29pt tiles to 46pt ones.
The same layout is what a desktop browser window gets.

### Pre-built puzzle database

`assets/puzzles.json` ships a set of pre-solved blueprints (generated offline) that
load at startup, so the first play — and the web build — is instant with no on-device
solving. Regenerate it with:

```bash
dart run tool/generate_puzzles.dart [perKey]   # default 12
```

Player-generated solutions are additionally cached in `shared_preferences`
(cross-platform, incl. web).

## Running

```bash
flutter pub get
flutter run                # pick a device, or:
flutter run -d chrome      # web
```

The **Admin** panel (debug builds only) pre-generates puzzles into the on-disk cache.

## Testing

```bash
flutter test               # unit + widget tests (92)
flutter analyze            # static analysis (expected: no issues)
dart format .              # formatting (checked in CI)
```

CI (`.github/workflows/ci.yml`) runs format-check, `flutter analyze`, and
`flutter test` on every push to `main` and on PRs.

- `test/sudoku_game_test.dart` — engine unit tests: valid solutions, region
  shape/connectivity, **unique-solution guarantee** (verified by an independent
  solver), move validation, win conditions, hints, mistake-/hint-budget ramps,
  board reset, **daily-puzzle determinism**, and blueprint JSON round-trips.
- `test/game_stats_test.dart` — persisted-stats logic: JSON round-trip, the
  `longestStreak ≥ currentStreak` invariant, streak/marathon achievements across a
  loss, and daily-completion tracking.
- `test/persistence_test.dart` — `shared_preferences`-backed puzzle cache and the
  bundled puzzle database.
- `test/technique_solver_test.dart` — the human-technique solver: correctness
  against generated classic/jigsaw solutions, `nextStep`, technique-isolation
  cases, and the difficulty mapping.
- `test/widget_test.dart` — widget/integration tests: home navigation, the
  narrow-phone layout, the stats sheet, a live 4×4 play-through and drag-to-place,
  the logic-rating pill, the next-logical-step hint, the explain walkthrough, and
  the notes-mode, completion-dialog, hint-exhaustion, lose-path and daily-launch
  flows.

## Deploying (Vercel)

The web build is a static site. Because Vercel's build image has no Flutter, we
build locally and deploy the prebuilt `build/web`. `./deploy.sh` does this in one
step (build → write `vercel.json` → link the `sudoku` project → deploy):

```bash
./deploy.sh            # production deploy (JS/canvaskit)
./deploy.sh --preview  # preview deploy
./deploy.sh --wasm     # WebAssembly (skwasm) build + COOP/COEP headers
```

Requires `vercel login` (or a `VERCEL_TOKEN` env var). Live at
https://sudoku-lac-five.vercel.app

## Deploying (GitHub Pages)

A second, free mirror, published by the `Pages` workflow on every `v*` tag (or
manually via *Run workflow*). Pages serves from a subpath, so that build passes
`--base-href /Sudoku/`; it also copies `index.html` to `404.html`, which is how
a static Pages site gets the SPA deep-link fallback Vercel does with a rewrite.
Live at https://crispstrobe.github.io/Sudoku/

## Checking the web build's number semantics

`flutter test` runs on the Dart VM, where `int` is a true 64-bit integer.
dart2js compiles `int` to a JS double and cannot allocate a `Uint64List` at all,
so engine code that is correct under `flutter test` can still throw in a
browser. The Killer generator leans on the `dart_csp` solver, which is where
that bit us, so there is a probe that compiles the real generator with dart2js
and runs it:

```bash
dart compile js -o /tmp/probe.js tool/web_killer_probe.dart
node -e 'globalThis.self = globalThis; require("/tmp/probe.js")'
```

Every line should say `OK`. A `FAIL` there means Killer is broken on the web
even when the whole Flutter suite is green.

## Regenerating serialization code

```bash
dart run build_runner build --delete-conflicting-outputs
```

## About & licenses

An in-app **About** screen (Home → *About & Licenses*) shows the version
(`package_info_plus`), contact/legal info, and a **Open-source licenses** button
that opens Flutter's `showLicensePage` listing every bundled dependency.

## Store release

App-store metadata is prepared under [`store/`](store/) (listing copy, privacy
policy, data-safety answers, screenshot specs, Play graphics) with uploadable
Fastlane text in `fastlane/metadata/`. The privacy policy is hosted at
`/privacy.html`, and Apple's privacy manifest is at
`ios/Runner/PrivacyInfo.xcprivacy`. See [`store/README.md`](store/README.md) for
the submission checklist.

## License

CrispSudoku is free software licensed under the **GNU Affero General Public
License v3.0 or later** (see [`LICENSE`](LICENSE)). As the sole copyright holder,
the author additionally distributes official app-store binaries (Apple App Store
/ Google Play), including any in-app purchases, under those stores' standard
terms — see [`NOTICE`](NOTICE). Third-party components (notably the MIT-licensed
[`dart_csp`](https://github.com/CrispStrobe/dart_csp) solver) retain their own
licenses.
</content>
