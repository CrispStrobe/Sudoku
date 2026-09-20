/// A self-contained Killer Sudoku engine built on top of the existing
/// [SudokuGame] generator (for the base solution + box regions) and the
/// `dart_csp` solver (for cage-sum arithmetic, solving and uniqueness checks).
///
/// Killer Sudoku partitions the grid into "cages". Each cage's cells must sum
/// to a target and contain no repeated digit; the usual row/column/region
/// all-different rules also apply. Classic Killer has no given digits, but a
/// few givens are permitted (and may be added here when a pure-cage puzzle is
/// not uniquely solvable).
///
/// Pure Dart — no Flutter imports.
library;

import 'dart:math' as math;

import 'package:dart_csp/dart_csp.dart';
import 'package:sudoku/sudoku_game.dart';

/// A Killer cage: a connected set of cells that must sum to [sum] with no
/// repeated digit.
class KillerCage {
  final List<List<int>> cells; // each [row, col]
  final int sum;
  const KillerCage({required this.cells, required this.sum});

  bool contains(int row, int col) =>
      cells.any((c) => c[0] == row && c[1] == col);

  /// The cage's anchor cell (top-most, then left-most) — where the sum label
  /// is drawn.
  List<int> get labelCell {
    var best = cells.first;
    for (final c in cells) {
      if (c[0] < best[0] || (c[0] == best[0] && c[1] < best[1])) best = c;
    }
    return best;
  }

  /// True if the cage is currently inconsistent given [grid]: a repeated digit
  /// among its filled cells, its filled-cell sum already exceeds [sum], or it
  /// is fully filled but does not total [sum].
  bool hasError(List<List<int>> grid) {
    final seen = <int>{};
    var total = 0;
    var filled = 0;
    for (final cell in cells) {
      final v = grid[cell[0]][cell[1]];
      if (v == 0) continue;
      filled++;
      total += v;
      if (!seen.add(v)) return true; // repeated digit
    }
    if (total > sum) return true;
    if (filled == cells.length && total != sum) return true;
    return false;
  }

  Map<String, dynamic> toJson() => {'cells': cells, 'sum': sum};

  factory KillerCage.fromJson(Map<String, dynamic> json) {
    final cells = (json['cells'] as List)
        .map((cell) => (cell as List).cast<int>().toList())
        .toList();
    if (cells.isEmpty) {
      throw const FormatException('killer cage: no cells');
    }
    for (final cell in cells) {
      if (cell.length != 2) {
        throw const FormatException('killer cage: cell is not [row, col]');
      }
    }
    return KillerCage(cells: cells, sum: json['sum'] as int);
  }

  /// True when every cell is filled with distinct digits summing to [sum].
  bool isSatisfied(List<List<int>> grid) {
    final seen = <int>{};
    var total = 0;
    for (final cell in cells) {
      final v = grid[cell[0]][cell[1]];
      if (v == 0) return false;
      if (!seen.add(v)) return false;
      total += v;
    }
    return total == sum;
  }
}

/// The arithmetic a KenKen cage applies to its digits.
///
/// `none` is a one-cell cage: the clue is just the digit. Subtraction and
/// division are order-independent and restricted to two cells — `3-` means the
/// two digits differ by three, either way round — which is the standard rule
/// and the only one that makes an unordered cage well defined.
enum KenKenOp { none, add, subtract, multiply, divide }

extension KenKenOpSymbol on KenKenOp {
  String get symbol => switch (this) {
    KenKenOp.none => '',
    KenKenOp.add => '+',
    KenKenOp.subtract => '−',
    KenKenOp.multiply => '×',
    KenKenOp.divide => '÷',
  };

  /// Cage sizes this operation accepts.
  bool acceptsCellCount(int n) => switch (this) {
    KenKenOp.none => n == 1,
    KenKenOp.add || KenKenOp.multiply => n >= 2,
    KenKenOp.subtract || KenKenOp.divide => n == 2,
  };
}

/// A KenKen cage: connected cells whose digits combine under [op] to [target].
///
/// Note what is *absent*: a cage does not forbid repeated digits, unlike a
/// Killer cage. Two cells of the same cage may hold the same digit as long as
/// they are in different rows and columns, because in KenKen the only
/// all-different rules are the row and the column. Getting this wrong makes
/// perfectly good puzzles look unsolvable.
class KenKenCage {
  final List<List<int>> cells; // each [row, col]
  final KenKenOp op;
  final int target;
  const KenKenCage({
    required this.cells,
    required this.op,
    required this.target,
  });

  bool contains(int row, int col) =>
      cells.any((c) => c[0] == row && c[1] == col);

  /// The cell the clue is written in: top-most, then left-most.
  List<int> get labelCell {
    var best = cells.first;
    for (final c in cells) {
      if (c[0] < best[0] || (c[0] == best[0] && c[1] < best[1])) best = c;
    }
    return best;
  }

  /// `12+`, `3−`, `2÷`, or just `5` for a one-cell cage.
  String get clue => op == KenKenOp.none ? '$target' : '$target${op.symbol}';

  /// Apply [op] to [values]; null when the combination is not valid for it
  /// (a division that does not divide evenly, say).
  static int? combine(KenKenOp op, List<int> values) {
    switch (op) {
      case KenKenOp.none:
        return values.length == 1 ? values.first : null;
      case KenKenOp.add:
        return values.reduce((a, b) => a + b);
      case KenKenOp.multiply:
        return values.reduce((a, b) => a * b);
      case KenKenOp.subtract:
        if (values.length != 2) return null;
        return (values[0] - values[1]).abs();
      case KenKenOp.divide:
        if (values.length != 2) return null;
        final hi = math.max(values[0], values[1]);
        final lo = math.min(values[0], values[1]);
        if (lo == 0 || hi % lo != 0) return null;
        return hi ~/ lo;
    }
  }

  /// True when every cell is filled and the arithmetic comes out.
  bool isSatisfied(List<List<int>> grid) {
    final values = <int>[];
    for (final cell in cells) {
      final v = grid[cell[0]][cell[1]];
      if (v == 0) return false;
      values.add(v);
    }
    return combine(op, values) == target;
  }

  /// True when the cage is already provably wrong.
  ///
  /// A partially filled cage is usually not decidable, so this is deliberately
  /// conservative: it reports an error only where one is certain. Addition and
  /// multiplication overshoot monotonically (every digit is at least one), so
  /// a running total past the target is final; the two-cell operations can only
  /// be judged once both cells are filled.
  bool hasError(List<List<int>> grid) {
    final values = <int>[];
    var filled = 0;
    for (final cell in cells) {
      final v = grid[cell[0]][cell[1]];
      if (v != 0) {
        filled++;
        values.add(v);
      }
    }
    if (filled == cells.length) return combine(op, values) != target;
    if (filled == 0) return false;
    switch (op) {
      case KenKenOp.add:
        // The remaining cells add at least one each.
        return values.fold(0, (a, b) => a + b) + (cells.length - filled) >
            target;
      case KenKenOp.multiply:
        final product = values.fold(1, (a, b) => a * b);
        return product > target || target % product != 0;
      case KenKenOp.none:
      case KenKenOp.subtract:
      case KenKenOp.divide:
        return false;
    }
  }

  Map<String, dynamic> toJson() => {
    'cells': cells,
    'op': op.name,
    'target': target,
  };

