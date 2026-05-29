import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/sudoku_game.dart';

// ---------------------------------------------------------------------------
// Independent validators (deliberately NOT reusing engine internals, so the
// tests cross-check the engine rather than trusting it).
// ---------------------------------------------------------------------------

/// True if [grid] is a fully-filled, conflict-free solution for [regions].
bool isValidFullSolution(List<List<int>> grid, List<List<int>> regions, int dim) {
  for (var r = 0; r < dim; r++) {
    final rowSeen = <int>{};
    final colSeen = <int>{};
    for (var c = 0; c < dim; c++) {
      final rv = grid[r][c];
      final cv = grid[c][r];
      if (rv < 1 || rv > dim) return false;
      if (!rowSeen.add(rv)) return false;
      if (!colSeen.add(cv)) return false;
    }
  }
  // Regions: each region must hold 1..dim exactly once.
  final byRegion = <int, List<int>>{};
  for (var r = 0; r < dim; r++) {
    for (var c = 0; c < dim; c++) {
      byRegion.putIfAbsent(regions[r][c], () => []).add(grid[r][c]);
    }
  }
  for (final values in byRegion.values) {
    if (values.toSet().length != dim) return false;
  }
  return true;
}

bool _safe(List<List<int>> g, List<List<int>> regions, int dim, int row, int col, int num) {
  for (var i = 0; i < dim; i++) {
    if (g[row][i] == num) return false;
    if (g[i][col] == num) return false;
  }
  final region = regions[row][col];
  for (var r = 0; r < dim; r++) {
    for (var c = 0; c < dim; c++) {
      if (regions[r][c] == region && g[r][c] == num) return false;
    }
  }
  return true;
}

List<int>? _firstEmptyMrv(List<List<int>> g, List<List<int>> regions, int dim) {
  var best = dim + 1;
  List<int>? cell;
  for (var r = 0; r < dim; r++) {
    for (var c = 0; c < dim; c++) {
      if (g[r][c] != 0) continue;
      var n = 0;
      for (var v = 1; v <= dim; v++) {
        if (_safe(g, regions, dim, r, c, v)) n++;
      }
      if (n == 0) return [r, c];
      if (n < best) {
        best = n;
        cell = [r, c];
      }
    }
  }
  return cell;
}

/// Counts solutions of [puzzle] up to [limit] (independent solver).
int countSolutions(List<List<int>> puzzle, List<List<int>> regions, int dim,
    {int limit = 2}) {
  final g = puzzle.map((row) => List<int>.from(row)).toList();
  var found = 0;
  void solve() {
    if (found >= limit) return;
    final cell = _firstEmptyMrv(g, regions, dim);
    if (cell == null) {
      found++;
      return;
    }
    final r = cell[0], c = cell[1];
    for (var v = 1; v <= dim; v++) {
      if (_safe(g, regions, dim, r, c, v)) {
        g[r][c] = v;
        solve();
        g[r][c] = 0;
        if (found >= limit) return;
      }
    }
  }

  solve();
  return found;
}

