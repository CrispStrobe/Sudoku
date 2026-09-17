import 'dart:convert';
import 'sudoku_game.dart';
import 'variant_engine.dart';

/// Versioned snapshot of an unfinished run, separate from the ready cache.
/// JSON is captured eagerly so subsequent edits cannot mutate a pending save.
class SavedGame {
  static const schemaVersion = 1;
  final String _encoded;
  SavedGame._(Map<String, dynamic> data) : _encoded = jsonEncode(data);
  Map<String, dynamic> toJson() => jsonDecode(_encoded) as Map<String, dynamic>;
  T _get<T>(String key) => toJson()[key] as T;
  GridSize get size => GridSize.values.byName(_get('size'));
  GridShape get shape => GridShape.values.byName(_get('shape'));
  GameMode get gameMode => GameMode.values.byName(_get('gameMode'));
  SudokuVariant get variant => SudokuVariant.values.byName(_get('variant'));
  SudokuDifficulty get difficulty =>
      SudokuDifficulty.values.byName(_get('difficulty'));
  SudokuDifficulty? get rating => _get('rating') == null
      ? null
      : SudokuDifficulty.values.byName(_get('rating'));
  Duration get elapsed => Duration(microseconds: _get('elapsedUs'));
  int get score => _get('score');
  int get mistakes => _get('mistakes');
  int get hintsUsed => _get('hintsUsed');
  int? get dailySeed => _get('dailySeed');
  String? get dailyKey => _get('dailyKey');
  bool get notesMode => _get('notesMode');
  List<KillerCage> get cages => [
    for (final c in _get<List<dynamic>>('cages').cast<Map<String, dynamic>>())
      KillerCage(cells: _grid(c['cells']), sum: c['sum'] as int),
  ];
  static List<List<int>> _grid(dynamic value) => [
    for (final row in value as List) (row as List).cast<int>().toList(),
  ];

  factory SavedGame.capture({
    required SudokuGame game,
    required GridSize size,
    required GridShape shape,
    required GameMode gameMode,
    required Duration elapsed,
    required int score,
    required int mistakes,
    required int hintsUsed,
    int? dailySeed,
    String? dailyKey,
    SudokuDifficulty? rating,
    List<KillerCage> cages = const [],
    bool notesMode = false,
  }) => SavedGame._({
    'version': schemaVersion,
    'givens': [
      for (var r = 0; r < game.gridDim; r++)
        [
          for (var c = 0; c < game.gridDim; c++)
            game.isOriginal[r][c] ? game.grid[r][c] : 0,
        ],
    ],
    'grid': game.grid,
    'solution': game.solution,
    'regions': game.regions,
    'notes': [
      for (final row in game.notes)
        [for (final cell in row) cell.toList()..sort()],
    ],
    'size': size.name,
    'shape': shape.name,
    'gameMode': gameMode.name,
    'difficulty': game.difficulty.name,
    'variant': game.variant.name,
    'rating': rating?.name,
    'elapsedUs': elapsed.inMicroseconds,
    'score': score,
    'mistakes': mistakes,
    'hintsUsed': hintsUsed,
    'dailySeed': dailySeed,
    'dailyKey': dailyKey,
    'notesMode': notesMode,
    'cages': [
      for (final cage in cages) {'cells': cage.cells, 'sum': cage.sum},
    ],
  });

  factory SavedGame.fromJson(Map<String, dynamic> data) {
    void require(bool valid) {
      if (!valid) throw const FormatException('Invalid saved game');
    }

    require(data['version'] == schemaVersion);
    final saved = SavedGame._(data);
    final dim = gridDimensionFor(saved.size);
    // Eagerly validate every metadata getter before exposing a resume button.
    saved.shape;
    saved.gameMode;
    saved.rating;
    saved.notesMode;
    require(
      saved.elapsed >= Duration.zero &&
          saved.score >= 0 &&
          saved.mistakes >= 0 &&
          saved.hintsUsed >= 0 &&
          saved.hintsUsed <= maxHintsFor(saved.difficulty),
    );
    final key = saved.dailyKey;
    require((key == null) == (saved.dailySeed == null));
    if (key != null) {
      require(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key));
      final date = DateTime.parse(key);
      require(
        dailyDateKey(date) == key &&
            date.year * 10000 + date.month * 100 + date.day == saved.dailySeed,
      );
    }
    final givens = _grid(data['givens']);
    final grid = _grid(data['grid']);
    final solution = _grid(data['solution']);
    final regions = _grid(data['regions']);
    for (final matrix in [givens, grid, solution, regions]) {
      require(matrix.length == dim && matrix.every((row) => row.length == dim));
    }
    final notes = data['notes'] as List;
    require(notes.length == dim);
    final regionCounts = List.filled(dim, 0);
    for (var r = 0; r < dim; r++) {
      final rowNotes = notes[r] as List;
      require(rowNotes.length == dim);
      for (var c = 0; c < dim; c++) {
        require(solution[r][c] >= 1 && solution[r][c] <= dim);
        require(grid[r][c] >= 0 && grid[r][c] <= dim);
        require(regions[r][c] >= 0 && regions[r][c] < dim);
        regionCounts[regions[r][c]]++;
        require(
          givens[r][c] == 0 ||
              (givens[r][c] == solution[r][c] && grid[r][c] == givens[r][c]),
        );
        final cellNotes = (rowNotes[c] as List).cast<int>();
        require(cellNotes.every((v) => v >= 1 && v <= dim));
        require(cellNotes.toSet().length == cellNotes.length);
        require(grid[r][c] == 0 || cellNotes.isEmpty);
      }
    }
    require(regionCounts.every((n) => n == dim));
    final solved = SudokuGame.fromState(
      givens: solution,
      solution: solution,
      regions: regions,
      difficulty: saved.difficulty,
      variant: saved.variant,
    );
    require(solved.isSolved()); // validity check only; no search or rating
    final cages = saved.cages;
    if (saved.variant == SudokuVariant.killer) {
      final covered = <int>{};
      for (final cage in cages) {
        require(cage.cells.isNotEmpty && cage.sum > 0);
        for (final cell in cage.cells) {
          require(cell.length == 2 && cell.every((v) => v >= 0 && v < dim));
          require(covered.add(cell[0] * dim + cell[1]));
        }
        require(cage.isSatisfied(solution));
      }
      require(covered.length == dim * dim);
    } else {
      require(cages.isEmpty);
    }
    final restored = saved.createGame();
    require(
      !restored.isSolved() ||
          (saved.variant == SudokuVariant.killer &&
              !cagesSatisfied(cages, grid)),
    );
    return saved;
  }

  /// Reconstruct directly: never generate, dig holes, or run a rating solver.
  /// Existing engine history is private; undo starts fresh after restoration.
  SudokuGame createGame() {
    final data = toJson();
    final game = SudokuGame.fromState(
      givens: _grid(data['givens']),
      solution: _grid(data['solution']),
      regions: _grid(data['regions']),
      difficulty: difficulty,
      variant: variant,
    );
    game.grid = _grid(data['grid']);
    game.notes = [
      for (final row in data['notes'] as List)
        [for (final cell in row as List) (cell as List).cast<int>().toSet()],
    ];
    return game;
  }
}
