import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku/explain_screen.dart';
import 'package:sudoku/game_stats.dart';
import 'package:sudoku/l10n/app_localizations.dart';
import 'package:sudoku/sudoku_game.dart';

/// The explain-the-solve board has to be visible while it is being explained.
///
/// It lived inside a vertical `SingleChildScrollView` as an `AspectRatio(1)`,
/// which meant it only ever knew its *width*: the scroll view offers unbounded
/// height, so the square took the full width in both axes. On a 653x280
/// landscape phone that produced a 420pt board inside a 190pt viewport — two of
/// nine rows on screen, with the caption explaining the deduction pushed off
/// the bottom entirely. A walkthrough you have to scroll to follow is not one.
void main() {
  Future<void> pumpExplain(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final game = SudokuGame.generate(
      SudokuDifficulty.easy,
      GridSize.standard,
      GridShape.classic,
      seed: 3,
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ExplainScreen(
          grid: game.grid,
          regions: game.regions,
          gridDim: game.gridDim,
          jigsaw: false,
          diagonal: false,
          scheme: GameStats.current,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(seconds: 1));
  }

  /// The rendered board's edge.
  double boardEdge(WidgetTester tester) {
    // The grid is the only square GridView-free box built from Columns of
    // Rows; find it by its own widget type via the first Table-like Column.
    final gridFinder = find.byKey(const ValueKey('explain-grid'));
    if (gridFinder.evaluate().isNotEmpty) {
      return tester.renderObject<RenderBox>(gridFinder).size.width;
    }
    // Fall back to the SizedBox.square that wraps it.
    final boxes = find
        .byWidgetPredicate(
          (w) => w is SizedBox && w.width != null && w.width == w.height,
        )
        .evaluate();
    expect(boxes, isNotEmpty, reason: 'no square board box found');
    return boxes
        .map((e) => (e.renderObject as RenderBox).size.width)
        .reduce(math.max);
  }

  for (final (label, size) in <(String, Size)>[
    ('phone portrait (320x568)', const Size(320, 568)),
    ('phone landscape (568x320)', const Size(568, 320)),
    ('folded Fold landscape (653x280)', const Size(653, 280)),
    ('tablet (834x1194)', const Size(834, 1194)),
  ]) {
    testWidgets('$label fits the explain board on screen', (tester) async {
      await pumpExplain(tester, size);
      expect(tester.takeException(), isNull);

      final edge = boardEdge(tester);
      expect(edge, greaterThan(0), reason: 'board did not render');
      // The board must fit the window in BOTH axes — that is the whole defect.
      expect(
        edge,
        lessThanOrEqualTo(size.width),
        reason:
            'explain board is ${edge.toStringAsFixed(1)}pt wide in a '
            '${size.width.toInt()}pt window',
      );
      expect(
        edge,
        lessThanOrEqualTo(size.height),
        reason:
            'explain board is ${edge.toStringAsFixed(1)}pt tall in a '
            '${size.height.toInt()}pt window — it is sized from width alone',
      );
      // And it must still be big enough to read.
      expect(
        edge,
        greaterThanOrEqualTo(math.min(size.width, size.height) * 0.4),
        reason: 'explain board shrank to ${edge.toStringAsFixed(1)}pt',
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
}
