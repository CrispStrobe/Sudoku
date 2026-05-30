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

### "Generation takes forever on web" — root-caused and fixed

Two distinct problems behind the report:

- [x] **E7 — Web generation hung.** E2's `Isolate.spawn` does not exist on Flutter
  web, so `create()` never returned and the loading spinner stuck forever.
  → On web, generate inline on the main thread (`kIsWeb` branch in `main.dart`);
  the killable isolate is kept for native platforms.
- [x] **E8 — O(n⁵) solver (the real culprit).** The safety check rescanned the whole
  grid for every candidate at every backtracking step, so an irregular jigsaw layout
  that needed deep backtracking ground for minutes. Measured **10×10 jigsaw:
  166,567 ms**. → Rewrote the solver and uniqueness counter to use incremental
  row/column/region **bitmasks** (O(1) safety). Now **10×10 jigsaw: ~430 ms** (~380×),
  and 12×12 completes in a few seconds instead of effectively never. Generation
  timeout widened so 12×12 fits on native.
- [x] **E9 — Bundled puzzle database.** `assets/puzzles.json` ships pre-solved
  blueprints (generated offline by `tool/generate_puzzles.dart`), loaded at startup
  so the first play and the web build are instant — no on-device solving required.
  Bundled puzzles are read-only; player-generated ones still persist via E1.

### Streak / lose path

- [x] **E10 — Mistake limit (lose path) + streak reset.** Previously the game had
  no failure condition, so `currentStreak` only ever grew. Added a per-difficulty
  mistake budget (`maxMistakesFor`: easy 5, medium 4, hard 3, expert 2). A
  "mistake" is a placement that conflicts with a visible peer (the same event that
  already shook the board and docked score, so free placement of *non-conflicting*
  guesses is unchanged). Reaching the budget triggers a **Game Over** dialog,
  resets `GameStats.currentStreak` to 0, and persists it. The dialog offers **Try
  Again** — which replays the *same* board via a new pure `SudokuGame.reset()`
  (clears non-given cells, notes, and undo history) — or **Main Menu**. A slim
  pip strip above the grid shows remaining lives (`n/max`), reddening on the last
  life. Covered by engine tests (`maxMistakesFor` ramp, `reset` semantics) and a
  widget test that drives a full loss + retry through the UI.

- [x] **E11 — Widget-test hardening + streak-achievement follow-through.** Added
  widget tests for the two UI paths previously only covered at the engine level:
  **notes mode** (a number tap pencils a candidate instead of placing a value)
  and the **completion dialog** (filling the final cell via the number pad raises
  the win dialog). The cached-4×4 boot boilerplate the live/lose tests duplicated
  is now a shared `_bootCachedGame` helper. Also locked in the achievement
  behaviour now that streaks can reset: `streak_master` unlocks at streak ≥ 5
  (granting the Ice theme) and **stays earned after a loss zeroes the streak**
  (achievements are one-time unlocks, never revoked) —
  `test/game_stats_test.dart`.

- [x] **E12 — Best-streak & games-lost stats.** Completes the streak/lose-path
  arc with the metrics the lose path makes meaningful. Added persisted
  `GameStats.longestStreak` (bumped on every win, never reset by a loss) and
  `gamesLost` (bumped on game over). `applyJson` enforces
  `longestStreak >= currentStreak` even for saves predating the field. The home
  screen now shows `Solved | Streak | Best`, plus a `Losses` line once any game
  has been lost. A new reward-free **Marathon** achievement (🏅, longest streak
  ≥ 10) gives the best-streak stat a goal. Covered in `game_stats_test.dart`
  (round-trip, invariant, marathon-from-longest) and asserted in the completion
  and lose widget tests (solved/longest increment on win, games-lost on loss).

- [x] **E13 — Per-difficulty hint budget.** Hints already cost score; now they
  are also a finite resource, capped by `maxHintsFor` (easy 10, medium 6, hard 3,
  expert 1 — always ≥ 1). Only penalty-bearing hints count; the free "cell
  occupied" / "conflict" diagnostics do not. The Hint button shows the remaining
  count (`Hint (n)`) and, when the budget is spent, switches to a disabled
  `No Hints`; trying to hint with none left snackbars instead. The budget resets
  per puzzle (new puzzle and "Try Again"). Covered by an engine ramp test and a
  widget test that drives one real hint on an expert board (budget 1) and asserts
  the button disables.

