import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/main.dart';
import 'package:sudoku/sudoku_game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  PuzzleBlueprint makeBlueprint(int seed) {
    final game = SudokuGame.generate(
        SudokuDifficulty.easy, GridSize.small, GridShape.classic,
        seed: seed);
    return PuzzleBlueprint(
      solutionGrid: game.solution,
      regions: game.regions,
      gridSize: GridSize.small,
      gridShape: GridShape.classic,
    );
  }

  test('StorageService round-trips blueprints through SharedPreferences', () async {
    final storage = StorageService();
    expect(await storage.loadBlueprints(), isEmpty);

    final bp = makeBlueprint(1);
    await storage.saveBlueprints([bp]);

    final loaded = await storage.loadBlueprints();
    expect(loaded, hasLength(1));
    expect(loaded.first.solutionGrid, bp.solutionGrid);
    expect(loaded.first.gridSize, GridSize.small);
    expect(loaded.first.gridShape, GridShape.classic);
  });

  test('StatsService round-trips stats through SharedPreferences', () async {
    final stats = StatsService();
    expect(await stats.load(), isNull);

    await stats.save({'totalPuzzlesSolved': 9, 'currentStreak': 3});
    final loaded = await stats.load();
    expect(loaded, isNotNull);
    expect(loaded!['totalPuzzlesSolved'], 9);
    expect(loaded['currentStreak'], 3);
  });

  test('PuzzleCache caps stored blueprints per key', () async {
    final cache = PuzzleCache();
    for (var i = 0; i < 30; i++) {
      await cache.set(makeBlueprint(i));
    }
    // Whatever this singleton accumulated, persistence must be capped at 25.
    final persisted = (await StorageService().loadBlueprints())
        .where((b) =>
            b.gridSize == GridSize.small && b.gridShape == GridShape.classic)
        .toList();
    expect(persisted.length, lessThanOrEqualTo(25));
    expect(persisted.length, 25, reason: '30 inserts should saturate the cap');
    // And the cache still returns a usable blueprint.
    expect(cache.getRandom(GridSize.small, GridShape.classic), isNotNull);
  });
}
