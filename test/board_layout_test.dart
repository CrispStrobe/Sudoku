import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku/main.dart';
import 'package:sudoku/painters.dart';
import 'package:sudoku/l10n/app_localizations.dart';
import 'package:sudoku/services.dart';
import 'package:sudoku/sudoku_game.dart';

/// Board and number-pad layout across viewport shapes.
///
/// Both the cell digits and the pad tiles used to be sized from values that had
/// nothing to do with the box they were drawn in — the cell font from a
/// width-only `isTablet` flag, the pad from a fixed flex share — so on a short
/// or wide viewport digits overflowed their cells and pad tiles collapsed.
/// These pin the invariant: every digit fits inside the thing that contains it.
void main() {
  Future<SudokuGame> pumpGame(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Seed the cache so the screen initializes from it rather than waiting on
    // a generator run (same approach as widget_test.dart's _bootCachedGame).
    final seeded = SudokuGame.generate(
      SudokuDifficulty.easy,
      GridSize.standard,
      GridShape.classic,
      seed: 7,
    );
    // ignore: unawaited_futures
    PuzzleCache().set(
      PuzzleBlueprint(
        solutionGrid: seeded.solution,
        regions: seeded.regions,
        gridSize: GridSize.standard,
        gridShape: GridShape.classic,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: GameScreen(
          difficulty: SudokuDifficulty.easy,
          gridSize: GridSize.standard,
          gridShape: GridShape.classic,
          gameMode: GameMode.classic,
        ),
      ),
    );

    dynamic state;
    SudokuGame? game;
    for (var i = 0; i < 200 && game == null; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      state = tester.state(find.byType(GameScreen));
      game = state.game as SudokuGame?;
    }
    expect(game, isNotNull, reason: 'board should generate');
    return game!;
  }

  /// The board's digits must be sized *from the cell they sit in*.
  ///
  /// Asserting on rendered height alone is not enough: the test font's metrics
  /// are near-square, so a 28pt glyph in a 29px cell measures as fitting here
  /// while clipping badly under SF Pro/Roboto on a device. What actually
  /// regressed was the derivation — a constant font size with no relation to
  /// the cell — so that is what this pins.
  void expectDigitsScaleToCells(WidgetTester tester, SudokuGame game) {
    // The board is square and painted at its full extent, so the grid painter's
    // box gives the exact cell size the cells were laid out with.
    final gridBox = tester.renderObject<RenderBox>(
      find
          .byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is SudokuGridPainter,
          )
          .first,
    );
    final cellSize = gridBox.size.width / game.gridDim;
    expect(cellSize, greaterThan(0));

    final gridRect = gridBox.localToGlobal(Offset.zero) & gridBox.size;

    var checked = 0;
    for (final element
        in find
            .byWidgetPredicate(
              (w) => w is Text && RegExp(r'^\d+$').hasMatch(w.data ?? ''),
            )
            .evaluate()) {
      final box = element.renderObject as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final centre = box.localToGlobal(box.size.center(Offset.zero));
      if (!gridRect.contains(centre)) continue; // number-pad digit, not a cell

      final fontSize = (element.widget as Text).style?.fontSize;
      expect(fontSize, isNotNull);
      // 0.75 leaves room for line height on top of the glyph itself; the
      // implementation targets 0.62.
      expect(
        fontSize!,
        lessThanOrEqualTo(cellSize * 0.75),
        reason:
            'cell digit is ${fontSize}pt in a ${cellSize.toStringAsFixed(1)}px '
            'cell — the font is not derived from the cell size',
      );
      checked++;
    }
    expect(checked, greaterThan(0), reason: 'no cell digits were inspected');
  }

  /// Number-pad tiles must stay tappable, and their digits must fit them.
  void expectPadTilesUsable(WidgetTester tester) {
    final buttons = find.descendant(
      of: find.byType(GridView),
      matching: find.byType(ElevatedButton),
    );
    expect(buttons, findsWidgets, reason: 'the pad should render tiles');

    for (final element in buttons.evaluate()) {
      final box = element.renderObject as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final tile = box.size.shortestSide;
      expect(
        tile,
        greaterThanOrEqualTo(28.0),
        reason: 'pad tile collapsed to ${tile.toStringAsFixed(1)}px',
      );
    }
  }

  testWidgets('wide, short viewport: digits fit their cells', (tester) async {
    final game = await pumpGame(tester, const Size(1000, 588));
    expect(tester.takeException(), isNull);
    expectDigitsScaleToCells(tester, game);
    expectPadTilesUsable(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('near-square viewport: digits fit their cells', (tester) async {
    final game = await pumpGame(tester, const Size(671, 588));
    expect(tester.takeException(), isNull);
    expectDigitsScaleToCells(tester, game);
    expectPadTilesUsable(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tall phone viewport: digits fit their cells', (tester) async {
    final game = await pumpGame(tester, const Size(390, 844));
    expect(tester.takeException(), isNull);
    expectDigitsScaleToCells(tester, game);
    expectPadTilesUsable(tester);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('short viewport still lays out without overflow', (tester) async {
    final game = await pumpGame(tester, const Size(900, 440));
    expect(tester.takeException(), isNull);
    expectDigitsScaleToCells(tester, game);
    expectPadTilesUsable(tester);
    await tester.pumpWidget(const SizedBox());
  });
}
