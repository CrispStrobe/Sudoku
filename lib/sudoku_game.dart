import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:json_annotation/json_annotation.dart';

part 'sudoku_game.g.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum GridSize { small, medium, large, standard, big, mega }

enum SudokuDifficulty { easy, medium, hard, expert }

enum GridShape { classic, jigsaw }

enum GameMode { classic }

enum HintType { showPossible, giveAnswer, nakedSingle, hiddenSingle, conflict }

/// How many conflicting placements a player may make before the game is lost.
/// Scales with difficulty: easier puzzles are more forgiving.
int maxMistakesFor(SudokuDifficulty difficulty) {
  switch (difficulty) {
    case SudokuDifficulty.easy:
      return 5;
    case SudokuDifficulty.medium:
      return 4;
    case SudokuDifficulty.hard:
      return 3;
    case SudokuDifficulty.expert:
      return 2;
  }
}

/// How many (penalty-bearing) hints a player may use per puzzle. Scales with
/// difficulty: easier puzzles are more generous. The free "cell occupied" /
/// "conflict" diagnostics are not hints and do not count against this budget.
int maxHintsFor(SudokuDifficulty difficulty) {
  switch (difficulty) {
    case SudokuDifficulty.easy:
      return 10;
    case SudokuDifficulty.medium:
      return 6;
    case SudokuDifficulty.hard:
      return 3;
    case SudokuDifficulty.expert:
      return 1;
  }
}

/// Side length (NxN) for a given [GridSize].
int gridDimensionFor(GridSize size) {
  switch (size) {
    case GridSize.small:
      return 4;
    case GridSize.medium:
      return 6;
    case GridSize.large:
      return 8;
    case GridSize.standard:
      return 9;
    case GridSize.big:
      return 10;
    case GridSize.mega:
      return 12;
  }
}

/// Region shape `[rows, cols]` used for the *classic* box layout of a grid.
List<int> boxDimensionsFor(int gridDim) {
  switch (gridDim) {
    case 4:
      return [2, 2];
    case 6:
      return [2, 3];
    case 8:
      return [2, 4];
    case 9:
      return [3, 3];
    case 10:
      return [2, 5];
    case 12:
      return [3, 4];
    default:
      return [2, 2];
  }
}

// ---------------------------------------------------------------------------
// Logging (debug builds only)
// ---------------------------------------------------------------------------

class DebugLogger {
  static void log(String message) {
    assert(() {
      // ignore: avoid_print
      print('[SUDOKU] $message');
      return true;
    }());
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    assert(() {
      // ignore: avoid_print
      print('[SUDOKU ERROR] $message${error != null ? ' — $error' : ''}');
      return true;
    }());
  }
}

// ---------------------------------------------------------------------------
// Serializable puzzle blueprint
// ---------------------------------------------------------------------------

@JsonSerializable()
class PuzzleBlueprint {
  final List<List<int>> solutionGrid;
  final List<List<int>> regions;
  final GridSize gridSize;
  final GridShape gridShape;

  PuzzleBlueprint({
    required this.solutionGrid,
    required this.regions,
    required this.gridSize,
    required this.gridShape,
  });

  factory PuzzleBlueprint.fromJson(Map<String, dynamic> json) =>
      _$PuzzleBlueprintFromJson(json);

  Map<String, dynamic> toJson() => _$PuzzleBlueprintToJson(this);
}

// ---------------------------------------------------------------------------
// Smart hint
// ---------------------------------------------------------------------------

class SmartHint {
  final HintType type;
  final String title;
  final String description;
  final int penalty;

  /// Solution payload: an `int` for single-answer hints, a `List<int>` for
  /// "show possible numbers", or `null` for informational hints.
  final Object? data;

  SmartHint({
    required this.type,
    required this.title,
    required this.description,
    required this.penalty,
    this.data,
  });
}

// ---------------------------------------------------------------------------
// Background generation (runs in a dedicated, killable isolate)
// ---------------------------------------------------------------------------

