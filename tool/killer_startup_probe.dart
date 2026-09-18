// Run with: dart run tool/killer_startup_probe.dart [output.json]
// Measures pure-Dart generation, not Flutter frame/startup latency.
import 'dart:convert';
import 'dart:io';

import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/variant_engine.dart';

Map<String, Object> snapshot(KillerPuzzle p) => {
  'regions': p.regions,
  'solution': p.solution,
  'givens': p.givens,
  'cages': [
    for (final c in p.cages) {'cells': c.cells, 'sum': c.sum},
  ],
};

Future<void> main(List<String> args) async {
  // One unrecorded warmup, then identical ordered workloads before and after.
  await VariantEngine.generateKiller(
    gridSize: GridSize.standard,
    difficulty: SudokuDifficulty.expert,
    seed: 42,
  );
  final records = <Map<String, Object>>[];
  for (var round = 0; round < 3; round++) {
    for (final seed in [4, 21, 42]) {
      final watch = Stopwatch()..start();
      KillerPuzzle? puzzle;
      String? error;
      try {
        puzzle = await VariantEngine.generateKiller(
          gridSize: GridSize.standard,
          difficulty: SudokuDifficulty.expert,
          seed: seed,
        );
      } on StateError catch (e) {
        error = e.message;
      }
      watch.stop();
      final record = <String, Object>{
        'round': round,
        'seed': seed,
        'microseconds': watch.elapsedMicroseconds,
        if (puzzle != null) 'puzzle': snapshot(puzzle),
        'error': ?error,
      };
      records.add(record);
      // ignore: avoid_print
      print('round=$round seed=$seed us=${watch.elapsedMicroseconds}');
      if (args.isNotEmpty) {
        File(args.first).writeAsStringSync(jsonEncode(records));
      }
    }
  }
}
