import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku/main.dart';
import 'package:sudoku/services.dart';
import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/l10n/app_localizations.dart';

/// The end-of-game dialogs, on the screens they were never tried on.
///
/// The win and game-over dialogs are `AlertDialog`s with a `Column` of result
/// lines. A dialog is the last thing a player sees in a run, and it is also
/// the classic place for a layout to fail quietly: `AlertDialog` gives its
/// content a bounded box, so a long line at a large text scale, or a title plus
/// two action buttons on a 280pt screen, has somewhere to overflow. Both were
/// untested at any size but 320x568 at 1.0x.
void main() {
  Future<dynamic> pumpGame(
    WidgetTester tester,
    Size size, {
    double textScale = 1.0,
    Locale? locale,
    GridSize gridSize = GridSize.standard,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final seeded = SudokuGame.generate(
      SudokuDifficulty.easy,
      gridSize,
      GridShape.classic,
      seed: 21,
    );
    // ignore: unawaited_futures
    PuzzleCache().set(
      PuzzleBlueprint(
        solutionGrid: seeded.solution,
        regions: seeded.regions,
        gridSize: gridSize,
        gridShape: GridShape.classic,
      ),
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
        locale: locale,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: GameScreen(
          difficulty: SudokuDifficulty.easy,
          gridSize: gridSize,
          gridShape: GridShape.classic,
          gameMode: GameMode.classic,
        ),
      ),
    );

    dynamic state;
    for (var i = 0; i < 300; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      state = tester.state(find.byType(GameScreen));
      if (state.game != null) break;
    }
    expect(state.game, isNotNull, reason: 'board should generate');
    return state;
  }

  /// Fill the board from its own solution, through the widgets, which is what
  /// actually triggers the win dialog.
  Future<void> solveThroughUi(WidgetTester tester, dynamic state) async {
    final game = state.game as SudokuGame;
    final dim = game.gridDim;
    for (var r = 0; r < dim; r++) {
      for (var c = 0; c < dim; c++) {
        if (game.grid[r][c] != 0) continue;
        state.selectedRow = r;
        state.selectedCol = c;
        game.grid[r][c] = game.solution[r][c];
      }
    }
    // One real placement through the UI so the win check runs.
    outer:
    for (var r = 0; r < dim; r++) {
      for (var c = 0; c < dim; c++) {
        if (game.isOriginal[r][c]) continue;
        game.grid[r][c] = 0;
        state.selectedRow = r;
        state.selectedCol = c;
        final value = game.solution[r][c];
        await tester.tap(
          find.descendant(
            of: find.byType(GridView),
            matching: find.text('$value'),
          ),
        );
        break outer;
      }
    }
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  for (final (label, size, scale, locale) in <(String, Size, double, Locale?)>[
    ('Galaxy Fold folded (280x653)', const Size(280, 653), 1.0, null),
    ('folded Fold landscape (653x280)', const Size(653, 280), 1.0, null),
    ('iPhone SE (320x568)', const Size(320, 568), 1.0, null),
    ('iPhone SE at 2.0x text', const Size(320, 568), 2.0, null),
    ('iPhone SE in German', const Size(320, 568), 1.0, const Locale('de')),
    ('phone landscape (568x320) at 1.6x', const Size(568, 320), 1.6, null),
  ]) {
    testWidgets('win dialog fits on $label', (tester) async {
      final state = await pumpGame(
        tester,
        size,
        textScale: scale,
        locale: locale,
      );
      await solveThroughUi(tester, state);

      expect(
        find.byType(AlertDialog),
        findsOneWidget,
        reason: 'the win dialog should be showing',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'the win dialog overflowed on $label',
      );

      // The dialog must be on screen, not hanging off it.
      final box = tester.renderObject<RenderBox>(find.byType(AlertDialog));
      final origin = box.localToGlobal(Offset.zero);
      expect(origin.dx, greaterThanOrEqualTo(-0.5));
      expect(origin.dy, greaterThanOrEqualTo(-0.5));
      expect(
        origin.dx + box.size.width,
        lessThanOrEqualTo(size.width + 0.5),
        reason:
            'dialog is ${box.size.width.toStringAsFixed(1)}pt wide on a '
            '${size.width.toInt()}pt screen',
      );
      expect(
        origin.dy + box.size.height,
        lessThanOrEqualTo(size.height + 0.5),
        reason:
            'dialog is ${box.size.height.toStringAsFixed(1)}pt tall on a '
            '${size.height.toInt()}pt screen',
      );

      // Its actions must still be reachable.
      expect(find.byType(TextButton), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
