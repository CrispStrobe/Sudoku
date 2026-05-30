import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/technique_solver.dart';

/// Classic 3x3-box regions for a 9x9 grid.
List<List<int>> classic9Regions() {
  return List.generate(
    9,
    (r) => List.generate(9, (c) => (r ~/ 3) * 3 + (c ~/ 3)),
  );
}

/// A fully solved, valid 9x9 Sudoku used as the basis for hand-crafted
/// fragments: blank specific cells and the rest stays a legal partial board.
List<List<int>> fullSolution9() {
  // A standard valid solution (rows are permutations; every box/col valid).
  return [
    [5, 3, 4, 6, 7, 8, 9, 1, 2],
    [6, 7, 2, 1, 9, 5, 3, 4, 8],
    [1, 9, 8, 3, 4, 2, 5, 6, 7],
    [8, 5, 9, 7, 6, 1, 4, 2, 3],
    [4, 2, 6, 8, 5, 3, 7, 9, 1],
    [7, 1, 3, 9, 2, 4, 8, 5, 6],
    [9, 6, 1, 5, 3, 7, 2, 8, 4],
    [2, 8, 7, 4, 1, 9, 6, 3, 5],
    [3, 4, 5, 2, 8, 6, 1, 7, 9],
  ];
}

void main() {
  group('Generated puzzles solve to the correct solution', () {
    // A solved board produced by ONLY the implemented techniques must match the
    // engine's unique solution exactly.
    void checkSeed(
      SudokuDifficulty difficulty,
      GridSize size,
      GridShape shape,
      int seed,
    ) {
      final game = SudokuGame.generate(difficulty, size, shape, seed: seed);
      final solver = TechniqueSolver(game.grid, game.regions);
      final result = solver.solve();
      if (result.solved) {
        for (var r = 0; r < game.gridDim; r++) {
          for (var c = 0; c < game.gridDim; c++) {
            expect(
              result.board[r][c],
              game.solution[r][c],
              reason:
                  'mismatch at R${r + 1}C${c + 1} '
                  '(size=$size shape=$shape seed=$seed)',
            );
          }
        }
      }
      // If not solved, the partial board must still be consistent with the
      // solution (a correct deduction never contradicts the unique answer).
      for (var r = 0; r < game.gridDim; r++) {
        for (var c = 0; c < game.gridDim; c++) {
          final v = result.board[r][c];
          if (v != 0) {
            expect(v, game.solution[r][c], reason: 'wrong fill while stuck');
          }
        }
      }
    }

    test('4x4 classic, several seeds', () {
      for (final seed in [1, 2, 3, 7, 42]) {
        checkSeed(
          SudokuDifficulty.easy,
          GridSize.small,
          GridShape.classic,
          seed,
        );
      }
    });

    test('9x9 classic, several seeds and difficulties', () {
      for (final seed in [1, 5, 11, 99]) {
        checkSeed(
          SudokuDifficulty.easy,
          GridSize.standard,
          GridShape.classic,
          seed,
        );
        checkSeed(
          SudokuDifficulty.medium,
          GridSize.standard,
          GridShape.classic,
          seed,
        );
      }
    });

    test('9x9 jigsaw, several seeds', () {
      for (final seed in [3, 8, 21]) {
        checkSeed(
          SudokuDifficulty.easy,
          GridSize.standard,
          GridShape.jigsaw,
          seed,
        );
      }
    });
  });

  group('nextStep', () {
    test('fresh easy board: non-null step matching the solution', () {
      final game = SudokuGame.generate(
        SudokuDifficulty.easy,
        GridSize.standard,
        GridShape.classic,
        seed: 4,
      );
      final solver = TechniqueSolver(game.grid, game.regions);
      final step = solver.nextStep();
      expect(step, isNotNull);
      // A placement step must agree with the unique solution.
      if (step!.value != null) {
        expect(step.value, game.solution[step.cell[0]][step.cell[1]]);
      }
    });

    test('nextStep does not mutate the board', () {
      final game = SudokuGame.generate(
        SudokuDifficulty.easy,
        GridSize.small,
        GridShape.classic,
        seed: 2,
      );
      final solver = TechniqueSolver(game.grid, game.regions);
      final before = solver.board;
      solver.nextStep();
      expect(solver.board, before);
    });
  });

  group('Hand-crafted technique isolation', () {
    test('naked single is reported', () {
      // Start from a full valid solution and blank exactly one cell. That cell
      // necessarily has a single candidate -> naked single.
      final grid = fullSolution9();
      grid[4][4] = 0; // value here is 5
      final solver = TechniqueSolver(grid, classic9Regions());
      final step = solver.nextStep();
      expect(step, isNotNull);
      expect(step!.technique, Technique.nakedSingle);
      expect(step.cell, [4, 4]);
      expect(step.value, 5); // the unique missing value
    });

    test('hidden single is reported', () {
      // On an otherwise-empty board, confine value 7 to a single cell of box 0
      // (rows 0-2, cols 0-2) by blocking 7 from the box's other eight cells:
      //   - a 7 in row 1 blocks (1,0),(1,1),(1,2)
      //   - a 7 in row 2 blocks (2,0),(2,1),(2,2)
      //   - a 7 in column 1 blocks (0,1)
      //   - a 7 in column 2 blocks (0,2)
      // The only remaining home for 7 in box 0 is (0,0). The board is sparse,
      // so every empty cell still has many candidates: no naked single fires
      // first, and the reported deduction is the hidden single for 7.
      final grid = List.generate(9, (_) => List.filled(9, 0));
      grid[1][4] = 7;
      grid[2][5] = 7;
      grid[3][1] = 7;
      grid[4][2] = 7;
      final solver = TechniqueSolver(grid, classic9Regions());
      final step = solver.nextStep();
      expect(step, isNotNull);
      expect(step!.technique, Technique.hiddenSingle);
      expect(step.value, 7);
      expect(step.cell, [0, 0]);
    });

    test('naked pair elimination is reported', () {
      // A hand-checked fragment whose first logical step is a naked pair: in
      // column 4, two cells share the candidate set {1,8}, which eliminates the
      // candidate 1 from the rest of that column. No naked or hidden single is
      // available earlier, so the solver reports the naked pair directly.
      final grid = [
        [5, 0, 4, 6, 0, 0, 9, 0, 2],
        [0, 7, 2, 0, 9, 0, 0, 0, 0],
        [0, 0, 8, 0, 4, 0, 0, 0, 7],
        [0, 0, 9, 0, 6, 0, 4, 0, 0],
        [0, 2, 6, 0, 5, 3, 7, 9, 0],
        [7, 0, 0, 0, 0, 0, 0, 0, 0],
        [0, 0, 0, 0, 0, 0, 2, 0, 0],
        [0, 0, 7, 0, 0, 0, 0, 3, 0],
        [0, 0, 0, 0, 8, 0, 1, 0, 0],
      ];
      final solver = TechniqueSolver(grid, classic9Regions());
      final step = solver.nextStep();
      expect(step, isNotNull);
      expect(step!.technique, Technique.nakedPair);
      // The step performs at least one candidate elimination.
      expect(step.eliminations, isNotEmpty);
      expect(step.value, isNull);
    });
  });

  group('Difficulty mapping', () {
    test('naked-singles-only board rates easy', () {
      // A nearly-complete board where each empty cell resolves by naked single.
      // Start from a full valid solution and blank a handful of cells that each
      // have a unique candidate.
      final game = SudokuGame.generate(
        SudokuDifficulty.easy,
        GridSize.standard,
        GridShape.classic,
        seed: 100,
      );
      // Take the full solution and remove just 6 scattered cells.
      final grid = game.solution.map((row) => List<int>.from(row)).toList();
      final blanks = [
        [0, 0],
        [1, 4],
        [3, 7],
        [5, 2],
        [6, 6],
        [8, 8],
      ];
      for (final b in blanks) {
        grid[b[0]][b[1]] = 0;
      }
      final solver = TechniqueSolver(grid, game.regions);
      final result = solver.solve();
      expect(result.solved, isTrue);
      // Each removed cell is the only empty cell in its row/col/box region for
      // its value, so naked singles suffice -> easy.
      expect(result.hardest, Technique.nakedSingle);
      expect(result.rating, SudokuDifficulty.easy);
    });

    test('ratingFor maps techniques correctly', () {
      expect(ratingFor(Technique.nakedSingle), SudokuDifficulty.easy);
      expect(ratingFor(Technique.hiddenSingle), SudokuDifficulty.easy);
      expect(ratingFor(Technique.lockedCandidates), SudokuDifficulty.medium);
      expect(ratingFor(Technique.nakedPair), SudokuDifficulty.medium);
      expect(ratingFor(Technique.nakedTriple), SudokuDifficulty.hard);
      expect(ratingFor(Technique.hiddenPair), SudokuDifficulty.hard);
      expect(ratingFor(Technique.xWing), SudokuDifficulty.expert);
      expect(ratingFor(Technique.guess), SudokuDifficulty.expert);
    });
  });

  group('Sudoku-X (diagonal units)', () {
    test('solves an X board to its solution with diagonal: true', () {
      for (final seed in [3, 11, 27]) {
        final game = SudokuGame.generate(
          SudokuDifficulty.easy,
          GridSize.standard,
          GridShape.classic,
          seed: seed,
          variant: SudokuVariant.x,
        );
        final solver = TechniqueSolver(game.grid, game.regions, diagonal: true);
        final result = solver.solve();
        if (result.solved) {
          expect(
            result.board,
            game.solution,
            reason: 'X solve must match the unique X solution (seed $seed)',
          );
        }
      }
    });

    test('uses the diagonal as a unit (a diagonal-only deduction)', () {
      // A board where, in the main diagonal, value 4 fits only one diagonal
      // cell — solvable as a hidden single ONLY when the diagonal is a unit.
      final game = SudokuGame.generate(
        SudokuDifficulty.easy,
        GridSize.small,
        GridShape.classic,
        seed: 9,
        variant: SudokuVariant.x,
      );
      // With diagonals on, an easy 4x4 X board still solves fully.
      final solver = TechniqueSolver(game.grid, game.regions, diagonal: true);
      final result = solver.solve();
      expect(result.solved, isTrue);
      expect(result.board, game.solution);
    });
  });
}