/// Isolate entry point. `args` is `[SendPort, difficulty, gridSize, gridShape]`.
void _generateIsolateEntry(List<dynamic> args) {
  final sendPort = args[0] as SendPort;
  final game = SudokuGame.generate(
    args[1] as SudokuDifficulty,
    args[2] as GridSize,
    args[3] as GridShape,
  );
  sendPort.send(game);
}

// ---------------------------------------------------------------------------
// The Sudoku engine — pure Dart, no Flutter widget dependencies.
// ---------------------------------------------------------------------------

class SudokuGame {
  late List<List<int>> grid;
  late List<List<bool>> isOriginal;
  late List<List<int>> solution;
  late List<List<int>> regions;

  /// Player pencil-marks (candidate numbers) per cell.
  late List<List<Set<int>>> notes;

  late int gridDim;
  final SudokuDifficulty difficulty;

  final math.Random _rng;

  /// Stack of reversible edits for [undo].
  final List<_UndoEntry> _history = [];

  /// How long hole-digging may spend trying to preserve a unique solution.
  static const Duration _digBudget = Duration(milliseconds: 2500);

  SudokuGame._(this.difficulty, {math.Random? rng})
    : _rng = rng ?? math.Random();

  /// Synchronous generation. Pass [seed] for deterministic output (tests).
  factory SudokuGame.generate(
    SudokuDifficulty difficulty,
    GridSize gridSize,
    GridShape gridShape, {
    int? seed,
  }) {
    final game = SudokuGame._(
      difficulty,
      rng: seed == null ? null : math.Random(seed),
    );
    game._build(gridSize, gridShape);
    return game;
  }

