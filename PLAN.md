# Sudoku — Audit & Optimization Plan

A full review of the repo (`lib/main.dart`, a single 3366-line file containing the
entire app) plus the broken test and generated code. This document records every
issue found, the fix, and the execution order. Status markers are updated as work
lands: `[ ]` todo, `[x]` done.

## Baseline (before work)

- `flutter analyze` → **41 issues**: 1 error, 8 warnings, ~32 infos.
- `flutter test` → **fails to compile** (test references non-existent `MyApp`).
- Architecture: one 3366-line `main.dart`; game logic and UI fully entangled, so
  the engine cannot be unit-tested.

---

## 1. Correctness bugs

- [x] **C1 — Broken test file.** `test/widget_test.dart` is the default counter
  template referencing `MyApp()`/`Icons.add`, neither of which exist. Compile error.
  → Replace with real tests.
- [x] **C2 — Puzzles are not guaranteed to have a unique solution.** Generation
  fills a complete grid then `_removeRandomCells` digs holes blindly (40–70% of
  cells) with no uniqueness check. Expert/large boards almost always end up with
  multiple solutions — not a valid Sudoku.
  → Dig holes with a solution-counter (cap at 2) and a time budget; only remove a
  cell if the puzzle stays uniquely solvable.
- [x] **C3 — `isCompleted()` does not validate.** It only checks "no empty cells".
  The *Give Answer* hint writes `solution[r][c]` via `setCell`, bypassing
  `isValidMove`, so a full board containing conflicts is declared "complete".
  → Add `isSolved()` that requires a full board **and** zero row/col/region conflicts;
  use it for the win condition.
- [x] **C4 — `_isHiddenSingle` only inspects the region.** Its description claims
  row/column/region. → Check all three units.
- [x] **C5 — `debugMode = true` hardcoded.** Ships the Admin panel and unlocks all
  themes in release builds. → Derive from `kDebugMode`.
- [x] **C6 — Isolate leak on timeout.** `SudokuGame.create` runs `compute(...)` then
  `.timeout(3s)`; on timeout the background isolate keeps running. The retry wrapper
  also re-applies a 3s timeout on top, so failures stack. → Simplify the retry/timeout
  story and document the limitation.
- [x] **C7 — Stats are not persisted.** `GameStats` was entirely static; solved
  count, streak, best time, achievements and unlocked themes reset every launch.
  → Added `GameStats.toJson`/`applyJson` plus a `StatsService` that reads/writes
  `stats.json`. Loaded at startup; saved on puzzle completion and theme change.
  `applyJson` is tolerant of missing/garbage keys, always keeps 'Ocean' unlocked,
  and never selects a locked/unknown theme. Covered by `test/game_stats_test.dart`.

## 2. Performance

- [x] **P1 — 60fps full-tree rebuild.** `_particleController` repeats every 16ms and
  its listener calls `setState` on the whole `GameScreen`, rebuilding the grid +
  number pad 60×/sec even with zero particles. Major CPU/battery drain.
  → Move particles into their own `RepaintBoundary` driven by a `CustomPainter`/
  isolated widget; only animate when particles exist.
- [x] **P2 — Per-cell `AnimatedBuilder` on the pulse animation.** Every cell rebuilds
  on each pulse tick though only the selected cell scales. → Scope the animation to
  the selected cell.
- [~] **P3 — O(n) storage writes.** `appendBlueprint` reads + rewrites the entire
  JSON file on every save. → Left as-is by design (blueprint counts are small and
  writes are infrequent); redundant re-save of *cached* puzzles was removed so
  replays no longer grow the file. Switching to append-only NDJSON is a future option.
- [x] **P4 — Whole-screen `setState` every second** from the game timer. → Scope the
  clock to a small widget.

## 3. Dead code & lints (target: 0 analyze issues)

- [x] **L1 — Unused methods/classes:** `_buildSingleRegion`, `_attemptDeadlockRecovery`,
  `_clearRegions`, `_getAdjacentUnassignedCells`, `_fillRegion`, `_fillJigsawGrid`,
  `BoundaryCell`, `SudokuGame.fromExisting`. → Remove.
- [x] **L2 — Unused locals** `paint`/`thickPaint` in `SudokuGridPainter.paint`.
- [x] **L3 — ~25 `withOpacity` deprecations** → `.withValues(alpha:)`.
- [x] **L4 — `onAccept`/`onWillAccept`** deprecated → `onAcceptWithDetails`/
  `onWillAcceptWithDetails`.
- [x] **L5 — `print` in production** → `debugPrint`, guarded by `kDebugMode`.
- [x] **L6 — Misc style:** `use_key_in_widget_constructors`,
  `library_private_types_in_public_api`, `sized_box_for_whitespace`,
  `avoid_unnecessary_containers`, `prefer_const_constructors_in_immutables`,
  `unnecessary_brace_in_string_interps`.

