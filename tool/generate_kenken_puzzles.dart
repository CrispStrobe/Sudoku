// Offline KenKen-puzzle generator.
//
// KenKen is the cheapest of the three CSP variants to generate — the cages are
// strong constraints, so a random partition over a random Latin square is
// usually uniquely solvable on the first attempt, and nearly every board comes
// out with no givens at all. "Usually cheap" is still not bounded, though, and
// on the web the generator runs on the only thread there is. So the boards are
// made here and shipped, the same trade the Killer and Thermo bundles make.
//
// Run from the project root (pure Dart, no Flutter needed):
//   dart run tool/generate_kenken_puzzles.dart [perConfig]   # default 6
//
// Writes assets/kenken_puzzles.json, keyed "<size>-<difficulty>". KenKen is
// offered up to 9x9 (see VariantEngine.kenKenSupports). Every puzzle is
// re-verified unique through its serialized form before it is written — the app
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
  final perConfig = args.isNotEmpty ? int.parse(args.first) : 6;
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
        KenKenPuzzle puzzle;
        try {
          puzzle = await VariantEngine.generateKenKen(
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
        final round = KenKenPuzzle.fromJson(
          jsonDecode(jsonEncode(puzzle.toJson())) as Map<String, dynamic>,
        );
        final unique = await VariantEngine.kenKenHasUniqueSolution(
          gridDim: round.gridDim,
          cages: round.cages,
          givens: round.givens,
        );
        if (!unique) {
          stderr.writeln('  REJECT $key seed $seed: not uniquely solvable');
          continue;
        }
        if (!kenKenCagesSatisfied(round.cages, round.solution)) {
          stderr.writeln('  REJECT $key seed $seed: solution breaks a cage');
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
        final biggest = round.cages.fold<int>(
          0,
          (n, c) => n > c.cells.length ? n : c.cells.length,
        );
        stdout.writeln(
          '  $key #${entries.length}: ${round.cages.length} cages '
          '(largest $biggest), $givens givens, ${sw.elapsedMilliseconds}ms',
        );
      }

      if (entries.length < 2) {
        throw StateError('Only ${entries.length} puzzle(s) for $key');
      }
      bundle[key] = entries;
    }
  }

  final file = File('assets/kenken_puzzles.json');
  await file.writeAsString(const JsonEncoder().convert(bundle));
  stdout.writeln(
    'Wrote $count puzzles ($noGivens with no givens at all) across '
    '${bundle.length} configurations to ${file.path} '
    '(${(await file.length()) ~/ 1024} KB) in ${totalTime.elapsed.inSeconds}s.',
  );
}
