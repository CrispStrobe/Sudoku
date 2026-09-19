import 'package:flutter_test/flutter_test.dart';

import 'package:sudoku/main.dart';
import 'package:sudoku/sudoku_game.dart';

/// Achievement tiers and the per-category counters they read.
void main() {
  setUp(() {
    // Statics persist across tests in one file; reset what these touch.
    GameStats.totalPuzzlesSolved = 0;
    GameStats.currentStreak = 0;
    GameStats.longestStreak = 0;
    GameStats.dailyCompletedCount = 0;
    GameStats.bestTime = const Duration(hours: 99);
    GameStats.solvedByDifficulty = {};
    GameStats.solvedByVariant = {};
    GameStats.solvedBySize = {};
    GameStats.jigsawSolved = 0;
    GameStats.flawlessSolves = 0;
    GameStats.perfectSolves = 0;
    GameStats.expertPerfectSolves = 0;
    GameStats.unlockedAchievements = {};
    GameStats.unlockedThemes = {'Ocean'};
  });

  void solve({
    SudokuDifficulty difficulty = SudokuDifficulty.easy,
    SudokuVariant variant = SudokuVariant.classic,
    GridSize size = GridSize.standard,
    GridShape shape = GridShape.classic,
    int mistakes = 0,
    int hintsUsed = 0,
  }) {
    GameStats.totalPuzzlesSolved++;
    GameStats.recordSolve(
      difficulty: difficulty,
      variant: variant,
      size: size,
      shape: shape,
      mistakes: mistakes,
      hintsUsed: hintsUsed,
    );
  }

  test('every achievement id is unique and has a tier', () {
    final ids = AchievementSystem.achievements.map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'duplicate achievement id');
    for (final a in AchievementSystem.achievements) {
      expect(
        a.tier,
        inInclusiveRange(1, 4),
        reason: '${a.id} has tier ${a.tier}',
      );
    }
  });

  test('reward themes all name a real theme', () {
    for (final a in AchievementSystem.achievements) {
      if (a.rewardTheme != null) {
        expect(
          GameStats.themes.containsKey(a.rewardTheme),
          isTrue,
          reason: '${a.id} rewards unknown theme ${a.rewardTheme}',
        );
      }
    }
  });

  test('nothing is unlocked on a fresh profile', () {
    AchievementSystem.checkAchievements();
    expect(GameStats.unlockedAchievements, isEmpty);
    expect(AchievementSystem.unlockedCount, 0);
  });

  test('recordSolve feeds the per-category counters', () {
    solve(difficulty: SudokuDifficulty.expert, variant: SudokuVariant.killer);
    solve(shape: GridShape.jigsaw, size: GridSize.small);
    solve(mistakes: 3); // neither flawless nor perfect

    expect(GameStats.solvedAt(SudokuDifficulty.expert), 1);
    expect(GameStats.solvedByVariant['killer'], 1);
    expect(GameStats.jigsawSolved, 1);
    expect(GameStats.solvedBySize[GridSize.small.name], 1);
    expect(GameStats.flawlessSolves, 2);
    expect(GameStats.perfectSolves, 2);
    expect(GameStats.expertPerfectSolves, 1);
  });

  test('a perfect expert win unlocks the legendary tier', () {
    solve(difficulty: SudokuDifficulty.expert);
    AchievementSystem.checkAchievements();
    expect(GameStats.unlockedAchievements, contains('perfect_expert'));
    expect(GameStats.unlockedAchievements, contains('expert_first'));
    expect(GameStats.unlockedAchievements, contains('flawless'));
  });

  test('beating every variant unlocks Polymath and its theme', () {
    expect(GameStats.hasBeatenEveryVariant, isFalse);
    solve();
    solve(variant: SudokuVariant.x);
    solve(variant: SudokuVariant.killer);
    expect(GameStats.hasBeatenEveryVariant, isFalse, reason: 'thermo missing');
    solve(variant: SudokuVariant.thermo);
    expect(GameStats.hasBeatenEveryVariant, isFalse, reason: 'jigsaw missing');
    solve(shape: GridShape.jigsaw);
    expect(GameStats.hasBeatenEveryVariant, isTrue);

    AchievementSystem.checkAchievements();
    expect(GameStats.unlockedAchievements, contains('variant_all'));
    expect(GameStats.unlockedThemes, contains('Sakura'));
  });

  test('beating every size unlocks Every Shape and Size', () {
    for (final size in GridSize.values) {
      solve(size: size);
    }
    expect(GameStats.hasBeatenEverySize, isTrue);
    AchievementSystem.checkAchievements();
    expect(GameStats.unlockedAchievements, contains('size_all'));
  });

  test('volume tiers unlock in order', () {
    GameStats.totalPuzzlesSolved = 50;
    AchievementSystem.checkAchievements();
    expect(GameStats.unlockedAchievements, contains('solve_50'));
    expect(GameStats.unlockedAchievements, isNot(contains('solve_100')));

    GameStats.totalPuzzlesSolved = 250;
    AchievementSystem.checkAchievements();
    expect(GameStats.unlockedAchievements, contains('solve_100'));
    expect(GameStats.unlockedAchievements, contains('solve_250'));
    expect(GameStats.unlockedThemes, contains('Obsidian'));
  });

  test('progress fractions stay within 0..1 and match the goal', () {
    GameStats.totalPuzzlesSolved = 25;
    final centurion = AchievementSystem.achievements.firstWhere(
      (a) => a.id == 'solve_100',
    );
    expect(centurion.goal, 100);
    expect(centurion.fraction, closeTo(0.25, 1e-9));

    GameStats.totalPuzzlesSolved = 400; // past the goal
    expect(centurion.fraction, 1.0);

    for (final a in AchievementSystem.achievements) {
      final f = a.fraction;
      if (f != null) expect(f, inInclusiveRange(0.0, 1.0), reason: a.id);
    }
  });

  test('counters survive a save/load round trip', () {
    solve(difficulty: SudokuDifficulty.expert, variant: SudokuVariant.killer);
    solve(shape: GridShape.jigsaw);
    final json = GameStats.toJson();

    GameStats.solvedByDifficulty = {};
    GameStats.solvedByVariant = {};
    GameStats.jigsawSolved = 0;
    GameStats.expertPerfectSolves = 0;

    GameStats.applyJson(json);
    expect(GameStats.solvedAt(SudokuDifficulty.expert), 1);
    expect(GameStats.solvedByVariant['killer'], 1);
    expect(GameStats.jigsawSolved, 1);
    expect(GameStats.expertPerfectSolves, 1);
  });

  test('applyJson tolerates malformed counter payloads', () {
    GameStats.applyJson({
      'solvedByDifficulty': 'not a map',
      'solvedByVariant': {'killer': 'seven', 'x': 2},
      'jigsawSolved': null,
    });
    expect(GameStats.solvedByDifficulty, isEmpty);
    expect(GameStats.solvedByVariant['x'], 2);
    expect(GameStats.solvedByVariant.containsKey('killer'), isFalse);
    expect(GameStats.jigsawSolved, 0);
  });
}
