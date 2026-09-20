import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku/l10n/app_localizations.dart';
import 'package:sudoku/main.dart';
import 'package:sudoku/painters.dart';
import 'package:sudoku/sudoku_game.dart';

/// A KenKen board must never silently degrade into a classic one.
///
/// The same invariant as `killer_no_silent_fallback_test.dart` and
/// `thermo_no_silent_fallback_test.dart`, and it exists for the same reason:
/// when Killer generation threw, the screen used to fall back to a plain
/// classic puzzle while still calling itself Killer, so the player got a board
/// with no cages and mysteriously disabled buttons. That is how a dart2js crash
/// stayed invisible through an entire release.
///
/// KenKen's failure shape is the worst of the three, because a KenKen board
/// with no cages is not merely a classic board wearing the label — it has no
/// clues of any kind and 89 of the 96 bundled boards have no givens either, so
/// the fallback would be an empty grid.
void main() {
  testWidgets('a KenKen board that renders has cages to render', (
    tester,
  ) async {
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
          gridSize: GridSize.small,
          gridShape: GridShape.classic,
          gameMode: GameMode.classic,
          variant: SudokuVariant.kenken,
        ),
      ),
    );

    dynamic state;
    for (var i = 0; i < 400; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      state = tester.state(find.byType(GameScreen));
      if (state.game != null) break;
    }
    expect(tester.takeException(), isNull);

    // Generation either produced a board or it did not. If it did, it must be
    // a real KenKen board: cages, and a painter mounted to draw them.
    if (state.game == null) return;

    final painters = find
        .byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is KenKenCagePainter,
        )
        .evaluate();
    expect(
      painters,
      isNotEmpty,
      reason: 'a KenKen screen rendered without a cage painter',
    );
    for (final element in painters) {
      final painter =
          (element.widget as CustomPaint).painter as KenKenCagePainter;
      expect(
        painter.cages,
        isNotEmpty,
        reason:
            'the KenKen screen rendered a board with zero cages — generation '
            'failed and fell back to a classic puzzle wearing the KenKen label',
      );
    }

    await tester.pumpWidget(const SizedBox());
  });
}
