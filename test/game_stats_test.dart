import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/main.dart';

void main() {
  // GameStats is global mutable state; snapshot and restore around each test.
  late int solved, hints, streak;
  late Duration best;
  late Set<String> achievements, themes;
  late String theme;

  setUp(() {
    solved = GameStats.totalPuzzlesSolved;
    hints = GameStats.totalHintsUsed;
    streak = GameStats.currentStreak;
    best = GameStats.bestTime;
    achievements = {...GameStats.unlockedAchievements};
    themes = {...GameStats.unlockedThemes};
    theme = GameStats.currentTheme;
  });

  tearDown(() {
    GameStats.totalPuzzlesSolved = solved;
    GameStats.totalHintsUsed = hints;
    GameStats.currentStreak = streak;
    GameStats.bestTime = best;
    GameStats.unlockedAchievements = achievements;
    GameStats.unlockedThemes = themes;
    GameStats.currentTheme = theme;
  });

  test('toJson/applyJson round-trips numeric and set fields', () {
    GameStats.totalPuzzlesSolved = 12;
    GameStats.totalHintsUsed = 7;
    GameStats.currentStreak = 4;
    GameStats.bestTime = const Duration(minutes: 2, seconds: 30);
    GameStats.unlockedAchievements = {'first_solve', 'streak_master'};

    final json = GameStats.toJson();

    // Clear, then re-apply.
    GameStats.totalPuzzlesSolved = 0;
    GameStats.totalHintsUsed = 0;
    GameStats.currentStreak = 0;
    GameStats.bestTime = const Duration(hours: 99);
    GameStats.unlockedAchievements = {};

    GameStats.applyJson(json);

    expect(GameStats.totalPuzzlesSolved, 12);
    expect(GameStats.totalHintsUsed, 7);
    expect(GameStats.currentStreak, 4);
    expect(GameStats.bestTime, const Duration(minutes: 2, seconds: 30));
    expect(
      GameStats.unlockedAchievements,
      containsAll(<String>['first_solve', 'streak_master']),
    );
  });

  test('applyJson tolerates an empty map (keeps current values)', () {
    GameStats.totalPuzzlesSolved = 5;
    GameStats.applyJson(<String, dynamic>{});
    expect(GameStats.totalPuzzlesSolved, 5);
  });

  test('Ocean is always unlocked and unknown theme names are ignored', () {
    GameStats.applyJson({
      'unlockedThemes': ['Ocean', 'NotARealTheme'],
    });
    expect(GameStats.unlockedThemes, contains('Ocean'));
    expect(GameStats.unlockedThemes, isNot(contains('NotARealTheme')));
  });

  test('currentTheme is only applied when that theme is unlocked', () {
    GameStats.currentTheme = 'Ocean';
    // Ocean is always unlocked, so this applies.
    GameStats.applyJson({'currentTheme': 'Ocean'});
    expect(GameStats.currentTheme, 'Ocean');

    // A theme not present in the catalogue is ignored.
    GameStats.applyJson({'currentTheme': 'Nonexistent'});
    expect(GameStats.currentTheme, 'Ocean');
  });
}
