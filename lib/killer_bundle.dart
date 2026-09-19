import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import 'sudoku_game.dart';
import 'variant_engine.dart';

/// Read-only store of pre-generated Killer puzzles shipped in the app bundle.
///
/// Killer generation is the slowest thing the app does: the base solution comes
/// from the bitmask engine, but proving that the cage sums admit exactly one
/// solution is a CSP search, and a 9x9 expert board takes several seconds — on
/// the web, on the main thread, because there is no `Isolate.spawn` there. That
/// is a long time to sit behind a spinner for the first board of a session.
///
/// So the same trick the classic boards already use (`ready_puzzle.dart`):
/// generate offline, ship the result, and play it instantly. The engine stays
/// the fallback for a configuration the bundle does not cover, and for the
/// second and subsequent boards of a long session.
///
/// Unlike [ReadyPuzzleCache] this has no local half — nothing is written back
/// to `SharedPreferences`. A player-generated Killer board is already the
/// slow path; caching it would only help if they replayed the identical
/// configuration, and the bundle covers that case better.
class KillerPuzzleBundle {
  static final KillerPuzzleBundle _instance = KillerPuzzleBundle._internal();
  factory KillerPuzzleBundle() => _instance;
  KillerPuzzleBundle._internal();

  /// Separate instance for tests, so one test's loads cannot leak into another.
  KillerPuzzleBundle.isolated();

  static const String assetPath = 'assets/killer_puzzles.json';

  final Map<String, List<KillerPuzzle>> _bundled = {};
  final Map<String, KillerPuzzle> _lastServed = {};
  final math.Random _random = math.Random();
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
                .add(KillerPuzzle.fromJson(item as Map<String, dynamic>));
          } catch (e) {
            DebugLogger.error('Skipping invalid bundled Killer puzzle.', e);
          }
        }
      }
      DebugLogger.log(
        'Killer bundle: ${_bundled.values.fold(0, (n, l) => n + l.length)} '
        'puzzles across ${_bundled.length} configurations.',
      );
    } catch (e) {
      DebugLogger.error('Failed to load bundled Killer puzzles.', e);
    }
  }

  /// A random bundled puzzle for this configuration, or null if there is none.
  ///
  /// Avoids handing back the board just served for the same key, so "new game"
  /// twice in a row does not replay the identical grid.
  KillerPuzzle? get(GridSize size, SudokuDifficulty difficulty) {
    final key = keyFor(size, difficulty);
    final pool = [...?_bundled[key]];
    if (pool.isEmpty) return null;
    if (pool.length > 1) pool.remove(_lastServed[key]);
    final puzzle = pool[_random.nextInt(pool.length)];
    _lastServed[key] = puzzle;
    return puzzle;
  }

  /// How many puzzles are loaded for a configuration (diagnostics and tests).
  int countFor(GridSize size, SudokuDifficulty difficulty) =>
      _bundled[keyFor(size, difficulty)]?.length ?? 0;
}
