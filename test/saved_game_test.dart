import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/saved_game.dart';
import 'package:sudoku/saved_game_service.dart';
import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/variant_engine.dart';

SudokuGame sampleGame() => SudokuGame.fromState(
  givens: [
    [1, 0, 0, 4],
    [0, 4, 1, 0],
    [2, 0, 4, 0],
    [0, 3, 0, 1],
  ],
  solution: [
    [1, 2, 3, 4],
    [3, 4, 1, 2],
    [2, 1, 4, 3],
    [4, 3, 2, 1],
  ],
  regions: [
    [0, 0, 1, 1],
    [0, 0, 1, 1],
    [2, 2, 3, 3],
    [2, 2, 3, 3],
  ],
  difficulty: SudokuDifficulty.medium,
);

SavedGame snapshot(SudokuGame game) => SavedGame.capture(
  game: game,
  size: GridSize.small,
  shape: GridShape.classic,
  gameMode: GameMode.classic,
  elapsed: const Duration(seconds: 123),
  score: 777,
  mistakes: 2,
  hintsUsed: 1,
  dailySeed: 20260917,
  dailyKey: '2026-09-17',
  rating: SudokuDifficulty.hard,
);

/// A 4x4 KenKen: a Latin square with no boxes, split into eight domino cages.
/// The regions are the row indices, which is how a boxless variant travels
/// through a schema that insists on a region map.
SudokuGame sampleKenKenGame() => SudokuGame.fromState(
  givens: [
    [1, 0, 0, 4],
    [0, 4, 1, 0],
    [2, 0, 4, 0],
    [0, 3, 0, 1],
  ],
  solution: [
    [1, 2, 3, 4],
    [3, 4, 1, 2],
    [2, 1, 4, 3],
    [4, 3, 2, 1],
  ],
  regions: KenKenPuzzle.latinRegions(4),
  difficulty: SudokuDifficulty.medium,
  // The variant travels on the game, not on `capture` — it is what gets
  // written as the snapshot's `variant` field.
  variant: SudokuVariant.kenken,
);

List<KenKenCage> sampleKenKenCages() => [
  for (final row in [0, 1, 2, 3])
    for (final half in [0, 2])
      KenKenCage(
        cells: [
          [row, half],
          [row, half + 1],
        ],
        op: KenKenOp.add,
        // Each domino covers {1,2} or {3,4} in this solution.
        target: (half == 0) == (row == 0 || row == 2) ? 3 : 7,
      ),
];

void main() {
  test('a KenKen snapshot survives a save and resume', () {
    final saved = SavedGame.capture(
      game: sampleKenKenGame(),
      size: GridSize.small,
      shape: GridShape.classic,
      gameMode: GameMode.classic,
      kenKenCages: sampleKenKenCages(),
      elapsed: const Duration(seconds: 12),
      score: 10,
      mistakes: 0,
      hintsUsed: 0,
    );
    final back = SavedGame.fromJson(
      jsonDecode(jsonEncode(saved.toJson())) as Map<String, dynamic>,
    );
    expect(back.variant, SudokuVariant.kenken);
    expect(back.kenKenCages.length, 8);
    expect(back.kenKenCages.first.op, KenKenOp.add);
    expect(
      kenKenCagesSatisfied(back.kenKenCages, sampleKenKenGame().solution),
      isTrue,
    );
  });

  test('a KenKen snapshot with no cages is rejected', () {
    // Resuming this would hand the player an empty Latin-square grid with no
    // clue of any kind — the no-silent-fallback rule, applied to the save slot
    // rather than to generation.
    final valid = SavedGame.capture(
      game: sampleKenKenGame(),
      size: GridSize.small,
      shape: GridShape.classic,
      gameMode: GameMode.classic,
      kenKenCages: sampleKenKenCages(),
      elapsed: const Duration(seconds: 12),
      score: 10,
      mistakes: 0,
      hintsUsed: 0,
    ).toJson();

    for (final mutate in <void Function(Map<String, dynamic>)>[
      (j) => j['kenKenCages'] = [],
      (j) => j.remove('kenKenCages'),
      // One cage dropped: the cages no longer cover the grid.
      (j) => (j['kenKenCages'] as List).removeLast(),
      // A clue its own solution does not satisfy.
      (j) => (j['kenKenCages'] as List)[0]['target'] = 99,
    ]) {
      final json = jsonDecode(jsonEncode(valid)) as Map<String, dynamic>;
      mutate(json);
      expect(
        () => SavedGame.fromJson(json),
        throwsA(anything),
        reason: '$json',
      );
    }
  });

  test('rejects old, corrupt, inconsistent and finished snapshots', () {
    final valid = snapshot(sampleGame()).toJson();
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (j) => j['version'] = 0,
      (j) => j['grid'] = [
        [1],
      ],
      (j) => j['notes'] = [],
      (j) => (j['grid'] as List)[0][0] = 2,
      (j) => (j['grid'] as List)[0][1] = 99,
      (j) => (j['notes'] as List)[0][1] = [0],
      (j) => j['size'] = 'unknown',
      (j) => j['elapsedUs'] = -1,
      (j) => j['score'] = -1,
      (j) => j['hintsUsed'] = -1,
      (j) => j['dailyKey'] = 'not-a-date',
      (j) => j['grid'] = j['solution'],
      (j) => (j['solution'] as List)[0][1] = 1,
      (j) => j['variant'] = 'killer',
    ]) {
      final json = jsonDecode(jsonEncode(valid)) as Map<String, dynamic>;
      mutate(json);
      expect(
        () => SavedGame.fromJson(json),
        throwsA(anything),
        reason: '$json',
      );
    }
  });

  test('queued save save clear cannot resurrect a completed game', () async {
    SharedPreferences.setMockInitialValues({});
    final service = SavedGameService.isolated();
    final first = service.save(snapshot(sampleGame()));
    final second = service.save(snapshot(sampleGame()));
    final clear = service.clear();
    await Future.wait([first, second, clear]);
    expect(await SavedGameService.isolated().load(), isNull);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SavedGameService.storageKey, '{broken');
    expect(await service.load(), isNull);
    await prefs.setString(SavedGameService.storageKey, '{"version":0}');
    expect(await service.load(), isNull);
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'disk round trip keeps player entries editable and original clues intact',
    () async {
      final game = sampleGame();
      game.setCell(0, 1, 2);
      game.toggleNote(0, 2, 3);
      final saved = snapshot(game);
      game.clearCell(0, 1); // captured state cannot alias the live game
      await SavedGameService.isolated().save(saved);
      final loaded = (await SavedGameService.isolated().load())!;
      final restored = loaded.createGame();
      expect(restored.grid[0], [1, 2, 0, 4]);
      expect(restored.isOriginal[0], [true, false, false, true]);
      expect(restored.notes[0][2], {3});
      expect(loaded.elapsed, const Duration(seconds: 123));
      expect(loaded.score, 777);
      expect(loaded.mistakes, 2);
      expect(loaded.hintsUsed, 1);
      expect(loaded.dailySeed, 20260917);
      expect(loaded.dailyKey, '2026-09-17');
      expect(loaded.rating, SudokuDifficulty.hard);
      restored.reset();
      expect(restored.grid, sampleGame().grid);
      expect(jsonDecode(jsonEncode(loaded.toJson())), saved.toJson());
    },
  );
}
