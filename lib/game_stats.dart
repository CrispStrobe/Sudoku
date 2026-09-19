import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'services.dart';
import 'sudoku_game.dart';

// ---------------------------------------------------------------------------
// Themes / stats / achievements
// ---------------------------------------------------------------------------

class EnvironmentalTheme {
  final String name;
  final List<Color> gradient;
  final Color primary;
  final Color accent;
  final Color cellHighlight;
  final List<String> particleEmojis;
  final String description;

  const EnvironmentalTheme({
    required this.name,
    required this.gradient,
    required this.primary,
    required this.accent,
    required this.cellHighlight,
    required this.particleEmojis,
    required this.description,
  });
}

class GameStats {
  static int totalPuzzlesSolved = 0;
  static int totalHintsUsed = 0;
  static Duration bestTime = const Duration(hours: 99);
  static int currentStreak = 0;

  /// Highest [currentStreak] ever reached (never reset by a loss).
  static int longestStreak = 0;

  /// Number of puzzles abandoned by hitting the mistake limit.
  static int gamesLost = 0;

  /// `YYYY-MM-DD` of the most recently completed daily puzzle (null if none).
  static String? lastDailyDate;

  /// How many distinct daily puzzles have been completed.
  static int dailyCompletedCount = 0;

  // --- Per-category solve counters -----------------------------------------
  //
  // Keyed by the enum's `.name` so a future variant/size/difficulty can be
  // added without a migration: unknown keys simply read back as absent, and
  // nothing here is load-bearing for game state — only for achievement tiers.

  /// Wins per [SudokuDifficulty].
  static Map<String, int> solvedByDifficulty = {};

  /// Wins per [SudokuVariant] (`classic`, `x`, `killer`).
  static Map<String, int> solvedByVariant = {};

  /// Wins per [GridSize] (4x4 through 12x12).
  static Map<String, int> solvedBySize = {};

  /// Wins on a jigsaw (irregular-region) board.
  static int jigsawSolved = 0;

  /// Wins with no mistakes at all.
  static int flawlessSolves = 0;

  /// Wins with no mistakes *and* no hints.
  static int perfectSolves = 0;

  /// [perfectSolves] restricted to expert difficulty — the top tier.
  static int expertPerfectSolves = 0;

  static int solvedAt(SudokuDifficulty d) => solvedByDifficulty[d.name] ?? 0;

  /// Every rule variant beaten at least once, jigsaw included.
  ///
  /// Reads `SudokuVariant.values`, so adding a variant raises the bar for this
  /// achievement — deliberately: it is called "every variant". Players who
  /// already earned it keep it, because `unlockedAchievements` is persisted and
  /// only ever appended to; the new requirement applies to anyone who has not
  /// unlocked it yet. If you add a variant, `achievements_test.dart` will fail
  /// until you beat that one too, which is the reminder working.
  static bool get hasBeatenEveryVariant =>
      SudokuVariant.values.every((v) => (solvedByVariant[v.name] ?? 0) > 0) &&
      jigsawSolved > 0;

  /// Every board size beaten at least once.
  static bool get hasBeatenEverySize =>
      GridSize.values.every((g) => (solvedBySize[g.name] ?? 0) > 0);

  /// Records one win across every counter above.
  static void recordSolve({
    required SudokuDifficulty difficulty,
    required SudokuVariant variant,
    required GridSize size,
    required GridShape shape,
    required int mistakes,
    required int hintsUsed,
  }) {
    bump(Map<String, int> m, String k) => m[k] = (m[k] ?? 0) + 1;
    bump(solvedByDifficulty, difficulty.name);
    bump(solvedByVariant, variant.name);
    bump(solvedBySize, size.name);
    if (shape == GridShape.jigsaw) jigsawSolved++;
    if (mistakes == 0) {
      flawlessSolves++;
      if (hintsUsed == 0) {
        perfectSolves++;
        if (difficulty == SudokuDifficulty.expert) expertPerfectSolves++;
      }
    }
  }

  /// Whether the daily puzzle for [date] has already been completed.
  static bool isDailyDoneOn(DateTime date) =>
      lastDailyDate == dailyDateKey(date);

  static Set<String> unlockedAchievements = {};

  /// Admin panel + all-themes-unlocked only in debug builds.
  static const bool debugMode = kDebugMode;

  static bool useSavedPuzzles = true;

  static Set<String> unlockedThemes = debugMode ? {...themes.keys} : {'Ocean'};

  static String currentTheme = 'Ocean';

  /// Manual language override (`'en'`/`'de'`); `null` follows the system
  /// locale. A [ValueNotifier] so the root [SudokuApp] can rebuild
  /// [MaterialApp] with the new locale as soon as the Settings sheet changes
  /// it, without lifting state through the whole widget tree.
  static final ValueNotifier<String?> localeNotifier = ValueNotifier<String?>(
    null,
  );
  static String? get localeCode => localeNotifier.value;
  static set localeCode(String? code) => localeNotifier.value = code;

  /// "Infinite errors" mode: when true, the mistake limit is never enforced
  /// regardless of difficulty.
  static bool unlimitedMistakes = false;

