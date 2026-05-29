// Offline puzzle-database generator.
//
// Pre-generates solved blueprints for every grid size and shape and writes them
// to `assets/puzzles.json`, which the app bundles and loads at startup so the
// first play (and the web build, which can't background generation in an
// isolate) is instant — no on-device solving required.
//
// Run from the project root:
//   dart run tool/generate_puzzles.dart [perKey]   # default perKey = 12
//
// This imports only the pure-Dart engine, so plain `dart run` works (no Flutter
// runtime needed).
import 'dart:convert';
import 'dart:io';

import 'package:sudoku/sudoku_game.dart';

/// Smaller grids are cheap to solve, so we bundle more of them for variety;
/// the large grids are expensive to generate offline, so we bundle fewer.
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
  final base = args.isNotEmpty ? int.parse(args.first) : 12;
  final blueprints = <Map<String, dynamic>>[];

  for (final shape in GridShape.values) {
    for (final size in GridSize.values) {
      final perKey = _countFor(size, base);
      for (var i = 0; i < perKey; i++) {
        final game = SudokuGame.generate(SudokuDifficulty.easy, size, shape);
        blueprints.add(
          PuzzleBlueprint(
            solutionGrid: game.solution,
            regions: game.regions,
            gridSize: size,
            gridShape: shape,
          ).toJson(),
        );
        stdout.writeln('${size.name}-${shape.name}  ${i + 1}/$perKey');
      }
    }
  }

  final file = File('assets/puzzles.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(blueprints));
  stdout.writeln(
    'Wrote ${blueprints.length} blueprints to ${file.path} '
    '(${(file.lengthSync() / 1024).round()} KB).',
  );
}
