# Sudoku Master Pro

A Flutter Sudoku game with classic, **jigsaw** (irregular-region) and **Sudoku-X**
(diagonal) variants across six grid sizes (4×4, 6×6, 8×8, 9×9, 10×10, 12×12) and
four difficulties. Features
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
- **`lib/sudoku_game.g.dart`** — generated `json_serializable` code for
  `PuzzleBlueprint`. Regenerate with build_runner (below).

### How generation works

A complete grid is solved with MRV backtracking over **incremental row/column/
region bitmasks** (O(1) safety checks — this keeps even irregular 10×10/12×12
jigsaw layouts sub-second). Cells are then removed one at a time, each kept **only
if the puzzle still has exactly one solution** (bounded by a time budget). On
native platforms generation runs in a **killable background isolate**; the web has
no `Isolate.spawn`, so it generates inline (fast enough for all sizes).

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
flutter test               # unit + widget tests (79)
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

## Regenerating serialization code

```bash
dart run build_runner build --delete-conflicting-outputs
```
</content>
