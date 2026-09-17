/// Pure-Dart solver prose. Engines retain structured facts, never parse English.
/// Cell and unit indices are zero-based; rendered coordinates are one-based.
class SolveLocalizations {
  SolveLocalizations([String languageCode = 'en'])
    : isGerman = languageCode.toLowerCase().split(RegExp('[-_]')).first == 'de';

  final bool isGerman;

  String cell(int row, int col) =>
      isGerman ? 'Z${row + 1}S${col + 1}' : 'R${row + 1}C${col + 1}';
}

/// Distinguishes occupied-cell diagnostics from no-candidate conflicts.
enum SmartHintMessage {
  occupied,
  conflict,
  nakedSingle,
  hiddenSingle,
  showPossible,
  giveAnswer;

  String title([String languageCode = 'en']) {
    final de = SolveLocalizations(languageCode).isGerman;
    return switch (this) {
      occupied => de ? 'Zelle belegt' : 'Cell Occupied',
      conflict => de ? 'Konflikt erkannt' : 'Conflict Detected',
      nakedSingle =>
        de
            ? 'Einzige Möglichkeit (nackter Einer)'
            : 'Only Choice (Naked Single)',
      hiddenSingle => de ? 'Versteckter Einer' : 'Hidden Single',
      showPossible => de ? 'Mögliche Zahlen anzeigen' : 'Show Possible Numbers',
      giveAnswer => de ? 'Lösung anzeigen' : 'Give Answer',
    };
  }

  String description([String languageCode = 'en']) {
    final de = SolveLocalizations(languageCode).isGerman;
    return switch (this) {
      occupied =>
        de
            ? 'Diese Zelle ist bereits ausgefüllt oder gehört zu den Vorgaben.'
            : 'This cell is already filled or is part of the original puzzle.',
      conflict =>
        de
            ? 'Keine Zahl ist hier nach den Regeln möglich. Prüfe die Zeile, Spalte oder Region auf einen Fehler.'
            : 'No number can legally go here. Check the row, column, or region for a mistake.',
      nakedSingle =>
        de
            ? 'In diese Zelle passt nur eine Zahl.'
            : 'There is only one number that can fit in this cell.',
      hiddenSingle =>
        de
            ? 'Nur in dieser Zelle der Zeile, Spalte oder Region kann diese Zahl stehen.'
            : 'This is the only cell in its row, column, or region where this number can go.',
      showPossible =>
        de
            ? 'Zeigt alle Zahlen, die hier nach den Regeln möglich sind.'
            : 'Reveals every number that can legally go here.',
      giveAnswer =>
        de ? 'Trägt die richtige Zahl ein.' : 'Fills in the correct number.',
    };
  }
}

/// Facts behind a deduction, independently renderable after a locale change.
abstract class SolveMessage {
  const SolveMessage();
  String localize([String languageCode = 'en']);
}

enum SolveUnitKind { row, column, region, mainDiagonal, antiDiagonal }

class SolveUnit {
  const SolveUnit(this.kind, [this.index = 0]);
  final SolveUnitKind kind;
  final int index;

  /// Unit name in the grammatical context "in ...".
  String localize([String languageCode = 'en']) {
    final de = SolveLocalizations(languageCode).isGerman;
    return switch (kind) {
      SolveUnitKind.row => de ? 'Zeile ${index + 1}' : 'row ${index + 1}',
      SolveUnitKind.column =>
        de ? 'Spalte ${index + 1}' : 'column ${index + 1}',
      SolveUnitKind.region =>
        de ? 'Region ${index + 1}' : 'region ${index + 1}',
      SolveUnitKind.mainDiagonal =>
        de ? 'der Hauptdiagonale' : 'the main diagonal',
      SolveUnitKind.antiDiagonal =>
        de ? 'der Gegendiagonale' : 'the anti-diagonal',
    };
  }
}

class HiddenSingleMessage extends SolveMessage {
  const HiddenSingleMessage(this.row, this.col, this.value, this.unit);
  final int row;
  final int col;
  final int value;
  final SolveUnit unit;

  @override
  String localize([String languageCode = 'en']) {
    final l = SolveLocalizations(languageCode);
    final cell = l.cell(row, col);
    final name = unit.localize(languageCode);
    return l.isGerman
        ? '$cell ist die einzige Zelle in $name, in der $value stehen kann — versteckter Einer.'
        : '$cell is the only cell in $name that can be $value — hidden single.';
  }
}

class LockedCandidatesMessage extends SolveMessage {
  const LockedCandidatesMessage({
    required this.value,
    required this.region,
    required this.line,
    required this.isRow,
    required this.pointing,
  });
  final int value;
  final int region;
  final int line;
  final bool isRow;
  final bool pointing;

