import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/thermo_bundle.dart';
import 'package:sudoku/variant_engine.dart';

/// The bundled Thermo boards are trusted at runtime — `ThermoPuzzle.fromJson`
/// validates structure (connected paths, lines that climb in their own
/// solution, givens that agree with it) but deliberately does not re-prove
/// uniqueness, because that proof is the expensive thing the bundle exists to
/// avoid.
///
/// So the proof happens here instead. Every board in the asset is re-solved and
/// checked to admit exactly one completion — the property a player would only
/// discover was missing by being unable to finish.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Thermo is offered up to 9x9; the generator covers exactly those.
  const sizes = [
    GridSize.small,
    GridSize.medium,
    GridSize.large,
    GridSize.standard,
  ];

  test('every configuration Thermo is offered at has a pool', () async {
    final bundle = ThermoPuzzleBundle.isolated();
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
          'configurations with too few bundled Thermo puzzles:\n'
          '${thin.join('\n')}\n'
          'Regenerate with: dart run tool/generate_thermo_puzzles.dart',
    );
  });

  test('the bundle serves a different board on consecutive draws', () async {
    final bundle = ThermoPuzzleBundle.isolated();
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
    'every bundled Thermo puzzle is valid and uniquely solvable',
    () async {
      final decoded =
          jsonDecode(await rootBundle.loadString(ThermoPuzzleBundle.assetPath))
              as Map<String, dynamic>;

      final failures = <String>[];
      var checked = 0;
      var noGivens = 0;
      final timer = Stopwatch()..start();

      for (final entry in decoded.entries) {
        final list = entry.value as List;
        for (var i = 0; i < list.length; i++) {
          final label = '${entry.key}#$i';
          late ThermoPuzzle puzzle;
          try {
            // fromJson is the runtime path: structural validation included.
            puzzle = ThermoPuzzle.fromJson(list[i] as Map<String, dynamic>);
          } catch (e) {
            failures.add('$label: rejected by fromJson — $e');
            continue;
          }

          if (!thermosSatisfied(puzzle.thermos, puzzle.solution)) {
            failures.add('$label: solution does not satisfy its own lines');
            continue;
          }
          if (!_rowsColumnsRegionsValid(puzzle)) {
            failures.add('$label: solution breaks row/column/region rules');
            continue;
          }
          if (!await VariantEngine.thermoHasUniqueSolution(
            gridDim: puzzle.gridDim,
            regions: puzzle.regions,
            thermos: puzzle.thermos,
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
        'Verified $checked bundled Thermo puzzles ($noGivens with no givens) '
        'in ${timer.elapsed.inSeconds}s.',
      );
      expect(checked, greaterThan(0), reason: 'the bundle is empty');
      expect(failures, isEmpty, reason: failures.join('\n'));
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

bool _rowsColumnsRegionsValid(ThermoPuzzle puzzle) {
  final dim = puzzle.gridDim;
  final rows = List.generate(dim, (_) => <int>{});
  final cols = List.generate(dim, (_) => <int>{});
  final regions = List.generate(dim, (_) => <int>{});
  for (var r = 0; r < dim; r++) {
    for (var c = 0; c < dim; c++) {
      final v = puzzle.solution[r][c];
      if (!rows[r].add(v) || !cols[c].add(v)) return false;
      if (!regions[puzzle.regions[r][c]].add(v)) return false;
    }
  }
  return true;
}
