import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/ready_puzzle.dart';
import 'package:sudoku/sudoku_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ready puzzle round-trips givens and rating without re-solving', () {
    final game = SudokuGame.generate(
      SudokuDifficulty.medium,
      GridSize.small,
      GridShape.classic,
      seed: 7,
    );
    final ready = ReadyPuzzle.fromGame(
      game,
      GridSize.small,
      GridShape.classic,
      rating: SudokuDifficulty.medium,
    );
    final restored = ReadyPuzzle.fromJson(ready.toJson());

    // The playable board is identical and replays are independent.
    final first = restored.createGame();
    expect(first.grid, game.grid);
    expect(first.solution, game.solution);
    expect(first.isOriginal, game.isOriginal);
    expect(restored.rating, SudokuDifficulty.medium);
    first.grid[0][0] = 0;
    expect(restored.createGame().grid, game.grid);
  });

  test('ready puzzle rejects malformed JSON', () {
    final ready = ReadyPuzzle.fromGame(
      SudokuGame.generate(
        SudokuDifficulty.easy,
        GridSize.small,
        GridShape.classic,
        seed: 3,
      ),
      GridSize.small,
      GridShape.classic,
    );
    final json = ready.toJson();

    // Ragged rows must fail fast instead of surfacing later during play.
    expect(
      () => ReadyPuzzle.fromJson({
        ...json,
        'givens': [
          [1],
        ],
      }),
      throwsFormatException,
    );
    // A given that disagrees with the solution must fail fast too.
    final badGivens = [
      for (final row in json['givens'] as List)
        (row as List).cast<int>().toList(),
    ];
    badGivens[0][0] = badGivens[0][0] == 1 ? 2 : 1;
    expect(
      () => ReadyPuzzle.fromJson({...json, 'givens': badGivens}),
      throwsFormatException,
    );
  });

  test(
    'cache stores per difficulty, persists, and reloads idempotently',
    () async {
      SharedPreferences.setMockInitialValues({});
      final game = SudokuGame.generate(
        SudokuDifficulty.medium,
        GridSize.small,
        GridShape.classic,
        seed: 9,
      );
      await ReadyPuzzleCache().add(
        ReadyPuzzle.fromGame(game, GridSize.small, GridShape.classic),
      );

      final reloaded = ReadyPuzzleCache.isolated();
      await reloaded.initialize(loadBundle: false);
      await reloaded.initialize(loadBundle: false); // idempotent
      expect(
        reloaded.get(GridSize.small, GridShape.classic, SudokuDifficulty.easy),
        isNull,
      ); // keyed by the generation difficulty, not the rating
      expect(
        reloaded
            .get(GridSize.small, GridShape.classic, SudokuDifficulty.medium)!
            .createGame()
            .grid,
        game.grid,
      );
    },
  );
}
