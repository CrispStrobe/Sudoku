// Offline Thermo-puzzle generator.
//
// Thermo boards are expensive to make well. The good ones — no givens at all,
// the grid pinned down by the thermometers alone — come from drawing line
// shapes and asking the CSP for a grid that fits, and most random layouts turn
// out contradictory, so a board can cost dozens of enumerations. That is fine
// here and not fine at runtime, which is the same trade the Killer bundle
// makes (tool/generate_killer_puzzles.dart).
//
// Run from the project root (pure Dart, no Flutter needed):
//   dart run tool/generate_thermo_puzzles.dart [perConfig]   # default 4
//
// Writes assets/thermo_puzzles.json, keyed "<size>-<difficulty>". Thermo is
// offered up to 9x9 (see VariantEngine.thermoSupports), so only those sizes are
// generated. Every puzzle is re-verified unique before it is written — the app
// trusts the bundle and does not re-check.
import 'dart:convert';
import 'dart:io';

import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/variant_engine.dart';

const _sizes = [
  GridSize.small,
  GridSize.medium,
  GridSize.large,
  GridSize.standard,
];

Future<void> main(List<String> args) async {
  final perConfig = args.isNotEmpty ? int.parse(args.first) : 4;
  if (perConfig < 2) {
    throw ArgumentError(
      'Use at least 2 so "new game" can serve a different board.',
    );
  }

  final bundle = <String, List<Map<String, dynamic>>>{};
  final totalTime = Stopwatch()..start();
  var count = 0;
  var noGivens = 0;

  for (final size in _sizes) {
    for (final difficulty in SudokuDifficulty.values) {
      final key = '${size.name}-${difficulty.name}';
      final entries = <Map<String, dynamic>>[];
      final seen = <String>{};

      for (var i = 0; entries.length < perConfig && i < perConfig * 4; i++) {
        final seed = 1000 * size.index + 100 * difficulty.index + i;
        final sw = Stopwatch()..start();
        ThermoPuzzle puzzle;
        try {
          puzzle = await VariantEngine.generateThermo(
            gridSize: size,
            difficulty: difficulty,
            seed: seed,
          );
        } on StateError catch (e) {
          stderr.writeln('  skip $key seed $seed: $e');
          continue;
        }

        // Belt and braces: prove it again, against the serialized form, since
        // this file is the only thing between a bad board and every player.
        final round = ThermoPuzzle.fromJson(
          jsonDecode(jsonEncode(puzzle.toJson())) as Map<String, dynamic>,
        );
        final unique = await VariantEngine.thermoHasUniqueSolution(
          gridDim: round.gridDim,
          regions: round.regions,
          thermos: round.thermos,
          givens: round.givens,
        );
        if (!unique) {
          stderr.writeln('  REJECT $key seed $seed: not uniquely solvable');
          continue;
        }
        if (!thermosSatisfied(round.thermos, round.solution)) {
          stderr.writeln('  REJECT $key seed $seed: solution breaks a line');
          continue;
        }

        final fingerprint = jsonEncode(round.toJson());
        if (!seen.add(fingerprint)) continue;

        entries.add(round.toJson());
        count++;
        final givens = round.givens
            .expand((row) => row)
            .where((v) => v != 0)
            .length;
        if (givens == 0) noGivens++;
        final cells = round.thermos.fold<int>(0, (n, t) => n + t.cells.length);
        stdout.writeln(
          '  $key #${entries.length}: ${round.thermos.length} thermometers '
          '($cells cells), $givens givens, ${sw.elapsedMilliseconds}ms',
        );
      }

      if (entries.length < 2) {
        throw StateError('Only ${entries.length} puzzle(s) for $key');
      }
      bundle[key] = entries;
    }
  }

  final file = File('assets/thermo_puzzles.json');
  await file.writeAsString(const JsonEncoder().convert(bundle));
  stdout.writeln(
    'Wrote $count puzzles ($noGivens with no givens at all) across '
    '${bundle.length} configurations to ${file.path} '
    '(${(await file.length()) ~/ 1024} KB) in ${totalTime.elapsed.inSeconds}s.',
  );
}