  factory KenKenCage.fromJson(Map<String, dynamic> json) {
    final cells = (json['cells'] as List)
        .map((cell) => (cell as List).cast<int>().toList())
        .toList();
    if (cells.isEmpty) {
      throw const FormatException('kenken cage: no cells');
    }
    for (final cell in cells) {
      if (cell.length != 2) {
        throw const FormatException('kenken cage: cell is not [row, col]');
      }
    }
    final op = KenKenOp.values.byName(json['op'] as String);
    if (!op.acceptsCellCount(cells.length)) {
      throw FormatException(
        'kenken cage: ${op.name} does not take ${cells.length} cells',
      );
    }
    return KenKenCage(cells: cells, op: op, target: json['target'] as int);
  }
}

/// True if every cage in [cages] is satisfied for [grid] (the extra win
/// condition for KenKen, on top of the standard full-and-consistent check).
bool kenKenCagesSatisfied(List<KenKenCage> cages, List<List<int>> grid) =>
    cages.every((cage) => cage.isSatisfied(grid));

/// A generated KenKen puzzle.
///
/// There is no `regions` field, and that absence is the whole variant: KenKen
/// is a Latin square with arithmetic cages, and has no boxes at all. The screen
/// passes row indices where the engine wants regions, which makes the engine's
/// region rule a duplicate of its row rule and therefore a no-op — see
/// `latinRegions`.
class KenKenPuzzle {
  final int gridDim;
  final List<KenKenCage> cages;
  final List<List<int>> givens;
  final List<List<int>> solution;
  const KenKenPuzzle({
    required this.gridDim,
    required this.cages,
    required this.givens,
    required this.solution,
  });

  /// A `regions` grid that encodes "no regions".
  ///
  /// The engine and the saved-game schema both insist on one region id per
  /// cell, with each region holding exactly `gridDim` cells. Numbering every
  /// cell by its row satisfies that and makes the region all-different
  /// identical to the row all-different the engine already applies — a
  /// constraint that is always trivially met, which is exactly what a variant
  /// with no boxes needs.
  static List<List<int>> latinRegions(int gridDim) => [
    for (var r = 0; r < gridDim; r++) List<int>.filled(gridDim, r),
  ];

  List<List<int>> get regions => latinRegions(gridDim);

  Map<String, dynamic> toJson() => {
    'gridDim': gridDim,
    'cages': [for (final c in cages) c.toJson()],
    'givens': givens,
    'solution': solution,
  };

  /// Rebuild from [json], validating hard enough that a corrupt or hand-edited
  /// bundle entry is rejected rather than played.
  factory KenKenPuzzle.fromJson(Map<String, dynamic> json) {
    final gridDim = json['gridDim'] as int;
    List<List<int>> grid(String key) => (json[key] as List)
        .map((row) => (row as List).cast<int>().toList())
        .toList();

    final puzzle = KenKenPuzzle(
      gridDim: gridDim,
      cages: [
        for (final c in json['cages'] as List)
          KenKenCage.fromJson(c as Map<String, dynamic>),
      ],
      givens: grid('givens'),
      solution: grid('solution'),
    );

    for (final g in [puzzle.givens, puzzle.solution]) {
      if (g.length != gridDim || g.any((row) => row.length != gridDim)) {
        throw const FormatException('kenken puzzle: wrong dimensions');
      }
    }
    // The cages must partition the grid, and each must be connected — a cage
    // drawn in two pieces is not a cage.
    final covered = List.generate(
      gridDim,
      (_) => List<bool>.filled(gridDim, false),
    );
    for (final cage in puzzle.cages) {
      for (final cell in cage.cells) {
        final r = cell[0], c = cell[1];
        if (r < 0 || r >= gridDim || c < 0 || c >= gridDim) {
          throw const FormatException('kenken puzzle: cage cell out of range');
        }
        if (covered[r][c]) {
          throw const FormatException('kenken puzzle: cages overlap');
        }
        covered[r][c] = true;
      }
      if (!_connected(cage.cells)) {
        throw const FormatException('kenken puzzle: cage is not connected');
      }
      if (!cage.isSatisfied(puzzle.solution)) {
        throw const FormatException(
          'kenken puzzle: a cage does not hold for its own solution',
        );
      }
    }
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        if (!covered[r][c]) {
          throw const FormatException('kenken puzzle: cages leave a gap');
        }
        final value = puzzle.solution[r][c];
        if (value < 1 || value > gridDim) {
          throw const FormatException('kenken puzzle: bad solution value');
        }
        final given = puzzle.givens[r][c];
        if (given != 0 && given != value) {
          throw const FormatException('kenken puzzle: given != solution');
        }
      }
    }
    // A Latin square: every row and column holds each digit once.
    for (var i = 0; i < gridDim; i++) {
      final row = <int>{}, col = <int>{};
      for (var j = 0; j < gridDim; j++) {
        if (!row.add(puzzle.solution[i][j]) ||
            !col.add(puzzle.solution[j][i])) {
          throw const FormatException(
            'kenken puzzle: solution is not a Latin square',
          );
        }
      }
    }
    return puzzle;
  }

  static bool _connected(List<List<int>> cells) {
    if (cells.length <= 1) return true;
    final remaining = {for (final c in cells) '${c[0]},${c[1]}'};
    final queue = <List<int>>[cells.first];
    remaining.remove('${cells.first[0]},${cells.first[1]}');
    while (queue.isNotEmpty) {
      final cell = queue.removeLast();
      for (final d in const [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ]) {
        final key = '${cell[0] + d[0]},${cell[1] + d[1]}';
        if (remaining.remove(key)) {
          queue.add([cell[0] + d[0], cell[1] + d[1]]);
        }
      }
    }
    return remaining.isEmpty;
  }
}

/// A thermometer: an ordered path of cells whose digits strictly increase from
/// the bulb (`cells.first`) to the tip (`cells.last`).
///
/// Unlike a Killer cage, a thermometer is *ordered* — reversing it is a
/// different constraint — and it carries no arithmetic, only comparisons. That
/// makes it the cheapest interesting variant to add: one `addStrictlyAscending`
/// per line and the existing pipeline does the rest.
class ThermoLine {
  final List<List<int>> cells; // each [row, col], bulb first
  const ThermoLine(this.cells);

  /// The bulb, drawn as a filled disc.
  List<int> get bulb => cells.first;

  bool contains(int row, int col) =>
      cells.any((c) => c[0] == row && c[1] == col);

  /// True if the filled cells so far already break the increase — a strictly
  /// increasing sequence read left to right, ignoring gaps.
  ///
  /// Gaps matter: with cells `[_, 5, _, 3]` the 3 is already wrong even though
  /// the cells between them are empty, because everything after the 5 must
  /// exceed it. Comparing only adjacent *filled* pairs catches exactly that.
  bool hasError(List<List<int>> grid) {
    var previous = 0;
    var previousIndex = -1;
    for (var i = 0; i < cells.length; i++) {
      final v = grid[cells[i][0]][cells[i][1]];
      if (v == 0) continue;
      if (previousIndex >= 0) {
        // Each step along the path must add at least one, so cells that are
        // `gap` apart must differ by at least `gap`.
        if (v - previous < i - previousIndex) return true;
      }
      previous = v;
      previousIndex = i;
    }
    return false;
  }

