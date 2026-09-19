import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import 'sudoku_game.dart';
import 'variant_engine.dart';

/// Read-only store of pre-generated Thermo puzzles shipped in the app bundle.
///
/// Same reasoning as [KillerPuzzleBundle], and the same trade. A good Thermo
/// board — the grid pinned down by the thermometers alone, with no givens at
/// all — comes from drawing line shapes and asking the CSP for a grid that fits
/// them, and most random layouts turn out contradictory. Proving that costs a
/// full enumeration per attempt, so a single board can cost dozens. That is
/// fine offline and not fine on the main thread, which on the web is the only
/// thread there is.
///
/// The live generator stays as a bounded fallback for a configuration the
/// bundle does not cover.
class ThermoPuzzleBundle {
  static final ThermoPuzzleBundle _instance = ThermoPuzzleBundle._internal();
  factory ThermoPuzzleBundle() => _instance;
  ThermoPuzzleBundle._internal();

  /// Separate instance for tests, so one test's loads cannot leak into another.
  ThermoPuzzleBundle.isolated();

  static const String assetPath = 'assets/thermo_puzzles.json';

  /// Fixes which board [get] serves. Only golden tests set it: the pool is
  /// drawn from at random, so a rendered Thermo screen is a different picture
  /// every run, and a golden that changes every run is not a golden. Mirrors
  /// `debugParticleSeed` in `game_screen.dart`, which exists for the same
  /// reason.
  static int? debugSeed;

  final Map<String, List<ThermoPuzzle>> _bundled = {};
  final Map<String, ThermoPuzzle> _lastServed = {};
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
                .add(ThermoPuzzle.fromJson(item as Map<String, dynamic>));
          } catch (e) {
            DebugLogger.error('Skipping invalid bundled Thermo puzzle.', e);
          }
        }
      }
      DebugLogger.log(
        'Thermo bundle: ${_bundled.values.fold(0, (n, l) => n + l.length)} '
        'puzzles across ${_bundled.length} configurations.',
      );
    } catch (e) {
      DebugLogger.error('Failed to load bundled Thermo puzzles.', e);
    }
  }

  /// A random bundled puzzle for this configuration, or null if there is none.
  ///
  /// Avoids handing back the board just served for the same key, so "new game"
  /// twice in a row does not replay the identical grid.
  ThermoPuzzle? get(GridSize size, SudokuDifficulty difficulty) {
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
