import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import 'sudoku_game.dart';
import 'variant_engine.dart';

/// Read-only store of pre-generated KenKen puzzles shipped in the app bundle.
///
/// KenKen generates faster than either Killer or Thermo — the cages are strong
/// constraints, so a random partition over a Latin square is usually unique on
/// the first attempt — but "usually fast" is not "bounded", and on the web the
/// generator runs on the only thread there is. Ship the boards, the same trade
/// [KillerPuzzleBundle] makes.
///
/// The live generator stays as a bounded fallback for a configuration the
/// bundle does not cover.
class KenKenPuzzleBundle {
  static final KenKenPuzzleBundle _instance = KenKenPuzzleBundle._internal();
  factory KenKenPuzzleBundle() => _instance;
  KenKenPuzzleBundle._internal();

  /// Separate instance for tests, so one test's loads cannot leak into another.
  KenKenPuzzleBundle.isolated();

  static const String assetPath = 'assets/kenken_puzzles.json';

  /// Fixes which board [get] serves. Only golden tests set it: the pool is
  /// drawn from at random, so a rendered KenKen screen is a different picture
  /// every run, and a golden that changes every run is not a golden. Mirrors
  /// `debugParticleSeed` in `game_screen.dart`, which exists for the same
  /// reason.
  static int? debugSeed;

  final Map<String, List<KenKenPuzzle>> _bundled = {};
  final Map<String, KenKenPuzzle> _lastServed = {};
  late final math.Random _random = math.Random(debugSeed);
  Future<void>? _initializing;

  static String keyFor(GridSize size, SudokuDifficulty difficulty) =>
      '${size.name}-${difficulty.name}';

  /// Load the bundle. Idempotent, and never throws: a missing or corrupt asset
  /// simply means every request falls back to the generator.
  Future<void> initialize() => _initializing ??= _load();

  Future<void> _load() async {
    try {
      final decoded =
          jsonDecode(await rootBundle.loadString(assetPath))
              as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        for (final item in entry.value as List) {
          try {
            _bundled
                .putIfAbsent(entry.key, () => [])
                .add(KenKenPuzzle.fromJson(item as Map<String, dynamic>));
          } catch (e) {
            DebugLogger.error('Skipping invalid bundled KenKen puzzle.', e);
          }
        }
      }
      DebugLogger.log(
        'KenKen bundle: ${_bundled.values.fold(0, (n, l) => n + l.length)} '
        'puzzles across ${_bundled.length} configurations.',
      );
    } catch (e) {
      DebugLogger.error('Failed to load bundled KenKen puzzles.', e);
    }
  }

  /// A random bundled puzzle for this configuration, or null if there is none.
  ///
  /// Avoids handing back the board just served for the same key, so "new game"
  /// twice in a row does not replay the identical grid.
  KenKenPuzzle? get(GridSize size, SudokuDifficulty difficulty) {
    final key = keyFor(size, difficulty);
    final pool = [...?_bundled[key]];
    if (pool.isEmpty) return null;
    // With a fixed seed the pool must not shrink as boards are served, or the
    // choice stops being reproducible.
    if (pool.length > 1 && debugSeed == null) pool.remove(_lastServed[key]);
    final puzzle = pool[_random.nextInt(pool.length)];
    _lastServed[key] = puzzle;
    return puzzle;
  }

  /// How many puzzles are loaded for a configuration (diagnostics and tests).
  int countFor(GridSize size, SudokuDifficulty difficulty) =>
      _bundled[keyFor(size, difficulty)]?.length ?? 0;
}
