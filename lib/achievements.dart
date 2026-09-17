import 'package:flutter/material.dart';

import 'game_stats.dart';
import 'l10n/app_localizations.dart';
import 'sudoku_game.dart';

class Achievement {
  final String id;
  final String icon;

  /// 1 = getting started, 4 = legendary. Groups the list and sets the accent
  /// colour, so the upper tiers read as a ladder rather than a flat set.
  final int tier;

  final bool Function() isUnlocked;

  /// Current value and target for a countable goal, e.g. 42 of 50 puzzles.
  /// Null for one-shot achievements ("solve a Killer board") where a bar would
  /// say nothing a checkmark does not.
  final int Function()? progress;
  final int? goal;

  final String? rewardTheme;

  const Achievement({
    required this.id,
    required this.icon,
    required this.tier,
    required this.isUnlocked,
    this.progress,
    this.goal,
    this.rewardTheme,
  });

  /// Fraction complete in 0..1, or null when a bar would say nothing.
  ///
  /// A goal of 1 is a one-shot ("solve a Killer board"): an empty 0/1 bar next
  /// to the padlock is noise, so those report null and render as lock-only.
  double? get fraction {
    final p = progress;
    final g = goal;
    if (p == null || g == null || g <= 1) return null;
    return (p() / g).clamp(0.0, 1.0);
  }
}

