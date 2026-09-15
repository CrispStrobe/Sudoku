// Persistence and the puzzle-blueprint cache, split out of main.dart.
// These are plain singletons with no widget dependencies.

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'sudoku_game.dart';
// ---------------------------------------------------------------------------

class PuzzleCache {
  static final PuzzleCache _instance = PuzzleCache._internal();
  factory PuzzleCache() => _instance;
  PuzzleCache._internal();

  /// Cap on cached blueprints per size/shape key — bounds the persisted payload
  /// (and avoids unbounded growth) while keeping plenty of variety.
  static const int _maxPerKey = 25;

  /// Bundled, read-only database (shipped as an asset) — never persisted back.
  final Map<String, List<PuzzleBlueprint>> _bundled = {};

  /// Player-generated blueprints, persisted to [SharedPreferences].
  final Map<String, List<PuzzleBlueprint>> _cache = {};
  final StorageService _storage = StorageService();
  final math.Random _random = math.Random();

  Future<void> initialize() async {
    // 1. The bundled, pre-generated database (always present, so the first play
    //    — and the web build — is instant, with no solving required).
    await _loadBundled();
    // 2. Anything the player generated and persisted locally.
    for (final bp in await _storage.loadBlueprints()) {
      _cache.putIfAbsent(_key(bp.gridSize, bp.gridShape), () => []).add(bp);
    }
    DebugLogger.log(
      'Puzzle cache: ${_bundled.length} bundled + ${_cache.length} local types.',
    );
  }

  Future<void> _loadBundled() async {
    try {
      final data = await rootBundle.loadString('assets/puzzles.json');
      final list = jsonDecode(data) as List<dynamic>;
      for (final json in list) {
        final bp = PuzzleBlueprint.fromJson(json as Map<String, dynamic>);
        _bundled.putIfAbsent(_key(bp.gridSize, bp.gridShape), () => []).add(bp);
      }
    } catch (e) {
      DebugLogger.error('No bundled puzzle database.', e);
    }
  }

  String _key(GridSize size, GridShape shape) => '${size.name}-${shape.name}';

  PuzzleBlueprint? getRandom(GridSize size, GridShape shape) {
    final key = _key(size, shape);
    final pool = [...?_bundled[key], ...?_cache[key]];
    if (pool.isEmpty) return null;
    return pool[_random.nextInt(pool.length)];
  }

  Future<void> set(PuzzleBlueprint blueprint) async {
    final list = _cache.putIfAbsent(
      _key(blueprint.gridSize, blueprint.gridShape),
      () => [],
    );
    list.add(blueprint);
    if (list.length > _maxPerKey) {
      list.removeRange(0, list.length - _maxPerKey); // drop oldest
    }
    // Persist only player-generated blueprints (the bundled DB ships with app).
    await _storage.saveBlueprints(_cache.values.expand((l) => l).toList());
  }
}

/// Stores the puzzle-blueprint cache in [SharedPreferences] (works on web,
/// mobile and desktop alike).
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  static const String _key = 'puzzle_blueprints';

  /// Encoded form of each blueprint, memoised by identity.
  ///
  /// Blueprints are immutable once constructed, and [PuzzleCache.set]
  /// re-persists the whole collection on every add — so without this, adding
  /// the Nth puzzle re-encodes the N-1 already stored. The admin generator adds
  /// in a loop, which made that quadratic. An [Expando] holds its keys weakly,
  /// so dropped blueprints take their cached JSON with them.
  static final Expando<String> _encoded = Expando<String>();

  static String _encode(PuzzleBlueprint bp) =>
      _encoded[bp] ??= jsonEncode(bp.toJson());

  Future<List<PuzzleBlueprint>> loadBlueprints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contents = prefs.getString(_key);
      if (contents == null || contents.isEmpty) return [];
      final jsonList = jsonDecode(contents) as List<dynamic>;
      return jsonList
          .map((json) => PuzzleBlueprint.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      DebugLogger.error('Failed to load blueprints.', e);
      return [];
    }
  }

  Future<void> saveBlueprints(List<PuzzleBlueprint> blueprints) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Assembled from the memoised per-blueprint JSON rather than encoding
      // the list wholesale.
      await prefs.setString(_key, '[${blueprints.map(_encode).join(',')}]');
    } catch (e) {
      DebugLogger.error('Failed to save blueprints.', e);
    }
  }
}

/// Persists [GameStats] in [SharedPreferences].
class StatsService {
  static final StatsService _instance = StatsService._internal();
  factory StatsService() => _instance;
  StatsService._internal();

  static const String _key = 'game_stats';

  Future<Map<String, dynamic>?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contents = prefs.getString(_key);
      if (contents == null || contents.isEmpty) return null;
      return jsonDecode(contents) as Map<String, dynamic>;
    } catch (e) {
      DebugLogger.error('Failed to load stats.', e);
      return null;
    }
  }

  Future<void> save(Map<String, dynamic> json) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(json));
    } catch (e) {
      DebugLogger.error('Failed to save stats.', e);
    }
  }
}
