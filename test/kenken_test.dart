import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/variant_engine.dart';

/// KenKen's rule set is small but its edge cases are the interesting part:
/// subtraction and division are order-independent, cages *may* repeat a digit
/// (unlike Killer), and the grid is a plain Latin square with no boxes at all.
/// Each of those is a place an implementation quietly gets it wrong.
void main() {
  group('cage arithmetic', () {
    test('addition and multiplication combine in any order', () {
      expect(KenKenCage.combine(KenKenOp.add, [1, 2, 3]), 6);
      expect(KenKenCage.combine(KenKenOp.add, [3, 2, 1]), 6);
      expect(KenKenCage.combine(KenKenOp.multiply, [2, 3, 4]), 24);
      expect(KenKenCage.combine(KenKenOp.multiply, [4, 3, 2]), 24);
    });

    test('subtraction is the absolute difference, either way round', () {
      expect(KenKenCage.combine(KenKenOp.subtract, [5, 2]), 3);
      expect(KenKenCage.combine(KenKenOp.subtract, [2, 5]), 3);
    });

    test('division divides the larger by the smaller, and only if exact', () {
      expect(KenKenCage.combine(KenKenOp.divide, [6, 2]), 3);
      expect(KenKenCage.combine(KenKenOp.divide, [2, 6]), 3);
      // 5/2 is not a whole number, so the pair cannot satisfy any division
      // clue at all — null, not a rounded answer.
      expect(KenKenCage.combine(KenKenOp.divide, [5, 2]), isNull);
    });

    test('a single cell just is its value', () {
      expect(KenKenCage.combine(KenKenOp.none, [7]), 7);
    });

    test('subtraction and division are two-cell operations only', () {
      expect(KenKenOp.subtract.acceptsCellCount(2), isTrue);
      expect(KenKenOp.subtract.acceptsCellCount(3), isFalse);
      expect(KenKenOp.divide.acceptsCellCount(3), isFalse);
      expect(KenKenOp.none.acceptsCellCount(1), isTrue);
      expect(KenKenOp.none.acceptsCellCount(2), isFalse);
      expect(KenKenOp.add.acceptsCellCount(1), isFalse);
    });
  });

  group('hasError — is it wrong yet?', () {
    // A 2x2 cage in the top-left, summing to 10.
    final cage = KenKenCage(
      cells: const [
        [0, 0],
        [0, 1],
      ],
      op: KenKenOp.add,
      target: 10,
    );

    List<List<int>> grid(List<List<int>> rows) => rows;

    test('a partly filled cage is not an error while it can still reach', () {
      expect(
        cage.hasError(
          grid([
            [4, 0],
            [0, 0],
          ]),
        ),
        isFalse,
      );
    });

    test('a partial sum already past the target is an error', () {
      // 9 + 5 = 14 > 10 with nothing left to subtract.
      final big = KenKenCage(
        cells: const [
          [0, 0],
          [0, 1],
          [0, 2],
        ],
        op: KenKenOp.add,
        target: 10,
      );
      expect(
        big.hasError(
          grid([
            [9, 5, 0],
            [0, 0, 0],
            [0, 0, 0],
          ]),
        ),
        isTrue,
      );
    });

    test('a full cage with the wrong result is an error', () {
      expect(
        cage.hasError(
          grid([
            [4, 5],
            [0, 0],
          ]),
        ),
        isTrue,
      );
    });

    test('a full cage with the right result is not', () {
      expect(
        cage.hasError(
          grid([
            [4, 6],
            [0, 0],
          ]),
        ),
        isFalse,
      );
    });

    test('a repeated digit inside a cage is legal in KenKen', () {
      // The Killer instinct is to reject this. KenKen only forbids repeats
      // along a row or a column; a cage that bends around is free to repeat.
      final bent = KenKenCage(
        cells: const [
          [0, 0],
          [1, 0],
        ],
        op: KenKenOp.add,
        target: 4,
      );
      expect(
        bent.hasError(
          grid([
            [2, 0],
            [2, 0],
          ]),
        ),
        isFalse,
      );
      expect(
        bent.isSatisfied(
          grid([
            [2, 0],
            [2, 0],
          ]),
        ),
        isTrue,
      );
    });
  });

  group('the clue label', () {
    test('carries the operator except for a single cell', () {
      expect(
        KenKenCage(
          cells: const [
            [0, 0],
            [0, 1],
          ],
          op: KenKenOp.divide,
          target: 3,
        ).clue,
        '3÷',
      );
      expect(
        KenKenCage(
          cells: const [
            [0, 0],
          ],
          op: KenKenOp.none,
          target: 7,
        ).clue,
        '7',
      );
    });

    test('sits on the top-left-most cell of the cage', () {
      final cage = KenKenCage(
        cells: const [
          [2, 3],
          [1, 5],
          [1, 2],
        ],
        op: KenKenOp.add,
        target: 9,
      );
      expect(cage.labelCell, [1, 2]);
    });
  });

  group('JSON', () {
    test('round-trips', () {
      final puzzle = KenKenPuzzle(
        gridDim: 4,
        cages: [
          KenKenCage(
            cells: const [
              [0, 0],
              [0, 1],
            ],
            op: KenKenOp.add,
            target: 5,
          ),
          KenKenCage(
            cells: const [
              [0, 2],
              [0, 3],
            ],
            op: KenKenOp.subtract,
            // |4 - 1| in the solution's top row.
            target: 3,
          ),
          KenKenCage(
            cells: const [
              [1, 0],
              [1, 1],
              [1, 2],
              [1, 3],
            ],
            op: KenKenOp.add,
            target: 10,
          ),
          KenKenCage(
            cells: const [
              [2, 0],
              [2, 1],
              [2, 2],
              [2, 3],
            ],
            op: KenKenOp.add,
            target: 10,
          ),
          KenKenCage(
            cells: const [
              [3, 0],
              [3, 1],
              [3, 2],
              [3, 3],
            ],
            op: KenKenOp.add,
            target: 10,
          ),
        ],
        givens: List.generate(4, (_) => List<int>.filled(4, 0)),
        solution: const [
          [2, 3, 4, 1],
          [1, 2, 3, 4],
          [3, 4, 1, 2],
          [4, 1, 2, 3],
        ],
      );
      final back = KenKenPuzzle.fromJson(
        jsonDecode(jsonEncode(puzzle.toJson())) as Map<String, dynamic>,
      );
      expect(back.gridDim, 4);
      expect(back.cages.length, 5);
      expect(back.cages[1].op, KenKenOp.subtract);
      expect(back.solution, puzzle.solution);
    });

    test('rejects cages that do not partition the grid', () {
      // The bundle is the only thing between a bad board and a player, so
      // fromJson validates rather than trusting.
      final json = {
        'gridDim': 2,
        'cages': [
          {
            'cells': [
              [0, 0],
              [0, 1],
            ],
            'op': 'add',
            'target': 3,
          },
          // Row 1 is simply missing.
        ],
        'givens': [
          [0, 0],
          [0, 0],
        ],
        'solution': [
          [1, 2],
          [2, 1],
        ],
      };
      expect(
        () => KenKenPuzzle.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a disconnected cage', () {
      final json = {
        'gridDim': 2,
        'cages': [
          {
            'cells': [
              [0, 0],
              [1, 1],
            ],
            'op': 'add',
            'target': 2,
          },
          {
            'cells': [
              [0, 1],
              [1, 0],
            ],
            'op': 'add',
            'target': 4,
          },
        ],
        'givens': [
          [0, 0],
          [0, 0],
        ],
        'solution': [
          [1, 2],
          [2, 1],
        ],
      };
      expect(
        () => KenKenPuzzle.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a solution that is not a Latin square', () {
      final json = {
        'gridDim': 2,
        'cages': [
          {
            'cells': [
              [0, 0],
              [0, 1],
            ],
            'op': 'add',
            'target': 2,
          },
          {
            'cells': [
              [1, 0],
              [1, 1],
            ],
            'op': 'add',
            'target': 2,
          },
        ],
        'givens': [
          [0, 0],
          [0, 0],
        ],
        'solution': [
          [1, 1],
          [1, 1],
        ],
      };
      expect(
        () => KenKenPuzzle.fromJson(json),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('regions', () {
    test('are the rows, so the engine draws and checks no boxes', () {
      // The engine, the saved-game schema and the painter all want a region
      // map. KenKen has no boxes, so its regions are the row indices: the
      // region rule then says exactly what the row rule already said, and is a
      // no-op rather than an extra constraint the player cannot see.
      final regions = KenKenPuzzle.latinRegions(4);
      expect(regions.length, 4);
      for (var r = 0; r < 4; r++) {
        expect(regions[r], everyElement(r));
      }
    });
  });

  group('generation', () {
    test('produces a solvable board with cages that fit their clues', () async {
      final puzzle = await VariantEngine.generateKenKen(
        gridSize: GridSize.medium,
        difficulty: SudokuDifficulty.easy,
        seed: 7,
      );
      expect(puzzle.cages, isNotEmpty);
      expect(kenKenCagesSatisfied(puzzle.cages, puzzle.solution), isTrue);

      // Every cell belongs to exactly one cage.
      final covered = <String>{};
      for (final cage in puzzle.cages) {
        for (final cell in cage.cells) {
          expect(covered.add('${cell[0]},${cell[1]}'), isTrue);
        }
      }
      expect(covered.length, puzzle.gridDim * puzzle.gridDim);

      expect(
        await VariantEngine.kenKenHasUniqueSolution(
          gridDim: puzzle.gridDim,
          cages: puzzle.cages,
          givens: puzzle.givens,
        ),
        isTrue,
      );
    });

    test('is offered exactly where the grid dimension allows it', () {
      expect(VariantEngine.kenKenSupports(GridSize.small), isTrue);
      expect(VariantEngine.kenKenSupports(GridSize.standard), isTrue);
      // A 16x16 board would need clue arithmetic over sixteen digits, which is
      // not KenKen as anyone plays it.
      expect(VariantEngine.kenKenSupports(GridSize.mega), isFalse);
    });
  });
}
