import 'dart:math' as math;

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

  /// The board's edge, in logical pixels, as actually laid out.
  double boardEdge(WidgetTester tester) {
    return tester
        .renderObject<RenderBox>(
          find
              .byWidgetPredicate(
                (w) => w is CustomPaint && w.painter is SudokuGridPainter,
              )
              .first,
        )
        .size
        .width;
  }

  /// A small/old iPhone is the worst case and the one that regressed: the
  /// chrome (outer padding, three inter-block gaps, a five-button control row
  /// whose hint label wrapped one character per line, and a number pad claiming
  /// 42% of the body) squeezed the board down to roughly half the screen width
  /// while empty gradient sat around it. The board is the screen; pin the floor
  /// so it cannot be given away again.
  ///
  /// The fractions are deliberately below what the current layout achieves —
  /// they are a regression floor, not a spec of the exact size.
  for (final (label, size, minFraction) in <(String, Size, double)>[
    ('iPhone SE / 5s (320x568)', const Size(320, 568), 0.8),
    ('iPhone 6/7/8/SE2 (375x667)', const Size(375, 667), 0.85),
    ('iPhone 14 (390x844)', const Size(390, 844), 0.9),
  ]) {
    testWidgets('$label gives the board most of the width', (tester) async {
      final game = await pumpGame(tester, size);
      expect(tester.takeException(), isNull);

      final edge = boardEdge(tester);
      expect(
        edge,
        greaterThanOrEqualTo(size.width * minFraction),
        reason:
            'board is ${edge.toStringAsFixed(1)}pt on a ${size.width.toInt()}pt '
            'screen — the chrome is eating the board again',
      );
      // And it must still fit: never wider than the screen, never taller than
      // the space above the pad.
      expect(edge, lessThanOrEqualTo(size.width));

      expectDigitsScaleToCells(tester, game);
      expectPadTilesUsable(tester);
      await tester.pumpWidget(const SizedBox());
    });
  }

  /// Landscape is the shape where stacking everything vertically is worst:
  /// the board competes with the chrome for the scarce axis while the
  /// plentiful one sits empty on both sides. On a 568x320 phone that left the
  /// board about 90pt. The chrome belongs beside the board there.
  for (final (label, size) in <(String, Size)>[
    ('phone landscape (568x320)', const Size(568, 320)),
    ('larger phone landscape (667x375)', const Size(667, 375)),
  ]) {
    testWidgets('$label puts the board on the tall axis', (tester) async {
      final game = await pumpGame(tester, size);
      expect(tester.takeException(), isNull);

      final edge = boardEdge(tester);
      // The board should be limited by the window's height, not squeezed into
      // a fraction of it by chrome stacked above and below.
      expect(
        edge,
        greaterThanOrEqualTo(size.height * 0.6),
        reason:
            'board is ${edge.toStringAsFixed(1)}pt in a ${size.height.toInt()}pt'
            '-tall landscape window — the chrome is still stacked vertically',
      );
      expect(edge, lessThanOrEqualTo(size.height));

      expectDigitsScaleToCells(tester, game);
      expectPadTilesUsable(tester);
      await tester.pumpWidget(const SizedBox());
    });
  }

  /// Real device sizes, including the ones that are nobody's idea of a phone.
  ///
  /// A folded Galaxy Fold in landscape is 653x280, and `isTablet` used to be
  /// `size.width > 600` — width alone — so it was classified a tablet and
  /// handed 24pt padding, 12pt gaps and 52pt controls to spend inside 224
  /// points of height. The number pad got what was left: about five points,
  /// with no digits in it, on a screen the game otherwise rendered perfectly.
  /// A device's class is its *narrow* dimension, and that does not change when
  /// you turn it sideways.
  for (final (label, size) in <(String, Size)>[
    ('Galaxy Fold folded (280x653)', const Size(280, 653)),
    ('Galaxy Fold folded, landscape (653x280)', const Size(653, 280)),
    ('Galaxy S8 (360x740)', const Size(360, 740)),
    ('Surface Duo (540x720)', const Size(540, 720)),
    ('iPhone 15 Pro Max (430x932)', const Size(430, 932)),
    ('iPad mini (744x1133)', const Size(744, 1133)),
    ('iPad Pro 11 landscape (1194x834)', const Size(1194, 834)),
    ('desktop (1920x1080)', const Size(1920, 1080)),
  ]) {
    testWidgets('$label lays out a playable board and pad', (tester) async {
      final game = await pumpGame(tester, size);
      expect(tester.takeException(), isNull);

      final edge = boardEdge(tester);
      expect(
        edge,
        greaterThanOrEqualTo(math.min(size.width, size.height) * 0.5),
        reason:
            'board is ${edge.toStringAsFixed(1)}pt on a '
            '${size.width.toInt()}x${size.height.toInt()} screen',
      );
      expectDigitsScaleToCells(tester, game);
      expectPadTilesUsable(tester);

      // Every pad digit must actually be on screen. A pad squeezed to a
      // sliver still "renders" — its tiles are just too short to show a digit,
      // which is what made the folded-Fold landscape case unplayable while
      // throwing no exception and failing no other assertion.
      for (var n = 1; n <= game.gridDim; n++) {
        final tile = find.descendant(
          of: find.byType(GridView),
          matching: find.text('$n'),
        );
        expect(tile, findsOneWidget, reason: 'pad is missing the $n tile');
        final box = tester.renderObject<RenderBox>(tile);
        expect(
          box.size.height,
          greaterThan(0),
          reason: 'pad digit $n collapsed to zero height',
        );
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  /// The hint button's label used to wrap one character per line when the
  /// control row ran out of width, turning a 48pt button into a 100pt one and
  /// taking the difference out of the board.
  testWidgets('control row stays one row tall on a 320pt screen', (
    tester,
  ) async {
    await pumpGame(tester, const Size(320, 568));
    expect(tester.takeException(), isNull);

    final hint = tester.renderObject<RenderBox>(
      find.ancestor(
        of: find.byIcon(Icons.lightbulb),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(
      hint.size.height,
      lessThanOrEqualTo(56.0),
      reason:
          'hint button is ${hint.size.height.toStringAsFixed(1)}pt tall — its '
          'label is wrapping instead of scaling down',
    );

    // Every control must remain a usable tap target.
    for (final icon in [
      Icons.lightbulb,
      Icons.edit,
      Icons.undo,
      Icons.clear,
      Icons.school,
    ]) {
      final box = tester.renderObject<RenderBox>(
        find.ancestor(
          of: find.byIcon(icon),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(
        box.size.shortestSide,
        greaterThanOrEqualTo(40.0),
        reason: '$icon control collapsed to ${box.size.shortestSide}pt',
      );
    }
    await tester.pumpWidget(const SizedBox());
  });
}