  /// Asynchronous generation in a dedicated background isolate with a hard
  /// timeout. Unlike `compute`, the worker isolate is **killed** on timeout or
  /// error, so a pathological shape can neither freeze the UI nor leak a
  /// runaway isolate.
  ///
  /// The web (dart2js/dart2wasm) has no `Isolate.spawn`, so there we generate
  /// inline on the main thread — generation is bounded by the engine's internal
  /// step/time budgets, and results are cached so repeat plays stay fast.
  static Future<SudokuGame> create(
    SudokuDifficulty difficulty,
    GridSize gridSize,
    GridShape gridShape, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final resultPort = ReceivePort();
    final errorPort = ReceivePort();
    final completer = Completer<SudokuGame>();
    Timer? timer;
    Isolate? isolate;

    void cleanup() {
      timer?.cancel();
      resultPort.close();
      errorPort.close();
      isolate?.kill(priority: Isolate.immediate);
    }

    resultPort.listen((message) {
      if (!completer.isCompleted) completer.complete(message as SudokuGame);
      cleanup();
    });
    errorPort.listen((dynamic error) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Generation failed: $error'));
      }
      cleanup();
    });

    try {
      isolate = await Isolate.spawn(
        _generateIsolateEntry,
        [resultPort.sendPort, difficulty, gridSize, gridShape],
        onError: errorPort.sendPort,
        errorsAreFatal: true,
      );
    } catch (e) {
      cleanup();
      rethrow;
    }

    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException('Puzzle generation exceeded ${timeout.inSeconds}s.'),
        );
        cleanup(); // kills the isolate — true cancellation
      }
    });

    return completer.future;
  }

  /// Build a playable puzzle from a cached, fully-solved blueprint by digging a
  /// fresh set of holes (so a cached solution feels new each play).
  factory SudokuGame.fromBlueprint(
    PuzzleBlueprint blueprint,
    SudokuDifficulty difficulty, {
    math.Random? rng,
  }) {
    final game = SudokuGame._(difficulty, rng: rng);
    game.gridDim = gridDimensionFor(blueprint.gridSize);
    game.solution = blueprint.solutionGrid
        .map((row) => List<int>.from(row))
        .toList();
    game.grid = blueprint.solutionGrid
        .map((row) => List<int>.from(row))
        .toList();
    game.regions = blueprint.regions.map((row) => List<int>.from(row)).toList();
    game.isOriginal = List.generate(
      game.gridDim,
      (_) => List.filled(game.gridDim, false),
    );
    game._puzzlify();
    return game;
  }

  // --- Construction ------------------------------------------------------

  void _build(GridSize gridSize, GridShape gridShape) {
    gridDim = gridDimensionFor(gridSize);
    grid = List.generate(gridDim, (_) => List.filled(gridDim, 0));
    solution = List.generate(gridDim, (_) => List.filled(gridDim, 0));
    isOriginal = List.generate(gridDim, (_) => List.filled(gridDim, false));
    regions = List.generate(gridDim, (_) => List.filled(gridDim, 0));

    // A single set of jigsaw regions can be unsolvable, so retry with fresh
    // region shapes a few times before giving up. Classic boxes always solve,
    // so one attempt suffices there.
    final maxAttempts = gridShape == GridShape.jigsaw ? 25 : 3;
    var solved = false;
    for (var attempt = 0; attempt < maxAttempts && !solved; attempt++) {
      _buildRegions(gridShape);
      for (var r = 0; r < gridDim; r++) {
        for (var c = 0; c < gridDim; c++) {
          grid[r][c] = 0;
        }
      }
      solved = _fillComplete();
    }
    if (!solved) {
      throw StateError('Failed to generate a complete $gridDim×$gridDim grid.');
    }

    _puzzlify();
  }

  // --- Region layout -----------------------------------------------------

  void _buildRegions(GridShape shape) {
    _buildBoxRegions();
    if (shape == GridShape.jigsaw) {
      // Mutate the box layout into irregular-but-connected regions via
      // boundary swaps. Large grids get fewer swaps so the solver stays fast.
      final swapBudget = gridDim >= 10
          ? (gridDim == 12 ? 4 : gridDim)
          : 1 << 30;
      var swaps = 0;
      for (var a = 0; a < gridDim && swaps < swapBudget; a++) {
        for (var b = a + 1; b < gridDim && swaps < swapBudget; b++) {
          swaps += _swapBoundary(a, b, gridDim >= 10 ? 1 : 3);
        }
      }
      DebugLogger.log('Jigsaw regions built with $swaps swaps.');
    }
  }

  void _buildBoxRegions() {
    final box = boxDimensionsFor(gridDim);
    final rowsPerBox = box[0];
    final colsPerBox = box[1];
    final boxesPerRow = gridDim ~/ colsPerBox;
    for (var row = 0; row < gridDim; row++) {
      for (var col = 0; col < gridDim; col++) {
        regions[row][col] =
            (row ~/ rowsPerBox) * boxesPerRow + (col ~/ colsPerBox);
      }
    }
  }

  /// Swap up to [maxSwaps] boundary cells between regions [a] and [b], keeping
  /// both regions connected. Returns the number of successful swaps.
  int _swapBoundary(int a, int b, int maxSwaps) {
    final boundaryA = <List<int>>[];
    final boundaryB = <List<int>>[];
    for (var row = 0; row < gridDim; row++) {
      for (var col = 0; col < gridDim; col++) {
        if (regions[row][col] == a && _isAdjacentToRegion(row, col, b)) {
          boundaryA.add([row, col]);
        } else if (regions[row][col] == b && _isAdjacentToRegion(row, col, a)) {
          boundaryB.add([row, col]);
        }
      }
    }
    if (boundaryA.isEmpty || boundaryB.isEmpty) return 0;

    boundaryA.shuffle(_rng);
    boundaryB.shuffle(_rng);
    final count = math.min(
      maxSwaps,
      math.min(boundaryA.length, boundaryB.length),
    );
    var done = 0;
    for (var i = 0; i < count; i++) {
      final ca = boundaryA[i];
      final cb = boundaryB[i];
      if (_canSwap(ca[0], ca[1], a, cb[0], cb[1], b)) {
        regions[ca[0]][ca[1]] = b;
        regions[cb[0]][cb[1]] = a;
        done++;
      }
    }
    return done;
  }

  bool _isAdjacentToRegion(int row, int col, int region) {
    for (final d in const [
      [-1, 0],
      [1, 0],
      [0, -1],
      [0, 1],
    ]) {
      final r = row + d[0];
      final c = col + d[1];
      if (r >= 0 &&
          r < gridDim &&
          c >= 0 &&
          c < gridDim &&
          regions[r][c] == region) {
        return true;
      }
    }
    return false;
  }

  bool _canSwap(int rA, int cA, int regA, int rB, int cB, int regB) {
    regions[rA][cA] = regB;
    regions[rB][cB] = regA;
    final ok = _isRegionConnected(regA) && _isRegionConnected(regB);
    regions[rA][cA] = regA;
    regions[rB][cB] = regB;
    return ok;
  }

  bool _isRegionConnected(int region) {
    final cells = <List<int>>[];
    for (var row = 0; row < gridDim; row++) {
      for (var col = 0; col < gridDim; col++) {
        if (regions[row][col] == region) cells.add([row, col]);
      }
    }
    if (cells.length <= 1) return cells.isNotEmpty;

    final visited = <String>{'${cells[0][0]},${cells[0][1]}'};
    final queue = <List<int>>[cells[0]];
    while (queue.isNotEmpty) {
      final cur = queue.removeLast();
      for (final d in const [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ]) {
        final r = cur[0] + d[0];
        final c = cur[1] + d[1];
        final key = '$r,$c';
        if (r >= 0 &&
            r < gridDim &&
            c >= 0 &&
            c < gridDim &&
            regions[r][c] == region &&
            !visited.contains(key)) {
          visited.add(key);
          queue.add([r, c]);
        }
      }
    }
    return visited.length == cells.length;
  }

  // --- Complete-grid solver (MRV + incremental bitmasks) -----------------
  //
  // Row/column/region "used-value" bitmasks make the safety test O(1), so a
  // backtracking step costs O(n²) (the MRV scan) instead of O(n⁵). This is the
  // difference between sub-second and multi-minute generation for irregular
  // jigsaw layouts that require deep backtracking.

  int get _fullMask => ((1 << gridDim) - 1) << 1; // bits 1..gridDim

  static int _popcount(int x) {
    var n = 0;
    while (x != 0) {
      x &= x - 1;
      n++;
    }
    return n;
  }

  bool _fillComplete() {
    // A bad jigsaw shape can still need pathological backtracking; cap the steps
    // so we bail fast and retry with a fresh shape rather than grind for minutes.
    final maxSteps = gridDim <= 9 ? 100000 : 50000;
    final rowMask = List<int>.filled(gridDim, 0);
    final colMask = List<int>.filled(gridDim, 0);
    final regMask = List<int>.filled(gridDim, 0);
    return _solveFill(rowMask, colMask, regMask, _StepCounter(maxSteps));
  }

  bool _solveFill(
    List<int> rowMask,
    List<int> colMask,
    List<int> regMask,
    _StepCounter steps,
  ) {
    if (steps.exceeded) return false;
    steps.value++;

    // Pick the empty cell with the fewest candidates (MRV).
    var br = -1, bc = -1, bestCount = gridDim + 2, bestAllowed = 0;
    final full = _fullMask;
    outer:
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        if (grid[r][c] != 0) continue;
        final allowed =
            full & ~(rowMask[r] | colMask[c] | regMask[regions[r][c]]);
        if (allowed == 0) return false; // dead end
        final count = _popcount(allowed);
        if (count < bestCount) {
          bestCount = count;
          br = r;
          bc = c;
          bestAllowed = allowed;
          if (count == 1) break outer;
        }
      }
    }
    if (br == -1) return true; // grid full → solved

    final candidates = <int>[];
    for (var v = 1; v <= gridDim; v++) {
      if ((bestAllowed & (1 << v)) != 0) candidates.add(v);
    }
    candidates.shuffle(_rng);

    final reg = regions[br][bc];
    for (final v in candidates) {
      final bit = 1 << v;
      grid[br][bc] = v;
      rowMask[br] |= bit;
      colMask[bc] |= bit;
      regMask[reg] |= bit;
      if (_solveFill(rowMask, colMask, regMask, steps)) return true;
      grid[br][bc] = 0;
      rowMask[br] &= ~bit;
      colMask[bc] &= ~bit;
      regMask[reg] &= ~bit;
    }
    return false;
  }

  // --- Hole digging that preserves a unique solution ---------------------

  void _puzzlify() {
    // Snapshot the full grid as the canonical solution.
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        solution[r][c] = grid[r][c];
      }
    }

    _digHoles(_cellsToRemove(difficulty));

    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        isOriginal[r][c] = grid[r][c] != 0;
      }
    }

    notes = List.generate(
      gridDim,
      (_) => List.generate(gridDim, (_) => <int>{}),
    );
  }

  int _cellsToRemove(SudokuDifficulty difficulty) {
    final total = gridDim * gridDim;
    switch (difficulty) {
      case SudokuDifficulty.easy:
        return (total * 0.4).round();
      case SudokuDifficulty.medium:
        return (total * 0.5).round();
      case SudokuDifficulty.hard:
        return (total * 0.6).round();
      case SudokuDifficulty.expert:
        return (total * 0.7).round();
    }
  }

  /// Remove up to [target] cells while keeping the solution unique. Bounded by
  /// [_digBudget] so large/expert boards never hang.
  void _digHoles(int target) {
    final positions = <List<int>>[];
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        positions.add([r, c]);
      }
    }
    positions.shuffle(_rng);

    final stopwatch = Stopwatch()..start();
    var removed = 0;
    for (final pos in positions) {
      if (removed >= target || stopwatch.elapsed > _digBudget) break;
      final r = pos[0];
      final c = pos[1];
      final backup = grid[r][c];
      if (backup == 0) continue;

      grid[r][c] = 0;
      if (_hasUniqueSolution()) {
        removed++;
      } else {
        grid[r][c] = backup; // keep this clue
      }
    }
    DebugLogger.log(
      'Dug $removed/$target holes in ${stopwatch.elapsedMilliseconds}ms.',
    );
  }

  /// True iff the current [grid] (with holes) has exactly one completion.
  /// Solves in place using bitmasks and fully restores the grid afterwards.
  bool _hasUniqueSolution() {
    final rowMask = List<int>.filled(gridDim, 0);
    final colMask = List<int>.filled(gridDim, 0);
    final regMask = List<int>.filled(gridDim, 0);
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        final v = grid[r][c];
        if (v != 0) {
          final bit = 1 << v;
          rowMask[r] |= bit;
          colMask[c] |= bit;
          regMask[regions[r][c]] |= bit;
        }
      }
    }
    return _countSolutions(rowMask, colMask, regMask, 0, 2) == 1;
  }

  int _countSolutions(
    List<int> rowMask,
    List<int> colMask,
    List<int> regMask,
    int found,
    int limit,
  ) {
    var br = -1, bc = -1, bestCount = gridDim + 2, bestAllowed = 0;
    final full = _fullMask;
    outer:
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        if (grid[r][c] != 0) continue;
        final allowed =
            full & ~(rowMask[r] | colMask[c] | regMask[regions[r][c]]);
        if (allowed == 0) return found; // dead end, no solution down here
        final count = _popcount(allowed);
        if (count < bestCount) {
          bestCount = count;
          br = r;
          bc = c;
          bestAllowed = allowed;
          if (count == 1) break outer;
        }
      }
    }
    if (br == -1) return found + 1; // a complete solution

    final reg = regions[br][bc];
    for (var v = 1; v <= gridDim; v++) {
      if ((bestAllowed & (1 << v)) == 0) continue;
      final bit = 1 << v;
      grid[br][bc] = v;
      rowMask[br] |= bit;
      colMask[bc] |= bit;
      regMask[reg] |= bit;
      found = _countSolutions(rowMask, colMask, regMask, found, limit);
      grid[br][bc] = 0;
      rowMask[br] &= ~bit;
      colMask[bc] &= ~bit;
      regMask[reg] &= ~bit;
      if (found >= limit) return found; // early-out: not unique
    }
    return found;
  }

  // --- Gameplay API ------------------------------------------------------

  /// True if placing [num] at (row,col) breaks no row/column/region rule.
  /// Original (given) cells can never be changed.
  bool isValidMove(int row, int col, int num) {
    if (isOriginal[row][col]) return false;
    for (var i = 0; i < gridDim; i++) {
      if (i != col && grid[row][i] == num) return false;
      if (i != row && grid[i][col] == num) return false;
    }
    final region = regions[row][col];
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        if ((r != row || c != col) &&
            regions[r][c] == region &&
            grid[r][c] == num) {
          return false;
        }
      }
    }
    return true;
  }

  void _record(int row, int col) {
    _history.add(
      _UndoEntry(row, col, grid[row][col], Set<int>.from(notes[row][col])),
    );
  }

  /// Place [value] (or 0 to erase). Conflicting values are allowed — the move
  /// is recorded for [undo] and clears the cell's notes. No-ops on givens.
  void setCell(int row, int col, int value) {
    if (isOriginal[row][col]) return;
    _record(row, col);
    grid[row][col] = value;
    notes[row][col].clear();
  }

  void clearCell(int row, int col) => setCell(row, col, 0);

  /// Restore the puzzle to its starting state: clear every non-given cell and
  /// its notes, and drop the undo history. The givens, solution and region
  /// layout are untouched, so this re-plays the *same* board (used by the
  /// "Try Again" path after a game over).
  void reset() {
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        if (!isOriginal[r][c]) {
          grid[r][c] = 0;
          notes[r][c].clear();
        }
      }
    }
    _history.clear();
  }

  /// Toggle a pencil-mark. No-op on givens or cells already holding a value.
  void toggleNote(int row, int col, int value) {
    if (isOriginal[row][col] || grid[row][col] != 0) return;
    if (value < 1 || value > gridDim) return;
    _record(row, col);
    if (!notes[row][col].remove(value)) notes[row][col].add(value);
  }

  /// Revert the most recent edit. Returns the affected cell, or null if the
  /// history is empty.
  List<int>? undo() {
    if (_history.isEmpty) return null;
    final entry = _history.removeLast();
    grid[entry.row][entry.col] = entry.value;
    notes[entry.row][entry.col] = entry.notes;
    return [entry.row, entry.col];
  }

  bool get canUndo => _history.isNotEmpty;

  /// True if (row,col) holds a value that conflicts with another cell in its
  /// row, column or region (used for live error highlighting).
  bool hasConflict(int row, int col) {
    final v = grid[row][col];
    if (v == 0) return false;
    for (var i = 0; i < gridDim; i++) {
      if (i != col && grid[row][i] == v) return true;
      if (i != row && grid[i][col] == v) return true;
    }
    final region = regions[row][col];
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        if ((r != row || c != col) &&
            regions[r][c] == region &&
            grid[r][c] == v) {
          return true;
        }
      }
    }
    return false;
  }

  /// Board is full (no validity guarantee).
  bool isCompleted() {
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        if (grid[r][c] == 0) return false;
      }
    }
    return true;
  }

  /// Board is full **and** every row/column/region is conflict-free. This is
  /// the real win condition — a board filled via the "give answer" hint (which
  /// bypasses [isValidMove]) is only a win when it is genuinely consistent.
  bool isSolved() {
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        final v = grid[r][c];
        if (v == 0) return false;
        for (var i = 0; i < gridDim; i++) {
          if (i != c && grid[r][i] == v) return false;
          if (i != r && grid[i][c] == v) return false;
        }
        final region = regions[r][c];
        for (var rr = 0; rr < gridDim; rr++) {
          for (var cc = 0; cc < gridDim; cc++) {
            if ((rr != r || cc != c) &&
                regions[rr][cc] == region &&
                grid[rr][cc] == v) {
              return false;
            }
          }
        }
      }
    }
    return true;
  }

  // --- Hints -------------------------------------------------------------

  List<SmartHint> getSmartHints(int row, int col) {
    if (isOriginal[row][col] || grid[row][col] != 0) {
      return [
        SmartHint(
          type: HintType.conflict,
          title: 'Cell Occupied',
          description:
              'This cell is already filled or is part of the original puzzle.',
          penalty: 0,
        ),
      ];
    }

    final possible = possibleNumbers(row, col);
    if (possible.isEmpty) {
      return [
        SmartHint(
          type: HintType.conflict,
          title: 'Conflict Detected',
          description:
              'No number can legally go here. Check the row, column, or region '
              'for a mistake.',
          penalty: 0,
        ),
      ];
    }

    final hints = <SmartHint>[];
    if (possible.length == 1) {
      hints.add(
        SmartHint(
          type: HintType.nakedSingle,
          title: 'Only Choice (Naked Single)',
          description: 'There is only one number that can fit in this cell.',
          penalty: 25,
          data: possible.first,
        ),
      );
      return hints;
    }

    for (final num in possible) {
      if (_isHiddenSingle(row, col, num)) {
        hints.add(
          SmartHint(
            type: HintType.hiddenSingle,
            title: 'Hidden Single',
            description:
                'This is the only cell in its row, column, or region where this '
                'number can go.',
            penalty: 30,
            data: num,
          ),
        );
        break;
      }
    }

    hints.add(
      SmartHint(
        type: HintType.showPossible,
        title: 'Show Possible Numbers',
        description: 'Reveals every number that can legally go here.',
        penalty: 15,
        data: possible,
      ),
    );
    hints.add(
      SmartHint(
        type: HintType.giveAnswer,
        title: 'Give Answer',
        description: 'Fills in the correct number.',
        penalty: 50,
        data: solution[row][col],
      ),
    );
    return hints;
  }

  List<int> possibleNumbers(int row, int col) {
    final possible = <int>[];
    for (var num = 1; num <= gridDim; num++) {
      if (isValidMove(row, col, num)) possible.add(num);
    }
    return possible;
  }

  /// True if [num] can go in exactly one empty cell of (row,col)'s row, OR its
  /// column, OR its region.
  bool _isHiddenSingle(int row, int col, int num) {
    // Row
    var rowCount = 0;
    for (var c = 0; c < gridDim; c++) {
      if (grid[row][c] == 0 && isValidMove(row, c, num)) rowCount++;
    }
    if (rowCount == 1) return true;

    // Column
    var colCount = 0;
    for (var r = 0; r < gridDim; r++) {
      if (grid[r][col] == 0 && isValidMove(r, col, num)) colCount++;
    }
    if (colCount == 1) return true;

    // Region
    final region = regions[row][col];
    var regionCount = 0;
    for (var r = 0; r < gridDim; r++) {
      for (var c = 0; c < gridDim; c++) {
        if (regions[r][c] == region &&
            grid[r][c] == 0 &&
            isValidMove(r, c, num)) {
          regionCount++;
        }
      }
    }
    return regionCount == 1;
  }
}

/// Mutable step budget for the backtracking solver.
class _StepCounter {
  _StepCounter(this.max);
  final int max;
  int value = 0;
  bool get exceeded => value > max;
}

/// A single reversible edit (value + notes snapshot) for the undo stack.
class _UndoEntry {
  _UndoEntry(this.row, this.col, this.value, this.notes);
  final int row;
  final int col;
  final int value;
  final Set<int> notes;
}
