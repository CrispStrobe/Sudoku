import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku/main.dart';
import 'package:sudoku/painters.dart';
import 'package:sudoku/services.dart';
import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/l10n/app_localizations.dart';

/// Pencil marks have to fit the cell they are written in.
///
/// `_buildNotes` used to clamp its font to a *floor* of 6pt while giving each
/// candidate a slot `cellWidth / ceil(sqrt(gridDim))` wide. On a 12x12 board on
/// a 320pt phone the cell is about 21pt, so a slot is about 5pt: the floor
/// guaranteed a glyph bigger than the box that had to hold it, and three rows
/// of them taller than the cell. The board's own digits and the number pad had
/// both already been fixed for exactly this; the notes had not.
///
/// 12x12 on the smallest supported screen is the worst case, so that is what
/// this drives — through the real UI (notes mode, tap a cell, tap digits),
/// because the bug was in what got rendered, not in what got stored.
void main() {
  Future<dynamic> pumpGame(
    WidgetTester tester,
    Size size,
    GridSize gridSize,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final seeded = SudokuGame.generate(
      SudokuDifficulty.easy,
      gridSize,
      GridShape.classic,
      seed: 11,
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

  for (final (label, gridSize, dim) in <(String, GridSize, int)>[
    ('12x12', GridSize.mega, 12),
    ('10x10', GridSize.big, 10),
    ('9x9', GridSize.standard, 9),
  ]) {
    testWidgets('$label pencil marks fit their cell on a 320pt phone', (
      tester,
    ) async {
      final state = await pumpGame(tester, const Size(320, 568), gridSize);
      final game = state.game as SudokuGame;

      // Notes mode, then an empty cell, then every digit on the pad — the
      // fullest a cell can get, which is the case that overflowed.
      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();

      var row = -1, col = -1;
      for (var r = 0; r < dim && row < 0; r++) {
        for (var c = 0; c < dim; c++) {
          if (game.grid[r][c] == 0) {
            row = r;
            col = c;
            break;
          }
        }
      }
      expect(row, greaterThanOrEqualTo(0), reason: 'no empty cell');

      // Tap the cell where it actually is, then every pad digit. Going through
      // the widgets (rather than poking state) is the point: the defect was in
      // what got laid out, and only a real tap produces that.
      final gridBox = tester.renderObject<RenderBox>(
        find
            .byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is SudokuGridPainter,
            )
            .first,
      );
      final cell = gridBox.size.width / dim;
      final origin = gridBox.localToGlobal(Offset.zero);
      await tester.tapAt(
        origin + Offset((col + 0.5) * cell, (row + 0.5) * cell),
      );
      await tester.pump();

      for (var n = 1; n <= dim; n++) {
        final tile = find.descendant(
          of: find.byType(GridView),
          matching: find.text('$n'),
        );
        expect(tile, findsOneWidget, reason: 'pad is missing the $n tile');
        await tester.tap(tile);
        await tester.pump();
      }

      expect(
        game.notes[row][col],
        hasLength(dim),
        reason: 'the cell should hold every candidate',
      );
      expect(tester.takeException(), isNull);
      final noteBoxes = find
          .byWidgetPredicate(
            (w) =>
                w is Text &&
                w.style?.color == Colors.grey.shade600 &&
                RegExp(r'^\d+$').hasMatch(w.data ?? ''),
          )
          .evaluate();
      expect(noteBoxes, isNotEmpty, reason: 'no pencil marks were rendered');

      // Assert the *derivation*, as board_layout_test does for cell digits.
      // Measuring the rendered box would not catch the regression: each note
      // sits in a scaleDown FittedBox, which shrinks by transform and leaves
      // the child's reported size at its natural value — so a 6pt glyph in a
      // 5pt slot measures as 6pt whether or not it is painted at 5. What broke
      // was a font size with a floor unrelated to the slot, and that is what
      // this pins. (Two-digit notes — 10, 11, 12 — are wider than one slot at
      // any legible size; FittedBox is what makes those fit, by design.)
      final perRow = (dim <= 9) ? 3 : 4;
      final rows = (dim / perRow).ceil();
      final slot = cell / perRow;
      for (final element in noteBoxes) {
        final fontSize = (element.widget as Text).style?.fontSize;
        expect(fontSize, isNotNull, reason: 'a note has no explicit font size');
        expect(
          fontSize!,
          lessThanOrEqualTo(slot),
          reason:
              'a pencil mark is ${fontSize}pt for a '
              '${slot.toStringAsFixed(1)}pt slot (cell '
              '${cell.toStringAsFixed(1)}pt, ${dim}x$dim) — the font is not '
              'derived from the slot it has to fit',
        );
        expect(
          fontSize,
          lessThanOrEqualTo(cell / rows),
          reason:
              'a pencil mark is ${fontSize}pt tall in a '
              '${(cell / rows).toStringAsFixed(1)}pt row',
        );
      }

      await tester.pumpWidget(const SizedBox());
    });
  }
}