  @override
  String localize([String languageCode = 'en']) {
    final de = SolveLocalizations(languageCode).isGerman;
    final axis = de ? (isRow ? 'Zeile' : 'Spalte') : (isRow ? 'row' : 'column');
    if (pointing) {
      return de
          ? 'In Region ${region + 1} kommt $value nur in $axis ${line + 1} als Kandidat vor (Pointing); $value wurde außerhalb der Region aus dieser $axis entfernt.'
          : 'In region ${region + 1}, $value only appears in $axis ${line + 1} (pointing); removed $value from that $axis outside the region.';
    }
    return de
        ? 'In $axis ${line + 1} ist $value auf Region ${region + 1} beschränkt (Claiming); $value wurde aus den übrigen Zellen dieser Region entfernt.'
        : 'In $axis ${line + 1}, $value is confined to region ${region + 1} (claiming); removed $value from the rest of that region.';
  }
}

enum SubsetKind { nakedPair, nakedTriple, hiddenPair }

class SubsetMessage extends SolveMessage {
  SubsetMessage({
    required this.kind,
    required List<List<int>> cells,
    required List<int> candidates,
    required this.unit,
  }) : cells = List.unmodifiable(cells.map((c) => List<int>.unmodifiable(c))),
       candidates = List.unmodifiable(candidates);
  final SubsetKind kind;
  final List<List<int>> cells;
  final List<int> candidates;
  final SolveUnit unit;

  @override
  String localize([String languageCode = 'en']) {
    final l = SolveLocalizations(languageCode);
    final coords = cells.map((c) => l.cell(c[0], c[1])).toList();
    final and = l.isGerman ? 'und' : 'and';
    final locations =
        '${coords.take(coords.length - 1).join(', ')} $and ${coords.last}';
    final name = unit.localize(languageCode);
    if (kind == SubsetKind.hiddenPair) {
      return l.isGerman
          ? 'Die Zahlen ${candidates[0]} und ${candidates[1]} sind in $name auf $locations beschränkt (verstecktes Paar); andere Kandidaten wurden aus diesen Zellen entfernt.'
          : 'Values ${candidates[0]} and ${candidates[1]} are confined to $locations in $name (hidden pair); removed other candidates from those cells.';
    }
    final triple = kind == SubsetKind.nakedTriple;
    final technique = l.isGerman
        ? (triple ? 'nacktes Tripel' : 'nacktes Paar')
        : (triple ? 'naked triple' : 'naked pair');
    final values = candidates.join(',');
    return l.isGerman
        ? '$locations bilden ein $technique ($values) in $name; diese Kandidaten wurden aus den übrigen Zellen der Einheit entfernt.'
        : '$locations form a $technique ($values) in $name; removed those from the rest of the unit.';
  }
}

class XWingMessage extends SolveMessage {
  const XWingMessage({
    required this.value,
    required this.row1,
    required this.row2,
    required this.col1,
    required this.col2,
    required this.rowBased,
  });
  final int value;
  final int row1;
  final int row2;
  final int col1;
  final int col2;
  final bool rowBased;

  @override
  String localize([String languageCode = 'en']) {
    final de = SolveLocalizations(languageCode).isGerman;
    if (rowBased) {
      return de
          ? 'X-Wing für $value: In den Zeilen ${row1 + 1} und ${row2 + 1} ist $value auf die Spalten ${col1 + 1} und ${col2 + 1} beschränkt; $value wurde in den anderen Zeilen aus diesen Spalten entfernt.'
          : 'X-wing on $value: rows ${row1 + 1} and ${row2 + 1} confine it to columns ${col1 + 1} and ${col2 + 1}; removed $value from those columns in other rows.';
    }
    return de
        ? 'X-Wing für $value: In den Spalten ${col1 + 1} und ${col2 + 1} ist $value auf die Zeilen ${row1 + 1} und ${row2 + 1} beschränkt; $value wurde in den anderen Spalten aus diesen Zeilen entfernt.'
        : 'X-wing on $value: columns ${col1 + 1} and ${col2 + 1} confine it to rows ${row1 + 1} and ${row2 + 1}; removed $value from those rows in other columns.';
  }
}

class NakedSingleMessage extends SolveMessage {
  const NakedSingleMessage(this.row, this.col, this.value);
  final int row;
  final int col;
  final int value;

  @override
  String localize([String languageCode = 'en']) {
    final l = SolveLocalizations(languageCode);
    final cell = l.cell(row, col);
    return l.isGerman
        ? '$cell hat nur einen Kandidaten ($value) — nackter Einer.'
        : '$cell has only one candidate ($value) — naked single.';
  }
}
