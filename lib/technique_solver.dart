import 'sudoku_game.dart';

/// Ordered easiest -> hardest. `guess` means the puzzle needs more than the
/// implemented logical techniques (treated as the hardest tier).
enum Technique {
  nakedSingle,
  hiddenSingle,
  lockedCandidates,
  nakedPair,
  nakedTriple,
  hiddenPair,
  xWing,
  guess,
}

/// One human-readable solving step.
class SolveStep {
  /// The technique that produced this step.
  final Technique technique;

  /// `[row, col]` of the primary cell: the placement for a single, or a
  /// representative eliminated cell for a pure-elimination step.
  final List<int> cell;

  /// The value placed; `null` for pure-elimination steps.
  final int? value;

  /// Human-readable description of the deduction.
  final String explanation;

  /// Candidate eliminations performed by this step, each `[row, col, value]`.
  /// Empty for placement steps.
  final List<List<int>> eliminations;

  const SolveStep({
    required this.technique,
    required this.cell,
    required this.value,
    required this.explanation,
    this.eliminations = const [],
  });
}

class TechniqueSolveResult {
  /// Fully solved using ONLY the implemented techniques (no guessing).
  final bool solved;

  /// The placement/elimination steps in order.
  final List<SolveStep> steps;

  /// Hardest technique actually needed.
  final Technique hardest;

  /// Difficulty derived from [hardest].
  final SudokuDifficulty rating;

  /// The board after solving (solved completely iff [solved] is true).
  final List<List<int>> board;

  const TechniqueSolveResult({
    required this.solved,
    required this.steps,
    required this.hardest,
    required this.rating,
    required this.board,
  });
}

/// Maps the hardest technique used to a difficulty rating.
SudokuDifficulty ratingFor(Technique hardest) {
  switch (hardest) {
    case Technique.nakedSingle:
    case Technique.hiddenSingle:
      return SudokuDifficulty.easy;
    case Technique.lockedCandidates:
    case Technique.nakedPair:
      return SudokuDifficulty.medium;
    case Technique.nakedTriple:
    case Technique.hiddenPair:
      return SudokuDifficulty.hard;
    case Technique.xWing:
    case Technique.guess:
      return SudokuDifficulty.expert;
  }
}

/// A human-technique logical Sudoku solver. Operates on a copy of the supplied
/// grid and never mutates the caller's data. Works for any dimension
/// (4/6/8/9/10/12) and for both classic and jigsaw layouts, since all reasoning
/// is expressed over rows, columns and the supplied [regions] grid.
class TechniqueSolver {
  /// Working grid (a copy). `0` means empty.
  final List<List<int>> _grid;

  /// Region id per cell (a copy).
  final List<List<int>> _regions;

  final int _dim;

  /// Candidate sets per cell. Empty for filled cells.
  late final List<List<Set<int>>> _cands;

  /// Cells belonging to each region id, precomputed.
  late final List<List<List<int>>> _regionCells;

  /// When true, the two main diagonals are treated as extra units (Sudoku-X).
  final bool _diagonal;

  /// Operates on a COPY of [grid]; does not mutate the caller's grid. Set
  /// [diagonal] for Sudoku-X (adds the two diagonals as units).
  TechniqueSolver(
    List<List<int>> grid,
    List<List<int>> regions, {
    bool diagonal = false,
  }) : _grid = grid.map((row) => List<int>.from(row)).toList(),
       _regions = regions.map((row) => List<int>.from(row)).toList(),
       _dim = grid.length,
       _diagonal = diagonal {
    _initRegionCells();
    _initCandidates();
  }

  /// The current board state (a defensive copy).
  List<List<int>> get board => _grid.map((row) => List<int>.from(row)).toList();

  void _initRegionCells() {
    _regionCells = List.generate(_dim, (_) => <List<int>>[]);
    for (var r = 0; r < _dim; r++) {
      for (var c = 0; c < _dim; c++) {
        _regionCells[_regions[r][c]].add([r, c]);
      }
    }
  }

