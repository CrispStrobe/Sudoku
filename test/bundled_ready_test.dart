import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/ready_puzzle.dart';
import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/technique_solver.dart';

import 'sudoku_game_test.dart' show isValidFullSolution;
import 'support/independent_uniqueness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all 232 bundled puzzles have distinct givens, one solution and fresh ratings',
    () async {
      final entries =
          jsonDecode(await rootBundle.loadString('assets/ready_puzzles.json'))
              as List;
      final counts = <String, int>{};
      final givensByKey = <String, Set<String>>{};
      final failures = <String>[];
      final uniquenessTime = Stopwatch();
      final ratingTime = Stopwatch();
      var uniqueCount = 0;
      var ratingCount = 0;
      var logicalCount = 0;
      var totalNodes = 0;
      var maxNodes = 0;
      var checked = 0;
      void check(bool ok, String message) {
        if (!ok) failures.add(message);
      }

      // Accumulate failures instead of stopping at the first bad board, so a
      // run always audits the entire bundle, including every large/jigsaw entry.
      for (var index = 0; index < entries.length; index++) {
        try {
          final ready = ReadyPuzzle.fromJson(
            entries[index] as Map<String, dynamic>,
          );
          final key =
              '${ready.size.name}/${ready.shape.name}/${ready.difficulty.name}';
          final label = 'entry $index ($key)';
          counts.update(key, (n) => n + 1, ifAbsent: () => 1);
          check(
            givensByKey
                .putIfAbsent(key, () => <String>{})
                .add(jsonEncode(ready.givens)),
            '$label duplicates a given board in its configuration',
          );
          final game = ready.createGame();
          check(
            isValidFullSolution(game.solution, game.regions, game.gridDim),
            '$label invalid stored solution',
          );
          check(game.grid.expand((r) => r).contains(0), '$label has no holes');
          check(
            game.notes.expand((r) => r).every((notes) => notes.isEmpty),
            '$label has initial notes',
          );
          uniquenessTime.start();
          final uniqueness = verifyUnique(ready.givens, ready.regions);
          uniquenessTime.stop();
          totalNodes += uniqueness.visitedNodes;
          if (uniqueness.visitedNodes > maxNodes) {
            maxNodes = uniqueness.visitedNodes;
          }
          check(
            uniqueness.isUnique,
            '$label uniqueness: ${uniqueness.solutionsFound} solutions, exhausted=${uniqueness.budgetExhausted}, nodes=${uniqueness.visitedNodes}',
          );
          if (uniqueness.isUnique) uniqueCount++;
          check(
            jsonEncode(uniqueness.firstSolution) == jsonEncode(ready.solution),
            '$label independent solution differs',
          );

          ratingTime.start();
          final result = TechniqueSolver(ready.givens, ready.regions).solve();
          ratingTime.stop();
          check(
            ready.rating != null && ready.rating == result.rating,
            '$label stored rating ${ready.rating} != recomputed ${result.rating} (${result.hardest})',
          );
          if (ready.rating != null && ready.rating == result.rating) {
            ratingCount++;
          }
          // A stuck logical solve legitimately rates expert/guess. It is not
          // evidence of non-uniqueness; the independent search above proves that.
          if (result.solved) {
            logicalCount++;
            check(
              jsonEncode(result.board) == jsonEncode(ready.solution),
              '$label logical solution differs',
            );
          } else {
            check(
              result.hardest == Technique.guess,
              '$label incomplete solve without guess rating',
            );
            for (var r = 0; r < game.gridDim; r++) {
              for (var c = 0; c < game.gridDim; c++) {
                check(
                  result.board[r][c] == 0 ||
                      result.board[r][c] == ready.solution[r][c],
                  '$label incorrect partial deduction at $r,$c',
                );
              }
            }
          }
          checked++;
        } catch (error) {
          uniquenessTime.stop();
          ratingTime.stop();
          failures.add('entry $index threw $error');
        }
      }
      final expectedKeys = {
        for (final size in GridSize.values)
          for (final shape in GridShape.values)
            for (final difficulty in SudokuDifficulty.values)
              '${size.name}/${shape.name}/${difficulty.name}',
      };
      // ignore: avoid_print
      print(
        'Bundled audit: $checked/${entries.length} checked; '
        '$uniqueCount unique; $ratingCount matching ratings; '
        '$logicalCount logically solved; ${entries.length - logicalCount} guess-rated. '
        'Uniqueness ${uniquenessTime.elapsedMilliseconds}ms, '
        'ratings ${ratingTime.elapsedMilliseconds}ms; '
        '$totalNodes search nodes total, $maxNodes maximum per puzzle.',
      );
      expect(entries, hasLength(232));
      expect(checked, 232);
      expect(counts.keys.toSet(), expectedKeys);
      expect(counts, hasLength(48));
      expect(counts.values, everyElement(greaterThanOrEqualTo(2)));
      expect(failures, isEmpty, reason: failures.join('\n'));
      expect(uniqueCount, 232);
      expect(ratingCount, 232);
    },
    timeout: const Timeout(Duration(minutes: 5)),
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
            expect(second!.givens, isNot(equals(first!.givens)));
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
