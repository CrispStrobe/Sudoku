// Validates the puzzles recorded by tool/killer_startup_probe.dart: every
// recorded puzzle must be uniquely solvable and generation must not have
// failed. Exits non-zero when any recorded puzzle is ambiguous.
import 'dart:convert';
import 'dart:io';

import 'package:sudoku/variant_engine.dart';

Future<void> main(List<String> args) async {
  final records =
      jsonDecode(File(args.first).readAsStringSync()) as List<dynamic>;
  var ok = 0;
  var failed = 0;
  for (final raw in records) {
    final record = raw as Map<String, dynamic>;
    final label = 'round=${record['round']} seed=${record['seed']}';
    final puzzle = record['puzzle'];
    if (puzzle == null) {
      // ignore: avoid_print
      print('$label: generation error -> ${record['error']}');
      failed++;
      continue;
    }
    final data = puzzle as Map<String, dynamic>;
    final cells = (data['solution'] as List).length;
    List<List<int>> grid(String key) => [
      for (final row in data[key] as List) (row as List).cast<int>().toList(),
    ];
    final cages = <KillerCage>[];
    for (final entry in data['cages'] as List) {
      final cage = entry as Map<String, dynamic>;
      cages.add(
        KillerCage(
          cells: [
            for (final cell in cage['cells'] as List)
              (cell as List).cast<int>().toList(),
          ],
          sum: cage['sum'] as int,
        ),
      );
    }
    final givens = grid('givens');
    final unique = await VariantEngine.killerHasUniqueSolution(
      gridDim: cells,
      regions: grid('regions'),
      cages: cages,
      givens: givens,
    );
    final clues = givens.expand((r) => r).where((v) => v != 0).length;
    // ignore: avoid_print
    print(
      '$label: unique=$unique givens=$clues dim=$cells '
      'us=${record['microseconds']}',
    );
    if (unique) {
      ok++;
    } else {
      failed++;
    }
  }
  // ignore: avoid_print
  print('unique=$ok failed=$failed');
  if (failed != 0) exitCode = 1;
}