  void _initCandidates() {
    _cands = List.generate(_dim, (_) => List.generate(_dim, (_) => <int>{}));
    for (var r = 0; r < _dim; r++) {
      for (var c = 0; c < _dim; c++) {
        if (_grid[r][c] == 0) {
          for (var v = 1; v <= _dim; v++) {
            if (_isLegal(r, c, v)) _cands[r][c].add(v);
          }
        }
      }
    }
  }

  /// True if [v] does not already appear in (r,c)'s row, column, region or
  /// (Sudoku-X only) shared diagonal.
  bool _isLegal(int row, int col, int v) {
    for (var i = 0; i < _dim; i++) {
      if (_grid[row][i] == v) return false;
      if (_grid[i][col] == v) return false;
    }
    for (final cell in _regionCells[_regions[row][col]]) {
      if (_grid[cell[0]][cell[1]] == v) return false;
    }
    if (_diagonal) {
      if (row == col) {
        for (var i = 0; i < _dim; i++) {
          if (_grid[i][i] == v) return false;
        }
      }
      if (row + col == _dim - 1) {
        for (var i = 0; i < _dim; i++) {
          if (_grid[i][_dim - 1 - i] == v) return false;
        }
      }
    }
    return true;
  }

  /// Place [v] at (r,c) and remove it as a candidate from all peers.
  void _place(int r, int c, int v) {
    _grid[r][c] = v;
    _cands[r][c] = <int>{};
    for (var i = 0; i < _dim; i++) {
      _cands[r][i].remove(v);
      _cands[i][c].remove(v);
    }
    for (final cell in _regionCells[_regions[r][c]]) {
      _cands[cell[0]][cell[1]].remove(v);
    }
    if (_diagonal) {
      if (r == c) {
        for (var i = 0; i < _dim; i++) {
          _cands[i][i].remove(v);
        }
      }
      if (r + c == _dim - 1) {
        for (var i = 0; i < _dim; i++) {
          _cands[i][_dim - 1 - i].remove(v);
        }
      }
    }
  }

  // --- The three unit families ------------------------------------------

  /// All units (rows, then columns, then regions) as lists of `[row, col]`.
  List<List<List<int>>> _allUnits() {
    final units = <List<List<int>>>[];
    for (var r = 0; r < _dim; r++) {
      units.add([
        for (var c = 0; c < _dim; c++) [r, c],
      ]);
    }
    for (var c = 0; c < _dim; c++) {
      units.add([
        for (var r = 0; r < _dim; r++) [r, c],
      ]);
    }
    for (var id = 0; id < _dim; id++) {
      units.add(_regionCells[id]);
    }
    if (_diagonal) {
      units.add([
        for (var i = 0; i < _dim; i++) [i, i],
      ]);
      units.add([
        for (var i = 0; i < _dim; i++) [i, _dim - 1 - i],
      ]);
    }
    return units;
  }

  // --- Public solving API -----------------------------------------------

  /// Run techniques (easiest first) repeatedly until solved or stuck.
  TechniqueSolveResult solve() {
    final steps = <SolveStep>[];
    var hardest = Technique.nakedSingle;
    var anyStep = false;

    while (!_isFull()) {
      final step = _findStep();
      if (step == null) {
        // Stuck: requires guessing beyond implemented techniques.
        return TechniqueSolveResult(
          solved: false,
          steps: steps,
          hardest: Technique.guess,
          rating: ratingFor(Technique.guess),
          board: board,
        );
      }
      _applyStep(step);
      steps.add(step);
      anyStep = true;
      if (step.technique.index > hardest.index) hardest = step.technique;
    }

    // Empty board edge-case: nothing to do but already complete.
    if (!anyStep) hardest = Technique.nakedSingle;

    return TechniqueSolveResult(
      solved: true,
      steps: steps,
      hardest: hardest,
      rating: ratingFor(hardest),
      board: board,
    );
  }

  /// The single next logical step from the CURRENT board state, or null if none
  /// found by the implemented techniques. Does not mutate.
  SolveStep? nextStep() => _findStep();

  // --- Step dispatch (easiest first) ------------------------------------

