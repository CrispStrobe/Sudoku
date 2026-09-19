// Offline Killer-puzzle generator.
//
// Killer generation is the slowest thing the app does: proving the cage sums
// admit exactly one solution is a CSP search, and a 9x9 expert board takes
// several seconds — on the web, on the main thread, because there is no
// `Isolate.spawn` there. Baking the results into the bundle makes the first
// Killer board of a session instant, the same trick the classic boards already
// use (tool/generate_ready_puzzles.dart).
//
// Run from the project root (pure Dart, no Flutter needed):
//   dart run tool/generate_killer_puzzles.dart [perConfig]   # default 4
//
// Writes assets/killer_puzzles.json, keyed "<size>-<difficulty>". Killer is
// offered up to 9x9 only (see home_screen.dart), so only those sizes are
// generated. Every puzzle is re-verified unique before it is written — the app
// trusts the bundle and does not re-check.
import 'dart:convert';
import 'dart:io';

import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/variant_engine.dart';

/// Sizes Killer is offered at. Above 9x9 the CSP search is not practical.
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

  for (final size in _sizes) {
    for (final difficulty in SudokuDifficulty.values) {
      final key = '${size.name}-${difficulty.name}';
      final entries = <Map<String, dynamic>>[];
      // Reject duplicates within a configuration: two identical boards in the
      // pool would defeat the point of having a pool.
      final seen = <String>{};

      for (var i = 0; entries.length < perConfig && i < perConfig * 5; i++) {
        final seed = 1000 * size.index + 100 * difficulty.index + i;
        final sw = Stopwatch()..start();
        KillerPuzzle puzzle;
        try {
          puzzle = await VariantEngine.generateKiller(
            gridSize: size,
            difficulty: difficulty,
            seed: seed,
          );
        } on StateError catch (e) {
          stderr.writeln('  skip $key seed $seed: $e');
          continue;
        }

        // Belt and braces: the generator proves uniqueness before returning,
        // but this file is the only thing standing between a bad board and
        // every player, so prove it again against the serialized form.
        final round = KillerPuzzle.fromJson(
          jsonDecode(jsonEncode(puzzle.toJson())) as Map<String, dynamic>,
        );
        final unique = await VariantEngine.killerHasUniqueSolution(
          gridDim: round.gridDim,
          regions: round.regions,
          cages: round.cages,
          givens: round.givens,
        );
        if (!unique) {
          stderr.writeln('  REJECT $key seed $seed: not uniquely solvable');
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
        stdout.writeln(
          '  $key #${entries.length}: ${round.cages.length} cages, '
          '$givens givens, ${sw.elapsedMilliseconds}ms',
        );
      }

      if (entries.length < 2) {
        throw StateError('Only ${entries.length} puzzle(s) for $key');
      }
      bundle[key] = entries;
    }
  }

  final file = File('assets/killer_puzzles.json');
  await file.writeAsString(const JsonEncoder().convert(bundle));
  stdout.writeln(
    'Wrote $count puzzles across ${bundle.length} configurations to '
    '${file.path} (${(await file.length()) ~/ 1024} KB) in '
    '${totalTime.elapsed.inSeconds}s.',
  );
}
