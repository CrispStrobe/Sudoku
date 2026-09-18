import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/variant_engine.dart';

void main() {
  test(
    'default expert generation continues until uniqueness is proven',
    () async {
      final puzzle = await VariantEngine.generateKiller(
        gridSize: GridSize.standard,
        difficulty: SudokuDifficulty.expert,
        seed: 4,
      );
      expect(
        await VariantEngine.killerHasUniqueSolution(
          gridDim: puzzle.gridDim,
          regions: puzzle.regions,
          cages: puzzle.cages,
          givens: puzzle.givens,
        ),
        isTrue,
      );
      expect(
        puzzle.givens.expand((row) => row).where((v) => v != 0).length,
        greaterThan(30),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
  test('invalid generation limits are rejected', () async {
    for (final limits in [(0, 30), (1, -1)]) {
      await expectLater(
        VariantEngine.generateKiller(
          gridSize: GridSize.small,
          difficulty: SudokuDifficulty.expert,
          seed: 42,
          maxPartitionAttempts: limits.$1,
          maxGivens: limits.$2,
        ),
        throwsArgumentError,
      );
    }
  });

  test('an exhausted reveal cap never returns an ambiguous puzzle', () async {
    // One actual random partition, no mocked solver. The zero-reveal budget
    // makes the existing unchecked return reproducible on a tiny grid.
    await expectLater(
      VariantEngine.generateKiller(
        gridSize: GridSize.small,
        difficulty: SudokuDifficulty.expert,
        seed: 42,
        maxPartitionAttempts: 1,
        maxGivens: 0,
      ),
      throwsStateError,
    );
  });
}
