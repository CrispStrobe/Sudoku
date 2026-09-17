import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/ready_puzzle.dart';
import 'package:sudoku/sudoku_game.dart';

import 'sudoku_game_test.dart' show isValidFullSolution;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundle covers all 48 configurations with variety and valid solutions',
    () async {
      final entries =
          jsonDecode(await rootBundle.loadString('assets/ready_puzzles.json'))
              as List;
      final counts = <String, int>{};
      for (final entry in entries) {
        final ready = ReadyPuzzle.fromJson(entry as Map<String, dynamic>);
        final key =
            '${ready.size.name}/${ready.shape.name}/${ready.difficulty.name}';
        counts.update(key, (n) => n + 1, ifAbsent: () => 1);
        final game = ready.createGame();
        expect(
          isValidFullSolution(game.solution, game.regions, game.gridDim),
          isTrue,
          reason: key,
        );
        expect(game.grid.expand((r) => r), contains(0), reason: key);
        expect(game.notes.expand((r) => r), everyElement(isEmpty));
        expect(ready.rating, isNotNull, reason: key);
      }
      expect(entries, hasLength(232));
      expect(counts, hasLength(48));
      expect(counts.values, everyElement(greaterThanOrEqualTo(2)));
    },
  );

  test(
    'bundled lookup covers every configuration without consecutive repeats',
    () async {
      SharedPreferences.setMockInitialValues({});
      final cache = ReadyPuzzleCache.isolated();
      await cache.initialize();
      for (final size in GridSize.values) {
        for (final shape in GridShape.values) {
          for (final difficulty in SudokuDifficulty.values) {
            final first = cache.get(size, shape, difficulty);
            final second = cache.get(size, shape, difficulty);
            expect(first, isNotNull);
            expect(second, isNotNull);
            expect(identical(first, second), isFalse);
          }
        }
      }
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('ready_puzzles'),
        isNull,
        reason: 'Bundled entries must never be persisted as local puzzles',
      );
    },
  );
}