  SolveStep? _findStep() {
    return _nakedSingle() ??
        _hiddenSingle() ??
        _lockedCandidates() ??
        _nakedPair() ??
        _nakedTriple() ??
        _hiddenPair() ??
        _xWing();
  }

  void _applyStep(SolveStep step) {
    if (step.value != null) {
      _place(step.cell[0], step.cell[1], step.value!);
    } else {
      for (final e in step.eliminations) {
        _cands[e[0]][e[1]].remove(e[2]);
      }
    }
  }

  bool _isFull() {
    for (var r = 0; r < _dim; r++) {
      for (var c = 0; c < _dim; c++) {
        if (_grid[r][c] == 0) return false;
      }
    }
    return true;
  }

  // --- Technique 1: Naked single ----------------------------------------

  SolveStep? _nakedSingle() {
    for (var r = 0; r < _dim; r++) {
      for (var c = 0; c < _dim; c++) {
        if (_grid[r][c] == 0 && _cands[r][c].length == 1) {
          final v = _cands[r][c].first;
          return SolveStep(
            technique: Technique.nakedSingle,
            cell: [r, c],
            value: v,
            explanation:
                'R${r + 1}C${c + 1} has only one candidate ($v) — naked single.',
          );
        }
      }
    }
    return null;
  }

  // --- Technique 2: Hidden single ---------------------------------------

  SolveStep? _hiddenSingle() {
    final units = _allUnits();
    final names = _unitNames();
    for (var u = 0; u < units.length; u++) {
      final unit = units[u];
      for (var v = 1; v <= _dim; v++) {
        List<int>? only;
        var count = 0;
        for (final cell in unit) {
          if (_grid[cell[0]][cell[1]] == 0 &&
              _cands[cell[0]][cell[1]].contains(v)) {
            count++;
            only = cell;
            if (count > 1) break;
          }
        }
        if (count == 1 && only != null) {
          return SolveStep(
            technique: Technique.hiddenSingle,
            cell: only,
            value: v,
            explanation:
                'R${only[0] + 1}C${only[1] + 1} is the only cell in '
                '${names[u]} that can be $v — hidden single.',
          );
        }
      }
    }
    return null;
  }

  List<String> _unitNames() {
    final names = <String>[];
    for (var r = 0; r < _dim; r++) {
      names.add('row ${r + 1}');
    }
    for (var c = 0; c < _dim; c++) {
      names.add('column ${c + 1}');
    }
    for (var id = 0; id < _dim; id++) {
      names.add('region ${id + 1}');
    }
    return names;
  }

  // --- Technique 3: Locked candidates -----------------------------------

  SolveStep? _lockedCandidates() {
    return _pointing() ?? _claiming();
  }

  /// Pointing: within a region, if all candidate cells for a value share a
  /// single row (or column), eliminate that value from that row/col OUTSIDE
  /// the region.
  SolveStep? _pointing() {
    for (var id = 0; id < _dim; id++) {
      final cells = _regionCells[id];
      for (var v = 1; v <= _dim; v++) {
        final holders = <List<int>>[];
        for (final cell in cells) {
          if (_cands[cell[0]][cell[1]].contains(v)) holders.add(cell);
        }
        if (holders.length < 2) continue;

        // Shared row?
        final rows = holders.map((c) => c[0]).toSet();
        if (rows.length == 1) {
          final row = rows.first;
          final elims = <List<int>>[];
          for (var c = 0; c < _dim; c++) {
            if (_regions[row][c] != id && _cands[row][c].contains(v)) {
              elims.add([row, c, v]);
            }
          }
          if (elims.isNotEmpty) {
            return SolveStep(
              technique: Technique.lockedCandidates,
              cell: [elims.first[0], elims.first[1]],
              value: null,
              explanation:
                  'In region ${id + 1}, $v only appears in row ${row + 1} '
                  '(pointing); removed $v from that row outside the region.',
              eliminations: elims,
            );
          }
        }

        // Shared column?
        final cols = holders.map((c) => c[1]).toSet();
        if (cols.length == 1) {
          final col = cols.first;
          final elims = <List<int>>[];
          for (var r = 0; r < _dim; r++) {
            if (_regions[r][col] != id && _cands[r][col].contains(v)) {
              elims.add([r, col, v]);
            }
          }
          if (elims.isNotEmpty) {
            return SolveStep(
              technique: Technique.lockedCandidates,
              cell: [elims.first[0], elims.first[1]],
              value: null,
              explanation:
                  'In region ${id + 1}, $v only appears in column '
                  '${col + 1} (pointing); removed $v from that column outside '
                  'the region.',
              eliminations: elims,
            );
          }
        }
      }
    }
    return null;
  }

