import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku/main.dart';
import 'package:sudoku/sudoku_game.dart';

void main() {
  testWidgets('Home screen renders title and game modes', (tester) async {
    await tester.pumpWidget(const SudokuApp());

    expect(find.text('SUDOKU\nMASTER'), findsOneWidget);
    expect(find.text('🎯 CLASSIC MODE'), findsOneWidget);
    expect(find.text('🧩 JIGSAW MODE'), findsOneWidget);
    expect(find.text('Themes'), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
  });

  testWidgets('Classic flow opens size and difficulty selection', (
    tester,
  ) async {
    await tester.pumpWidget(const SudokuApp());

    await tester.tap(find.text('🎯 CLASSIC MODE'));
    await tester.pumpAndSettle();
    expect(find.text('Classic Sudoku'), findsOneWidget);
    expect(find.text('4×4'), findsOneWidget);
    expect(find.text('9×9'), findsOneWidget);

    await tester.tap(find.text('4×4'));
    await tester.pumpAndSettle();
    expect(find.text('Select Difficulty'), findsOneWidget);
    expect(find.text('EASY'), findsOneWidget);
    expect(find.text('EXPERT'), findsOneWidget);
  });

  testWidgets('Themes sheet opens and lists themes', (tester) async {
    await tester.pumpWidget(const SudokuApp());
    await tester.tap(find.text('Themes'));
    await tester.pumpAndSettle();
    expect(find.text('Environmental Themes'), findsOneWidget);
    expect(find.text('Ocean'), findsWidgets);
  });

  testWidgets('Live game: play a cached 4×4 puzzle and place a number', (
    tester,
  ) async {
    // Use a realistic portrait phone surface (default test surface is a short
    // 800×600 landscape that crams the board + number pad).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Seed the puzzle cache with a deterministic 4×4 solution so the game
    // builds synchronously (via fromBlueprint) — no background isolate.
    // set() populates the in-memory cache before its disk write, so we don't
    // await it (avoids blocking on path_provider, which is unavailable in the
    // test host).
    final seedGame = SudokuGame.generate(
      SudokuDifficulty.easy,
      GridSize.small,
      GridShape.classic,
      seed: 1234,
    );
    // ignore: unawaited_futures
    PuzzleCache().set(
      PuzzleBlueprint(
        solutionGrid: seedGame.solution,
        regions: seedGame.regions,
        gridSize: GridSize.small,
        gridShape: GridShape.classic,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          difficulty: SudokuDifficulty.easy,
          gridSize: GridSize.small,
          gridShape: GridShape.classic,
          gameMode: GameMode.classic,
        ),
      ),
    );

    // Pump until the post-frame initialization has built the game (bounded so a
    // regression can never hang the suite).
    dynamic state;
    SudokuGame? game;
    for (var i = 0; i < 40 && game == null; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      state = tester.state(find.byType(GameScreen));
      game = state.game as SudokuGame?;
    }
    expect(game, isNotNull, reason: 'game should initialize from cache');
    final g = game!;

    // The number pad for a 4×4 grid exposes buttons 1..4.
    expect(find.widgetWithText(ElevatedButton, '1'), findsWidgets);
    expect(find.text('Hint'), findsOneWidget);

    // Tap the first empty cell, then a candidate number for it.
    int er = -1, ec = -1;
    outer:
    for (var r = 0; r < g.gridDim; r++) {
      for (var c = 0; c < g.gridDim; c++) {
        if (g.grid[r][c] == 0) {
          er = r;
          ec = c;
          break outer;
        }
      }
    }
    expect(er, isNot(-1));
    final answer = g.solution[er][ec];

    // Tap the empty cell (GestureDetector inside the grid Stack).
    await tester.tapAt(_cellCenter(tester, er, ec, g.gridDim));
    await tester.pump(const Duration(milliseconds: 700)); // let pulse settle
    expect(state.selectedRow as int?, er, reason: 'cell tap should select row');
    expect(state.selectedCol as int?, ec, reason: 'cell tap should select col');

    // Tap the number-pad button for the correct answer.
    await tester.tap(find.widgetWithText(ElevatedButton, '$answer').last);
    await tester.pump();

    expect(
      g.grid[er][ec],
      answer,
      reason: 'placing the solution value should stick',
    );

    // Undo via the toolbar button should clear the cell again.
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(g.grid[er][ec], 0, reason: 'undo should revert the placement');

    // Dispose to cancel timers/animations cleanly.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Lose path: hitting the mistake limit ends the run and resets '
      'the streak; Try Again replays the board', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final seedGame = SudokuGame.generate(
      SudokuDifficulty.easy,
      GridSize.small,
      GridShape.classic,
      seed: 4321,
    );
    // ignore: unawaited_futures
    PuzzleCache().set(
      PuzzleBlueprint(
        solutionGrid: seedGame.solution,
        regions: seedGame.regions,
        gridSize: GridSize.small,
        gridShape: GridShape.classic,
      ),
    );

    // A non-zero streak that the loss must clear.
    GameStats.currentStreak = 3;
    addTearDown(() => GameStats.currentStreak = 0);

    await tester.pumpWidget(
      const MaterialApp(
        home: GameScreen(
          difficulty: SudokuDifficulty.easy,
          gridSize: GridSize.small,
          gridShape: GridShape.classic,
          gameMode: GameMode.classic,
        ),
      ),
    );

    dynamic state;
    SudokuGame? game;
    for (var i = 0; i < 40 && game == null; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      state = tester.state(find.byType(GameScreen));
      game = state.game as SudokuGame?;
    }
    expect(game, isNotNull);
    final g = game!;

    // The mistake budget is shown as "0/<max>" for easy (max = 5).
    final maxMistakes = maxMistakesFor(SudokuDifficulty.easy);
    expect(find.text('0/$maxMistakes'), findsOneWidget);

    // Find an empty cell and a value that already appears elsewhere in its row,
    // so placing it there is always a conflict (a counted mistake).
    int er = -1, ec = -1, conflictValue = -1;
    outer:
    for (var r = 0; r < g.gridDim; r++) {
      for (var c = 0; c < g.gridDim; c++) {
        if (g.grid[r][c] != 0) continue;
        for (var cc = 0; cc < g.gridDim; cc++) {
          if (cc != c && g.grid[r][cc] != 0) {
            er = r;
            ec = c;
            conflictValue = g.grid[r][cc];
            break outer;
          }
        }
      }
    }
    expect(conflictValue, isNot(-1), reason: 'need a conflicting value');

    await tester.tapAt(_cellCenter(tester, er, ec, g.gridDim));
    await tester.pump(const Duration(milliseconds: 700));

    // Each tap of the conflicting value is one mistake. The last one loses.
    for (var i = 0; i < maxMistakes; i++) {
      await tester.tap(
        find.widgetWithText(ElevatedButton, '$conflictValue').last,
      );
      await tester.pump(const Duration(milliseconds: 450)); // let shake settle
    }

    // Game Over dialog is up and the streak has been broken.
    expect(find.text('💥 Game Over'), findsOneWidget);
    expect(GameStats.currentStreak, 0, reason: 'streak resets on loss');
    expect(state.mistakes as int, maxMistakes);

    // Try Again replays the same board: dialog gone, mistakes back to 0,
    // and the previously-filled cell is empty again.
    await tester.tap(find.widgetWithText(ElevatedButton, 'Try Again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('💥 Game Over'), findsNothing);
    expect(state.mistakes as int, 0);
    expect(g.grid[er][ec], 0, reason: 'reset clears player entries');

    await tester.pumpWidget(const SizedBox());
  });
}

/// On-screen centre of cell (row,col) within the rendered Sudoku grid.
Offset _cellCenter(WidgetTester tester, int row, int col, int dim) {
  final finder = find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is SudokuGridPainter,
  );
  final box = tester.renderObject<RenderBox>(finder);
  final topLeft = box.localToGlobal(Offset.zero);
  final cell = box.size.width / dim;
  return topLeft + Offset((col + 0.5) * cell, (row + 0.5) * cell);
}
