// Offline ready-to-play puzzle generator.
//
// Unlike tool/generate_puzzles.dart (which stores solved blueprints and makes
// the app dig holes on every first play), this bakes playable puzzles:
// givens, regions, generation difficulty and technique rating per entry, so
// first play replays with zero solving work (see lib/ready_puzzle.dart).
//
// Run from the project root (pure Dart, no Flutter needed):
//   dart run tool/generate_ready_puzzles.dart [perConfig]   # default 6
import 'dart:convert';
import 'dart:io';

import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/technique_solver.dart';

int _countFor(GridSize size, int base) {
  switch (size) {
    case GridSize.small:
    case GridSize.medium:
    case GridSize.large:
    case GridSize.standard:
      return base;
    case GridSize.big:
      return (base / 2).ceil();
    case GridSize.mega:
      return (base / 3).ceil();
  }
}

void main(List<String> args) {
  final base = args.isNotEmpty ? int.parse(args.first) : 6;
  if (base < 6) {
    throw ArgumentError(
      'Use at least 6 for two or more puzzles per configuration.',
    );
  }
  final entries = <Map<String, dynamic>>[];

  for (final shape in GridShape.values) {
    for (final size in GridSize.values) {
      final perConfig = _countFor(size, base);
      for (final difficulty in SudokuDifficulty.values) {
        for (var i = 0; i < perConfig; i++) {
          final seed =
              100000 * shape.index +
              1000 * size.index +
              100 * difficulty.index +
              i;
          SudokuGame? generated;
          for (var attempt = 0; attempt < 20 && generated == null; attempt++) {
            try {
              generated = SudokuGame.generate(
                difficulty,
                size,
                shape,
                seed: seed + attempt * 1000000,
              );
            } on StateError {
              // A bounded fill can reject a pathological jigsaw layout.
              // Retry a different seed; never substitute another shape.
            }
          }
          if (generated == null) {
            throw StateError('Could not generate $size/$shape/$difficulty');
          }
          final game = generated;
          SudokuDifficulty? rating;
          try {
            rating = TechniqueSolver(game.grid, game.regions).solve().rating;
          } catch (_) {
            rating = null; // unrated; no technique rating is displayed
          }
          entries.add({
            'givens': [
              for (var r = 0; r < game.gridDim; r++)
                [
                  for (var c = 0; c < game.gridDim; c++)
                    game.isOriginal[r][c] ? game.grid[r][c] : 0,
                ],
            ],
            'solution': game.solution,
            'regions': game.regions,
            'size': size.name,
            'shape': shape.name,
            'difficulty': difficulty.name,
            'rating': rating?.name,
          });
          stdout.writeln(
            '${size.name}-${shape.name}-${difficulty.name}  ${i + 1}/$perConfig',
          );
        }
      }
    }
  }

  final file = File('assets/ready_puzzles.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(entries));
  stdout.writeln(
    'Wrote ${entries.length} ready puzzles to ${file.path} '
    '(${(file.lengthSync() / 1024).round()} KB).',
  );
}
