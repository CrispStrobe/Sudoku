import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku/main.dart';
import 'package:sudoku/painters.dart';
import 'package:sudoku/services.dart';
import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/l10n/app_localizations.dart';

/// The game screen under the OS's large-text settings.
///
/// iOS Dynamic Type and Android font-size go up to about 2x, and a player who
/// needs them is exactly the player a 5pt pencil mark fails. Nothing in this
/// suite had ever pumped the screen at a text scale other than 1.0, and the
/// screen is full of `Text` in fixed-height boxes — the status strip, the hint
/// button, the pad tiles — every one of which grows when the scale does.
///
/// The invariant is not "the text stays the same size"; it is that nothing
/// overflows and the board stays playable, on the smallest screen, at the
/// largest scale anyone will set.
void main() {
  Future<SudokuGame> pumpGame(
    WidgetTester tester,
    Size size,
    double textScale, {
    Locale? locale,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final seeded = SudokuGame.generate(
      SudokuDifficulty.easy,
      GridSize.standard,
      GridShape.classic,
      seed: 5,
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
        home: const GameScreen(
          difficulty: SudokuDifficulty.easy,
          gridSize: GridSize.standard,
          gridShape: GridShape.classic,
          gameMode: GameMode.classic,
        ),
      ),
    );

    dynamic state;
    SudokuGame? game;
    for (var i = 0; i < 300 && game == null; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      state = tester.state(find.byType(GameScreen));
      game = state.game as SudokuGame?;
    }
    expect(game, isNotNull, reason: 'board should generate');
    return game!;
  }

  double boardEdge(WidgetTester tester) => tester
      .renderObject<RenderBox>(
        find
            .byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is SudokuGridPainter,
            )
            .first,
      )
      .size
      .width;

  for (final (sizeLabel, size) in <(String, Size)>[
    ('320x568', const Size(320, 568)),
    ('375x667', const Size(375, 667)),
    ('568x320 landscape', const Size(568, 320)),
  ]) {
    for (final scale in [1.3, 1.6, 2.0]) {
      testWidgets('$sizeLabel at ${scale}x text stays playable', (
        tester,
      ) async {
        final game = await pumpGame(tester, size, scale);

        // No overflow. This is the assertion that matters: a Row or Column
        // that cannot fit its children throws here, and a fixed-height box
        // full of scaled-up text is exactly how that happens.
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflowed at ${scale}x text on $sizeLabel',
        );

        // The board must not have been squeezed away to make room for bigger
        // chrome — it is still the thing being played.
        final edge = boardEdge(tester);
        expect(
          edge,
          greaterThanOrEqualTo(math.min(size.width, size.height) * 0.45),
          reason:
              'board fell to ${edge.toStringAsFixed(1)}pt at ${scale}x text '
              'on $sizeLabel',
        );

        // And the pad must still be tappable and complete.
        for (var n = 1; n <= game.gridDim; n++) {
          expect(
            find.descendant(
              of: find.byType(GridView),
              matching: find.text('$n'),
            ),
            findsOneWidget,
            reason: 'pad lost the $n tile at ${scale}x text',
          );
        }
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  /// German, which is the app's other language and the longer one.
  ///
  /// "Keine Hinweise" against "No Hints", "Logik: Mittel" against "Logic:
  /// Medium" — a label that fits in English is not evidence that the layout
  /// holds, and combined with a large-text setting it is the worst realistic
  /// case the app ships to.
  for (final (label, size, scale) in <(String, Size, double)>[
    ('320x568', const Size(320, 568), 1.0),
    ('320x568 at 1.6x text', const Size(320, 568), 1.6),
    ('568x320 landscape at 1.6x text', const Size(568, 320), 1.6),
  ]) {
    testWidgets('German on $label stays playable', (tester) async {
      final game = await pumpGame(
        tester,
        size,
        scale,
        locale: const Locale('de'),
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'German overflowed on $label',
      );
      final edge = boardEdge(tester);
      expect(
        edge,
        greaterThanOrEqualTo(math.min(size.width, size.height) * 0.45),
        reason: 'board fell to ${edge.toStringAsFixed(1)}pt in German',
      );
      for (var n = 1; n <= game.gridDim; n++) {
        expect(
          find.descendant(of: find.byType(GridView), matching: find.text('$n')),
          findsOneWidget,
          reason: 'pad lost the $n tile in German on $label',
        );
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
}
