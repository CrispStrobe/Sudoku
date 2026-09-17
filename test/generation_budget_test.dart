import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/variant_engine.dart';
import 'package:sudoku/sudoku_game.dart';

import 'sudoku_game_test.dart' show countSolutions, isValidFullSolution;

void main() {
  test('complete blueprint matches generation without hole digging', () {
    final messages = <String>[];
    final blueprint = runZoned(
      () => SudokuGame.generateBlueprint(
        GridSize.standard,
        GridShape.classic,
        seed: 20260530,
      ),
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, message) => messages.add(message),
      ),
    );
    expect(messages.where((message) => message.contains('Dug ')), isEmpty);
    final game = SudokuGame.generate(
      SudokuDifficulty.medium,
      GridSize.standard,
      GridShape.classic,
      seed: 20260530,
    );
    expect(blueprint.solutionGrid, game.solution);
    expect(blueprint.regions, game.regions);
    expect(blueprint.gridSize, GridSize.standard);
    expect(blueprint.gridShape, GridShape.classic);
    expect(game.grid.expand((row) => row), contains(0));
  });

  test('Killer generates cages without discarded classic hole digging', () async {
    final messages = <String>[];
    final puzzle = await runZoned(
      () => VariantEngine.generateKiller(
        gridSize: GridSize.small,
        difficulty: SudokuDifficulty.expert,
        seed: 42,
      ),
      zoneSpecification: ZoneSpecification(
        print: (_, _, _, message) => messages.add(message),
      ),
    );
    expect(messages.where((message) => message.contains('Dug ')), isEmpty);
    expect(cagesSatisfied(puzzle.cages, puzzle.solution), isTrue);
    expect(await VariantEngine.killerHasUniqueSolution(
      gridDim: puzzle.gridDim,
      regions: puzzle.regions,
      cages: puzzle.cages,
      givens: puzzle.givens,
    ), isTrue);
  });

  test('the recursive step allowance is shared across removal attempts', () {
    for (final steps in [2, 3, 4]) {
      final game = SudokuGame.generate(
        SudokuDifficulty.expert,
        GridSize.small,
        GridShape.classic,
        seed: 42,
        uniquenessBudget: GenerationBudget(maxSteps: steps),
      );
      // First hole costs two visits; the second requires three more. Its
      // interrupted search must restore every assignment, not only the clue.
      expect(game.grid.expand((row) => row).where((v) => v == 0), hasLength(1));
      expect(countSolutions(game.grid, game.regions, 4), 1);
    }
  });

  test('zero time or steps retains a full, initialized game', () {
    final blueprint = SudokuGame.generateBlueprint(
      GridSize.mega,
      GridShape.classic,
      seed: 42,
    );
    for (final budget in [
      const GenerationBudget(maxSteps: 0),
      const GenerationBudget(timeLimit: Duration.zero),
    ]) {
      final game = SudokuGame.fromBlueprint(
        blueprint,
        SudokuDifficulty.expert,
        uniquenessBudget: budget,
      );
      expect(game.grid, blueprint.solutionGrid);
      expect(game.isSolved(), isTrue);
      expect(game.isOriginal.expand((row) => row), everyElement(isTrue));
      expect(game.notes.expand((row) => row), everyElement(isEmpty));
      game.grid[0][0] = 0;
      expect(blueprint.solutionGrid[0][0], isNot(0));
      expect(game.solution[0][0], isNot(0));
    }
  });

  test('partial searches never certify an ambiguous board as unique', () {
    // Sweep budgets that cut off at different depths, including after the
    // first completion of a multi-solution branch. Cross-check independently.
    for (var steps = 0; steps <= 250; steps++) {
      final game = SudokuGame.generate(
        SudokuDifficulty.expert,
        GridSize.small,
        GridShape.classic,
        seed: 7,
        uniquenessBudget: GenerationBudget(maxSteps: steps),
      );
      expect(countSolutions(game.grid, game.regions, 4), 1,
          reason: 'step budget $steps');
      expect(isValidFullSolution(game.solution, game.regions, 4), isTrue);
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          expect(game.grid[r][c], anyOf(0, game.solution[r][c]));
          expect(game.isOriginal[r][c], game.grid[r][c] != 0);
        }
      }
    }
  });

  test('an exhausted recursive search restores the tentative clue', () {
    final game = SudokuGame.generate(
      SudokuDifficulty.expert,
      GridSize.small,
      GridShape.classic,
      seed: 42,
      uniquenessBudget: const GenerationBudget(maxSteps: 1),
    );

    // The first search enters its root and places a value, but cannot visit
    // the completed child. An unproven removal must be rolled back.
    expect(game.grid, game.solution);
    expect(game.isOriginal.expand((row) => row), everyElement(isTrue));
    expect(game.notes.expand((row) => row), everyElement(isEmpty));
    expect(game.isSolved(), isTrue);
  });
}