  /// Claiming: within a row/col, if all candidate cells for a value lie in one
  /// region, eliminate that value from the rest of that region.
  SolveStep? _claiming() {
    // Rows.
    for (var r = 0; r < _dim; r++) {
      for (var v = 1; v <= _dim; v++) {
        final holders = <int>[];
        for (var c = 0; c < _dim; c++) {
          if (_cands[r][c].contains(v)) holders.add(c);
        }
        if (holders.length < 2) continue;
        final regionsOf = holders.map((c) => _regions[r][c]).toSet();
        if (regionsOf.length == 1) {
          final id = regionsOf.first;
          final elims = <List<int>>[];
          for (final cell in _regionCells[id]) {
            if (cell[0] != r && _cands[cell[0]][cell[1]].contains(v)) {
              elims.add([cell[0], cell[1], v]);
            }
          }
          if (elims.isNotEmpty) {
            return SolveStep(
              technique: Technique.lockedCandidates,
              cell: [elims.first[0], elims.first[1]],
              value: null,
              explanation:
                  'In row ${r + 1}, $v is confined to region ${id + 1} '
                  '(claiming); removed $v from the rest of that region.',
              eliminations: elims,
            );
          }
        }
      }
    }
    // Columns.
    for (var c = 0; c < _dim; c++) {
      for (var v = 1; v <= _dim; v++) {
        final holders = <int>[];
        for (var r = 0; r < _dim; r++) {
          if (_cands[r][c].contains(v)) holders.add(r);
        }
        if (holders.length < 2) continue;
        final regionsOf = holders.map((r) => _regions[r][c]).toSet();
        if (regionsOf.length == 1) {
          final id = regionsOf.first;
          final elims = <List<int>>[];
          for (final cell in _regionCells[id]) {
            if (cell[1] != c && _cands[cell[0]][cell[1]].contains(v)) {
              elims.add([cell[0], cell[1], v]);
            }
          }
          if (elims.isNotEmpty) {
            return SolveStep(
              technique: Technique.lockedCandidates,
              cell: [elims.first[0], elims.first[1]],
              value: null,
              explanation:
                  'In column ${c + 1}, $v is confined to region ${id + 1} '
                  '(claiming); removed $v from the rest of that region.',
              eliminations: elims,
            );
          }
        }
      }
    }
    return null;
  }

  // --- Technique 4: Naked pair ------------------------------------------

  SolveStep? _nakedPair() {
    final units = _allUnits();
    final names = _unitNames();
    for (var u = 0; u < units.length; u++) {
      final unit = units[u];
      final twos = <List<int>>[];
      for (final cell in unit) {
        if (_cands[cell[0]][cell[1]].length == 2) twos.add(cell);
      }
      for (var i = 0; i < twos.length; i++) {
        for (var j = i + 1; j < twos.length; j++) {
          final a = twos[i];
          final b = twos[j];
          final sa = _cands[a[0]][a[1]];
          final sb = _cands[b[0]][b[1]];
          if (sa.length == 2 && _setEquals(sa, sb)) {
            final pair = sa.toList()..sort();
            final elims = <List<int>>[];
            for (final cell in unit) {
              if ((cell[0] == a[0] && cell[1] == a[1]) ||
                  (cell[0] == b[0] && cell[1] == b[1])) {
                continue;
              }
              for (final v in pair) {
                if (_cands[cell[0]][cell[1]].contains(v)) {
                  elims.add([cell[0], cell[1], v]);
                }
              }
            }
            if (elims.isNotEmpty) {
              return SolveStep(
                technique: Technique.nakedPair,
                cell: [elims.first[0], elims.first[1]],
                value: null,
                explanation:
                    'R${a[0] + 1}C${a[1] + 1} and R${b[0] + 1}C${b[1] + 1} '
                    'form a naked pair (${pair[0]},${pair[1]}) in ${names[u]}; '
                    'removed those from the rest of the unit.',
                eliminations: elims,
              );
            }
          }
        }
      }
    }
    return null;
  }

