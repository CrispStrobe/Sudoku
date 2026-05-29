# Sudoku Master Pro

A Flutter Sudoku game with classic and **jigsaw** (irregular-region) variants across
six grid sizes (4×4, 6×6, 8×8, 9×9, 10×10, 12×12), four difficulties, smart hints,
themes, achievements, and a celebratory particle layer.

## Architecture

- **`lib/sudoku_game.dart`** — the pure-Dart engine (no Flutter widget deps):
  enums, `PuzzleBlueprint`, `SmartHint`, and the `SudokuGame` class (generation,
  uniqueness-preserving hole digging, validation, hints). Fully unit-testable.
- **`lib/main.dart`** — the UI: screens, theming, particle overlay, the puzzle
  cache, on-disk storage of solved blueprints, and persisted player stats
  (`stats.json`: solved count, streak, best time, achievements, unlocked themes).
- **`lib/sudoku_game.g.dart`** — generated `json_serializable` code for
  `PuzzleBlueprint`. Regenerate with build_runner (below).

### How generation works

A complete grid is solved with MRV backtracking, then cells are removed one at a
time — each removal is kept **only if the puzzle still has exactly one solution**
(bounded by a time budget so large boards never hang). Solved blueprints are cached
to disk so subsequent plays of the same size/shape start instantly; each play digs
a fresh set of holes from the cached solution.

## Running

```bash
flutter pub get
flutter run                # pick a device, or:
flutter run -d chrome      # web
```

The **Admin** panel (debug builds only) pre-generates puzzles into the on-disk cache.

## Testing

```bash
flutter test               # unit + widget tests
flutter analyze            # static analysis (expected: no issues)
```

- `test/sudoku_game_test.dart` — engine unit tests: valid solutions, region
  shape/connectivity, **unique-solution guarantee** (verified by an independent
  solver), move validation, win conditions, hints, and blueprint JSON round-trips.
- `test/widget_test.dart` — widget/integration tests: home navigation, difficulty
  selection, and a live play-through that places a number on a cached 4×4 board.

## Regenerating serialization code

```bash
dart run build_runner build --delete-conflicting-outputs
```
</content>
