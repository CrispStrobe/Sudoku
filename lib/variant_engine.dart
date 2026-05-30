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
    // A solution must exist AND there must not be a second one.
    final first = await p.getSolution();
    if (first is! Map) return false;
    return !await p.hasMultipleSolutions();
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

  /// Generate a uniquely-solvable Killer puzzle. Reuses [SudokuGame.generate]
  /// for the base solution + regions, partitions the grid into connected cages,
  /// computes each cage sum from the solution, and verifies uniqueness via
  /// dart_csp. If a pure-cage puzzle is not unique, it re-rolls the partition a
  /// few times and then, if still ambiguous, reveals a few random cells as
  /// givens until unique (or an attempt cap is hit).
  ///
  /// Determinism: the same [seed] reproduces the same puzzle.
  static Future<KillerPuzzle> generateKiller({
    required GridSize gridSize,
    required SudokuDifficulty difficulty,
    int? seed,
  }) async {
    final effectiveSeed = seed ?? math.Random().nextInt(1 << 31);
    final rng = math.Random(effectiveSeed);

    // Base full solution + box regions (reuse the existing engine).
    final base = SudokuGame.generate(
      difficulty,
      gridSize,
      GridShape.classic,
      seed: effectiveSeed,
    );
    final gridDim = base.gridDim;
    final solution = base.solution.map((row) => List<int>.from(row)).toList();
    final regions = base.regions.map((row) => List<int>.from(row)).toList();
    final maxCageSize = _maxCageSizeFor(difficulty);

    final empty = List.generate(gridDim, (_) => List<int>.filled(gridDim, 0));

    // Phase 1: try several pure-cage partitions; accept the first unique one.
    const maxPartitionAttempts = 12;
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

    const maxGivens = 30;
    var revealed = 0;
    for (final cell in cells) {
      if (revealed >= maxGivens) break;
      final unique = await killerHasUniqueSolution(
        gridDim: gridDim,
        regions: regions,
        cages: cages,
        givens: givens,
      );
      if (unique) break;
      givens[cell[0]][cell[1]] = solution[cell[0]][cell[1]];
      revealed++;
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
