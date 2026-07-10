// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get homeStatsButton => 'Stats';

  @override
  String get homeThemesButton => 'Themes';

  @override
  String get homeAchievementsButton => 'Achievements';

  @override
  String get homeSettingsButton => 'Settings';

  @override
  String homeStatsLine(int solved, int streak, int best) {
    return 'Solved: $solved  |  Streak: $streak  |  Best: $best';
  }

  @override
  String homeLossesLine(int losses) {
    return 'Losses: $losses';
  }

  @override
  String get homeDailyChallengeDone => '📅 DAILY CHALLENGE ✓';

  @override
  String get homeDailyChallenge => '📅 DAILY CHALLENGE';

  @override
  String get homeDailyCompletedSubtitle => 'Completed — back tomorrow!';

  @override
  String get homeDailySubtitle => 'Today\'s 9×9 puzzle, same for everyone';

  @override
  String get homeGameModes => 'GAME MODES';

  @override
  String get homeClassicMode => '🎯 CLASSIC MODE';

  @override
  String get homeClassicModeSubtitle => 'Traditional Sudoku';

  @override
  String get homeJigsawMode => '🧩 JIGSAW MODE';

  @override
  String get homeAdminPanel => 'Admin Panel';

  @override
  String get homeAboutLicenses => 'About & Licenses';

  @override
  String get classicSheetTitle => 'Classic Sudoku';

  @override
  String get sizeSmallDifficulty => 'SMALL';

  @override
  String get sizeMediumDifficulty => 'MEDIUM';

  @override
  String get sizeLargeDifficulty => 'LARGE';

  @override
  String get sizeStandardDifficulty => 'CLASSIC';

  @override
  String get sizeBigDifficulty => 'BIG';

  @override
  String get sizeMegaDifficulty => 'MEGA';

  @override
  String get selectDifficultyTitle => 'Select Difficulty';

  @override
  String get jigsawIrregularNote =>
      'Jigsaw mode: Regions have irregular shapes!';

  @override
  String get variantLabel => 'Variant';

  @override
  String get variantClassic => 'Classic';

  @override
  String get variantSudokuX => '⊗ Sudoku-X';

  @override
  String get variantKiller => '🧮 Killer';

  @override
  String get variantXNote => 'Both main diagonals must also contain 1–N.';

  @override
  String get variantKillerNote =>
      'No givens — each dashed cage must sum to its number with no repeats.';

  @override
  String get difficultyEasy => 'EASY';

  @override
  String get difficultyMedium => 'MEDIUM';

  @override
  String get difficultyHard => 'HARD';

  @override
  String get difficultyExpert => 'EXPERT';

  @override
  String get jigsawSheetTitle => '🧩 Jigsaw Sudoku';

  @override
  String get jigsawSheetSubtitle =>
      'Irregular shaped regions instead of squares! Each size has unique region shapes.';

  @override
  String jigsawSizeLabel(String size) {
    return '$size Jigsaw';
  }

  @override
  String get jigsawMini => 'Mini Challenge';

  @override
  String get jigsawQuick => 'Quick Puzzle';

  @override
  String get jigsawBrain => 'Brain Teaser';

  @override
  String get jigsawClassicTwist => 'Classic Twist';

  @override
  String get jigsawBig => 'Big Challenge';

  @override
  String get jigsawUltimate => 'Ultimate Test';

  @override
  String get themesSheetTitle => 'Environmental Themes';

  @override
  String get themeOceanName => 'Ocean';

  @override
  String get themeOceanDesc => 'Deep ocean depths';

  @override
  String get themeForestName => 'Forest';

  @override
  String get themeForestDesc => 'Mysterious forest';

  @override
  String get themeSpaceName => 'Space';

  @override
  String get themeSpaceDesc => 'Cosmic adventure';

  @override
  String get themeFireName => 'Fire';

  @override
  String get themeFireDesc => 'Volcanic eruption';

  @override
  String get themeIceName => 'Ice';

  @override
  String get themeIceDesc => 'Frozen tundra';

  @override
  String get achievementsSheetTitle => 'Achievements';

  @override
  String get achFirstStepsName => 'First Steps';

  @override
  String get achFirstStepsDesc => 'Complete your first puzzle';

  @override
  String get achSpeedDemonName => 'Speed Demon';

  @override
  String get achSpeedDemonDesc => 'Complete a puzzle in under 3 minutes';

  @override
  String get achPuzzleMasterName => 'Puzzle Master';

  @override
  String get achPuzzleMasterDesc => 'Complete 10 puzzles';

  @override
  String get achPureLogicName => 'Pure Logic';

  @override
  String get achPureLogicDesc => 'Complete a hard puzzle without hints';

  @override
  String get achStreakMasterName => 'Streak Master';

  @override
  String get achStreakMasterDesc => 'Solve 5 puzzles in a row';

  @override
  String get achMarathonName => 'Marathon';

  @override
  String get achMarathonDesc => 'Reach a 10-puzzle streak';

  @override
  String achievementRewardTheme(String theme) {
    return 'Reward: $theme theme';
  }

  @override
  String get statsSheetTitle => 'Statistics';

  @override
  String get statPuzzlesSolved => 'Puzzles solved';

  @override
  String get statWinRate => 'Win rate';

  @override
  String get statCurrentStreak => 'Current streak';

  @override
  String get statLongestStreak => 'Longest streak';

  @override
  String get statGamesLost => 'Games lost';

  @override
  String get statBestTime => 'Best time';

  @override
  String get statDailyPuzzlesDone => 'Daily puzzles done';

  @override
  String get statHintsUsed => 'Hints used';

  @override
  String get statAchievements => 'Achievements';

  @override
  String get generatingPuzzle => 'Generating puzzle...';

  @override
  String get mainMenuTooltip => 'Main Menu';

  @override
  String scoreLabel(int score) {
    return 'Score: $score';
  }

  @override
  String get mistakesLabel => 'Mistakes';

  @override
  String mistakesCount(int mistakes, int max) {
    return '$mistakes/$max';
  }

  @override
  String mistakesCountUnlimited(int mistakes) {
    return '$mistakes / ∞';
  }

  @override
  String logicRatingPill(String rating) {
    return '🧠 $rating';
  }

  @override
  String get hintButtonLabel => 'Hint';

  @override
  String hintButtonWithCount(int count) {
    return 'Hint ($count)';
  }

  @override
  String get noHintsLabel => 'No Hints';

  @override
  String get notesModeTooltip => 'Notes mode';

  @override
  String get undoTooltip => 'Undo';

  @override
  String get eraseTooltip => 'Erase';

  @override
  String get explainSolveTooltip => 'Explain solve';

  @override
  String get failedToCreatePuzzle => 'Failed to create puzzle. Please restart.';

  @override
  String get smartHintsTitle => 'Smart Hints';

  @override
  String get nextLogicalStepTitle => 'Next logical step';

  @override
  String get nextLogicalStepSubtitle =>
      'Find and explain the next deduction on the board.';

  @override
  String penaltyLabel(int penalty) {
    return '-$penalty';
  }

  @override
  String get noHintsLeftSnackbar => 'No hints left for this puzzle!';

  @override
  String possibleNumbersSnackbar(String numbers) {
    return 'Possible Numbers: $numbers';
  }

  @override
  String get noStepFoundTitle => 'No logical step found';

  @override
  String get noStepFoundBody =>
      'No straightforward deduction is available from the current board — it may need a more advanced technique or contain a wrong entry. Try clearing any conflicts first.';

  @override
  String get okButton => 'OK';

  @override
  String get cancelButton => 'Cancel';

  @override
  String placeItButton(int penalty) {
    return 'Place it (-$penalty)';
  }

  @override
  String get gotItButton => 'Got it';

  @override
  String get confirmButton => 'Confirm';

  @override
  String useHintConfirm(int penalty) {
    return 'Use this hint for a -$penalty score penalty?';
  }

  @override
  String get techniqueNakedSingle => 'Naked Single';

  @override
  String get techniqueHiddenSingle => 'Hidden Single';

  @override
  String get techniqueLockedCandidates => 'Locked Candidates';

  @override
  String get techniqueNakedPair => 'Naked Pair';

  @override
  String get techniqueNakedTriple => 'Naked Triple';

  @override
  String get techniqueHiddenPair => 'Hidden Pair';

  @override
  String get techniqueXWing => 'X-Wing';

  @override
  String get techniqueNextStep => 'Next Step';

  @override
  String get dailyCompleteTitle => '🎉 Daily Complete!';

  @override
  String get completedTitle => '🎉 Completed!';

  @override
  String scoreResult(int score) {
    return 'Score: $score';
  }

  @override
  String timeResult(String time, int bonus) {
    return 'Time: $time  •  Bonus: +$bonus';
  }

  @override
  String logicRatingResult(String rating) {
    return 'Logic rating: $rating';
  }

  @override
  String get dailyComeBackNote => 'Come back tomorrow for a new daily!';

  @override
  String get mainMenuButton => 'Main Menu';

  @override
  String get nextPuzzleButton => 'Next Puzzle';

  @override
  String get gameOverTitle => '💥 Game Over';

  @override
  String reachedMistakesMessage(int max) {
    return 'You reached $max mistakes.';
  }

  @override
  String get streakResetMessage => 'Your streak has been reset.';

  @override
  String get tryAgainButton => 'Try Again';

  @override
  String get explainAppBarTitle => 'Explain the solve';

  @override
  String get explainStart => 'Start';

  @override
  String explainStepOf(int index, int count) {
    return 'Step $index / $count';
  }

  @override
  String get explainNoStepsNeeded => 'No logical steps were needed.';

  @override
  String explainStartingPosition(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Starting position — $count steps to go.',
      one: 'Starting position — 1 step to go.',
    );
    return '$_temp0';
  }

  @override
  String explainSolvedNote(String technique) {
    return '✅ Solved with logic — hardest technique: $technique.';
  }

  @override
  String get explainStuckNote =>
      '⛔ Stuck — needs a technique beyond this solver.';

  @override
  String get explainPreviousTooltip => 'Previous';

  @override
  String get explainPlayTooltip => 'Play';

  @override
  String get explainPauseTooltip => 'Pause';

  @override
  String get explainNextTooltip => 'Next';

  @override
  String get settingsSheetTitle => 'Settings';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageGerman => 'Deutsch';

  @override
  String get settingsUnlimitedMistakes => 'Unlimited mistakes';

  @override
  String get settingsUnlimitedMistakesSubtitle =>
      'Play without a mistake limit (Infinite Errors mode)';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutServiceProvider => 'Service provider';

  @override
  String get aboutContact => 'Contact';

  @override
  String get aboutPrivacy => 'Privacy';

  @override
  String get aboutDisclaimer => 'Disclaimer';

  @override
  String get aboutLicense => 'License';

  @override
  String get aboutTagline =>
      'Classic, jigsaw, Sudoku-X & Killer puzzles with a daily challenge.';

  @override
  String get aboutPrivacyText =>
      'CrispSudoku runs entirely on-device. Your games, statistics and settings never leave your device — there is no account, no analytics and no contact with remote services.';

  @override
  String get aboutDisclaimerText =>
      'CrispSudoku is provided \"as is\", without warranty of any kind. Every generated puzzle is verified to have a unique solution, but use the app at your own discretion.';

  @override
  String get aboutLicenseText =>
      'CrispSudoku is free software, distributed under the GNU Affero General Public License version 3 or later. As the sole copyright holder, the author additionally makes official binary distributions (e.g. via the Apple App Store and Google Play) available under those stores’ standard terms; this does not affect your rights to the source under AGPL-3.0.';

  @override
  String aboutVersionLabel(String v) {
    return 'Version $v';
  }

  @override
  String get aboutOpenSourceLicenses => 'Open-source licenses';
}
