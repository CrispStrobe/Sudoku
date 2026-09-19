@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku/main.dart';
import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/l10n/app_localizations.dart';

/// Golden images of the game screen across the device matrix.
///
/// The assertions in board_layout_test pin numbers — board edge, tile size,
/// row height — and numbers only catch what someone thought to measure. Every
/// layout bug this project shipped was visible at a glance and invisible to
/// the suite: a pad collapsed to a sliver, a hint label stacked one character
/// per line, a board given half its screen. A picture catches those without
/// anyone having predicted them.
///
/// Tagged `golden` so `flutter test` skips them by default: they are
/// font-and-platform sensitive, and a Linux CI runner and a developer's Mac
/// will not agree pixel for pixel. Run and review them deliberately:
///
///   flutter test --tags golden                     # compare
///   flutter test --tags golden --update-goldens    # accept new output
///
/// Regenerate whenever a layout change is intended, and *look at the diff* in
/// `test/failures/` when one is not.
void main() {
  setUp(() => debugParticleSeed = 7);
  tearDown(() => debugParticleSeed = null);

  Future<void> pumpGame(
    WidgetTester tester,
    Size size, {
    GridSize gridSize = GridSize.standard,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // `dailySeed` is the only fully deterministic path into the screen. The
    // cache path is not: it stores a *solved* blueprint and the screen digs
    // the holes itself under a wall-clock budget, so the same seed yields a
    // different set of givens under a different machine load — about 10% of
    // the pixels, which is enough to make a golden useless. (`dailyKey` stays
    // null, so none of the daily-specific UI appears.)
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
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
          dailySeed: 20260919,
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
    // Settle the entry animations, then stop: with the particle RNG seeded
    // and ambient spawning off, the frame at a fixed elapsed time is the same
    // every run.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The awkward sizes, not the comfortable ones — these are where the bugs
  /// were. Each is a real device.
  for (final (name, size) in <(String, Size)>[
    ('fold-closed', const Size(280, 653)),
    ('fold-closed-landscape', const Size(653, 280)),
    ('iphone-se', const Size(320, 568)),
    ('iphone-se-landscape', const Size(568, 320)),
    ('iphone-8', const Size(375, 667)),
    ('iphone-14', const Size(390, 844)),
    ('surface-duo', const Size(540, 720)),
    ('ipad-mini', const Size(744, 1133)),
    ('ipad-pro-landscape', const Size(1194, 834)),
  ]) {
    testWidgets('golden: $name', (tester) async {
      await pumpGame(tester, size);
      await expectLater(
        find.byType(GameScreen),
        matchesGoldenFile('goldens/game_$name.png'),
      );
    });
  }

  // The two cases that are about content rather than the window.
  testWidgets('golden: 12x12 on an iPhone SE', (tester) async {
    await pumpGame(tester, const Size(320, 568), gridSize: GridSize.mega);
    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/game_12x12_iphone-se.png'),
    );
  });

  testWidgets('golden: iPhone SE at 2.0x text', (tester) async {
    await pumpGame(tester, const Size(320, 568), textScale: 2.0);
    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/game_iphone-se_text2x.png'),
    );
  });
}