  /// True when every cell is filled and strictly increasing bulb to tip.
  bool isSatisfied(List<List<int>> grid) {
    var previous = 0;
    for (final cell in cells) {
      final v = grid[cell[0]][cell[1]];
      if (v == 0 || v <= previous) return false;
      previous = v;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {'cells': cells};

  factory ThermoLine.fromJson(Map<String, dynamic> json) {
    final cells = (json['cells'] as List)
        .map((cell) => (cell as List).cast<int>().toList())
        .toList();
    if (cells.length < 2) {
      throw const FormatException('thermometer: needs at least two cells');
    }
    for (final cell in cells) {
      if (cell.length != 2) {
        throw const FormatException('thermometer: cell is not [row, col]');
      }
    }
    return ThermoLine(cells);
  }
}

/// True if every thermometer in [thermos] is satisfied for [grid] (the extra
/// win condition for Thermo, on top of the standard full-and-consistent check).
bool thermosSatisfied(List<ThermoLine> thermos, List<List<int>> grid) =>
    thermos.every((t) => t.isSatisfied(grid));

/// A generated Thermo puzzle.
class ThermoPuzzle {
  final int gridDim;
  final List<List<int>> regions;
  final List<ThermoLine> thermos;
  final List<List<int>> givens;
  final List<List<int>> solution;
  const ThermoPuzzle({
    required this.gridDim,
    required this.regions,
    required this.thermos,
    required this.givens,
    required this.solution,
  });

  Map<String, dynamic> toJson() => {
    'gridDim': gridDim,
    'regions': regions,
    'thermos': [for (final t in thermos) t.toJson()],
    'givens': givens,
    'solution': solution,
  };

  /// Rebuild from [json], validating hard enough that a corrupt or hand-edited
  /// bundle entry is rejected rather than played.
  ///
  /// Uniqueness is *not* re-checked here: proving it costs a CSP search, which
  /// is why the bundle exists. `tool/generate_thermo_puzzles.dart` proves it
  /// once offline and `test/bundled_thermo_test.dart` proves it again in CI.
  factory ThermoPuzzle.fromJson(Map<String, dynamic> json) {
    final gridDim = json['gridDim'] as int;
    List<List<int>> grid(String key) => (json[key] as List)
        .map((row) => (row as List).cast<int>().toList())
        .toList();

    final puzzle = ThermoPuzzle(
      gridDim: gridDim,
      regions: grid('regions'),
      thermos: [
        for (final t in json['thermos'] as List)
          ThermoLine.fromJson(t as Map<String, dynamic>),
      ],
      givens: grid('givens'),
      solution: grid('solution'),
    );

    for (final g in [puzzle.regions, puzzle.givens, puzzle.solution]) {
      if (g.length != gridDim || g.any((row) => row.length != gridDim)) {
        throw const FormatException('thermo puzzle: wrong dimensions');
      }
    }
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        final value = puzzle.solution[r][c];
        if (value < 1 || value > gridDim) {
          throw const FormatException('thermo puzzle: bad solution value');
        }
        if (puzzle.regions[r][c] < 0 || puzzle.regions[r][c] >= gridDim) {
          throw const FormatException('thermo puzzle: bad region id');
        }
        final given = puzzle.givens[r][c];
        if (given != 0 && given != value) {
          throw const FormatException('thermo puzzle: given != solution');
        }
      }
    }
    // Thermometers must be orthogonally connected paths that actually
    // increase in the solution — a clue that contradicts its own answer is
    // worse than no clue.
    for (final t in puzzle.thermos) {
      for (var i = 0; i < t.cells.length; i++) {
        final cell = t.cells[i];
        if (cell[0] < 0 ||
            cell[0] >= gridDim ||
            cell[1] < 0 ||
            cell[1] >= gridDim) {
          throw const FormatException('thermo puzzle: cell out of range');
        }
        if (i > 0) {
          final previous = t.cells[i - 1];
          final dr = (cell[0] - previous[0]).abs();
          final dc = (cell[1] - previous[1]).abs();
          if (dr + dc != 1) {
            throw const FormatException('thermo puzzle: path is not connected');
          }
          if (puzzle.solution[cell[0]][cell[1]] <=
              puzzle.solution[previous[0]][previous[1]]) {
            throw const FormatException(
              'thermo puzzle: solution does not increase along a thermometer',
            );
          }
        }
      }
    }
    return puzzle;
  }
}

/// True if every cage in [cages] is satisfied for [grid] (used as the extra
/// win condition for Killer, on top of the standard full-and-consistent check).
bool cagesSatisfied(List<KillerCage> cages, List<List<int>> grid) =>
    cages.every((cage) => cage.isSatisfied(grid));

/// A generated Killer puzzle.
class KillerPuzzle {
  final int gridDim;
  final List<List<int>> regions; // box layout reused from the base game
  final List<KillerCage> cages; // partition the whole grid
  final List<List<int>> givens; // 0 = empty; usually mostly/all zero
  final List<List<int>> solution; // the unique solution
  const KillerPuzzle({
    required this.gridDim,
    required this.regions,
    required this.cages,
    required this.givens,
    required this.solution,
  });

  Map<String, dynamic> toJson() => {
    'gridDim': gridDim,
    'regions': regions,
    'cages': [for (final cage in cages) cage.toJson()],
    'givens': givens,
    'solution': solution,
  };

  /// Rebuild a puzzle from [json], validating it hard enough that a corrupt or
  /// hand-edited bundle entry is rejected rather than played.
  ///
  /// Uniqueness is *not* re-checked here — proving it costs a CSP search, which
  /// is the entire reason the bundle exists. It is checked once, offline, by
  /// `tool/generate_killer_puzzles.dart`, and again in CI by
  /// `test/bundled_killer_test.dart`.
  factory KillerPuzzle.fromJson(Map<String, dynamic> json) {
    final gridDim = json['gridDim'] as int;
    List<List<int>> grid(String key) => (json[key] as List)
        .map((row) => (row as List).cast<int>().toList())
        .toList();

    final puzzle = KillerPuzzle(
      gridDim: gridDim,
      regions: grid('regions'),
      cages: [
        for (final cage in json['cages'] as List)
          KillerCage.fromJson(cage as Map<String, dynamic>),
      ],
      givens: grid('givens'),
      solution: grid('solution'),
    );

    for (final g in [puzzle.regions, puzzle.givens, puzzle.solution]) {
      if (g.length != gridDim || g.any((row) => row.length != gridDim)) {
        throw const FormatException('killer puzzle: wrong dimensions');
      }
    }
    // The cages must partition the grid exactly: every cell in exactly one.
    final covered = List.generate(
      gridDim,
      (_) => List<bool>.filled(gridDim, false),
    );
    for (final cage in puzzle.cages) {
      var total = 0;
      for (final cell in cage.cells) {
        final r = cell[0], c = cell[1];
        if (r < 0 || r >= gridDim || c < 0 || c >= gridDim) {
          throw const FormatException('killer puzzle: cage cell out of range');
        }
        if (covered[r][c]) {
          throw const FormatException('killer puzzle: cages overlap');
        }
        covered[r][c] = true;
        total += puzzle.solution[r][c];
      }
      if (total != cage.sum) {
        throw const FormatException('killer puzzle: cage sum != solution');
      }
    }
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        if (!covered[r][c]) {
          throw const FormatException('killer puzzle: cages leave a gap');
        }
        final value = puzzle.solution[r][c];
        if (value < 1 || value > gridDim) {
          throw const FormatException('killer puzzle: bad solution value');
        }
        final given = puzzle.givens[r][c];
        if (given != 0 && given != value) {
          throw const FormatException('killer puzzle: given != solution');
        }
      }
    }
    return puzzle;
  }
}

class VariantEngine {
  VariantEngine._();

