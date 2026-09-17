import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/explain_screen.dart';
import 'package:sudoku/game_screen.dart';
import 'package:sudoku/game_stats.dart';
import 'package:sudoku/l10n/app_localizations.dart';
import 'package:sudoku/l10n/app_localizations_de.dart';
import 'package:sudoku/saved_game.dart';
import 'package:sudoku/saved_game_service.dart';
import 'package:sudoku/solve_localizations.dart';
import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/technique_solver.dart';
import 'saved_game_test.dart' show sampleGame;
import 'technique_solver_test.dart' show fullSolution9;

Widget germanApp(Widget home, {double scale = 1}) => MaterialApp(
  locale: const Locale('de'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: home,
);

SavedGame save(SudokuGame game) => SavedGame.capture(
  game: game,
  size: game.gridDim == 4 ? GridSize.small : GridSize.standard,
  shape: GridShape.classic,
  gameMode: GameMode.classic,
  elapsed: Duration.zero,
  score: 1000,
  mistakes: 0,
  hintsUsed: 0,
);

const pairGrid = [
  [5, 0, 4, 6, 0, 0, 9, 0, 2],
  [0, 7, 2, 0, 9, 0, 0, 0, 0],
  [0, 0, 8, 0, 4, 0, 0, 0, 7],
  [0, 0, 9, 0, 6, 0, 4, 0, 0],
  [0, 2, 6, 0, 5, 3, 7, 9, 0],
  [7, 0, 0, 0, 0, 0, 0, 0, 0],
  [0, 0, 0, 0, 0, 0, 2, 0, 0],
  [0, 0, 7, 0, 0, 0, 0, 3, 0],
  [0, 0, 0, 0, 8, 0, 1, 0, 0],
];
List<List<int>> get regions9 =>
    List.generate(9, (r) => List.generate(9, (c) => r ~/ 3 * 3 + c ~/ 3));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('German technique labels match structured solver terminology', () {
    final l = AppLocalizationsDe();
    expect(l.techniqueNakedSingle, 'Nackter Einer');
    expect(l.techniqueHiddenSingle, SmartHintMessage.hiddenSingle.title('de'));
    expect(l.techniqueNakedTriple, 'Nacktes Tripel');
  });

  testWidgets('German actual cell hint and confirmation fit a narrow phone', (
    tester,
  ) async {
    tester.view.reset();
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final game = sampleGame();
    await tester.pumpWidget(germanApp(GameScreen.resume(save(game))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DragTarget<int>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.lightbulb).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
    expect(find.text('Intelligente Hinweise'), findsOneWidget);
    final hint = game
        .getSmartHints(0, 1)
        .firstWhere((h) => h.type == HintType.nakedSingle);
    final title = find.text(hint.titleFor('de'));
    expect(title, findsOneWidget);
    expect(find.text(hint.descriptionFor('de')), findsOneWidget);
    await tester.ensureVisible(title);
    await tester.tap(title);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      find.text('Diesen Hinweis für -${hint.penalty} Punkte verwenden?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Bestätigen'));
    // Ambient particles keep scheduling frames once the game has run for 2s.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final persisted = (await SavedGameService().load())!;
    expect(persisted.createGame().grid[0][1], 2);
    expect(persisted.hintsUsed, 1);
    expect(persisted.score, 1000 - hint.penalty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await SavedGameService().load();
  });

  testWidgets(
    'German actual long elimination hint fits and does not place a value',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final game = SudokuGame.fromState(
        givens: pairGrid,
        solution: fullSolution9(),
        regions: regions9,
        difficulty: SudokuDifficulty.medium,
      );
      final step = TechniqueSolver(game.grid, game.regions).nextStep()!;
      await tester.pumpWidget(germanApp(GameScreen.resume(save(game))));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.lightbulb).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Nächster logischer Schritt'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      expect(find.text('Nacktes Paar'), findsOneWidget);
      expect(find.text(step.explanationFor('de')), findsOneWidget);
      await tester.tap(find.text('Verstanden'));
      await tester.pump();
      final persisted = (await SavedGameService().load())!;
      expect(persisted.createGame().grid, pairGrid);
      expect(persisted.score, 960);
      expect(persisted.hintsUsed, 1);
      await tester.pumpWidget(const SizedBox());
      await SavedGameService().load();
    },
  );

  testWidgets('German actual next-step dialog and Explain share Einer prose', (
    tester,
  ) async {
    final game = sampleGame();
    final step = TechniqueSolver(game.grid, game.regions).nextStep()!;
    expect(step.technique, Technique.nakedSingle);
    await tester.pumpWidget(germanApp(GameScreen.resume(save(game))));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.lightbulb).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.auto_awesome));
    await tester.pumpAndSettle();
    expect(find.text('Nackter Einer'), findsOneWidget);
    expect(find.text(step.explanationFor('de')), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.school));
    await tester.pumpAndSettle();
    expect(find.byType(ExplainScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Weiter'));
    await tester.pump();
    expect(find.text('Nackter Einer'), findsOneWidget);
    expect(find.text(step.explanationFor('de')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.skip_previous));
    await tester.pump();
    expect(find.text('Start'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await SavedGameService().load();
  });

  testWidgets(
    'German Explain long elimination prose remains readable at large text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final step = TechniqueSolver(pairGrid, regions9).nextStep()!;
      expect(step.technique, Technique.nakedPair);
      await tester.pumpWidget(
        germanApp(
          ExplainScreen(
            grid: pairGrid,
            regions: regions9,
            gridDim: 9,
            jigsaw: false,
            diagonal: false,
            scheme: GameStats.current,
          ),
          scale: 2,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Weiter'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Nacktes Paar'), findsOneWidget);
      final caption = find.text(step.explanationFor('de'));
      expect(caption, findsOneWidget);
      await tester.ensureVisible(caption);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Weiter').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Abspielen'));
      await tester.pump(const Duration(milliseconds: 1100));
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
