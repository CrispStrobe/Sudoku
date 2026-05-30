import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/variant_engine.dart';

/// Assert structural invariants of a generated [KillerPuzzle]:
/// - cages partition every cell exactly once,
/// - each cage sum equals the solution sum over its cells,
/// - no cage repeats a solution-digit.
void _checkPuzzleInvariants(KillerPuzzle puzzle) {
  final dim = puzzle.gridDim;
  final coverage = List.generate(dim, (_) => List<int>.filled(dim, 0));

  for (final cage in puzzle.cages) {
    var sum = 0;
    final digits = <int>{};
    for (final cell in cage.cells) {
      final r = cell[0];
      final c = cell[1];
      coverage[r][c]++;
      final d = puzzle.solution[r][c];
      sum += d;
      expect(
        digits.add(d),
        isTrue,
        reason: 'Cage repeated solution-digit $d at [$r,$c]',
      );
    }
    expect(cage.sum, sum, reason: 'Cage sum mismatch for $cage.cells');
  }

  // Every cell covered exactly once.
  for (var r = 0; r < dim; r++) {
    for (var c = 0; c < dim; c++) {
      expect(
        coverage[r][c],
        1,
        reason: 'Cell [$r,$c] covered ${coverage[r][c]} times (expected 1)',
      );
    }
  }

  // Givens, where present, must match the solution.
  for (var r = 0; r < dim; r++) {
    for (var c = 0; c < dim; c++) {
      final g = puzzle.givens[r][c];
      if (g != 0) expect(g, puzzle.solution[r][c]);
    }
  }
}

Future<void> _assertUnique(KillerPuzzle puzzle) async {
  final unique = await VariantEngine.killerHasUniqueSolution(
    gridDim: puzzle.gridDim,
    regions: puzzle.regions,
    cages: puzzle.cages,
    givens: puzzle.givens,
  );
  expect(unique, isTrue, reason: 'Generated puzzle must be uniquely solvable');
}

void main() {
  group('Killer 4x4 (GridSize.small)', () {
    for (final seed in [1, 7, 42]) {
      test('generateKiller is valid & unique (seed=$seed)', () async {
        final puzzle = await VariantEngine.generateKiller(
          gridSize: GridSize.small,
          difficulty: SudokuDifficulty.easy,
          seed: seed,
        );
        expect(puzzle.gridDim, 4);
        _checkPuzzleInvariants(puzzle);
        await _assertUnique(puzzle);
      });
    }

    test('solveKiller returns the puzzle solution', () async {
      final puzzle = await VariantEngine.generateKiller(
        gridSize: GridSize.small,
        difficulty: SudokuDifficulty.easy,
        seed: 3,
      );
      final solved = await VariantEngine.solveKiller(
        gridDim: puzzle.gridDim,
        regions: puzzle.regions,
        cages: puzzle.cages,
        givens: puzzle.givens,
      );
      expect(solved, isNotNull);
      expect(solved, puzzle.solution);
    });

    test('same seed reproduces an identical puzzle', () async {
      final a = await VariantEngine.generateKiller(
        gridSize: GridSize.small,
        difficulty: SudokuDifficulty.medium,
        seed: 99,
      );
      final b = await VariantEngine.generateKiller(
        gridSize: GridSize.small,
        difficulty: SudokuDifficulty.medium,
        seed: 99,
      );
      expect(b.gridDim, a.gridDim);
      expect(b.solution, a.solution);
      expect(b.givens, a.givens);
      expect(b.cages.length, a.cages.length);
      for (var i = 0; i < a.cages.length; i++) {
        expect(b.cages[i].sum, a.cages[i].sum);
        expect(b.cages[i].cells, a.cages[i].cells);
      }
    });
  });

  group('Killer 6x6 (GridSize.medium)', () {
    for (final seed in [5, 11]) {
      test('generateKiller is valid & unique (seed=$seed)', () async {
        final puzzle = await VariantEngine.generateKiller(
          gridSize: GridSize.medium,
          difficulty: SudokuDifficulty.medium,
          seed: seed,
        );
        expect(puzzle.gridDim, 6);
        _checkPuzzleInvariants(puzzle);
        await _assertUnique(puzzle);
      });
    }
  });

  group('Killer 9x9 (GridSize.standard)', () {
    for (final seed in [4, 21]) {
      test(
        'generateKiller is valid & unique (seed=$seed)',
        () async {
          final puzzle = await VariantEngine.generateKiller(
            gridSize: GridSize.standard,
            difficulty: SudokuDifficulty.medium,
            seed: seed,
          );
          expect(puzzle.gridDim, 9);
          _checkPuzzleInvariants(puzzle);
          await _assertUnique(puzzle);
        },
        timeout: const Timeout(Duration(minutes: 2)),
      );
    }

    test(
      'solveKiller returns the puzzle solution (9x9)',
      () async {
        final puzzle = await VariantEngine.generateKiller(
          gridSize: GridSize.standard,
          difficulty: SudokuDifficulty.medium,
          seed: 4,
        );
        final solved = await VariantEngine.solveKiller(
          gridDim: puzzle.gridDim,
          regions: puzzle.regions,
          cages: puzzle.cages,
          givens: puzzle.givens,
        );
        expect(solved, puzzle.solution);
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
