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

  testWidgets('Home lays out without overflow on a narrow phone', (
    tester,
  ) async {
    // The other home tests use the default wide 800×600 surface; pin a narrow
    // portrait phone (360×800) to guard the mode buttons against the RenderFlex
    // overflow long labels caused there (a thrown overflow fails the test).
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SudokuApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('CLASSIC MODE'), findsOneWidget);
    expect(find.textContaining('JIGSAW MODE'), findsOneWidget);
    expect(find.textContaining('DAILY CHALLENGE'), findsOneWidget);
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

  testWidgets('Stats sheet shows computed statistics', (tester) async {
    final savedSolved = GameStats.totalPuzzlesSolved;
    final savedLost = GameStats.gamesLost;
    final savedLongest = GameStats.longestStreak;
    final savedDaily = GameStats.dailyCompletedCount;
    addTearDown(() {
      GameStats.totalPuzzlesSolved = savedSolved;
      GameStats.gamesLost = savedLost;
      GameStats.longestStreak = savedLongest;
      GameStats.dailyCompletedCount = savedDaily;
    });
    GameStats.totalPuzzlesSolved = 8;
    GameStats.gamesLost = 2; // 8 / (8+2) = 80% win rate
    GameStats.longestStreak = 6;
    GameStats.dailyCompletedCount = 3;

    await tester.pumpWidget(const SudokuApp());
    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Win rate'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
    expect(find.text('Longest streak'), findsOneWidget);
    expect(find.text('6'), findsWidgets);
    expect(find.text('Daily puzzles done'), findsOneWidget);
  });

  testWidgets('Live game: play a cached 4×4 puzzle and place a number', (
    tester,
  ) async {
    final state = await _bootCachedGame(tester, seed: 1234);
    final g = state.game as SudokuGame;

    // The number pad for a 4×4 grid exposes buttons 1..4.
    expect(find.widgetWithText(ElevatedButton, '1'), findsWidgets);
    // The hint button shows the remaining budget (easy → 10).
    expect(
      find.text('Hint (${maxHintsFor(SudokuDifficulty.easy)})'),
      findsOneWidget,
    );

    // Tap the first empty cell, then its correct number.
    final cell = _firstEmpty(g);
    final er = cell[0], ec = cell[1];
    final answer = g.solution[er][ec];

    await tester.tapAt(_cellCenter(tester, er, ec, g.gridDim));
    await tester.pump(const Duration(milliseconds: 700)); // let pulse settle
    expect(state.selectedRow as int?, er, reason: 'cell tap should select row');
    expect(state.selectedCol as int?, ec, reason: 'cell tap should select col');

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

    await tester.pumpWidget(const SizedBox()); // dispose timers/animations
  });

  testWidgets('Drag a number from the pad onto a cell places it', (
    tester,
  ) async {
    final state = await _bootCachedGame(tester, seed: 1234);
    final g = state.game as SudokuGame;

    final cell = _firstEmpty(g);
    final er = cell[0], ec = cell[1];
    final answer = g.solution[er][ec];

    // The number pad exposes one Draggable<int> per number.
    final draggable = find.byWidgetPredicate(
      (w) => w is Draggable<int> && w.data == answer,
    );
    expect(draggable, findsOneWidget);

    // Drag from the pad tile to the target cell and release.
    final start = tester.getCenter(draggable);
    final target = _cellCenter(tester, er, ec, g.gridDim);
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveTo(target);
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump();

    expect(
      g.grid[er][ec],
      answer,
      reason: 'dropping a number on a cell should place it',
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Notes mode: tapping a number pencils a candidate, not a value', (
    tester,
  ) async {
    final state = await _bootCachedGame(tester, seed: 1234);
    final g = state.game as SudokuGame;

    final cell = _firstEmpty(g);
    final er = cell[0], ec = cell[1];

    // Enable notes mode, then select the empty cell.
    await tester.tap(find.byTooltip('Notes mode'));
    await tester.pump();
    await tester.tapAt(_cellCenter(tester, er, ec, g.gridDim));
    await tester.pump(const Duration(milliseconds: 700));

    // A number tap now adds a pencil mark instead of placing a value.
    await tester.tap(find.widgetWithText(ElevatedButton, '3').last);
    await tester.pump();

    expect(g.grid[er][ec], 0, reason: 'notes mode must not place a value');
    expect(
      g.notes[er][ec],
      contains(3),
      reason: 'number becomes a pencil mark',
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Completion: filling the last cell shows the win dialog', (
    tester,
  ) async {
    // Completing mutates global stats; snapshot and restore.
    final solved = GameStats.totalPuzzlesSolved;
    final streak = GameStats.currentStreak;
    final longest = GameStats.longestStreak;
    final best = GameStats.bestTime;
    final achievements = {...GameStats.unlockedAchievements};
    final themes = {...GameStats.unlockedThemes};
    addTearDown(() {
      GameStats.totalPuzzlesSolved = solved;
      GameStats.currentStreak = streak;
      GameStats.longestStreak = longest;
      GameStats.bestTime = best;
      GameStats.unlockedAchievements = achievements;
      GameStats.unlockedThemes = themes;
    });

    final state = await _bootCachedGame(tester, seed: 1234);
    final g = state.game as SudokuGame;

    // Fill every empty cell but the last with its solution value via the
    // engine, then place the final cell through the UI so the tap path
    // (_placeValue → isSolved → completion dialog) is exercised.
    final empties = <List<int>>[];
    for (var r = 0; r < g.gridDim; r++) {
      for (var c = 0; c < g.gridDim; c++) {
        if (!g.isOriginal[r][c] && g.grid[r][c] == 0) empties.add([r, c]);
      }
    }
    expect(empties.length, greaterThan(0));
    for (var i = 0; i < empties.length - 1; i++) {
      final cell = empties[i];
      g.setCell(cell[0], cell[1], g.solution[cell[0]][cell[1]]);
    }
    final last = empties.last;
    final answer = g.solution[last[0]][last[1]];

    await tester.tapAt(_cellCenter(tester, last[0], last[1], g.gridDim));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.widgetWithText(ElevatedButton, '$answer').last);
    await tester.pump(const Duration(milliseconds: 700)); // dialog transition

    expect(g.isSolved(), isTrue);
    expect(find.text('🎉 Completed!'), findsOneWidget);
    expect(
      GameStats.totalPuzzlesSolved,
      solved + 1,
      reason: 'a win increments the solved count',
    );
    expect(
      GameStats.longestStreak,
      greaterThanOrEqualTo(GameStats.currentStreak),
      reason: 'longest streak tracks the current streak',
    );

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Lose path: hitting the mistake limit ends the run and resets '
      'the streak; Try Again replays the board', (tester) async {
    // A non-zero streak that the loss must clear.
    GameStats.currentStreak = 3;
    final lostBefore = GameStats.gamesLost;
    addTearDown(() {
      GameStats.currentStreak = 0;
      GameStats.gamesLost = lostBefore;
    });

    final state = await _bootCachedGame(tester, seed: 4321);
    final g = state.game as SudokuGame;

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
    expect(
      GameStats.gamesLost,
      lostBefore + 1,
      reason: 'a loss increments the games-lost count',
    );
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

  testWidgets('Hint limit: exhausting the budget disables the hint button', (
    tester,
  ) async {
    // _applyHint bumps the global hint counter; snapshot and restore.
    final hintsBefore = GameStats.totalHintsUsed;
    addTearDown(() => GameStats.totalHintsUsed = hintsBefore);

    // Expert has the tightest budget (1 hint), so a single use exhausts it.
    final state = await _bootCachedGame(
      tester,
      difficulty: SudokuDifficulty.expert,
      seed: 2468,
    );
    final g = state.game as SudokuGame;

    final maxHints = maxHintsFor(SudokuDifficulty.expert);
    expect(maxHints, 1);
    expect(find.text('Hint ($maxHints)'), findsOneWidget);

    // Select an empty cell and open the Smart Hints dialog.
    final cell = _firstEmpty(g);
    await tester.tapAt(_cellCenter(tester, cell[0], cell[1], g.gridDim));
    await tester.pump(const Duration(milliseconds: 700));
    // The hint button is an ElevatedButton.icon (a private subtype), so tap its
    // label text rather than matching the button by exact type.
    await tester.tap(find.text('Hint ($maxHints)'));
    await tester.pump(const Duration(milliseconds: 300));

    // Pick a (penalty-bearing) hint, then confirm it.
    await tester.tap(find.byType(ListTile).last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Confirm'));
    await tester.pump(const Duration(milliseconds: 300));

    // The budget is spent: the button flips to a disabled "No Hints".
    expect(state.hintsUsed as int, 1);
    expect(find.text('No Hints'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('No Hints'),
        matching: find.bySubtype<ElevatedButton>(),
      ),
    );
    expect(button.enabled, isFalse, reason: 'no hints left → disabled');

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Daily challenge launches a deterministic daily game', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400); // 360×800 logical phone
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Force "not done today" so the button label is stable.
    final savedDaily = GameStats.lastDailyDate;
    GameStats.lastDailyDate = null;
    addTearDown(() => GameStats.lastDailyDate = savedDaily);

    await tester.pumpWidget(const SudokuApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('DAILY CHALLENGE'), findsOneWidget);
    await tester.tap(find.textContaining('DAILY CHALLENGE'));

    // Navigation + deterministic generation. The game timer is periodic, so we
    // can't pumpAndSettle; pump in bounded steps until the board is built.
    dynamic state;
    for (var i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      final finder = find.byType(GameScreen);
      if (finder.evaluate().isNotEmpty) {
        state = tester.state(finder);
        if (state.game != null) break;
      }
    }
    expect(state, isNotNull, reason: 'daily GameScreen should mount');

    final screen = state.widget as GameScreen;
    expect(screen.isDaily, isTrue);
    expect(screen.dailySeed, dailySeed(DateTime.now()));
    expect(screen.gridSize, kDailyGridSize);
    expect(
      state.game,
      isNotNull,
      reason: 'daily board generated deterministically (no cache/isolate)',
    );

    await tester.pumpWidget(const SizedBox());
  });
}

/// Seeds the puzzle cache with a deterministic [size] solution, mounts a
/// [GameScreen], and pumps until its game has initialized from the cache (so
/// no background isolate is needed). Returns the GameScreen State.
Future<dynamic> _bootCachedGame(
  WidgetTester tester, {
  GridSize size = GridSize.small,
  SudokuDifficulty difficulty = SudokuDifficulty.easy,
  required int seed,
}) async {
  // Realistic portrait phone surface (the default 800×600 landscape crams the
  // board + number pad).
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final seedGame = SudokuGame.generate(
    difficulty,
    size,
    GridShape.classic,
    seed: seed,
  );
  // set() populates the in-memory cache before its disk write, so we don't
  // await it (avoids blocking on path_provider, unavailable in the test host).
  // ignore: unawaited_futures
  PuzzleCache().set(
    PuzzleBlueprint(
      solutionGrid: seedGame.solution,
      regions: seedGame.regions,
      gridSize: size,
      gridShape: GridShape.classic,
    ),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: GameScreen(
        difficulty: difficulty,
        gridSize: size,
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
  return state;
}

/// First empty (player-editable) cell as `[row, col]`.
List<int> _firstEmpty(SudokuGame g) {
  for (var r = 0; r < g.gridDim; r++) {
    for (var c = 0; c < g.gridDim; c++) {
      if (g.grid[r][c] == 0) return [r, c];
    }
  }
  throw StateError('no empty cell');
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