  /// Largest cage allowed when partitioning, by difficulty. Easier puzzles use
  /// smaller cages (more, tighter sum clues = easier); harder puzzles allow
  /// larger cages with more internal freedom.
  static int _maxCageSizeFor(SudokuDifficulty difficulty) {
    switch (difficulty) {
      case SudokuDifficulty.easy:
        return 2;
      case SudokuDifficulty.medium:
        return 3;
      case SudokuDifficulty.hard:
        return 4;
      case SudokuDifficulty.expert:
        return 5;
    }
  }

  // --- Constraint building (shared by solve + uniqueness) -----------------

  /// Build a [Problem] for a Killer puzzle: one variable per cell, the standard
  /// row/column/region all-different constraints, and per-cage sum +
  /// all-different constraints.
  static Problem _buildProblem({
    required int gridDim,
    required List<List<int>> regions,
    required List<KillerCage> cages,
    required List<List<int>> givens,
  }) {
    final p = Problem();
    final fullDomain = [for (var v = 1; v <= gridDim; v++) v];

    String name(int r, int c) => 'r${r}c$c';

    // One variable per cell; givens become singleton domains.
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        final g = givens[r][c];
        p.addVariable(name(r, c), g != 0 ? [g] : List<int>.from(fullDomain));
      }
    }

    // Rows and columns.
    for (var i = 0; i < gridDim; i++) {
      final rowVars = <String>[];
      final colVars = <String>[];
      for (var j = 0; j < gridDim; j++) {
        rowVars.add(name(i, j));
        colVars.add(name(j, i));
      }
      p.addAllDifferent(rowVars, label: 'row$i');
      p.addAllDifferent(colVars, label: 'col$i');
    }

    // Regions (grouped by region id).
    final regionVars = <int, List<String>>{};
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        regionVars.putIfAbsent(regions[r][c], () => <String>[]).add(name(r, c));
      }
    }
    for (final entry in regionVars.entries) {
      p.addAllDifferent(entry.value, label: 'region${entry.key}');
    }

    // Cages: exact sum, plus all-different unless the cage already lies wholly
    // within a single row, column or region (in which case the standard
    // all-different already covers it — a small optimisation).
    for (var k = 0; k < cages.length; k++) {
      final cage = cages[k];
      final cageVars = [for (final cell in cage.cells) name(cell[0], cell[1])];
      p.addExactSum(cageVars, cage.sum, label: 'cageSum$k');
      if (cageVars.length > 1 && !_sharesOneUnit(cage, regions)) {
        p.addAllDifferent(cageVars, label: 'cageDiff$k');
      }
    }

    return p;
  }

  /// True if every cell of [cage] shares the same row, the same column, or the
  /// same region — meaning a standard all-different already forbids repeats.
  static bool _sharesOneUnit(KillerCage cage, List<List<int>> regions) {
    final first = cage.cells.first;
    final sameRow = cage.cells.every((c) => c[0] == first[0]);
    final sameCol = cage.cells.every((c) => c[1] == first[1]);
    final reg0 = regions[first[0]][first[1]];
    final sameReg = cage.cells.every((c) => regions[c[0]][c[1]] == reg0);
    return sameRow || sameCol || sameReg;
  }

  /// Solve a Killer puzzle (row/col/region all-different + per-cage
  /// all-different + per-cage sum). Returns the solved grid (gridDim x gridDim)
  /// or null if infeasible. [givens] may be all-zero.
  static Future<List<List<int>>?> solveKiller({
    required int gridDim,
    required List<List<int>> regions,
    required List<KillerCage> cages,
    required List<List<int>> givens,
  }) async {
    final p = _buildProblem(
      gridDim: gridDim,
      regions: regions,
      cages: cages,
      givens: givens,
    );
    final result = await p.getSolution();
    if (result is! Map) return null; // 'FAILURE'
    final grid = List.generate(gridDim, (_) => List<int>.filled(gridDim, 0));
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        grid[r][c] = (result['r${r}c$c'] as num).toInt();
      }
    }
    return grid;
  }

  /// True iff the Killer puzzle has exactly one solution.
  static Future<bool> killerHasUniqueSolution({
    required int gridDim,
    required List<List<int>> regions,
    required List<KillerCage> cages,
    required List<List<int>> givens,
  }) async {
    final p = _buildProblem(
      gridDim: gridDim,
      regions: regions,
      cages: cages,
      givens: givens,
    );
    // Enumerate once, stopping at the second solution. Unlike negating
    // hasMultipleSolutions, this also rejects an empty (infeasible) search.
    return (await p.getFirstNSolutions(2)).length == 1;
  }

  // --- KenKen -------------------------------------------------------------

  /// Build a [Problem] for a KenKen puzzle.
  ///
  /// Rows and columns all-different — and nothing else structural, because
  /// KenKen has no boxes. Each cage then gets its arithmetic:
  ///
  /// * `+` and `×` map straight onto `addExactSum` / `addExactProduct`.
  /// * `−` and `÷` are order-independent over two cells, which no single
  ///   arithmetic constraint expresses. Enumerating the valid pairs into a
  ///   table does express it, exactly, and a table over two variables of at
  ///   most twelve values is trivially small.
  ///
  /// Note what is *not* here: no per-cage all-different. A KenKen cage may
  /// repeat a digit where the row and column rules allow it, unlike a Killer
  /// cage. Adding the Killer rule here would reject valid puzzles.
  static Problem _buildKenKenProblem({
    required int gridDim,
    required List<KenKenCage> cages,
    required List<List<int>> givens,
  }) {
    final p = Problem();
    final fullDomain = [for (var v = 1; v <= gridDim; v++) v];
    String name(int r, int c) => 'r${r}c$c';

    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        final g = givens[r][c];
        p.addVariable(name(r, c), g != 0 ? [g] : List<int>.from(fullDomain));
      }
    }
    for (var i = 0; i < gridDim; i++) {
      p.addAllDifferent([
        for (var j = 0; j < gridDim; j++) name(i, j),
      ], label: 'row$i');
      p.addAllDifferent([
        for (var j = 0; j < gridDim; j++) name(j, i),
      ], label: 'col$i');
    }

    for (var k = 0; k < cages.length; k++) {
      final cage = cages[k];
      final vars = [for (final cell in cage.cells) name(cell[0], cell[1])];
      final label = 'cage$k(${cage.clue})';
      switch (cage.op) {
        case KenKenOp.none:
          // A one-cell cage is a given by another name.
          p.addInSet(vars, {cage.target}, label: label);
        case KenKenOp.add:
          p.addExactSum(vars, cage.target, label: label);
        case KenKenOp.multiply:
          p.addExactProduct(vars, cage.target, label: label);
        case KenKenOp.subtract:
        case KenKenOp.divide:
          final tuples = <List<int>>[];
          for (var a = 1; a <= gridDim; a++) {
            for (var b = 1; b <= gridDim; b++) {
              if (KenKenCage.combine(cage.op, [a, b]) == cage.target) {
                tuples.add([a, b]);
              }
            }
          }
          p.addTable(vars, tuples, label: label);
      }
    }
    return p;
  }

  /// True if [cages] + [givens] admit exactly one completion.
  static Future<bool> kenKenHasUniqueSolution({
    required int gridDim,
    required List<KenKenCage> cages,
    required List<List<int>> givens,
  }) async {
    final p = _buildKenKenProblem(
      gridDim: gridDim,
      cages: cages,
      givens: givens,
    );
    return (await p.getFirstNSolutions(2)).length == 1;
  }

  /// Grid sizes KenKen is offered at.
  ///
  /// KenKen needs no box factorisation — it is a Latin square — so every size
  /// works by the rules. The cap is the search: with no boxes the cages carry
  /// the entire puzzle, and proving uniqueness on a 10x10 or 12x12 costs more
  /// than it is worth on a phone. Same reasoning, and the same cap, as Killer
  /// and Thermo.
  static bool kenKenSupports(GridSize size) => gridDimensionFor(size) <= 9;

  /// Largest cage the partitioner will build, by difficulty.
  ///
  /// Bigger cages mean fewer, weaker clues and more to deduce. Unlike Killer,
  /// where a large cage still pins a sum, a large KenKen cage with `×` can be
  /// satisfied many ways.
  static int _maxKenKenCageFor(SudokuDifficulty difficulty) {
    switch (difficulty) {
      case SudokuDifficulty.easy:
        return 2;
      case SudokuDifficulty.medium:
        return 3;
      case SudokuDifficulty.hard:
        return 4;
      case SudokuDifficulty.expert:
        return 5;
    }
  }

  /// A random Latin square: every digit once per row and once per column.
  ///
  /// Not a Sudoku grid — KenKen has no boxes, so the bitmask engine's
  /// blueprint would impose a structure the variant does not have. A shuffled
  /// cyclic square is the standard construction and is uniform enough for
  /// puzzle generation: start from `(r + c) mod n`, then permute the rows, the
  /// columns and the symbols independently.
  static List<List<int>> _latinSquare(int gridDim, math.Random rng) {
    final rows = [for (var i = 0; i < gridDim; i++) i]..shuffle(rng);
    final cols = [for (var i = 0; i < gridDim; i++) i]..shuffle(rng);
    final symbols = [for (var i = 1; i <= gridDim; i++) i]..shuffle(rng);
    return [
      for (var r = 0; r < gridDim; r++)
        [
          for (var c = 0; c < gridDim; c++)
            symbols[(rows[r] + cols[c]) % gridDim],
        ],
    ];
  }

  /// Partition the grid into connected cages and give each one an operation
  /// that its digits actually satisfy.
  ///
  /// The operation is chosen from those that *fit* the cage — division only
  /// where one digit divides the other, subtraction only on a pair — so the
  /// clue is always true of the solution by construction. Preferring the less
  /// common operations where they are available keeps a board from being all
  /// addition, which is the dull failure mode.
  static List<KenKenCage> _partitionKenKen({
    required int gridDim,
    required List<List<int>> solution,
    required int maxCageSize,
    required math.Random rng,
  }) {
    final used = List.generate(
      gridDim,
      (_) => List<bool>.filled(gridDim, false),
    );
    final cages = <KenKenCage>[];
    const dirs = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];

    final starts = <List<int>>[
      for (var r = 0; r < gridDim; r++)
        for (var c = 0; c < gridDim; c++) [r, c],
    ]..shuffle(rng);

    for (final start in starts) {
      if (used[start[0]][start[1]]) continue;
      final cells = <List<int>>[start];
      used[start[0]][start[1]] = true;
      // Aim for two cells minimum. A one-cell cage is a revealed digit dressed
      // up as a clue, and drawing the size uniformly from 1..max made them
      // most of the board — 37 of 59 cages on a 9x9, which is not a puzzle.
      // They still occur where a cell has no free neighbour left, which is the
      // only place they belong.
      final target = maxCageSize < 2 ? 1 : 2 + rng.nextInt(maxCageSize - 1);

      while (cells.length < target) {
        final candidates = <List<int>>[];
        for (final cell in cells) {
          for (final d in dirs) {
            final nr = cell[0] + d[0];
            final nc = cell[1] + d[1];
            if (nr < 0 || nr >= gridDim || nc < 0 || nc >= gridDim) continue;
            if (used[nr][nc]) continue;
            candidates.add([nr, nc]);
          }
        }
        if (candidates.isEmpty) break;
        final pick = candidates[rng.nextInt(candidates.length)];
        used[pick[0]][pick[1]] = true;
        cells.add(pick);
      }

      final values = [for (final c in cells) solution[c[0]][c[1]]];
      // One draw, used for both fields: calling _pickOp twice would roll the
      // operation separately from the target and label the cage with a clue
      // its own digits do not satisfy.
      final op = _pickOp(values, rng);
      cages.add(
        KenKenCage(cells: cells, op: op, target: _targetFor(op, values)),
      );
    }
    return cages;
  }

  /// Choose an operation the cage's own digits satisfy.
  static KenKenOp _pickOp(List<int> values, math.Random rng) {
    if (values.length == 1) return KenKenOp.none;
    final options = <KenKenOp>[KenKenOp.add, KenKenOp.multiply];
    if (values.length == 2) {
      options.add(KenKenOp.subtract);
      if (KenKenCage.combine(KenKenOp.divide, values) != null) {
        // Division is the rarest and most informative clue; weight it up.
        options.addAll([KenKenOp.divide, KenKenOp.divide]);
      }
      // Subtraction is likewise more telling than another sum.
      options.add(KenKenOp.subtract);
    }
    return options[rng.nextInt(options.length)];
  }

  static int _targetFor(KenKenOp op, List<int> values) =>
      KenKenCage.combine(op, values)!;

  /// Generate a uniquely-solvable KenKen puzzle.
  ///
  /// Latin square first, then cages over it — so every clue is true of the
  /// answer by construction and no layout can be contradictory. The CSP then
  /// decides whether those clues alone pin the grid down; if not, digits are
  /// revealed until they do. Classic KenKen has no givens, and small grids
  /// usually need none.
  ///
  /// Determinism: the same [seed] and limits reproduce the same puzzle.
  static Future<KenKenPuzzle> generateKenKen({
    required GridSize gridSize,
    required SudokuDifficulty difficulty,
    int? seed,
    int maxPartitionAttempts = 12,
    int? maxGivens,
  }) async {
    if (maxPartitionAttempts < 1) {
      throw ArgumentError.value(maxPartitionAttempts, 'maxPartitionAttempts');
    }
    if (maxGivens != null && maxGivens < 0) {
      throw ArgumentError.value(maxGivens, 'maxGivens');
    }
    final effectiveSeed = seed ?? math.Random().nextInt(1 << 31);
    final rng = math.Random(effectiveSeed);
    final gridDim = gridDimensionFor(gridSize);
    final solution = _latinSquare(gridDim, rng);
    final empty = List.generate(gridDim, (_) => List<int>.filled(gridDim, 0));

    List<KenKenCage>? fallback;
    for (var attempt = 0; attempt < maxPartitionAttempts; attempt++) {
      final cages = _partitionKenKen(
        gridDim: gridDim,
        solution: solution,
        maxCageSize: _maxKenKenCageFor(difficulty),
        rng: rng,
      );
      if (await kenKenHasUniqueSolution(
        gridDim: gridDim,
        cages: cages,
        givens: empty,
      )) {
        return KenKenPuzzle(
          gridDim: gridDim,
          cages: cages,
          givens: empty,
          solution: solution,
        );
      }
      fallback ??= cages;
    }

    final cages = fallback!;
    final givens = List.generate(gridDim, (_) => List<int>.filled(gridDim, 0));
    final cells = <List<int>>[
      for (var r = 0; r < gridDim; r++)
        for (var c = 0; c < gridDim; c++) [r, c],
    ]..shuffle(rng);

    var unique = false;
    for (final cell in cells.take(maxGivens ?? cells.length)) {
      givens[cell[0]][cell[1]] = solution[cell[0]][cell[1]];
      unique = await kenKenHasUniqueSolution(
        gridDim: gridDim,
        cages: cages,
        givens: givens,
      );
      if (unique) break;
    }
    if (!unique) {
      throw StateError('KenKen uniqueness not established within reveal cap');
    }

    return KenKenPuzzle(
      gridDim: gridDim,
      cages: cages,
      givens: givens,
      solution: solution,
    );
  }

  // --- Thermo -------------------------------------------------------------

  /// Build a [Problem] for a Thermo puzzle: the standard row/column/region
  /// all-different constraints plus one strictly-ascending chain per
  /// thermometer.
  ///
  /// That single `addStrictlyAscending` is the whole variant. It is also why
  /// Thermo is the cheapest one to add: no arithmetic, no new solver feature,
  /// and the same uniqueness/dig pipeline Killer already uses.
  static Problem _buildThermoProblem({
    required int gridDim,
    required List<List<int>> regions,
    required List<ThermoLine> thermos,
    required List<List<int>> givens,
  }) {
    final p = Problem();
    final fullDomain = [for (var v = 1; v <= gridDim; v++) v];
    String name(int r, int c) => 'r${r}c$c';

    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        final g = givens[r][c];
        p.addVariable(name(r, c), g != 0 ? [g] : List<int>.from(fullDomain));
      }
    }
    for (var i = 0; i < gridDim; i++) {
      final rowVars = <String>[];
      final colVars = <String>[];
      for (var j = 0; j < gridDim; j++) {
        rowVars.add(name(i, j));
        colVars.add(name(j, i));
      }
      p.addAllDifferent(rowVars, label: 'row$i');
      p.addAllDifferent(colVars, label: 'col$i');
    }
    final regionVars = <int, List<String>>{};
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        regionVars.putIfAbsent(regions[r][c], () => <String>[]).add(name(r, c));
      }
    }
    for (final entry in regionVars.entries) {
      p.addAllDifferent(entry.value, label: 'region${entry.key}');
    }
    for (var i = 0; i < thermos.length; i++) {
      p.addStrictlyAscending([
        for (final cell in thermos[i].cells) name(cell[0], cell[1]),
      ], label: 'thermo$i');
    }
    return p;
  }

  /// True if [thermos] + [givens] admit exactly one completion.
  static Future<bool> thermoHasUniqueSolution({
    required int gridDim,
    required List<List<int>> regions,
    required List<ThermoLine> thermos,
    required List<List<int>> givens,
  }) async {
    final p = _buildThermoProblem(
      gridDim: gridDim,
      regions: regions,
      thermos: thermos,
      givens: givens,
    );
    return (await p.getFirstNSolutions(2)).length == 1;
  }

  /// Longest thermometer allowed, by difficulty.
  ///
  /// This runs opposite to Killer's cage size. A long thermometer is a *strong*
  /// clue — a five-cell line in a 9x9 pins its bulb to at most 5 and its tip to
  /// at least 5 before a single digit is written — so long lines make an easier
  /// board and short ones a harder board, at the same coverage.
  static int _maxThermoLengthFor(SudokuDifficulty difficulty) {
    switch (difficulty) {
      case SudokuDifficulty.easy:
        return 5;
      case SudokuDifficulty.medium:
        return 4;
      case SudokuDifficulty.hard:
        return 4;
      case SudokuDifficulty.expert:
        return 3;
    }
  }

  /// Default layout attempts before falling back to a board with givens.
  ///
  /// Generous on purpose. Every attempt that fails costs one enumeration, but
  /// these boards are generated offline into `assets/thermo_puzzles.json` and
  /// served instantly — the same trade the Killer bundle makes, where a single
  /// 9x9 expert board took up to 474 seconds to prove. Spending a minute here
  /// to ship a no-givens board is the right way round.
  static int _thermoLayoutAttemptsFor(int gridDim) {
    // Phase 1 (draw shapes, let the solver find a grid) almost always wins on a
    // small board and almost never on a 9x9, where a random layout over
    // eighty-one cells is nearly always contradictory. Each failed attempt
    // there costs a full enumeration — measured at ~20 seconds — so twenty-five
    // of them is nine minutes spent to reach the fallback anyway. Spend the
    // attempts where they pay.
    if (gridDim <= 6) return 30;
    if (gridDim <= 8) return 12;
    return 6;
  }

  /// Grid sizes Thermo is offered at.
  ///
  /// Capped at 9x9, like Killer, and for a related reason: an
  /// under-constrained layout makes the uniqueness check *enumerate*, and on a
  /// 10x10 or 12x12 that search stops being bounded in any useful way — 25
  /// seconds and still counting, against under a second at 9x9. The cap is a
  /// property of the search, not of the rules.
  static bool thermoSupports(GridSize size) => gridDimensionFor(size) <= 9;

  /// How much of the grid to cover with thermometers, by difficulty.
  ///
  /// Kept high everywhere, and the range is narrow on purpose. Thinning the
  /// coverage to make a board "harder" is a trap: fewer thermometers means less
  /// constraint, which means the generator has to reveal more digits to reach a
  /// unique solution — and a Thermo puzzle with thirty-five givens is not a
  /// hard Thermo puzzle, it is a classic puzzle with decoration.
  ///
  /// These numbers come from sweeping coverage against line length on real 9x9
  /// boards (`debugGenerateThermo`). Around 0.8 coverage with four-cell lines
  /// is the configuration that reliably produces a board with **no givens at
  /// all**; push either much higher and most layouts come out contradictory.
  static double _thermoCoverageFor(SudokuDifficulty difficulty) {
    switch (difficulty) {
      case SudokuDifficulty.easy:
        return 0.85;
      case SudokuDifficulty.medium:
        return 0.8;
      case SudokuDifficulty.hard:
        return 0.72;
      case SudokuDifficulty.expert:
        return 0.65;
    }
  }

  /// Lay thermometer *shapes* with no reference to any grid: orthogonally
  /// connected paths of 2..[maxLength] cells covering roughly [coverage] of the
  /// board, never overlapping.
  ///
  /// This is how these puzzles are built by hand — the lines are the model, and
  /// the grid is whatever satisfies them — and it is the only way to get the
  /// no-givens boards the variant is known for. The catch is that a randomly
  /// drawn layout is often contradictory, so the caller has to be willing to
  /// throw one away and draw another.
  static List<ThermoLine> _drawThermoShapes({
    required int gridDim,
    required int maxLength,
    required double coverage,
    required math.Random rng,
  }) {
    final used = List.generate(
      gridDim,
      (_) => List<bool>.filled(gridDim, false),
    );
    final thermos = <ThermoLine>[];
    const dirs = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];
    final starts = <List<int>>[
      for (var r = 0; r < gridDim; r++)
        for (var c = 0; c < gridDim; c++) [r, c],
    ]..shuffle(rng);

    final cap = math.min(maxLength, gridDim);
    final target = (gridDim * gridDim * coverage).round();
    var covered = 0;

    for (final start in starts) {
      if (covered >= target) break;
      if (used[start[0]][start[1]]) continue;
      final cells = <List<int>>[start];
      used[start[0]][start[1]] = true;
      final limit = 2 + rng.nextInt(math.max(1, cap - 1));
      while (cells.length < limit) {
        final head = cells.last;
        final options = <List<int>>[];
        for (final d in dirs) {
          final nr = head[0] + d[0];
          final nc = head[1] + d[1];
          if (nr < 0 || nr >= gridDim || nc < 0 || nc >= gridDim) continue;
          if (used[nr][nc]) continue;
          options.add([nr, nc]);
        }
        if (options.isEmpty) break;
        final pick = options[rng.nextInt(options.length)];
        used[pick[0]][pick[1]] = true;
        cells.add(pick);
      }
      if (cells.length < 2) {
        used[start[0]][start[1]] = false;
        continue;
      }
      thermos.add(ThermoLine(cells));
      covered += cells.length;
    }
    return thermos;
  }

  /// Lay thermometers over [solution]: orthogonally connected paths whose
  /// digits strictly increase, so the puzzle's own answer satisfies every line
  /// it draws.
  ///
  /// Two approaches were tried and measured before this one.
  ///
  /// *Shapes first* — draw paths with no reference to any grid and let the CSP
  /// find a grid that fits — is how these puzzles are constructed by hand, and
  /// it does produce genuine no-givens boards. But most random layouts turn out
  /// contradictory, and deciding that costs a full enumeration each time: at
  /// 9x9 with five-cell lines every attempt failed, at 40 seconds apiece.
  ///
  /// *Greedy walk over a solution* is always satisfiable and fast, but a random
  /// Latin square has few long ascending runs, so it produced two-cell stubs
  /// and a board needing thirty givens.
  ///
  /// This keeps the guarantee and fixes the stubs: search for the **longest**
  /// ascending path from each bulb rather than taking the first step that
  /// works. Branching is at most three after the first cell and depth is capped
  /// at [maxLength], so the whole search is a few hundred steps per bulb and
  /// disappears next to one CSP call.
  static List<ThermoLine> _layThermos({
    required int gridDim,
    required List<List<int>> solution,
    required int maxLength,
    required double coverage,
    required math.Random rng,
  }) {
    final used = List.generate(
      gridDim,
      (_) => List<bool>.filled(gridDim, false),
    );
    final thermos = <ThermoLine>[];
    const dirs = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];

    // Bulbs hold the smallest digit on their line, so starting at low digits
    // leaves the most room to climb. Shuffle first so equal digits are still
    // visited in a seed-dependent order.
    final starts = <List<int>>[
      for (var r = 0; r < gridDim; r++)
        for (var c = 0; c < gridDim; c++) [r, c],
    ]..shuffle(rng);
    starts.sort((a, b) => solution[a[0]][a[1]].compareTo(solution[b[0]][b[1]]));

    final cap = math.min(maxLength, gridDim);
    final target = (gridDim * gridDim * coverage).round();
    var covered = 0;

    for (final start in starts) {
      if (covered >= target) break;
      if (used[start[0]][start[1]]) continue;

      // Depth-first search for the longest strictly ascending path, taking the
      // neighbours in a seed-dependent order so two runs with different seeds
      // pick different lines of the same length.
      final path = <List<int>>[start];
      var best = <List<int>>[start];

      void explore() {
        if (path.length > best.length) best = List.of(path);
        if (path.length >= cap) return;
        final head = path.last;
        final value = solution[head[0]][head[1]];
        final options = <List<int>>[];
        for (final d in dirs) {
          final nr = head[0] + d[0];
          final nc = head[1] + d[1];
          if (nr < 0 || nr >= gridDim || nc < 0 || nc >= gridDim) continue;
          if (used[nr][nc]) continue;
          if (solution[nr][nc] <= value) continue;
          options.add([nr, nc]);
        }
        options.shuffle(rng);
        for (final option in options) {
          used[option[0]][option[1]] = true;
          path.add(option);
          explore();
          path.removeLast();
          used[option[0]][option[1]] = false;
        }
      }

      used[start[0]][start[1]] = true;
      explore();

      // A one-cell "thermometer" constrains nothing; give the cell back.
      if (best.length < 2) {
        used[start[0]][start[1]] = false;
        continue;
      }
      for (final cell in best) {
        used[cell[0]][cell[1]] = true;
      }
      thermos.add(ThermoLine(best));
      covered += best.length;
    }

    return thermos;
  }

  /// Generate a uniquely-solvable Thermo puzzle.
  ///
  /// Build a full solution with the bitmask engine, lay thermometers over it
  /// (always satisfiable, by construction), then ask the CSP whether those
  /// lines alone pin the grid down. If they do the board ships with no givens
  /// at all, which is what a Thermo puzzle is supposed to look like; if they
  /// do not, reveal digits until it does.
  ///
  /// Determinism: the same [seed] and limits reproduce the same puzzle.
  static Future<ThermoPuzzle> generateThermo({
    required GridSize gridSize,
    required SudokuDifficulty difficulty,
    int? seed,
    int? maxLayoutAttempts,
    int? maxGivens,
  }) {
    maxLayoutAttempts ??= _thermoLayoutAttemptsFor(gridDimensionFor(gridSize));
    if (maxLayoutAttempts < 1) {
      throw ArgumentError.value(maxLayoutAttempts, 'maxLayoutAttempts');
    }
    if (maxGivens != null && maxGivens < 0) {
      throw ArgumentError.value(maxGivens, 'maxGivens');
    }
    return _generateThermo(
      gridSize: gridSize,
      seed: seed ?? math.Random().nextInt(1 << 31),
      maxLength: _maxThermoLengthFor(difficulty),
      coverage: _thermoCoverageFor(difficulty),
      maxLayoutAttempts: maxLayoutAttempts,
      maxGivens: maxGivens,
    );
  }

  static Future<ThermoPuzzle> _generateThermo({
    required GridSize gridSize,
    required int seed,
    required int maxLength,
    required double coverage,
    required int maxLayoutAttempts,
    int? maxGivens,
  }) async {
    final rng = math.Random(seed);
    final gridDim = gridDimensionFor(gridSize);
    final base = SudokuGame.generateBlueprint(
      gridSize,
      GridShape.classic,
      seed: seed,
    );
    final solution = base.solutionGrid;
    final regions = base.regions;
    final empty = List.generate(gridDim, (_) => List<int>.filled(gridDim, 0));

    // Phase 1: draw shapes and let the solver find a grid for them. When a
    // layout is both satisfiable and unique this yields a board with no givens
    // at all — the real thing. Most draws are contradictory, so try several;
    // each rejection costs one enumeration and is quick.
    for (var attempt = 0; attempt < maxLayoutAttempts; attempt++) {
      final thermos = _drawThermoShapes(
        gridDim: gridDim,
        maxLength: maxLength,
        coverage: coverage,
        rng: rng,
      );
      final drawn = await _buildThermoProblem(
        gridDim: gridDim,
        regions: regions,
        thermos: thermos,
        givens: empty,
      ).getFirstNSolutions(2);
      if (drawn.length == 1) {
        return ThermoPuzzle(
          gridDim: gridDim,
          regions: regions,
          thermos: thermos,
          givens: empty,
          solution: [
            for (var r = 0; r < gridDim; r++)
              [
                for (var c = 0; c < gridDim; c++)
                  drawn.first['r${r}c$c'] as int,
              ],
          ],
        );
      }
    }

    // Phase 2: the guaranteed route. Lay lines over a solution we already have,
    // so the layout cannot be contradictory, and buy uniqueness with revealed
    // digits. Weaker as a puzzle — a Thermo board wants few givens — but it
    // always terminates, which phase 1 cannot promise.
    List<ThermoLine>? fallback;
    for (var attempt = 0; attempt < maxLayoutAttempts; attempt++) {
      final thermos = _layThermos(
        gridDim: gridDim,
        solution: solution,
        maxLength: maxLength,
        coverage: coverage,
        rng: rng,
      );
      if (await thermoHasUniqueSolution(
        gridDim: gridDim,
        regions: regions,
        thermos: thermos,
        givens: empty,
      )) {
        return ThermoPuzzle(
          gridDim: gridDim,
          regions: regions,
          thermos: thermos,
          givens: empty,
          solution: solution,
        );
      }
      // Keep the layout covering the most cells: more constraint means fewer
      // digits have to be given away below.
      if (fallback == null ||
          thermos.fold<int>(0, (n, t) => n + t.cells.length) >
              fallback.fold<int>(0, (n, t) => n + t.cells.length)) {
        fallback = thermos;
      }
    }

    final thermos = fallback!;
    final givens = List.generate(gridDim, (_) => List<int>.filled(gridDim, 0));
    final cells = <List<int>>[
      for (var r = 0; r < gridDim; r++)
        for (var c = 0; c < gridDim; c++) [r, c],
    ]..shuffle(rng);

    var unique = false;
    for (final cell in cells.take(maxGivens ?? cells.length)) {
      givens[cell[0]][cell[1]] = solution[cell[0]][cell[1]];
      unique = await thermoHasUniqueSolution(
        gridDim: gridDim,
        regions: regions,
        thermos: thermos,
        givens: givens,
      );
      if (unique) break;
    }
    if (!unique) {
      throw StateError('Thermo uniqueness not established within reveal cap');
    }

    return ThermoPuzzle(
      gridDim: gridDim,
      regions: regions,
      thermos: thermos,
      givens: givens,
      solution: solution,
    );
  }

  // --- Cage generation ----------------------------------------------------

  /// Greedily partition the whole grid into connected cages of size
  /// 1..[maxCageSize], each free of repeated solution-digits. Deterministic for
  /// a given [rng]. Returns the cage list with sums computed from [solution].
  static List<KillerCage> _partition({
    required int gridDim,
    required List<List<int>> solution,
    required int maxCageSize,
    required math.Random rng,
  }) {
    final used = List.generate(
      gridDim,
      (_) => List<bool>.filled(gridDim, false),
    );
    final cages = <KillerCage>[];

    const dirs = [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ];

    for (var r0 = 0; r0 < gridDim; r0++) {
      for (var c0 = 0; c0 < gridDim; c0++) {
        if (used[r0][c0]) continue;

        final cells = <List<int>>[
          [r0, c0],
        ];
        final digits = <int>{solution[r0][c0]};
        used[r0][c0] = true;

        final target = 1 + rng.nextInt(maxCageSize);
        while (cells.length < target) {
          // Collect all unused orthogonal neighbours of the current cage whose
          // digit does not already appear in the cage.
          final candidates = <List<int>>[];
          for (final cell in cells) {
            for (final d in dirs) {
              final nr = cell[0] + d[0];
              final nc = cell[1] + d[1];
              if (nr < 0 || nr >= gridDim || nc < 0 || nc >= gridDim) continue;
              if (used[nr][nc]) continue;
              if (digits.contains(solution[nr][nc])) continue;
              candidates.add([nr, nc]);
            }
          }
          if (candidates.isEmpty) break;
          final pick = candidates[rng.nextInt(candidates.length)];
          used[pick[0]][pick[1]] = true;
          cells.add(pick);
          digits.add(solution[pick[0]][pick[1]]);
        }

        var sum = 0;
        for (final cell in cells) {
          sum += solution[cell[0]][cell[1]];
        }
        cages.add(KillerCage(cells: cells, sum: sum));
      }
    }

    return cages;
  }

  /// Generate a uniquely-solvable Killer puzzle. Reuses [SudokuGame.generateBlueprint]
  /// for the base solution + regions, partitions the grid into connected cages,
  /// computes each cage sum from the solution, and verifies uniqueness via
  /// dart_csp. If a pure-cage puzzle is not unique, it re-rolls the partition a
  /// few times and then, if still ambiguous, reveals a few random cells as
  /// givens until unique. Throws [StateError] rather than returning an unproven
  /// puzzle when an explicit [maxGivens] is exhausted. By default all cells
  /// may be revealed, guaranteeing eventual uniqueness for the valid base
  /// solution. [maxPartitionAttempts] must be at least one; [maxGivens], when
  /// supplied, must be nonnegative. These limits bound partition retries and
  /// clue reveals, not the duration of each CSP search.
  ///
  /// Determinism: the same [seed] and limits reproduce the same puzzle.
  static Future<KillerPuzzle> generateKiller({
    required GridSize gridSize,
    required SudokuDifficulty difficulty,
    int? seed,
    int maxPartitionAttempts = 12,
    int? maxGivens,
  }) async {
    if (maxPartitionAttempts < 1) {
      throw ArgumentError.value(maxPartitionAttempts, 'maxPartitionAttempts');
    }
    if (maxGivens != null && maxGivens < 0) {
      throw ArgumentError.value(maxGivens, 'maxGivens');
    }
    final effectiveSeed = seed ?? math.Random().nextInt(1 << 31);
    final rng = math.Random(effectiveSeed);

    // Base full solution + box regions (reuse the existing engine).
    final base = SudokuGame.generateBlueprint(
      gridSize,
      GridShape.classic,
      seed: effectiveSeed,
    );
    final gridDim = gridDimensionFor(gridSize);
    final solution = base.solutionGrid;
    final regions = base.regions;
    final maxCageSize = _maxCageSizeFor(difficulty);

    final empty = List.generate(gridDim, (_) => List<int>.filled(gridDim, 0));

    // Phase 1: try several pure-cage partitions; accept the first unique one.
    List<KillerCage>? chosen;
    for (var attempt = 0; attempt < maxPartitionAttempts; attempt++) {
      final cages = _partition(
        gridDim: gridDim,
        solution: solution,
        maxCageSize: maxCageSize,
        rng: rng,
      );
      final unique = await killerHasUniqueSolution(
        gridDim: gridDim,
        regions: regions,
        cages: cages,
        givens: empty,
      );
      if (unique) {
        return KillerPuzzle(
          gridDim: gridDim,
          regions: regions,
          cages: cages,
          givens: empty,
          solution: solution,
        );
      }
      chosen ??= cages; // remember the first partition for phase 2
    }

    // Phase 2: keep the (first) partition and reveal givens until unique.
    final cages = chosen!;
    final givens = List.generate(gridDim, (_) => List<int>.filled(gridDim, 0));

    // Candidate reveal order — deterministic shuffle of all cells.
    final cells = <List<int>>[];
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        cells.add([r, c]);
      }
    }
    cells.shuffle(rng);

    // Phase 1 already proved this partition ambiguous without givens. Check
    // after each reveal, including the last allowed one; never return an
    // unproven puzzle merely because the reveal budget ran out.
    var unique = false;
    for (final cell in cells.take(maxGivens ?? cells.length)) {
      givens[cell[0]][cell[1]] = solution[cell[0]][cell[1]];
      unique = await killerHasUniqueSolution(
        gridDim: gridDim,
        regions: regions,
        cages: cages,
        givens: givens,
      );
      if (unique) break;
    }
    if (!unique) {
      throw StateError('Killer uniqueness not established within reveal cap');
    }

    return KillerPuzzle(
      gridDim: gridDim,
      regions: regions,
      cages: cages,
      givens: givens,
      solution: solution,
    );
  }
}