- [x] **E14 — Daily challenge.** A once-a-day puzzle that is identical for every
  player: a fixed 9×9 classic medium board seeded deterministically from the
  calendar date (`dailySeed`/`dailyDateKey`, pure + tested). Generated cache-free
  and isolate-free so it reproduces exactly (9×9 digging is well under the time
  budget, so it never truncates non-deterministically). The home screen gets a
  Daily Challenge button that flips to a green "Completed ✓" once the day's board
  is solved; `GameStats` persists `lastDailyDate` + `dailyCompletedCount`. The
  daily completion dialog drops "Next Puzzle" (one board per day) and "Try Again"
  replays the same deterministic board. Covered by engine tests (seed/key,
  same-seed reproducibility), stats round-trip/`isDailyDoneOn`, and a widget test
  that taps the home button and asserts a deterministic daily game mounts.

- [x] **E15 — Narrow-phone home layout fix.** The home screen was only ever
  rendered in tests on the default wide 800×600 surface, hiding two `RenderFlex`
  overflows at a 360px portrait width: the Jigsaw button's icon+label `Row`
  (pre-existing) and `_buildModeButton`'s `Column` (long labels, surfaced by the
  Daily button's subtitle). Both now wrap their content in `FittedBox(scaleDown)`
  (the mode button also stretches its column) so labels shrink to one line
  instead of overflowing. Guarded by a new widget test that renders Home at
  360×800; the daily-launch test also runs at phone size now (full home→9×9 flow
  is overflow-free).

- [x] **E16 — Statistics screen.** A home "Stats" quick button opens a sheet
  (mirroring Themes/Achievements) summarising the now-meaningful metrics: puzzles
  solved, **win rate** (solved / (solved + lost)), current and longest streak,
  games lost, best time, daily puzzles done, hints used, and achievements
  unlocked / total. Best time shows "—" until a record exists; win rate "—" until
  a game finishes. A top-level `formatClock` is now shared by the in-game timer
  and this screen (`_formatDuration` delegates to it). Covered by a widget test
  that seeds stats and asserts the computed win rate.

- [x] **E17 — Dependency audit.** Brought every direct and dev dependency to its
  latest resolvable version. `flutter pub upgrade` bumped 27 packages within the
  existing constraints (cupertino_icons 1.0.9, json_annotation 4.12.0,
  build_runner 2.15.0, json_serializable 6.14.0, + transitive patches), then two
  constraint edits: `json_annotation` `^4.9.0` → `^4.12.0` (matches what
  json_serializable 6.14 emits, clearing a build_runner warning) and
  `flutter_lints` `^5.0.0` → `^6.0.0`. The lint bump added `unnecessary_underscores`,
  fixed by collapsing a `(_, __)` callback to `(_, _)`. Regenerated `.g.dart`
  (byte-identical), `flutter analyze` clean, 60 tests green, web build succeeds.
  The remaining "outdated" packages are all transitive and pinned by the Flutter
  SDK (analyzer, meta, vector_math, material_color_utilities, …) — not bumpable
  without a Flutter SDK upgrade, which is out of scope.

- [x] **E18 — Drag feedback off-cursor.** When dragging a number from the pad to
  the grid, the floating miniature tile lagged off to one side of the
  finger/cursor even though the target cell highlighted correctly. Cause: the
  `Draggable` used the default `childDragAnchorStrategy`, which offsets the
  feedback by the grab point within the *number-pad cell* — and that cell is sized
  independently of (and usually larger than) the fixed-size feedback, so the
  offset pushed the tile off-cursor. Fixed with a `dragAnchorStrategy` that anchors
  the feedback's centre on the pointer, so the tile tracks the finger and sits over
  the highlighted cell. Added a drag-to-place widget test (the drop path had only
  tap coverage before).

- [x] **E19 — Human-technique solver + three features built on it.** Added a
  pure-Dart logical solver (`lib/technique_solver.dart`) that applies human
  techniques easiest-first — naked/hidden singles, locked candidates
  (pointing/claiming), naked/hidden pairs, naked triples, X-wing — over
  rows/columns/`regions`, so it covers classic and jigsaw at any size. It returns
  ordered, human-readable steps, the hardest technique needed, and a difficulty
  rating. Three UI features consume it:
  - **Logic difficulty rating** — each board is rated by the hardest technique it
    requires (distinct from the hole-count generation difficulty); shown as a 🧠
    pill above the grid and in the completion dialog.
  - **"Next logical step" hint** — the Smart Hints dialog leads with a board-wide
    deduction that explains the next move in plain language and (for placements)
    applies it for a score cost. Hint dialog is now scrollable.
  - **Explain-the-solve walkthrough** (`ExplainScreen`) — scrub/auto-play through
    the full logical solve, each frame highlighting the cell + naming the
    technique with its explanation.
  Inspired by the `dart_csp` CSP library and `CrispCalc`'s Sudoku module. 10
  engine tests + widget tests for the pill, next-step and explain flows.