  static const Map<String, EnvironmentalTheme> themes = {
    'Ocean': EnvironmentalTheme(
      name: 'Ocean',
      gradient: [Color(0xFF0066CC), Color(0xFF003D7A), Color(0xFF001A33)],
      primary: Color(0xFF0066CC),
      accent: Color(0xFFB3D9FF),
      cellHighlight: Color(0xFFE6F3FF),
      particleEmojis: ['🐠', '🐙', '🦑', '🌊', '💧'],
      description: 'Deep ocean depths',
    ),
    'Forest': EnvironmentalTheme(
      name: 'Forest',
      gradient: [Color(0xFF2D5016), Color(0xFF1A3009), Color(0xFF0D1804)],
      primary: Color(0xFF2D5016),
      accent: Color(0xFFB3E5A3),
      cellHighlight: Color(0xFFE8F5E0),
      particleEmojis: ['🌲', '🍃', '🦋', '🌿', '🐛'],
      description: 'Mysterious forest',
    ),
    'Space': EnvironmentalTheme(
      name: 'Space',
      gradient: [Color(0xFF1A0033), Color(0xFF0D001A), Color(0xFF000000)],
      primary: Color(0xFF6600CC),
      accent: Color(0xFFD4B3FF),
      cellHighlight: Color(0xFFF0E6FF),
      particleEmojis: ['⭐', '🌟', '💫', '🚀', '🛸'],
      description: 'Cosmic adventure',
    ),
    'Fire': EnvironmentalTheme(
      name: 'Fire',
      gradient: [Color(0xFFCC3300), Color(0xFF991F00), Color(0xFF660A00)],
      primary: Color(0xFFCC3300),
      accent: Color(0xFFFFB3A3),
      cellHighlight: Color(0xFFFFE6E0),
      particleEmojis: ['🔥', '⚡', '💥', '🌋', '☄️'],
      description: 'Volcanic eruption',
    ),
    'Ice': EnvironmentalTheme(
      name: 'Ice',
      gradient: [Color(0xFF00CCFF), Color(0xFF0099CC), Color(0xFF006699)],
      primary: Color(0xFF0099CC),
      accent: Color(0xFFB3E5FF),
      cellHighlight: Color(0xFFE6F7FF),
      particleEmojis: ['❄️', '🧊', '⛄', '🌨️', '💎'],
      description: 'Frozen tundra',
    ),
    // Reward themes for the upper achievement tiers. Deliberately more
    // saturated/atmospheric than the starter set so a late unlock reads as a
    // genuine step up rather than another colour swap.
    'Aurora': EnvironmentalTheme(
      name: 'Aurora',
      gradient: [Color(0xFF00343D), Color(0xFF052E4A), Color(0xFF0B0B2B)],
      primary: Color(0xFF00A88E),
      accent: Color(0xFFA8F0E2),
      cellHighlight: Color(0xFFE2FBF5),
      particleEmojis: [
        '\u2744\uFE0F',
        '\u2728',
        '\uD83C\uDF0C',
        '\uD83D\uDCA0',
        '\uD83E\uDDCA',
      ],
      description: 'Polar light',
    ),
    'Sakura': EnvironmentalTheme(
      name: 'Sakura',
      gradient: [Color(0xFF7A2B4E), Color(0xFF4A1733), Color(0xFF240A1B)],
      primary: Color(0xFFC2185B),
      accent: Color(0xFFF8C8DC),
      cellHighlight: Color(0xFFFDEDF3),
      particleEmojis: [
        '\uD83C\uDF38',
        '\uD83C\uDF42',
        '\uD83E\uDD8B',
        '\uD83C\uDF8B',
        '\uD83C\uDF44',
      ],
      description: 'Blossom drift',
    ),
    'Obsidian': EnvironmentalTheme(
      name: 'Obsidian',
      gradient: [Color(0xFF241F2E), Color(0xFF15121C), Color(0xFF000000)],
      primary: Color(0xFF8E7CC3),
      accent: Color(0xFFD8CFF0),
      cellHighlight: Color(0xFFF1EDFA),
      particleEmojis: [
        '\uD83D\uDD2E',
        '\u2B50',
        '\uD83C\uDF11',
        '\u26A1',
        '\uD83D\uDC8E',
      ],
      description: 'Volcanic glass',
    ),
  };

  static EnvironmentalTheme get current => themes[currentTheme]!;

  /// Localized display name for a theme key (`'Ocean'`, `'Forest'`, ...). The
  /// key itself is the stable ID used for persistence/equality and must never
  /// be translated — only this lookup's return value is.
  static String themeDisplayName(BuildContext context, String key) {
    final l10n = AppLocalizations.of(context)!;
    return switch (key) {
      'Ocean' => l10n.themeOceanName,
      'Forest' => l10n.themeForestName,
      'Space' => l10n.themeSpaceName,
      'Fire' => l10n.themeFireName,
      'Ice' => l10n.themeIceName,
      'Aurora' => l10n.themeAuroraName,
      'Sakura' => l10n.themeSakuraName,
      'Obsidian' => l10n.themeObsidianName,
      _ => key,
    };
  }

