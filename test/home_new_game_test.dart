import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/game_screen.dart';
import 'package:sudoku/home_screen.dart';
import 'package:sudoku/game_stats.dart';
import 'package:sudoku/l10n/app_localizations.dart';
import 'package:sudoku/saved_game_service.dart';
import 'package:sudoku/sudoku_game.dart';
import 'saved_game_test.dart' show sampleGame, snapshot;

const _app = MaterialApp(
  locale: Locale('de'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: HomeScreen(),
);

Future<void> selectGame(WidgetTester tester, String path) async {
  final l = AppLocalizations.of(tester.element(find.byType(HomeScreen)))!;
  Future<void> tap(String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  if (path == 'daily') {
    await tap(l.homeDailyChallenge);
  } else {
    await tap(path == 'jigsaw' ? l.homeJigsawMode : l.homeClassicMode);
    await tap(path == 'jigsaw' ? l.jigsawSizeLabel('4×4') : '4×4');
    if (path == 'x') await tap(l.variantSudokuX);
    if (path == 'killer') await tap(l.variantKiller);
    await tap(l.difficultyEasy);
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GameStats.lastDailyDate = null;
    GameStats.useSavedPuzzles = false;
  });

  for (final path in ['daily', 'classic', 'jigsaw', 'x', 'killer']) {
    testWidgets(
      '$path cancel preserves slot and confirm starts selected game',
      (tester) async {
        final original = snapshot(sampleGame()..toggleNote(0, 1, 2));
        await SavedGameService().save(original);
        await tester.pumpWidget(_app);
        await tester.pumpAndSettle();
        await selectGame(tester, path);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(GameScreen), findsNothing);
        expect((await SavedGameService().load())!.toJson(), original.toJson());
        expect(find.text('Gespeichertes Spiel ersetzen?'), findsOneWidget);
        await tester.tap(find.text('Abbrechen'));
        await tester.pumpAndSettle();
        expect(find.byType(GameScreen), findsNothing);
        expect((await SavedGameService().load())!.toJson(), original.toJson());
        expect(find.byKey(const ValueKey('resume-game')), findsOneWidget);
        await selectGame(tester, path);
        await tester.tap(find.text('Neues Spiel starten'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        final screen = tester.widget<GameScreen>(find.byType(GameScreen));
        expect(screen.savedGame, isNull);
        expect(screen.isDaily, path == 'daily');
        expect(
          screen.gridSize,
          path == 'daily' ? kDailyGridSize : GridSize.small,
        );
        expect(
          screen.difficulty,
          path == 'daily' ? kDailyDifficulty : SudokuDifficulty.easy,
        );
        expect(
          screen.gridShape,
          path == 'jigsaw' ? GridShape.jigsaw : GridShape.classic,
        );
        expect(
          screen.variant,
          path == 'x'
              ? SudokuVariant.x
              : path == 'killer'
              ? SudokuVariant.killer
              : SudokuVariant.classic,
        );
        if (path == 'daily') {
          expect(screen.dailySeed, dailySeed(DateTime.now()));
          expect(screen.dailyKey, dailyDateKey(DateTime.now()));
        }
        // Let real isolate generation complete without fake-time spinning.
        for (
          var i = 0;
          i < 100 &&
              (tester.state(find.byType(GameScreen)) as dynamic).game == null;
          i++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        final dynamic state = tester.state(find.byType(GameScreen));
        expect(state.game, isNotNull);
        final replacement = (await SavedGameService().load())!;
        expect(replacement.score, isNot(original.score));
        expect(replacement.createGame().grid, (state.game as SudokuGame).grid);
        expect(replacement.variant, screen.variant);
        expect(replacement.shape, screen.gridShape);
        expect(replacement.dailyKey, screen.dailyKey);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await SavedGameService().load();
      },
    );
  }

  testWidgets('daily without a save starts without a confirmation', (
    tester,
  ) async {
    await tester.pumpWidget(_app);
    await tester.pumpAndSettle();
    await selectGame(tester, 'daily');
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.widget<GameScreen>(find.byType(GameScreen)).isDaily, isTrue);
    await tester.pumpWidget(const SizedBox());
    await SavedGameService().load();
  });
}
