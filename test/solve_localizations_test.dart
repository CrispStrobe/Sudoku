import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/solve_localizations.dart';
import 'package:sudoku/technique_solver.dart';

void checkMessage(SolveMessage message, String en, String de) {
  expect(message.localize(), en);
  expect(message.localize('de'), de);
  expect(message.localize('DE_at'), de);
  expect(message.localize('fr'), en);
}

void main() {
  test(
    'rendering every step leaves deduction payloads and boards unchanged',
    () {
      for (final size in GridSize.values) {
        final game = SudokuGame.generate(
          SudokuDifficulty.medium,
          size,
          GridShape.classic,
          seed: 19,
        );
        final solver = TechniqueSolver(game.grid, game.regions);
        final before = solver.board;
        final next = solver.nextStep();
        next?.explanationFor('de');
        expect(solver.board, before);
        final result = solver.solve();
        final boardBeforeRendering = solver.board;
        for (final step in result.steps) {
          final cell = step.cell.toList();
          final value = step.value;
          final eliminations = step.eliminations
              .map((e) => e.toList())
              .toList();
          expect(step.message, isNotNull);
          expect(step.explanationFor('de'), isNot(step.explanation));
          expect(step.explanationFor('de-DE'), step.explanationFor('de'));
          expect(step.explanationFor('fr'), step.explanation);
          expect(step.cell, cell);
          expect(step.value, value);
          expect(step.eliminations, eliminations);
        }
        expect(solver.board, boardBeforeRendering);
        expect(game.grid, before);
      }
    },
  );

  test('a real naked-pair producer retains its witness cells and unit', () {
    final grid = [
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
    final regions = List.generate(
      9,
      (r) => List.generate(9, (c) => (r ~/ 3) * 3 + c ~/ 3),
    );
    final step = TechniqueSolver(grid, regions).nextStep()!;
    expect(step.technique, Technique.nakedPair);
    final message = step.message! as SubsetMessage;
    expect(message.kind, SubsetKind.nakedPair);
    expect(message.cells, [
      [5, 4],
      [7, 4],
    ]);
    expect(message.candidates, [1, 2]);
    expect(message.unit.kind, SolveUnitKind.column);
    expect(message.unit.index, 4);
    expect(
      step.explanationFor('de'),
      contains('nacktes Paar (1,2) in Spalte 5'),
    );
    expect(step.eliminations, isNotEmpty);
    expect(step.value, isNull);
  });
  test('legacy constructors retain caller supplied prose for every locale', () {
    const step = SolveStep(
      technique: Technique.guess,
      cell: [0, 0],
      value: null,
      explanation: 'Custom explanation',
    );
    final hint = SmartHint(
      type: HintType.conflict,
      title: 'Custom title',
      description: 'Custom description',
      penalty: 0,
    );
    expect(step.explanationFor('de'), 'Custom explanation');
    expect(hint.titleFor('de'), 'Custom title');
    expect(hint.descriptionFor('de'), 'Custom description');
  });

  test('subset facts are snapshots, unaffected by subsequent solver edits', () {
    final cells = [
      [0, 0],
      [1, 1],
    ];
    final candidates = [1, 12];
    final message = SubsetMessage(
      kind: SubsetKind.nakedPair,
      cells: cells,
      candidates: candidates,
      unit: const SolveUnit(SolveUnitKind.mainDiagonal),
    );
    final before = message.localize('de');
    cells[0][0] = 11;
    candidates.clear();
    expect(message.localize('de'), before);
    expect(before, contains('in der Hauptdiagonale'));
    expect(() => message.cells[0][0] = 11, throwsUnsupportedError);
    expect(() => message.candidates.clear(), throwsUnsupportedError);
  });
  test('X-wing describes both orientations without swapping row and column', () {
    checkMessage(
      const XWingMessage(
        value: 12,
        row1: 0,
        row2: 10,
        col1: 1,
        col2: 11,
        rowBased: true,
      ),
      'X-wing on 12: rows 1 and 11 confine it to columns 2 and 12; removed 12 from those columns in other rows.',
      'X-Wing für 12: In den Zeilen 1 und 11 ist 12 auf die Spalten 2 und 12 beschränkt; 12 wurde in den anderen Zeilen aus diesen Spalten entfernt.',
    );
    checkMessage(
      const XWingMessage(
        value: 12,
        row1: 0,
        row2: 10,
        col1: 1,
        col2: 11,
        rowBased: false,
      ),
      'X-wing on 12: columns 2 and 12 confine it to rows 1 and 11; removed 12 from those rows in other columns.',
      'X-Wing für 12: In den Spalten 2 und 12 ist 12 auf die Zeilen 1 und 11 beschränkt; 12 wurde in den anderen Spalten aus diesen Zeilen entfernt.',
    );
  });
  test('pairs and triples preserve coordinates and candidates in both languages', () {
    const unit = SolveUnit(SolveUnitKind.column, 11);
    checkMessage(
      SubsetMessage(
        kind: SubsetKind.nakedPair,
        cells: [
          [0, 10],
          [1, 11],
        ],
        candidates: [10, 12],
        unit: unit,
      ),
      'R1C11 and R2C12 form a naked pair (10,12) in column 12; removed those from the rest of the unit.',
      'Z1S11 und Z2S12 bilden ein nacktes Paar (10,12) in Spalte 12; diese Kandidaten wurden aus den übrigen Zellen der Einheit entfernt.',
    );
    checkMessage(
      SubsetMessage(
        kind: SubsetKind.nakedTriple,
        cells: [
          [0, 10],
          [1, 11],
          [11, 11],
        ],
        candidates: [1, 10, 12],
        unit: unit,
      ),
      'R1C11, R2C12 and R12C12 form a naked triple (1,10,12) in column 12; removed those from the rest of the unit.',
      'Z1S11, Z2S12 und Z12S12 bilden ein nacktes Tripel (1,10,12) in Spalte 12; diese Kandidaten wurden aus den übrigen Zellen der Einheit entfernt.',
    );
    checkMessage(
      SubsetMessage(
        kind: SubsetKind.hiddenPair,
        cells: [
          [0, 10],
          [1, 11],
        ],
        candidates: [10, 12],
        unit: unit,
      ),
      'Values 10 and 12 are confined to R1C11 and R2C12 in column 12 (hidden pair); removed other candidates from those cells.',
      'Die Zahlen 10 und 12 sind in Spalte 12 auf Z1S11 und Z2S12 beschränkt (verstecktes Paar); andere Kandidaten wurden aus diesen Zellen entfernt.',
    );
  });
  test('locked candidates describe pointing and claiming on either axis', () {
    for (final row in [true, false]) {
      final enAxis = row ? 'row' : 'column';
      final deAxis = row ? 'Zeile' : 'Spalte';
      checkMessage(
        LockedCandidatesMessage(
          value: 12,
          region: 10,
          line: 11,
          isRow: row,
          pointing: true,
        ),
        'In region 11, 12 only appears in $enAxis 12 (pointing); removed 12 from that $enAxis outside the region.',
        'In Region 11 kommt 12 nur in $deAxis 12 als Kandidat vor (Pointing); 12 wurde außerhalb der Region aus dieser $deAxis entfernt.',
      );
      checkMessage(
        LockedCandidatesMessage(
          value: 12,
          region: 10,
          line: 11,
          isRow: row,
          pointing: false,
        ),
        'In $enAxis 12, 12 is confined to region 11 (claiming); removed 12 from the rest of that region.',
        'In $deAxis 12 ist 12 auf Region 11 beschränkt (Claiming); 12 wurde aus den übrigen Zellen dieser Region entfernt.',
      );
    }
  });
  test('hidden singles use localized row, column, region and diagonal names', () {
    const units = [
      SolveUnit(SolveUnitKind.row, 11),
      SolveUnit(SolveUnitKind.column, 11),
      SolveUnit(SolveUnitKind.region, 11),
      SolveUnit(SolveUnitKind.mainDiagonal),
      SolveUnit(SolveUnitKind.antiDiagonal),
    ];
    final en = [
      'row 12',
      'column 12',
      'region 12',
      'the main diagonal',
      'the anti-diagonal',
    ];
    final de = [
      'Zeile 12',
      'Spalte 12',
      'Region 12',
      'der Hauptdiagonale',
      'der Gegendiagonale',
    ];
    for (var i = 0; i < units.length; i++) {
      checkMessage(
        HiddenSingleMessage(10, 11, 12, units[i]),
        'R11C12 is the only cell in ${en[i]} that can be 12 — hidden single.',
        'Z11S12 ist die einzige Zelle in ${de[i]}, in der 12 stehen kann — versteckter Einer.',
      );
    }
    final grid = List.generate(9, (_) => List.filled(9, 0));
    grid[1][4] = grid[2][5] = grid[3][1] = grid[4][2] = 7;
    final regions = List.generate(
      9,
      (r) => List.generate(9, (c) => (r ~/ 3) * 3 + c ~/ 3),
    );
    final step = TechniqueSolver(grid, regions).nextStep()!;
    expect(step.message, isA<HiddenSingleMessage>());
    expect(
      step.explanationFor('de'),
      'Z1S1 ist die einzige Zelle in Region 1, in der 7 stehen kann — versteckter Einer.',
    );
  });
  test('all smart hint branches retain payloads and render German', () {
    final solution = [
      [1, 2, 3, 4],
      [3, 4, 1, 2],
      [2, 1, 4, 3],
      [4, 3, 2, 1],
    ];
    final regions = List.generate(
      4,
      (r) => List.generate(4, (c) => (r ~/ 2) * 2 + c ~/ 2),
    );
    SudokuGame game(List<List<int>> grid) => SudokuGame.fromState(
      givens: grid,
      solution: solution,
      regions: regions,
      difficulty: SudokuDifficulty.easy,
    );
    final occupied = game(solution).getSmartHints(0, 0).single;
    expect(occupied.titleFor('de'), 'Zelle belegt');
    expect(
      occupied.descriptionFor('de'),
      'Diese Zelle ist bereits ausgefüllt oder gehört zu den Vorgaben.',
    );
    final conflict = game([
      [0, 2, 3, 4],
      [1, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]).getSmartHints(0, 0).single;
    expect(conflict.titleFor('de'), 'Konflikt erkannt');
    expect(conflict.descriptionFor('de'), contains('Keine Zahl'));
    final singleGrid = solution.map((r) => r.toList()).toList();
    singleGrid[0][0] = 0;
    final single = game(singleGrid).getSmartHints(0, 0).single;
    expect(single.titleFor('de'), 'Einzige Möglichkeit (nackter Einer)');
    expect(single.descriptionFor('de'), 'In diese Zelle passt nur eine Zahl.');
    expect(single.data, 1);
    expect(single.penalty, 25);
    final empty = game(List.generate(4, (_) => List.filled(4, 0)));
    final hints = empty.getSmartHints(0, 0);
    expect(hints.map((h) => h.titleFor('de')), [
      'Mögliche Zahlen anzeigen',
      'Lösung anzeigen',
    ]);
    expect(hints.map((h) => h.descriptionFor('de')), [
      'Zeigt alle Zahlen, die hier nach den Regeln möglich sind.',
      'Trägt die richtige Zahl ein.',
    ]);
    expect(hints.map((h) => h.penalty), [15, 50]);
    expect(hints.map((h) => h.data), [
      [1, 2, 3, 4],
      1,
    ]);
    final hidden = game([
      [0, 0, 0, 0],
      [0, 0, 1, 0],
      [0, 1, 0, 0],
      [0, 0, 0, 0],
    ]).getSmartHints(0, 0).first;
    expect(hidden.type, HintType.hiddenSingle);
    expect(hidden.titleFor('de'), 'Versteckter Einer');
    expect(
      hidden.descriptionFor('de'),
      'Nur in dieser Zelle der Zeile, Spalte oder Region kann diese Zahl stehen.',
    );
    expect(hidden.data, 1);
    expect(hidden.penalty, 30);
    for (final hint in [occupied, conflict, single, hidden, ...hints]) {
      expect(hint.titleFor('en'), hint.title);
      expect(hint.descriptionFor('en'), hint.description);
      expect(hint.titleFor('de-DE'), hint.titleFor('de'));
      expect(hint.titleFor('fr'), hint.title);
    }
  });

  test('naked single explanation can be rendered in German', () {
    final grid = [
      [0, 2, 3, 4],
      [3, 4, 1, 2],
      [2, 1, 4, 3],
      [4, 3, 2, 1],
    ];
    final regions = List.generate(
      4,
      (r) => List.generate(4, (c) => (r ~/ 2) * 2 + c ~/ 2),
    );
    final step = TechniqueSolver(grid, regions).nextStep()!;
    expect(step.explanation, 'R1C1 has only one candidate (1) — naked single.');
    expect(
      step.explanationFor('de'),
      'Z1S1 hat nur einen Kandidaten (1) — nackter Einer.',
    );
    expect(step.cell, [0, 0]);
    expect(step.value, 1);
    expect(step.eliminations, isEmpty);
  });
}
