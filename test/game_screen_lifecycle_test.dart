import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku/l10n/app_localizations.dart';
import 'package:sudoku/main.dart';
import 'package:sudoku/sudoku_game.dart';

void main() {
  testWidgets('leaving the screen during generation is safe', (tester) async {
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
        ),
      ),
    );

    // Generation is still pending (the post-frame callback just ran). Unmount
    // the screen before the board is built; the pending work must complete
    // without touching the disposed state — no timer, no notifier update.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