## 4. Architecture / testability

- [x] **A1 — Split the monolith.** Extract enums, `PuzzleBlueprint`, `SmartHint`, and
  the `SudokuGame` engine into `lib/sudoku_game.dart` (pure Dart, no `material`
  imports) so the engine is unit-testable in isolation. Regenerate the
  `json_serializable` part file. UI stays in `main.dart` and imports the engine.
- [x] **A2 — Add a synchronous `SudokuGame.generate()`** factory for deterministic
  tests (seeded RNG), keeping the async `create()` (isolate) for the UI.

## 5. Testing

- [x] **T1 — Unit tests** (`test/sudoku_game_test.dart`): grid dimensions per size;
  generated solution is a valid full Sudoku (rows/cols/regions); jigsaw regions are
  the right count/size and connected; puzzle is uniquely solvable; `isValidMove`
  row/col/region rules; `setCell`/`clearCell` respect originals; `isSolved`;
  hint correctness (naked single, hidden single, give-answer matches solution);
  blueprint round-trips through JSON.
- [x] **T2 — Widget/"live" tests** (`test/widget_test.dart`): app boots to Home;
  navigation into Classic shows size + difficulty selection; the Themes sheet opens;
  and a live 4×4 game (seeded via the cache so it builds without an isolate) renders
  the board and number pad, real-taps a cell to select it, then real-taps the
  number pad to place the solution value. (Win-state assertion via the engine API is
  covered by T1's "filling with the solution wins" test.)

## 6. Docs

- [x] **D1 — Replace the placeholder README** with real run/test/build instructions
  and a feature overview.

---

## Execution order

1. PLAN.md (this file).
2. A1/A2 — extract engine, regenerate `.g.dart`, confirm app still builds.
3. C2/C3/C4/C6 + L1/L2 — correctness fixes inside the now-isolated engine.
4. C5 + P1/P2/P4 + L3/L4/L5/L6 — UI fixes & cleanup in `main.dart`.
5. T1/T2 — tests.
6. C7 — persistence (stretch).
7. D1 + final `flutter analyze` (0 issues) and `flutter test` (green).

---

## Results (initial audit)

- `flutter analyze` → **0 issues** (was 41).
- `flutter test` → **green** (was 0 — the suite didn't compile).
- `flutter build web` → **succeeds**.
- A latent UI bug surfaced and fixed while testing: the difficulty bottom sheet was
  not `isScrollControlled` and overflowed on short screens.
- The engine now retries jigsaw region generation internally, so a single
  `generate()` call reliably produces solvable 9×9/10×10 jigsaw boards (previously
  this only worked because the UI retried via fresh isolates).
- C7 (persisting stats across launches) implemented and tested.
- Deployed to Vercel (static prebuilt `build/web`); see `deploy.sh`.

---

## Post-audit enhancements

Follow-up work after the initial audit shipped and deployed.

- [x] **E1 — Cross-platform persistence.** Replaced file/`path_provider` storage
  (unsupported on web — stats + cache silently no-opped there) with
  `shared_preferences` for both the puzzle cache and player stats. Caps cached
  blueprints at 25 per size/shape key, which bounds the stored payload and
  **supersedes P3** (the O(n) full-file-rewrite concern).
- [x] **E2 — True isolate cancellation (completes C6).** Replaced `compute()` with
  a dedicated `Isolate` that is killed on timeout/error, so generation can neither
  freeze the UI nor leak a runaway isolate.
- [x] **E3 — Gameplay depth.** Pencil-mark **notes**, **undo** (value + notes),
  free placement of conflicting numbers with live red highlighting (`hasConflict`),
  and a completion **dialog** (Next Puzzle / Main Menu) replacing the blind 3 s
  auto-advance + floating score.
- [x] **E4 — CI.** `.github/workflows/ci.yml` runs format-check + `flutter analyze`
  + `flutter test` on push to `main` and PRs. First run: green.
- [x] **E5 — `--wasm` deploy option.** `deploy.sh --wasm` builds with WebAssembly
  and emits the COOP/COEP headers skwasm needs.
- [x] **E6 — Pruned dead dependencies.** Removed `path_provider` (unused after E1)
  and `audioplayers` (sound was never wired up).

### Results (post-audit)

- `flutter analyze` → **0 issues**; `dart format` → clean (CI-enforced).
- `flutter test` → **40 passing** (engine, persistence, isolate, notes/undo/
  conflict, and widget/live tests).
- Live at https://sudoku-lac-five.vercel.app

## Known limitations / not planned

- Streak never resets (the game auto-advances; there is no "lose" path).
- Notes-mode toggle and the completion dialog are covered at the engine level and
  via the live undo test, but not asserted individually in widget tests.
- `--wasm` is validated and available but the live deploy uses the JS/canvaskit
  build for broadest compatibility.