- [x] **E20 — Sudoku-X variant (diagonals).** Added the X rule variant — the two
  main diagonals must each hold 1..dim — implemented in our own bitmask engine
  (no new dependency; generation stays sub-second and web-safe). Threaded diagonal
  masks through the fill solver and the uniqueness counter, and diagonal checks
  through `isValidMove`/`hasConflict`/`isSolved`, all gated on the variant so
  classic/jigsaw are byte-for-byte unchanged. The technique solver gained a
  `diagonal` flag (diagonals as extra units) so the logic rating, next-step hint
  and explain mode stay correct on X boards. UI: a "⊗ Sudoku-X" toggle in the
  difficulty sheet, a faint diagonal tint on the board and in the explain grid,
  and X boards bypass the (classic-only) cache to always generate fresh. Killer
  cages (which need `dart_csp`'s sum arithmetic) remain the next variant. Engine
  tests verify X-unique generation + diagonal conflicts; solver tests verify X
  solving; a widget test covers the toggle.

- [x] **E21 — Killer variant (summed cages).** Added Killer Sudoku, the one
  variant that genuinely needs arithmetic constraints. Pulled in the pure-Dart
  `dart_csp` solver (pinned, dart2js-safe — verified it compiles to JS and the web
  build succeeds with it imported) and a self-contained `lib/variant_engine.dart`:
  `KillerCage`/`KillerPuzzle`, cage validation, and solve/uniqueness/generate.
  Generation reuses our bitmask engine for the base solution + box regions and only
  uses dart_csp for the cage-sum uniqueness check, so a 9×9 Killer generates in
  **~100ms** (not the ~30–60s a pure-CSP fill costs). A generic
  `SudokuGame.fromState` factory makes the generated board playable, reusing all
  existing gameplay (notes/undo/mistakes/win). UI: a Classic/Sudoku-X/Killer chip
  selector in the difficulty sheet (Killer offered for sizes ≤ 9×9), a
  `KillerCagePainter` overlay (dashed cage borders + sum labels), cage-aware
  conflict highlighting / mistake counting / win condition, and the logic-based
  features (rating, hint, explain) disabled for Killer since the technique solver
  doesn't model cages. 10 engine tests + a board-generation widget test + the
  variant-selector test.
- [x] **E22 — Release readiness (branding, About, licensing).** Productionised
  for an app-store release as **CrispSudoku** (app title, MaterialApp title, home
  header, Android label, iOS `CFBundleDisplayName`/`CFBundleName`, web manifest +
  page title, and pubspec description all updated). Added an in-app **About**
  screen (`lib/about_screen.dart`, matching the sibling CrispCalc / CrisperWeaver
  pattern — version via `package_info_plus`, contact via `url_launcher`, and
  Flutter's `showLicensePage`), reached from a Home footer link. Licensed under
  **AGPL-3.0** (full `LICENSE`) with a `NOTICE` documenting the
  sole-copyright-holder **App Store / Play additional permission** (so the binary,
  including future IAP, ships under store terms while the source stays AGPL) and
  preserving `dart_csp`'s MIT attribution. Covered by an About-screen widget test
  (sections + license page) and a Home About-link test.

### Results (post-audit)

- `flutter analyze` → **0 issues**; `dart format` → clean (CI-enforced).
- `flutter test` → **92 passing** (engine, persistence + bundled-DB, isolate,
  notes/undo/conflict, mistake-limit/reset, hint-budget, daily-puzzle determinism,
  streak/longest/lost stats + achievements, and widget/live tests incl. notes-mode,
  completion-dialog, hint-exhaustion, daily-launch, stats-sheet and
  narrow-phone-home coverage).
- Generation: all sizes sub-second except 12×12 (a few seconds); first play served
  instantly from the bundled DB.
- Live at https://sudoku-lac-five.vercel.app

## Known limitations / not planned

- "Try Again" replays the same givens but the elapsed clock and score restart from
  scratch (no partial-credit for a near-finish); this is intentional.
- 12×12 generation is a few seconds; the bundled DB hides this on first play, and a
  fresh dig still runs (≤2.5 s) when a cached solution is reused.
- `--wasm` is validated and available but the live deploy uses the JS/canvaskit
  build for broadest compatibility.