class AchievementSystem {
  /// Ordered by tier, then by the order declared here — which is also the
  /// order the sheet renders them in.
  static List<Achievement> achievements = [
    Achievement(
      id: 'first_solve',
      icon: '🎯',
      tier: 1,
      isUnlocked: () => GameStats.totalPuzzlesSolved >= 1,
      progress: () => GameStats.totalPuzzlesSolved,
      goal: 1,
    ),
    Achievement(
      id: 'speed_demon',
      icon: '⚡',
      tier: 1,
      isUnlocked: () => GameStats.bestTime.inMinutes < 3,
      rewardTheme: 'Space',
    ),
    Achievement(
      id: 'puzzle_master',
      icon: '🧩',
      tier: 1,
      isUnlocked: () => GameStats.totalPuzzlesSolved >= 10,
      progress: () => GameStats.totalPuzzlesSolved,
      goal: 10,
      rewardTheme: 'Forest',
    ),
    Achievement(
      id: 'no_hints_hero',
      icon: '🧠',
      tier: 2,
      isUnlocked: () =>
          GameStats.unlockedAchievements.contains('no_hints_hard'),
      rewardTheme: 'Fire',
    ),
    Achievement(
      id: 'streak_master',
      icon: '🔥',
      tier: 1,
      isUnlocked: () => GameStats.currentStreak >= 5,
      progress: () => GameStats.currentStreak,
      goal: 5,
      rewardTheme: 'Ice',
    ),
    Achievement(
      id: 'marathon',
      icon: '🏅',
      tier: 2,
      isUnlocked: () => GameStats.longestStreak >= 10,
      progress: () => GameStats.longestStreak,
      goal: 10,
    ),
    Achievement(
      id: 'solve_50',
      icon: '📚',
      tier: 2,
      isUnlocked: () => GameStats.totalPuzzlesSolved >= 50,
      progress: () => GameStats.totalPuzzlesSolved,
      goal: 50,
    ),
    Achievement(
      id: 'solve_100',
      icon: '🏆',
      tier: 3,
      isUnlocked: () => GameStats.totalPuzzlesSolved >= 100,
      progress: () => GameStats.totalPuzzlesSolved,
      goal: 100,
    ),
    Achievement(
      id: 'solve_250',
      icon: '👑',
      tier: 4,
      isUnlocked: () => GameStats.totalPuzzlesSolved >= 250,
      progress: () => GameStats.totalPuzzlesSolved,
      goal: 250,
      rewardTheme: 'Obsidian',
    ),
    Achievement(
      id: 'expert_first',
      icon: '🌑',
      tier: 2,
      isUnlocked: () => GameStats.solvedAt(SudokuDifficulty.expert) >= 1,
      progress: () => GameStats.solvedAt(SudokuDifficulty.expert),
      goal: 1,
    ),
    Achievement(
      id: 'expert_10',
      icon: '🎓',
      tier: 3,
      isUnlocked: () => GameStats.solvedAt(SudokuDifficulty.expert) >= 10,
      progress: () => GameStats.solvedAt(SudokuDifficulty.expert),
      goal: 10,
      rewardTheme: 'Aurora',
    ),
    Achievement(
      id: 'hard_25',
      icon: '⛏️',
      tier: 3,
      isUnlocked: () =>
          GameStats.solvedAt(SudokuDifficulty.hard) +
              GameStats.solvedAt(SudokuDifficulty.expert) >=
          25,
      progress: () =>
          GameStats.solvedAt(SudokuDifficulty.hard) +
          GameStats.solvedAt(SudokuDifficulty.expert),
      goal: 25,
    ),
    Achievement(
      id: 'flawless',
      icon: '💎',
      tier: 1,
      isUnlocked: () => GameStats.flawlessSolves >= 1,
      progress: () => GameStats.flawlessSolves,
      goal: 1,
    ),
    Achievement(
      id: 'flawless_10',
      icon: '🛡️',
      tier: 2,
      isUnlocked: () => GameStats.flawlessSolves >= 10,
      progress: () => GameStats.flawlessSolves,
      goal: 10,
    ),
    Achievement(
      id: 'perfect_expert',
      icon: '🦉',
      tier: 4,
      isUnlocked: () => GameStats.expertPerfectSolves >= 1,
      progress: () => GameStats.expertPerfectSolves,
      goal: 1,
    ),
    Achievement(
      id: 'jigsaw_first',
      icon: '🔷',
      tier: 1,
      isUnlocked: () => GameStats.jigsawSolved >= 1,
      progress: () => GameStats.jigsawSolved,
      goal: 1,
    ),
    Achievement(
      id: 'x_first',
      icon: '✖️',
      tier: 1,
      isUnlocked: () => (GameStats.solvedByVariant['x'] ?? 0) >= 1,
      progress: () => GameStats.solvedByVariant['x'] ?? 0,
      goal: 1,
    ),
    Achievement(
      id: 'killer_first',
      icon: '🗡️',
      tier: 2,
      isUnlocked: () => (GameStats.solvedByVariant['killer'] ?? 0) >= 1,
      progress: () => GameStats.solvedByVariant['killer'] ?? 0,
      goal: 1,
    ),
    Achievement(
      id: 'variant_all',
      icon: '🎭',
      tier: 4,
      isUnlocked: () => GameStats.hasBeatenEveryVariant,
      rewardTheme: 'Sakura',
    ),
    Achievement(
      id: 'big_board',
      icon: '🔢',
      tier: 2,
      isUnlocked: () => (GameStats.solvedBySize[GridSize.mega.name] ?? 0) >= 1,
      progress: () => GameStats.solvedBySize[GridSize.mega.name] ?? 0,
      goal: 1,
    ),
    Achievement(
      id: 'size_all',
      icon: '📐',
      tier: 3,
      isUnlocked: () => GameStats.hasBeatenEverySize,
    ),
    Achievement(
      id: 'speed_90',
      icon: '🏃',
      tier: 2,
      isUnlocked: () => GameStats.bestTime.inSeconds < 90,
    ),
    Achievement(
      id: 'speed_60',
      icon: '⏱️',
      tier: 3,
      isUnlocked: () => GameStats.bestTime.inSeconds < 60,
    ),
    Achievement(
      id: 'daily_7',
      icon: '📅',
      tier: 1,
      isUnlocked: () => GameStats.dailyCompletedCount >= 7,
      progress: () => GameStats.dailyCompletedCount,
      goal: 7,
    ),
    Achievement(
      id: 'daily_30',
      icon: '🗓️',
      tier: 3,
      isUnlocked: () => GameStats.dailyCompletedCount >= 30,
      progress: () => GameStats.dailyCompletedCount,
      goal: 30,
    ),
    Achievement(
      id: 'streak_25',
      icon: '🔗',
      tier: 3,
      isUnlocked: () => GameStats.longestStreak >= 25,
      progress: () => GameStats.longestStreak,
      goal: 25,
    ),
  ];

  static void checkAchievements() {
    for (final achievement in achievements) {
      if (!GameStats.unlockedAchievements.contains(achievement.id) &&
          achievement.isUnlocked()) {
        GameStats.unlockedAchievements.add(achievement.id);
        if (achievement.rewardTheme != null) {
          GameStats.unlockedThemes.add(achievement.rewardTheme!);
        }
      }
    }
  }

  static int get unlockedCount => achievements
      .where((a) => GameStats.unlockedAchievements.contains(a.id))
      .length;