  /// Localized description for a theme key. See [themeDisplayName].
  static String themeDescriptionText(BuildContext context, String key) {
    final l10n = AppLocalizations.of(context)!;
    return switch (key) {
      'Ocean' => l10n.themeOceanDesc,
      'Forest' => l10n.themeForestDesc,
      'Space' => l10n.themeSpaceDesc,
      'Fire' => l10n.themeFireDesc,
      'Ice' => l10n.themeIceDesc,
      'Aurora' => l10n.themeAuroraDesc,
      'Sakura' => l10n.themeSakuraDesc,
      'Obsidian' => l10n.themeObsidianDesc,
      _ => '',
    };
  }

  // --- Persistence ---------------------------------------------------------

  static final StatsService _store = StatsService();

  static Map<String, dynamic> toJson() => {
    'totalPuzzlesSolved': totalPuzzlesSolved,
    'totalHintsUsed': totalHintsUsed,
    'bestTimeMs': bestTime.inMilliseconds,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'gamesLost': gamesLost,
    'lastDailyDate': lastDailyDate,
    'dailyCompletedCount': dailyCompletedCount,
    'solvedByDifficulty': solvedByDifficulty,
    'solvedByVariant': solvedByVariant,
    'solvedBySize': solvedBySize,
    'jigsawSolved': jigsawSolved,
    'flawlessSolves': flawlessSolves,
    'perfectSolves': perfectSolves,
    'expertPerfectSolves': expertPerfectSolves,
    'unlockedAchievements': unlockedAchievements.toList(),
    'unlockedThemes': unlockedThemes.toList(),
    'currentTheme': currentTheme,
    'localeCode': localeCode,
    'unlimitedMistakes': unlimitedMistakes,
  };

  /// Overlays persisted values onto the static fields. Tolerant of missing or
  /// malformed keys, and always keeps 'Ocean' unlocked (all themes in debug).
  static void applyJson(Map<String, dynamic> json) {
    totalPuzzlesSolved =
        (json['totalPuzzlesSolved'] as num?)?.toInt() ?? totalPuzzlesSolved;
    totalHintsUsed =
        (json['totalHintsUsed'] as num?)?.toInt() ?? totalHintsUsed;
    final bestMs = (json['bestTimeMs'] as num?)?.toInt();
    if (bestMs != null) bestTime = Duration(milliseconds: bestMs);
    currentStreak = (json['currentStreak'] as num?)?.toInt() ?? currentStreak;
    longestStreak = (json['longestStreak'] as num?)?.toInt() ?? longestStreak;
    gamesLost = (json['gamesLost'] as num?)?.toInt() ?? gamesLost;
    // Keep the invariant even for stats saved before these fields existed.
    if (currentStreak > longestStreak) longestStreak = currentStreak;

    lastDailyDate = json['lastDailyDate'] as String? ?? lastDailyDate;
    dailyCompletedCount =
        (json['dailyCompletedCount'] as num?)?.toInt() ?? dailyCompletedCount;

    Map<String, int> counters(String key) {
      final raw = json[key];
      if (raw is! Map) return {};
      return {
        for (final e in raw.entries)
          if (e.key is String && e.value is num)
            e.key as String: (e.value as num).toInt(),
      };
    }

    final byDifficulty = counters('solvedByDifficulty');
    if (byDifficulty.isNotEmpty) solvedByDifficulty = byDifficulty;
    final byVariant = counters('solvedByVariant');
    if (byVariant.isNotEmpty) solvedByVariant = byVariant;
    final bySize = counters('solvedBySize');
    if (bySize.isNotEmpty) solvedBySize = bySize;
    jigsawSolved = (json['jigsawSolved'] as num?)?.toInt() ?? jigsawSolved;
    flawlessSolves =
        (json['flawlessSolves'] as num?)?.toInt() ?? flawlessSolves;
    perfectSolves = (json['perfectSolves'] as num?)?.toInt() ?? perfectSolves;
    expertPerfectSolves =
        (json['expertPerfectSolves'] as num?)?.toInt() ?? expertPerfectSolves;

    final achievements = (json['unlockedAchievements'] as List?)
        ?.cast<String>();
    if (achievements != null) unlockedAchievements = achievements.toSet();

    final themesList = (json['unlockedThemes'] as List?)?.cast<String>();
    if (themesList != null) {
      unlockedThemes = themesList.where(themes.containsKey).toSet();
    }
    unlockedThemes.add('Ocean');
    if (debugMode) unlockedThemes.addAll(themes.keys);

    final theme = json['currentTheme'] as String?;
    if (theme != null && unlockedThemes.contains(theme)) currentTheme = theme;

    localeNotifier.value = json['localeCode'] as String?;
    unlimitedMistakes = json['unlimitedMistakes'] as bool? ?? unlimitedMistakes;
  }

  static Future<void> load() async {
    final json = await _store.load();
    if (json != null) applyJson(json);
  }

  static Future<void> save() => _store.save(toJson());
}
