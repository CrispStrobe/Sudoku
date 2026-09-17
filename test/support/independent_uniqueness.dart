/// Test-only oracle. Does not use SudokuGame or TechniqueSolver.
class UniquenessResult {
  final int solutionsFound;
  final int visitedNodes;
  final bool budgetExhausted;
  final List<List<int>>? firstSolution;

  const UniquenessResult({
    required this.solutionsFound,
    required this.visitedNodes,
    required this.budgetExhausted,
    this.firstSolution,
  });

  bool get isUnique => !budgetExhausted && solutionsFound == 1;
}

/// Counts completions up to two using Algorithm X exact cover, independently
/// of the production bitmask search. A deterministic node limit bounds work;
/// exhaustion is explicitly unknown, even if one solution has already appeared.
UniquenessResult verifyUnique(
  List<List<int>> givens,
  List<List<int>> regions, {
  int maxNodes = 2000000,
}) {
  final n = givens.length;
  if (n == 0 ||
      regions.length != n ||
      givens.any((row) => row.length != n) ||
      regions.any((row) => row.length != n) ||
      givens.expand((row) => row).any((v) => v < 0 || v > n) ||
      regions.expand((row) => row).any((id) => id < 0 || id >= n) ||
      List.generate(
        n,
        (id) => regions.expand((row) => row).where((v) => v == id).length,
      ).any((count) => count != n)) {
    throw ArgumentError(
      'Expected square grids with values 0..n and n regions of n cells',
    );
  }
  if (maxNodes < 0) throw ArgumentError.value(maxNodes, 'maxNodes');

  final square = n * n;
  // Each possible (cell, value) satisfies four constraints: cell occupied,
  // row contains value, column contains value, region contains value.
  final columns = List.generate(4 * square, (_) => <int>{});
  final rowColumns = <List<int>>[];
  final placements = <(int, int, int)>[];
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      for (var v = 1; v <= n; v++) {
        if (givens[r][c] != 0 && givens[r][c] != v) continue;
        final constraints = [
          r * n + c,
          square + r * n + v - 1,
          2 * square + c * n + v - 1,
          3 * square + regions[r][c] * n + v - 1,
        ];
        final id = rowColumns.length;
        rowColumns.add(constraints);
        placements.add((r, c, v));
        for (final constraint in constraints) {
          columns[constraint].add(id);
        }
      }
    }
  }
  final active = List.filled(4 * square, true);
  final selected = <int>[];
  var nodes = 0;
  var solutions = 0;
  var exhausted = false;
  List<List<int>>? first;

  void search() {
    if (nodes >= maxNodes) {
      exhausted = true;
      return;
    }
    nodes++;
    var best = -1;
    for (var i = 0; i < columns.length; i++) {
      if (!active[i]) continue;
      if (columns[i].isEmpty) return;
      if (best == -1 || columns[i].length < columns[best].length) best = i;
    }
    if (best == -1) {
      solutions++;
      if (first == null) {
        first = List.generate(n, (_) => List.filled(n, 0));
        for (final id in selected) {
          final (r, c, v) = placements[id];
          first![r][c] = v;
        }
      }
      return;
    }
    for (final id in columns[best].toList()..sort()) {
      final removed = <(int, int)>[];
      for (final constraint in rowColumns[id]) {
        active[constraint] = false;
        for (final conflicting in columns[constraint].toList()) {
          for (final other in rowColumns[conflicting]) {
            if (active[other] && columns[other].remove(conflicting)) {
              removed.add((other, conflicting));
            }
          }
        }
      }
      selected.add(id);
      search();
      selected.removeLast();
      for (final (column, row) in removed.reversed) {
        columns[column].add(row);
      }
      for (final constraint in rowColumns[id]) {
        active[constraint] = true;
      }
      if (solutions >= 2 || exhausted) return;
    }
  }

  search();
  return UniquenessResult(
    solutionsFound: solutions,
    visitedNodes: nodes,
    budgetExhausted: exhausted,
    firstSolution: first,
  );
}
