import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/saved_game.dart';
import 'package:sudoku/saved_game_service.dart';
import 'package:sudoku/sudoku_game.dart';

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

void main() {
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
