import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/variant_engine.dart';

/// The Thermo variant: the rule, the generator, and the serialized form.
///
/// A thermometer is the cheapest interesting variant to add — one
/// `addStrictlyAscending` per line and the existing generate/prove/dig pipeline
/// does the rest — which is exactly why it is worth pinning properly. The next
/// variant will be built by copying this one.
void main() {
  group('ThermoLine', () {
    test('a strictly increasing line is satisfied', () {
      final grid = [
        [1, 2, 3],
        [4, 5, 6],
        [7, 8, 9],
      ];
      const line = ThermoLine([
        [0, 0],
        [0, 1],
        [0, 2],
      ]);
      expect(line.isSatisfied(grid), isTrue);
      expect(line.hasError(grid), isFalse);
    });

    test('a decreasing line is an error, not merely unsatisfied', () {
      final grid = [
        [3, 2, 1],
      ];
      const line = ThermoLine([
        [0, 0],
        [0, 1],
        [0, 2],
      ]);
      expect(line.isSatisfied(grid), isFalse);
      expect(line.hasError(grid), isTrue);
    });

    test('an empty line is unsatisfied but not yet wrong', () {
      final grid = [
        [0, 0, 0],
      ];
      const line = ThermoLine([
        [0, 0],
        [0, 1],
        [0, 2],
      ]);
      expect(line.isSatisfied(grid), isFalse);
      expect(line.hasError(grid), isFalse);
    });

    /// The subtle case: cells with a gap between them.
    ///
    /// With `[_, 5, _, 3]` the 3 is already wrong even though the cell between
    /// them is empty, because everything after the 5 must exceed it. Comparing
    /// only adjacent filled pairs is not enough — the *distance* matters, since
    /// each step along the path must add at least one.
    test('a gap does not hide a violation', () {
      final grid = [
        [0, 5, 0, 3],
      ];
      const line = ThermoLine([
        [0, 0],
        [0, 1],
        [0, 2],
        [0, 3],
      ]);
      expect(line.hasError(grid), isTrue);
    });

    test('a gap that is still reachable is not an error', () {
      final grid = [
        [0, 5, 0, 7],
      ];
      const line = ThermoLine([
        [0, 0],
        [0, 1],
        [0, 2],
        [0, 3],
      ]);
      expect(line.hasError(grid), isFalse);
    });

    test('two cells apart must differ by at least two', () {
      final grid = [
        [0, 5, 0, 6],
      ];
      const line = ThermoLine([
        [0, 0],
        [0, 1],
        [0, 2],
        [0, 3],
      ]);
      // 5 then 6 with one cell between them: the gap cell would have to be
      // strictly between 5 and 6, and there is no such digit.
      expect(line.hasError(grid), isTrue);
    });
  });

  group('generation', () {
    test(
      'a generated 4x4 board is uniquely solvable and self-consistent',
      () async {
        final puzzle = await VariantEngine.generateThermo(
          gridSize: GridSize.small,
          difficulty: SudokuDifficulty.easy,
          seed: 1,
        );
        expect(puzzle.thermos, isNotEmpty);
        // The answer must satisfy its own clues.
        expect(thermosSatisfied(puzzle.thermos, puzzle.solution), isTrue);
        // Every given must agree with the answer.
        for (var r = 0; r < puzzle.gridDim; r++) {
          for (var c = 0; c < puzzle.gridDim; c++) {
            final given = puzzle.givens[r][c];
            if (given != 0) expect(given, puzzle.solution[r][c]);
          }
        }
        expect(
          await VariantEngine.thermoHasUniqueSolution(
            gridDim: puzzle.gridDim,
            regions: puzzle.regions,
            thermos: puzzle.thermos,
            givens: puzzle.givens,
          ),
          isTrue,
        );
      },
    );

    test('the same seed reproduces the same puzzle', () async {
      Future<String> generate() async {
        final p = await VariantEngine.generateThermo(
          gridSize: GridSize.small,
          difficulty: SudokuDifficulty.medium,
          seed: 99,
        );
        return jsonEncode(p.toJson());
      }

      expect(await generate(), await generate());
    });

    test('thermometers are connected paths that climb', () async {
      final puzzle = await VariantEngine.generateThermo(
        gridSize: GridSize.medium,
        difficulty: SudokuDifficulty.easy,
        seed: 7,
      );
      for (final thermo in puzzle.thermos) {
        expect(thermo.cells.length, greaterThanOrEqualTo(2));
        for (var i = 1; i < thermo.cells.length; i++) {
          final a = thermo.cells[i - 1];
          final b = thermo.cells[i];
          expect(
            (a[0] - b[0]).abs() + (a[1] - b[1]).abs(),
            1,
            reason: 'thermometer jumps between non-adjacent cells',
          );
          expect(
            puzzle.solution[b[0]][b[1]],
            greaterThan(puzzle.solution[a[0]][a[1]]),
            reason: 'thermometer does not increase in its own solution',
          );
        }
      }
    });

    test('thermometers never overlap', () async {
      final puzzle = await VariantEngine.generateThermo(
        gridSize: GridSize.medium,
        difficulty: SudokuDifficulty.hard,
        seed: 12,
      );
      final seen = <int>{};
      for (final thermo in puzzle.thermos) {
        for (final cell in thermo.cells) {
          expect(
            seen.add(cell[0] * puzzle.gridDim + cell[1]),
            isTrue,
            reason: 'two thermometers share a cell',
          );
        }
      }
    });

    test('Thermo is offered up to 9x9 only', () {
      expect(VariantEngine.thermoSupports(GridSize.small), isTrue);
      expect(VariantEngine.thermoSupports(GridSize.standard), isTrue);
      expect(VariantEngine.thermoSupports(GridSize.big), isFalse);
      expect(VariantEngine.thermoSupports(GridSize.mega), isFalse);
    });
  });

  group('serialization', () {
    test('round-trips through JSON', () async {
      final puzzle = await VariantEngine.generateThermo(
        gridSize: GridSize.small,
        difficulty: SudokuDifficulty.easy,
        seed: 5,
      );
      final round = ThermoPuzzle.fromJson(
        jsonDecode(jsonEncode(puzzle.toJson())) as Map<String, dynamic>,
      );
      expect(round.gridDim, puzzle.gridDim);
      expect(round.thermos.length, puzzle.thermos.length);
      expect(round.solution, puzzle.solution);
      expect(round.givens, puzzle.givens);
      for (var i = 0; i < round.thermos.length; i++) {
        expect(round.thermos[i].cells, puzzle.thermos[i].cells);
      }
    });

    /// `fromJson` is the runtime path for every bundled board, so it has to
    /// reject a corrupt one rather than hand the player an unplayable puzzle.
    test('rejects a thermometer that contradicts its own solution', () async {
      final puzzle = await VariantEngine.generateThermo(
        gridSize: GridSize.small,
        difficulty: SudokuDifficulty.easy,
        seed: 5,
      );
      final json =
          jsonDecode(jsonEncode(puzzle.toJson())) as Map<String, dynamic>;
      // Reverse the first thermometer: the same cells, now descending.
      final first = (json['thermos'] as List).first as Map<String, dynamic>;
      first['cells'] = (first['cells'] as List).reversed.toList();
      expect(() => ThermoPuzzle.fromJson(json), throwsFormatException);
    });

    test('rejects a disconnected thermometer', () {
      expect(
        () => ThermoPuzzle.fromJson({
          'gridDim': 4,
          'regions': [
            [0, 0, 1, 1],
            [0, 0, 1, 1],
            [2, 2, 3, 3],
            [2, 2, 3, 3],
          ],
          'thermos': [
            {
              'cells': [
                [0, 0],
                [3, 3],
              ],
            },
          ],
          'givens': List.generate(4, (_) => List.filled(4, 0)),
          'solution': [
            [1, 2, 3, 4],
            [3, 4, 1, 2],
            [2, 1, 4, 3],
            [4, 3, 2, 1],
          ],
        }),
        throwsFormatException,
      );
    });

    test('rejects a one-cell thermometer', () {
      expect(
        () => ThermoLine.fromJson({
          'cells': [
            [0, 0],
          ],
        }),
        throwsFormatException,
      );
    });
  });
}
