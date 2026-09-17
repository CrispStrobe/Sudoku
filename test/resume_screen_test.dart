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

Widget app() => const MaterialApp(
  locale: Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: HomeScreen(),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GameStats.unlimitedMistakes = false;
  });

  testWidgets(
    'Home explicitly resumes saved board and persists moves on Home',
    (tester) async {
      final game = sampleGame()
        ..setCell(0, 1, 2)
        ..toggleNote(0, 2, 3);
      await SavedGameService().save(snapshot(game));
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(find.byType(GameScreen), findsNothing);
      expect(find.text('Resume'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();
      final dynamic state = tester.state(find.byType(GameScreen));
      final restored = state.game as SudokuGame;
      expect(restored.grid, game.grid);
      expect(restored.notes, game.notes);
      expect(restored.isOriginal, game.isOriginal);
      expect(state.score, 777);
      expect(state.mistakes, 2);
      expect(state.hintsUsed, 1);
      expect(find.text('02:03'), findsOneWidget);
      // Erase a player entry using the real board/controls.
      await tester.tap(find.byType(DragTarget<int>).at(1));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      expect((await SavedGameService().load())!.createGame().grid[0][1], 0);
      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();
      expect(find.text('Resume'), findsOneWidget);
      final saved = (await SavedGameService().load())!;
      expect(saved.createGame().isOriginal[0][1], false);
      expect(saved.rating, SudokuDifficulty.hard);
      await tester.pumpWidget(const SizedBox());
      await SavedGameService().load();
    },
  );

  testWidgets('placements notes undo and background persist without exiting', (
    tester,
  ) async {
    await SavedGameService().save(snapshot(sampleGame()));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DragTarget<int>).at(1));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, '2').last);
    await tester.pump();
    expect((await SavedGameService().load())!.createGame().notes[0][1], {2});
    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(
      (await SavedGameService().load())!.createGame().notes[0][1],
      isEmpty,
    );
    await tester.tap(find.byIcon(Icons.edit));
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, '2').last);
    await tester.pump();
    expect((await SavedGameService().load())!.createGame().grid[0][1], 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    final paused = (await SavedGameService().load())!.elapsed;
    await tester.pump(const Duration(seconds: 30));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect((await SavedGameService().load())!.elapsed, paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await SavedGameService().load();
    await tester.pump();
  });

  for (final win in [true, false]) {
    testWidgets(
      '${win ? "win" : "loss"} clears resume even after Home and disposal',
      (tester) async {
        final game = sampleGame();
        if (win) {
          for (var r = 0; r < 4; r++) {
            for (var c = 0; c < 4; c++) {
              if (r != 0 || c != 1) game.setCell(r, c, game.solution[r][c]);
            }
          }
        }
        await SavedGameService().save(snapshot(game));
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tester.tap(find.text('Resume'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(DragTarget<int>).at(1));
        await tester.pump();
        for (var i = 0; i < (win ? 1 : 2); i++) {
          await tester.tap(
            find.widgetWithText(ElevatedButton, win ? '2' : '1').last,
          );
          await tester.pump();
        }
        await tester.pump(const Duration(seconds: 1));
        expect(await SavedGameService().load(), isNull);
        await tester.tap(find.text('Main Menu').last);
        await tester.pumpAndSettle();
        expect(find.text('Resume'), findsNothing);
        expect(await SavedGameService().load(), isNull);
        await tester.pumpWidget(const SizedBox());
        await SavedGameService().load();
        await tester.pump();
      },
    );
  }

  testWidgets('hint charges persist and Explain pauses the active clock', (
    tester,
  ) async {
    await SavedGameService().save(snapshot(sampleGame()));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.lightbulb).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pump();
    final hinted = (await SavedGameService().load())!;
    expect(hinted.hintsUsed, 2);
    expect(hinted.score, 737);
    await tester.tap(find.byIcon(Icons.school));
    await tester.pumpAndSettle();
    final paused = (await SavedGameService().load())!.elapsed;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect((await SavedGameService().load())!.elapsed, paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
    await SavedGameService().load();
  });

  testWidgets('new daily run saves immediately and can resume from Home', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: GameScreen(
          difficulty: SudokuDifficulty.easy,
          gridSize: GridSize.small,
          gridShape: GridShape.classic,
          gameMode: GameMode.classic,
          dailySeed: 20260917,
          dailyKey: '2026-09-17',
        ),
      ),
    );
    await tester.pump();
    final saved = (await SavedGameService().load())!;
    expect(saved.dailyKey, '2026-09-17');
    expect(
      saved.createGame().grid,
      (tester.state(find.byType(GameScreen)) as dynamic).game.grid,
    );
    await tester.pumpWidget(const SizedBox());
    await SavedGameService().load();
  });

  testWidgets('invalid saved payload never offers Resume', (tester) async {
    SharedPreferences.setMockInitialValues({
      SavedGameService.storageKey: '{"version":0}',
    });
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('Resume'), findsNothing);
  });
}
