import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'saved_game.dart';
import 'sudoku_game.dart';

/// One resume slot. Queue all reads/writes in invocation order, including clear.
class SavedGameService {
  static final SavedGameService _instance = SavedGameService.isolated();
  factory SavedGameService() => _instance;
  SavedGameService.isolated();
  static const storageKey = 'saved_game';
  Future<void>? _writes;

  Future<void> _enqueue(Future<void> Function() action) {
    final previous = _writes ?? Future<void>.value();
    late final Future<void> operation;
    operation = previous.then((_) async {
      try {
        await action();
      } catch (e) {
        DebugLogger.error('Could not persist current game.', e);
      } finally {
        // Don't retain a completed Future from an obsolete execution zone.
        if (identical(_writes, operation)) _writes = null;
      }
    });
    _writes = operation;
    return operation;
  }

  Future<void> save(SavedGame game) {
    final encoded = jsonEncode(game.toJson());
    return _enqueue(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, encoded);
    });
  }

  Future<void> clear() => _enqueue(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  });

  Future<SavedGame?> load() async {
    await _writes;
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(storageKey);
      if (data == null) return null;
      return SavedGame.fromJson(jsonDecode(data) as Map<String, dynamic>);
    } catch (e) {
      DebugLogger.error('Ignoring invalid saved game.', e);
      return null;
    }
  }
}
