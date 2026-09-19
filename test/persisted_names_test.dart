import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/sudoku_game.dart';

/// Enum names that leave the process.
///
/// `SudokuVariant`, `GridSize`, `GridShape` and `SudokuDifficulty` are written
/// to disk by `.name` — into the resume slot (`saved_game.dart`) and into the
/// per-variant / per-size achievement counters in `stats.json` — and read back
/// with `values.byName`. A rename is therefore a data migration, not a
/// refactor: it invalidates every player's saved game and silently resets their
/// achievement progress, with no compile error and no test failure anywhere
/// else in this suite.
///
/// `SudokuVariant.x` is the standing temptation: the Dart-side accessors are
/// already called `diagonal`/`isDiagonal`, so "tidying" the enum to match looks
/// free. It is not.
///
/// Adding a value is fine and does not touch these lists. If you genuinely need
/// to rename one, write the migration first, then update the list here.
void main() {
  void expectNames(String label, List<String> actual, List<String> expected) {
    expect(
      actual,
      containsAll(expected),
      reason:
          '$label lost or renamed a persisted name. Saved games and stats.json '
          'store these verbatim — a rename needs a migration in '
          'saved_game.dart and game_stats.dart, not just a new spelling.',
    );
  }

  test('SudokuVariant names are stable', () {
    expectNames(
      'SudokuVariant',
      SudokuVariant.values.map((v) => v.name).toList(),
      ['classic', 'x', 'killer', 'thermo'],
    );
  });

  test('GridSize names are stable', () {
    expectNames('GridSize', GridSize.values.map((v) => v.name).toList(), [
      'small',
      'medium',
      'large',
      'standard',
      'big',
      'mega',
    ]);
  });

  test('GridShape names are stable', () {
    expectNames('GridShape', GridShape.values.map((v) => v.name).toList(), [
      'classic',
      'jigsaw',
    ]);
  });

  test('SudokuDifficulty names are stable', () {
    expectNames(
      'SudokuDifficulty',
      SudokuDifficulty.values.map((v) => v.name).toList(),
      ['easy', 'medium', 'hard', 'expert'],
    );
  });
}
