import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/kenken_bundle.dart';
import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/variant_engine.dart';

/// The bundled KenKen boards are trusted at runtime — `KenKenPuzzle.fromJson`
/// validates structure (the cages partition the grid, each one is connected,
/// the solution is a Latin square that satisfies every clue) but deliberately
/// does not re-prove uniqueness, because that proof is the expensive thing the
/// bundle exists to avoid. One bundled 9x9 expert board took 80 seconds to
/// find.
///
/// So the proof happens here instead. Every board in the asset is re-solved and
/// checked to admit exactly one completion — the property a player would only
/// discover was missing by being unable to finish.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// KenKen is offered up to 9x9; the generator covers exactly those.
  const sizes = [
    GridSize.small,
    GridSize.medium,
    GridSize.large,
    GridSize.standard,
  ];

  test('every configuration KenKen is offered at has a pool', () async {
    final bundle = KenKenPuzzleBundle.isolated();
    await bundle.initialize();

    final thin = <String>[];
    for (final size in sizes) {
      for (final difficulty in SudokuDifficulty.values) {
        final n = bundle.countFor(size, difficulty);
        // Two is the floor that lets "new game" serve a different board.
        if (n < 2) thin.add('${size.name}-${difficulty.name}: $n');
      }
    }
    expect(
      thin,
      isEmpty,
      reason:
          'configurations with too few bundled KenKen puzzles:\n'
          '${thin.join('\n')}\n'
          'Regenerate with: dart run tool/generate_kenken_puzzles.dart',
    );
  });

  test('the bundle serves a different board on consecutive draws', () async {
    final bundle = KenKenPuzzleBundle.isolated();
    await bundle.initialize();
    final first = bundle.get(GridSize.standard, SudokuDifficulty.easy);
    final second = bundle.get(GridSize.standard, SudokuDifficulty.easy);
    expect(first, isNotNull);
    expect(second, isNotNull);
    expect(
      identical(first, second),
      isFalse,
      reason: 'two "new game" taps in a row replayed the identical board',
    );
  });

  test(
    'every bundled KenKen puzzle is valid and uniquely solvable',
    () async {
      final decoded =
          jsonDecode(await rootBundle.loadString(KenKenPuzzleBundle.assetPath))
              as Map<String, dynamic>;

      final failures = <String>[];
      var checked = 0;
      var noGivens = 0;
      final timer = Stopwatch()..start();

      for (final entry in decoded.entries) {
        final list = entry.value as List;
        for (var i = 0; i < list.length; i++) {
          final label = '${entry.key}#$i';
          late KenKenPuzzle puzzle;
          try {
            // fromJson is the runtime path: structural validation included.
            puzzle = KenKenPuzzle.fromJson(list[i] as Map<String, dynamic>);
          } catch (e) {
            failures.add('$label: rejected by fromJson — $e');
            continue;
          }

          if (!kenKenCagesSatisfied(puzzle.cages, puzzle.solution)) {
            failures.add('$label: solution does not satisfy its own cages');
            continue;
          }
          if (!_latinSquare(puzzle)) {
            failures.add('$label: solution is not a Latin square');
            continue;
          }
          if (!_cageShapesLegal(puzzle)) {
            failures.add('$label: a cage carries an operator it cannot hold');
            continue;
          }
          if (!await VariantEngine.kenKenHasUniqueSolution(
            gridDim: puzzle.gridDim,
            cages: puzzle.cages,
            givens: puzzle.givens,
          )) {
            failures.add('$label: not uniquely solvable');
          }
          if (puzzle.givens.expand((r) => r).every((v) => v == 0)) noGivens++;
          checked++;
        }
      }

      // ignore: avoid_print
      print(
        'Verified $checked bundled KenKen puzzles ($noGivens with no givens) '
        'in ${timer.elapsed.inSeconds}s.',
      );
      expect(checked, greaterThan(0), reason: 'the bundle is empty');
      expect(failures, isEmpty, reason: failures.join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

bool _latinSquare(KenKenPuzzle puzzle) {
  final dim = puzzle.gridDim;
  final rows = List.generate(dim, (_) => <int>{});
  final cols = List.generate(dim, (_) => <int>{});
  for (var r = 0; r < dim; r++) {
    for (var c = 0; c < dim; c++) {
      final v = puzzle.solution[r][c];
      if (v < 1 || v > dim) return false;
      if (!rows[r].add(v) || !cols[c].add(v)) return false;
    }
  }
  return true;
}

/// − and ÷ are two-cell operators and a bare number is a one-cell cage. A clue
/// like "3−" on three cells is unreadable, not merely unusual.
bool _cageShapesLegal(KenKenPuzzle puzzle) => puzzle.cages.every(
  (cage) => cage.op.acceptsCellCount(cage.cells.length) && cage.target > 0,
);