  // --- Technique 5: Naked triple ----------------------------------------

  SolveStep? _nakedTriple() {
    final units = _allUnits();
    final names = _unitNames();
    for (var u = 0; u < units.length; u++) {
      final unit = units[u];
      // Candidate cells: 2 or 3 candidates (subsets of a potential triple).
      final small = <List<int>>[];
      for (final cell in unit) {
        final n = _cands[cell[0]][cell[1]].length;
        if (n == 2 || n == 3) small.add(cell);
      }
      for (var i = 0; i < small.length; i++) {
        for (var j = i + 1; j < small.length; j++) {
          for (var k = j + 1; k < small.length; k++) {
            final a = small[i];
            final b = small[j];
            final cc = small[k];
            final union = <int>{
              ..._cands[a[0]][a[1]],
              ..._cands[b[0]][b[1]],
              ..._cands[cc[0]][cc[1]],
            };
            if (union.length != 3) continue;
            final triple = union.toList()..sort();
            final elims = <List<int>>[];
            for (final cell in unit) {
              if (_sameCell(cell, a) ||
                  _sameCell(cell, b) ||
                  _sameCell(cell, cc)) {
                continue;
              }
              for (final v in triple) {
                if (_cands[cell[0]][cell[1]].contains(v)) {
                  elims.add([cell[0], cell[1], v]);
                }
              }
            }
            if (elims.isNotEmpty) {
              return SolveStep(
                technique: Technique.nakedTriple,
                cell: [elims.first[0], elims.first[1]],
                value: null,
                explanation:
                    'R${a[0] + 1}C${a[1] + 1}, R${b[0] + 1}C${b[1] + 1} and '
                    'R${cc[0] + 1}C${cc[1] + 1} form a naked triple '
                    '(${triple[0]},${triple[1]},${triple[2]}) in ${names[u]}; '
                    'removed those from the rest of the unit.',
                eliminations: elims,
              );
            }
          }
        }
      }
    }
    return null;
  }

  // --- Technique 6: Hidden pair -----------------------------------------

  SolveStep? _hiddenPair() {
    final units = _allUnits();
    final names = _unitNames();
    for (var u = 0; u < units.length; u++) {
      final unit = units[u];
      // For each value, which cells (indices into unit) can hold it.
      final positions = <int, List<int>>{};
      for (var v = 1; v <= _dim; v++) {
        final ps = <int>[];
        for (var idx = 0; idx < unit.length; idx++) {
          final cell = unit[idx];
          if (_cands[cell[0]][cell[1]].contains(v)) ps.add(idx);
        }
        if (ps.length == 2) positions[v] = ps;
      }
      final values = positions.keys.toList();
      for (var i = 0; i < values.length; i++) {
        for (var j = i + 1; j < values.length; j++) {
          final v1 = values[i];
          final v2 = values[j];
          if (_listEquals(positions[v1]!, positions[v2]!)) {
            // Both confined to the same two cells -> remove other candidates.
            final elims = <List<int>>[];
            for (final idx in positions[v1]!) {
              final cell = unit[idx];
              for (final v in _cands[cell[0]][cell[1]]) {
                if (v != v1 && v != v2) {
                  elims.add([cell[0], cell[1], v]);
                }
              }
            }
            if (elims.isNotEmpty) {
              final c1 = unit[positions[v1]![0]];
              final c2 = unit[positions[v1]![1]];
              return SolveStep(
                technique: Technique.hiddenPair,
                cell: [elims.first[0], elims.first[1]],
                value: null,
                explanation:
                    'Values $v1 and $v2 are confined to R${c1[0] + 1}C'
                    '${c1[1] + 1} and R${c2[0] + 1}C${c2[1] + 1} in '
                    '${names[u]} (hidden pair); removed other candidates from '
                    'those cells.',
                eliminations: elims,
              );
            }
          }
        }
      }
    }
    return null;
  }

