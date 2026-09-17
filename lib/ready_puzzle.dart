import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'sudoku_game.dart';

/// A puzzle stored in playable form: givens, solution, regions and the
/// technique rating, all captured once at generation time.
///
/// Unlike [PuzzleBlueprint] (which stores only the solved grid and must
/// re-dig holes and re-rate on every load), a [ReadyPuzzle] reconstructs a
/// game with zero solving work — [SudokuGame.fromState] just deep-copies.
class ReadyPuzzle {
  final List<List<int>> givens;
  final List<List<int>> solution;
  final List<List<int>> regions;
  final GridSize size;
  final GridShape shape;

  /// Difficulty the puzzle was generated for (drives mistake/hint limits).
  final SudokuDifficulty difficulty;

  /// Technique rating captured when the board was built; null when unrated
  /// (the UI falls back to the generation difficulty).
  final SudokuDifficulty? rating;

  ReadyPuzzle._(
    List<List<int>> givens,
    List<List<int>> solution,
    List<List<int>> regions,
    this.size,
    this.shape,
    this.difficulty,
    this.rating,
  ) : givens = _freeze(givens),
      solution = _freeze(solution),
      regions = _freeze(regions);

  static List<List<int>> _freeze(List<List<int>> grid) =>
      List.unmodifiable(grid.map((row) => List<int>.unmodifiable(row)));

  /// Capture a fully-initialized game in playable form.
  factory ReadyPuzzle.fromGame(
    SudokuGame game,
    GridSize size,
    GridShape shape, {
    SudokuDifficulty? rating,
  }) {
    if (game.variant != SudokuVariant.classic) {
      throw ArgumentError('ReadyPuzzle stores classic-rule boards only.');
    }
    return ReadyPuzzle._(
      [
        for (var r = 0; r < game.gridDim; r++)
          [
            for (var c = 0; c < game.gridDim; c++)
              game.isOriginal[r][c] ? game.grid[r][c] : 0,
          ],
      ],
      game.solution,
      game.regions,
      size,
      shape,
      game.difficulty,
      rating,
    );
  }

  factory ReadyPuzzle.fromJson(Map<String, dynamic> json) {
    List<List<int>> grid(String key) => (json[key] as List)
        .map((row) => (row as List).cast<int>().toList())
        .toList();

    final puzzle = ReadyPuzzle._(
      grid('givens'),
      grid('solution'),
      grid('regions'),
      GridSize.values.byName(json['size'] as String),
      GridShape.values.byName(json['shape'] as String),
      SudokuDifficulty.values.byName(json['difficulty'] as String),
      json['rating'] == null
          ? null
          : SudokuDifficulty.values.byName(json['rating'] as String),
    );

    final dim = gridDimensionFor(puzzle.size);
    for (final grid2 in [puzzle.givens, puzzle.solution, puzzle.regions]) {
      if (grid2.length != dim || grid2.any((row) => row.length != dim)) {
        throw const FormatException('ready puzzle: wrong dimensions');
      }
    }
    for (var r = 0; r < dim; r++) {
      for (var c = 0; c < dim; c++) {
        final value = puzzle.solution[r][c];
        if (value < 1 || value > dim) {
          throw const FormatException('ready puzzle: bad solution value');
        }
        if (puzzle.regions[r][c] < 0 || puzzle.regions[r][c] >= dim) {
          throw const FormatException('ready puzzle: bad region id');
        }
        final given = puzzle.givens[r][c];
        if (given != 0 && given != value) {
          throw const FormatException('ready puzzle: given != solution');
        }
      }
    }
    return puzzle;
  }

  Map<String, dynamic> toJson() => {
    'givens': givens,
    'solution': solution,
    'regions': regions,
    'size': size.name,
    'shape': shape.name,
    'difficulty': difficulty.name,
    'rating': rating?.name,
  };

  /// Build a fresh, independent playable game. No solving, no hole digging.
  SudokuGame createGame() => SudokuGame.fromState(
    givens: givens,
    solution: solution,
    regions: regions,
    difficulty: difficulty,
  );
}

