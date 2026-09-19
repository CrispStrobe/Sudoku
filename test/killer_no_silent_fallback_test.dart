import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku/main.dart';
import 'package:sudoku/l10n/app_localizations.dart';
import 'package:sudoku/painters.dart';
import 'package:sudoku/sudoku_game.dart';

/// A Killer board must never silently degrade into a classic one.
///
/// When Killer generation threw, the screen used to fall back to a plain
/// classic puzzle while `widget.isKiller` stayed true — so the player got a
/// cage-less board with the hint and explain buttons disabled, looking like a
/// working game and playing like the wrong one. That is exactly how a dart2js
/// crash inside the CSP solver (`Uint64List` is unallocatable there, so every
/// web Killer generation failed) stayed invisible through a whole release.
///
/// The invariant: a screen that says Killer either has cages, or reports the
/// failure. Never a third thing.
void main() {
  testWidgets('a Killer board that renders has cages to render', (
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
          variant: SudokuVariant.killer,
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
    // a real Killer board: cages, and a cage painter mounted to draw them.
    if (state.game == null) return;

    final painters = find
        .byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is KillerCagePainter,
        )
        .evaluate();
    expect(
      painters,
      isNotEmpty,
      reason: 'a Killer screen rendered without a cage painter',
    );
    for (final element in painters) {
      final painter =
          (element.widget as CustomPaint).painter as KillerCagePainter;
      expect(
        painter.cages,
        isNotEmpty,
        reason:
            'the Killer screen rendered a board with zero cages — generation '
            'failed and fell back to a classic puzzle wearing the Killer label',
      );
    }

    await tester.pumpWidget(const SizedBox());
  });
}