void main() {
  group('helpers', () {
    test('gridDimensionFor maps every size', () {
      expect(gridDimensionFor(GridSize.small), 4);
      expect(gridDimensionFor(GridSize.medium), 6);
      expect(gridDimensionFor(GridSize.large), 8);
      expect(gridDimensionFor(GridSize.standard), 9);
      expect(gridDimensionFor(GridSize.big), 10);
      expect(gridDimensionFor(GridSize.mega), 12);
    });

    test('box dimensions divide the grid evenly', () {
      for (final size in GridSize.values) {
        final dim = gridDimensionFor(size);
        final box = boxDimensionsFor(dim);
        expect(dim % box[0], 0, reason: '$dim rows divisible');
        expect(dim % box[1], 0, reason: '$dim cols divisible');
        expect(box[0] * box[1], dim, reason: 'box area == dim for $dim');
      }
    });
  });

  group('classic generation', () {
    for (final size in GridSize.values) {
      test('${size.name}: valid solution, regions, and unique puzzle', () {
        final game = SudokuGame.generate(
            SudokuDifficulty.easy, size, GridShape.classic,
            seed: 42);
        final dim = gridDimensionFor(size);

        expect(game.gridDim, dim);
        expect(game.solution.length, dim);
        expect(game.grid.length, dim);

        expect(isValidFullSolution(game.solution, game.regions, dim), isTrue,
            reason: 'solution must be a valid full sudoku');

        // Classic regions: dim regions, each of size dim.
        final sizes = <int, int>{};
        for (var r = 0; r < dim; r++) {
          for (var c = 0; c < dim; c++) {
            sizes[game.regions[r][c]] = (sizes[game.regions[r][c]] ?? 0) + 1;
          }
        }
        expect(sizes.length, dim);
        expect(sizes.values.every((s) => s == dim), isTrue);

        // Givens are a subset of the solution.
        for (var r = 0; r < dim; r++) {
          for (var c = 0; c < dim; c++) {
            if (game.grid[r][c] != 0) {
              expect(game.grid[r][c], game.solution[r][c]);
              expect(game.isOriginal[r][c], isTrue);
            }
          }
        }

        // The puzzle the player sees has exactly one solution.
        expect(countSolutions(game.grid, game.regions, dim), 1,
            reason: '${size.name} puzzle must be uniquely solvable');
      });
    }
  });

  group('jigsaw generation', () {
    for (final size in [
      GridSize.small,
      GridSize.medium,
      GridSize.large,
      GridSize.standard,
      GridSize.big,
    ]) {
      test('${size.name}: connected regions of correct size + valid solution',
          () {
        final game = SudokuGame.generate(
            SudokuDifficulty.medium, size, GridShape.jigsaw,
            seed: 7);
        final dim = gridDimensionFor(size);

        expect(isValidFullSolution(game.solution, game.regions, dim), isTrue);

        final sizes = <int, int>{};
        for (var r = 0; r < dim; r++) {
          for (var c = 0; c < dim; c++) {
            sizes[game.regions[r][c]] = (sizes[game.regions[r][c]] ?? 0) + 1;
          }
        }
        expect(sizes.length, dim, reason: 'should be dim regions');
        expect(sizes.values.every((s) => s == dim), isTrue,
            reason: 'each region has dim cells');

        expect(countSolutions(game.grid, game.regions, dim), 1,
            reason: 'jigsaw puzzle must be uniquely solvable');
      });
    }
  });

  group('gameplay API', () {
    late SudokuGame game;
    setUp(() {
      game = SudokuGame.generate(
          SudokuDifficulty.easy, GridSize.standard, GridShape.classic,
          seed: 99);
    });

    test('original cells are immutable', () {
      late int r, c, original;
      outer:
      for (r = 0; r < 9; r++) {
        for (c = 0; c < 9; c++) {
          if (game.isOriginal[r][c]) {
            original = game.grid[r][c];
            break outer;
          }
        }
      }
      game.setCell(r, c, original == 1 ? 2 : 1);
      expect(game.grid[r][c], original, reason: 'setCell ignores originals');
      game.clearCell(r, c);
      expect(game.grid[r][c], original, reason: 'clearCell ignores originals');
      expect(game.isValidMove(r, c, 5), isFalse);
    });

    test('isValidMove enforces row, column and region', () {
      // Find an empty cell and a value already present in its row.
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (game.grid[r][c] == 0) {
            final rowValue =
                List.generate(9, (i) => game.grid[r][i]).firstWhere((v) => v != 0,
                    orElse: () => 0);
            if (rowValue != 0) {
              expect(game.isValidMove(r, c, rowValue), isFalse);
            }
            // The solution value is always a legal move into an empty cell.
            expect(game.isValidMove(r, c, game.solution[r][c]), isTrue);
            return;
          }
        }
      }
    });

    test('filling with the solution wins; isSolved requires correctness', () {
      expect(game.isCompleted(), isFalse);
      expect(game.isSolved(), isFalse);
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (!game.isOriginal[r][c]) game.setCell(r, c, game.solution[r][c]);
        }
      }
      expect(game.isCompleted(), isTrue);
      expect(game.isSolved(), isTrue);
    });

    test('a full but conflicting board is complete yet not solved', () {
      // Force a conflict by filling every non-original cell with 1.
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (!game.isOriginal[r][c]) game.setCell(r, c, 1);
        }
      }
      expect(game.isCompleted(), isTrue);
      expect(game.isSolved(), isFalse,
          reason: 'isSolved must reject conflicting full boards');
    });
  });

  group('hints', () {
    test('occupied / original cell returns a conflict hint', () {
      final game = SudokuGame.generate(
          SudokuDifficulty.easy, GridSize.standard, GridShape.classic,
          seed: 5);
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (game.isOriginal[r][c]) {
            final hints = game.getSmartHints(r, c);
            expect(hints.single.type, HintType.conflict);
            return;
          }
        }
      }
    });

    test('give-answer hint always matches the solution', () {
      final game = SudokuGame.generate(
          SudokuDifficulty.medium, GridSize.standard, GridShape.classic,
          seed: 11);
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (game.grid[r][c] == 0) {
            final hints = game.getSmartHints(r, c);
            final answer = hints
                .where((h) =>
                    h.type == HintType.giveAnswer ||
                    h.type == HintType.nakedSingle)
                .map((h) => h.data as int)
                .toList();
            if (answer.isNotEmpty) {
              for (final a in answer) {
                expect(a, game.solution[r][c]);
              }
              return;
            }
          }
        }
      }
    });

    test('possibleNumbers always contains the solution value', () {
      final game = SudokuGame.generate(
          SudokuDifficulty.hard, GridSize.standard, GridShape.classic,
          seed: 3);
      for (var r = 0; r < 9; r++) {
        for (var c = 0; c < 9; c++) {
          if (game.grid[r][c] == 0) {
            expect(game.possibleNumbers(r, c), contains(game.solution[r][c]));
          }
        }
      }
    });
  });

  group('blueprint', () {
    test('round-trips through JSON', () {
      final game = SudokuGame.generate(
          SudokuDifficulty.easy, GridSize.medium, GridShape.jigsaw,
          seed: 21);
      final blueprint = PuzzleBlueprint(
        solutionGrid: game.solution,
        regions: game.regions,
        gridSize: GridSize.medium,
        gridShape: GridShape.jigsaw,
      );
      final restored = PuzzleBlueprint.fromJson(blueprint.toJson());
      expect(restored.gridSize, GridSize.medium);
      expect(restored.gridShape, GridShape.jigsaw);
      expect(restored.solutionGrid, blueprint.solutionGrid);
      expect(restored.regions, blueprint.regions);
    });

    test('fromBlueprint yields a playable, uniquely solvable puzzle', () {
      final source = SudokuGame.generate(
          SudokuDifficulty.easy, GridSize.standard, GridShape.classic,
          seed: 8);
      final blueprint = PuzzleBlueprint(
        solutionGrid: source.solution,
        regions: source.regions,
        gridSize: GridSize.standard,
        gridShape: GridShape.classic,
      );
      final game = SudokuGame.fromBlueprint(blueprint, SudokuDifficulty.medium);
      expect(game.gridDim, 9);
      expect(isValidFullSolution(game.solution, game.regions, 9), isTrue);
      expect(countSolutions(game.grid, game.regions, 9), 1);
    });
  });
}