  // --- Technique 7: X-wing ----------------------------------------------

  SolveStep? _xWing() {
    // Row-based: two rows where value v has candidates in exactly the same two
    // columns -> eliminate v from those columns in all other rows.
    for (var v = 1; v <= _dim; v++) {
      // For each row, the columns where v is a candidate.
      final rowCols = <int, List<int>>{};
      for (var r = 0; r < _dim; r++) {
        final cols = <int>[];
        for (var c = 0; c < _dim; c++) {
          if (_cands[r][c].contains(v)) cols.add(c);
        }
        if (cols.length == 2) rowCols[r] = cols;
      }
      final rows = rowCols.keys.toList();
      for (var i = 0; i < rows.length; i++) {
        for (var j = i + 1; j < rows.length; j++) {
          final r1 = rows[i];
          final r2 = rows[j];
          if (_listEquals(rowCols[r1]!, rowCols[r2]!)) {
            final c1 = rowCols[r1]![0];
            final c2 = rowCols[r1]![1];
            final elims = <List<int>>[];
            for (var r = 0; r < _dim; r++) {
              if (r == r1 || r == r2) continue;
              if (_cands[r][c1].contains(v)) elims.add([r, c1, v]);
              if (_cands[r][c2].contains(v)) elims.add([r, c2, v]);
            }
            if (elims.isNotEmpty) {
              return SolveStep(
                technique: Technique.xWing,
                cell: [elims.first[0], elims.first[1]],
                value: null,
                explanation:
                    'X-wing on $v: rows ${r1 + 1} and ${r2 + 1} confine it to '
                    'columns ${c1 + 1} and ${c2 + 1}; removed $v from those '
                    'columns in other rows.',
                eliminations: elims,
              );
            }
          }
        }
      }

      // Column-based (symmetric): two columns where v has candidates in exactly
      // the same two rows -> eliminate v from those rows in all other columns.
      final colRows = <int, List<int>>{};
      for (var c = 0; c < _dim; c++) {
        final rs = <int>[];
        for (var r = 0; r < _dim; r++) {
          if (_cands[r][c].contains(v)) rs.add(r);
        }
        if (rs.length == 2) colRows[c] = rs;
      }
      final cols = colRows.keys.toList();
      for (var i = 0; i < cols.length; i++) {
        for (var j = i + 1; j < cols.length; j++) {
          final cc1 = cols[i];
          final cc2 = cols[j];
          if (_listEquals(colRows[cc1]!, colRows[cc2]!)) {
            final rr1 = colRows[cc1]![0];
            final rr2 = colRows[cc1]![1];
            final elims = <List<int>>[];
            for (var c = 0; c < _dim; c++) {
              if (c == cc1 || c == cc2) continue;
              if (_cands[rr1][c].contains(v)) elims.add([rr1, c, v]);
              if (_cands[rr2][c].contains(v)) elims.add([rr2, c, v]);
            }
            if (elims.isNotEmpty) {
              return SolveStep(
                technique: Technique.xWing,
                cell: [elims.first[0], elims.first[1]],
                value: null,
                explanation:
                    'X-wing on $v: columns ${cc1 + 1} and ${cc2 + 1} confine '
                    'it to rows ${rr1 + 1} and ${rr2 + 1}; removed $v from '
                    'those rows in other columns.',
                eliminations: elims,
              );
            }
          }
        }
      }
    }
    return null;
  }

  // --- Small helpers -----------------------------------------------------

  bool _sameCell(List<int> a, List<int> b) => a[0] == b[0] && a[1] == b[1];

  bool _setEquals(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);

  bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