/// Persists [ReadyPuzzle]s in [SharedPreferences], keyed by
/// size/shape/difficulty so a hit replays the same rules the player chose.
///
/// Mirrors PuzzleCache's design: a fixed cap per key bounds the payload, and
/// only player-generated puzzles are persisted (the bundled DB is read-only).
class ReadyPuzzleCache {
  static final ReadyPuzzleCache _instance = ReadyPuzzleCache._internal();
  factory ReadyPuzzleCache() => _instance;
  ReadyPuzzleCache._internal();

  /// Separate cache instance for independent storage sessions and tests.
  ReadyPuzzleCache.isolated();

  static const String _key = 'ready_puzzles';
  static const int _maxPerKey = 8;

  final Map<String, List<ReadyPuzzle>> _local = {};
  final Map<String, List<ReadyPuzzle>> _bundled = {};
  final Map<String, ReadyPuzzle> _lastServed = {};
  Future<void>? _initializing;
  Future<void> _writes = Future<void>.value();
  final math.Random _random = math.Random();

  static String _keyFor(GridSize size, GridShape shape, SudokuDifficulty d) =>
      '${size.name}-${shape.name}-${d.name}';

  /// Load persisted puzzles. Idempotent.
  Future<void> initialize({bool loadBundle = true}) =>
      _initializing ??= _load(loadBundle);

  Future<void> _load(bool loadBundle) async {
    if (loadBundle) {
      try {
        final entries =
            jsonDecode(await rootBundle.loadString('assets/ready_puzzles.json'))
                as List<dynamic>;
        for (final entry in entries) {
          try {
            final ready = ReadyPuzzle.fromJson(entry as Map<String, dynamic>);
            _bundled
                .putIfAbsent(
                  _keyFor(ready.size, ready.shape, ready.difficulty),
                  () => [],
                )
                .add(ready);
          } catch (e) {
            DebugLogger.error('Skipping invalid bundled puzzle.', e);
          }
        }
      } catch (e) {
        DebugLogger.error('Failed to load bundled ready puzzles.', e);
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final contents = prefs.getString(_key);
      if (contents == null || contents.isEmpty) return;
      final list = jsonDecode(contents) as List<dynamic>;
      for (final item in list) {
        try {
          final ready = ReadyPuzzle.fromJson(item as Map<String, dynamic>);
          _cache(ready);
        } catch (e) {
          DebugLogger.error('Skipping invalid ready puzzle.', e);
        }
      }
    } catch (e) {
      DebugLogger.error('Failed to load ready puzzles.', e);
    }
  }

  void _cache(ReadyPuzzle ready) {
    final list = _cacheBucket(ready);
    list.add(ready);
    if (list.length > _maxPerKey) {
      list.removeRange(0, list.length - _maxPerKey); // drop oldest
    }
  }

  List<ReadyPuzzle> _cacheBucket(ReadyPuzzle ready) => _local.putIfAbsent(
    _keyFor(ready.size, ready.shape, ready.difficulty),
    () => [],
  );

  /// Store a puzzle generated for [size]/[shape]/[difficulty] and persist.
  Future<void> add(ReadyPuzzle ready) async {
    await initialize();
    _cache(ready);
    _writes = _writes.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final all = _local.values.expand((l) => l);
        await prefs.setString(
          _key,
          jsonEncode(all.map((p) => p.toJson()).toList()),
        );
      } catch (e) {
        DebugLogger.error('Failed to save ready puzzles.', e);
      }
    });
    await _writes;
  }

  /// A random stored puzzle for this exact configuration, or null.
  ReadyPuzzle? get(
    GridSize size,
    GridShape shape,
    SudokuDifficulty difficulty,
  ) {
    final key = _keyFor(size, shape, difficulty);
    final pool = [...?_bundled[key], ...?_local[key]];
    if (pool.isEmpty) return null;
    if (pool.length > 1) pool.remove(_lastServed[key]);
    final ready = pool[_random.nextInt(pool.length)];
    _lastServed[key] = ready;
    return ready;
  }
}