  /// Achievements grouped by [Achievement.tier], lowest tier first.
  static Map<int, List<Achievement>> byTier() {
    final map = <int, List<Achievement>>{};
    for (final a in achievements) {
      map.putIfAbsent(a.tier, () => []).add(a);
    }
    return Map.fromEntries(
      map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  /// Localized tier heading.
  static String tierName(BuildContext context, int tier) {
    final l10n = AppLocalizations.of(context)!;
    return switch (tier) {
      1 => l10n.achTier1,
      2 => l10n.achTier2,
      3 => l10n.achTier3,
      4 => l10n.achTier4,
      _ => '',
    };
  }

  /// Accent colour per tier: bronze, silver, gold, then a violet for legendary.
  static Color tierColor(int tier) => switch (tier) {
    1 => const Color(0xFFB07A42),
    2 => const Color(0xFF8D98A7),
    3 => const Color(0xFFD4A017),
    _ => const Color(0xFF7C4DFF),
  };

  /// Localized display name for an achievement, looked up by its stable
  /// [Achievement.id] (never translated — it's the persisted unlock key).
  static String displayName(BuildContext context, String id) {
    final l10n = AppLocalizations.of(context)!;
    return switch (id) {
      'first_solve' => l10n.achFirstStepsName,
      'speed_demon' => l10n.achSpeedDemonName,
      'puzzle_master' => l10n.achPuzzleMasterName,
      'no_hints_hero' => l10n.achPureLogicName,
      'streak_master' => l10n.achStreakMasterName,
      'marathon' => l10n.achMarathonName,
      'solve_50' => l10n.achHalfCenturyName,
      'solve_100' => l10n.achCenturionName,
      'solve_250' => l10n.achGrandmasterName,
      'expert_first' => l10n.achIntoTheDeepName,
      'expert_10' => l10n.achExpertHandlerName,
      'hard_25' => l10n.achHardenedName,
      'flawless' => l10n.achFlawlessName,
      'flawless_10' => l10n.achUntouchableName,
      'perfect_expert' => l10n.achPureReasonName,
      'jigsaw_first' => l10n.achShapeshifterName,
      'x_first' => l10n.achCrossingLinesName,
      'killer_first' => l10n.achKillerInstinctName,
      'variant_all' => l10n.achPolymathName,
      'big_board' => l10n.achTwelveSquaredName,
      'size_all' => l10n.achEverySizeName,
      'speed_90' => l10n.achQuicksilverName,
      'speed_60' => l10n.achSubMinuteName,
      'daily_7' => l10n.achSevenDaysName,
      'daily_30' => l10n.achMonthOfPuzzlesName,
      'streak_25' => l10n.achUnbrokenName,
      _ => id,
    };
  }

  /// Localized description for an achievement. See [displayName].
  static String description(BuildContext context, String id) {
    final l10n = AppLocalizations.of(context)!;
    return switch (id) {
      'first_solve' => l10n.achFirstStepsDesc,
      'speed_demon' => l10n.achSpeedDemonDesc,
      'puzzle_master' => l10n.achPuzzleMasterDesc,
      'no_hints_hero' => l10n.achPureLogicDesc,
      'streak_master' => l10n.achStreakMasterDesc,
      'marathon' => l10n.achMarathonDesc,
      'solve_50' => l10n.achHalfCenturyDesc,
      'solve_100' => l10n.achCenturionDesc,
      'solve_250' => l10n.achGrandmasterDesc,
      'expert_first' => l10n.achIntoTheDeepDesc,
      'expert_10' => l10n.achExpertHandlerDesc,
      'hard_25' => l10n.achHardenedDesc,
      'flawless' => l10n.achFlawlessDesc,
      'flawless_10' => l10n.achUntouchableDesc,
      'perfect_expert' => l10n.achPureReasonDesc,
      'jigsaw_first' => l10n.achShapeshifterDesc,
      'x_first' => l10n.achCrossingLinesDesc,
      'killer_first' => l10n.achKillerInstinctDesc,
      'variant_all' => l10n.achPolymathDesc,
      'big_board' => l10n.achTwelveSquaredDesc,
      'size_all' => l10n.achEverySizeDesc,
      'speed_90' => l10n.achQuicksilverDesc,
      'speed_60' => l10n.achSubMinuteDesc,
      'daily_7' => l10n.achSevenDaysDesc,
      'daily_30' => l10n.achMonthOfPuzzlesDesc,
      'streak_25' => l10n.achUnbrokenDesc,
      _ => '',
    };
  }
}
