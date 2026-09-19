// Runs the real app in a real browser.
//
// `flutter test` is a VM runner: every widget test in this repo executes with
// 64-bit ints, `dart:io` available and Skia rendering into an offscreen
// surface. The shipped web build has none of those — `int` is a JS double,
// `Uint64List` cannot be allocated, and the whole UI is a canvas. A crash that
// only happens under dart2js therefore passes the entire suite, which is
// exactly what happened to Killer generation in v1.1.0.
//
// `tool/web_killer_probe.dart` covers the engine under dart2js and
// `.github/scripts/render_check.js` covers the deployed page. This covers the
// gap between them: the app's own widgets, driven by the app's own test
// framework, in Chrome.
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/web_smoke_test.dart -d chrome
//
// Needs chromedriver on PATH, started on port 4444.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sudoku/l10n/app_localizations.dart';
import 'package:sudoku/main.dart';
import 'package:sudoku/painters.dart';
import 'package:sudoku/services.dart';
import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/variant_engine.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the Killer bundle loads and its boards are real', (
    tester,
  ) async {
    // The bundle is a rootBundle asset decoded with dart:convert. Both behave
    // differently enough on the web to be worth asserting there and not only
    // on the VM.
    final bundle = KillerPuzzleBundle.isolated();
    await bundle.initialize();

    final puzzle = bundle.get(GridSize.standard, SudokuDifficulty.easy);
    expect(puzzle, isNotNull, reason: 'no bundled Killer puzzle on the web');
    expect(puzzle!.cages, isNotEmpty);
    expect(puzzle.gridDim, 9);
  });

  testWidgets('the Killer generator runs under dart2js', (tester) async {
    // This is the one that would have caught v1.1.0: on the VM it passes
    // trivially, and under dart2js it used to throw
    // "Uint64List not supported on the web" inside the CSP solver.
    final puzzle = await VariantEngine.generateKiller(
      gridSize: GridSize.small,
      difficulty: SudokuDifficulty.easy,
      seed: 1,
    );
    expect(puzzle.cages, isNotEmpty);
    expect(puzzle.gridDim, 4);
  });

  testWidgets('a game screen renders a board in a browser', (tester) async {
    await PuzzleCache().initialize();

    await tester.pumpWidget(
      const MaterialApp(
        // The delegates are not optional: GameScreen reads
        // `AppLocalizations.of(context)!` on its first build, and without them
        // that is a null check on null — which surfaces as "multiple
        // exceptions during the test" rather than anything that names the
        // cause.
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GameScreen(
          difficulty: SudokuDifficulty.easy,
          gridSize: GridSize.standard,
          gridShape: GridShape.classic,
          gameMode: GameMode.classic,
          dailySeed: 20260919,
        ),
      ),
    );
    // NOT pumpAndSettle: the particle layer runs a repeating
    // AnimationController for as long as the screen is mounted, so "wait for
    // animations to stop" never returns. Pump a bounded number of frames and
    // stop when the board exists.
    final painter = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is SudokuGridPainter,
    );
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 30));
      if (painter.evaluate().isNotEmpty) break;
    }

    expect(painter, findsWidgets, reason: 'the board did not paint');
    final box = tester.renderObject<RenderBox>(painter.first);
    expect(box.size.width, greaterThan(100));
  });
}
