import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @homeStatsButton.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get homeStatsButton;

  /// No description provided for @homeThemesButton.
  ///
  /// In en, this message translates to:
  /// **'Themes'**
  String get homeThemesButton;

  /// No description provided for @homeAchievementsButton.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get homeAchievementsButton;

  /// No description provided for @homeSettingsButton.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettingsButton;

  /// No description provided for @homeStatsLine.
  ///
  /// In en, this message translates to:
  /// **'Solved: {solved}  |  Streak: {streak}  |  Best: {best}'**
  String homeStatsLine(int solved, int streak, int best);

  /// No description provided for @homeLossesLine.
  ///
  /// In en, this message translates to:
  /// **'Losses: {losses}'**
  String homeLossesLine(int losses);

  /// No description provided for @homeDailyChallengeDone.
  ///
  /// In en, this message translates to:
  /// **'📅 DAILY CHALLENGE ✓'**
  String get homeDailyChallengeDone;

  /// No description provided for @homeDailyChallenge.
  ///
  /// In en, this message translates to:
  /// **'📅 DAILY CHALLENGE'**
  String get homeDailyChallenge;

  /// No description provided for @homeDailyCompletedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Completed — back tomorrow!'**
  String get homeDailyCompletedSubtitle;

  /// No description provided for @homeDailySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s 9×9 puzzle, same for everyone'**
  String get homeDailySubtitle;

  /// No description provided for @homeGameModes.
  ///
  /// In en, this message translates to:
  /// **'GAME MODES'**
  String get homeGameModes;

  /// No description provided for @homeClassicMode.
  ///
  /// In en, this message translates to:
  /// **'🎯 CLASSIC MODE'**
  String get homeClassicMode;

  /// No description provided for @homeClassicModeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Traditional Sudoku'**
  String get homeClassicModeSubtitle;

  /// No description provided for @homeJigsawMode.
  ///
  /// In en, this message translates to:
  /// **'🧩 JIGSAW MODE'**
  String get homeJigsawMode;

  /// No description provided for @homeAdminPanel.
  ///
  /// In en, this message translates to:
  /// **'Admin Panel'**
  String get homeAdminPanel;

  /// No description provided for @homeAboutLicenses.
  ///
  /// In en, this message translates to:
  /// **'About & Licenses'**
  String get homeAboutLicenses;

  /// No description provided for @classicSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Classic Sudoku'**
  String get classicSheetTitle;

  /// No description provided for @sizeSmallDifficulty.
  ///
  /// In en, this message translates to:
  /// **'SMALL'**
  String get sizeSmallDifficulty;

  /// No description provided for @sizeMediumDifficulty.
  ///
  /// In en, this message translates to:
  /// **'MEDIUM'**
  String get sizeMediumDifficulty;

  /// No description provided for @sizeLargeDifficulty.
  ///
  /// In en, this message translates to:
  /// **'LARGE'**
  String get sizeLargeDifficulty;

  /// No description provided for @sizeStandardDifficulty.
  ///
  /// In en, this message translates to:
  /// **'CLASSIC'**
  String get sizeStandardDifficulty;

  /// No description provided for @sizeBigDifficulty.
  ///
  /// In en, this message translates to:
  /// **'BIG'**
  String get sizeBigDifficulty;

  /// No description provided for @sizeMegaDifficulty.
  ///
  /// In en, this message translates to:
  /// **'MEGA'**
  String get sizeMegaDifficulty;

  /// No description provided for @selectDifficultyTitle.
  ///
  /// In en, this message translates to:
  /// **'Select Difficulty'**
  String get selectDifficultyTitle;

  /// No description provided for @jigsawIrregularNote.
  ///
  /// In en, this message translates to:
  /// **'Jigsaw mode: Regions have irregular shapes!'**
  String get jigsawIrregularNote;

  /// No description provided for @variantLabel.
  ///
  /// In en, this message translates to:
  /// **'Variant'**
  String get variantLabel;

  /// No description provided for @variantClassic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get variantClassic;

  /// No description provided for @variantSudokuX.
  ///
  /// In en, this message translates to:
  /// **'⊗ Sudoku-X'**
  String get variantSudokuX;

  /// No description provided for @variantKiller.
  ///
  /// In en, this message translates to:
  /// **'🧮 Killer'**
  String get variantKiller;

  /// No description provided for @variantXNote.
  ///
  /// In en, this message translates to:
  /// **'Both main diagonals must also contain 1–N.'**
  String get variantXNote;

  /// No description provided for @variantKillerNote.
  ///
  /// In en, this message translates to:
  /// **'No givens — each dashed cage must sum to its number with no repeats.'**
  String get variantKillerNote;

  /// No description provided for @difficultyEasy.
  ///
  /// In en, this message translates to:
  /// **'EASY'**
  String get difficultyEasy;

  /// No description provided for @difficultyMedium.
  ///
  /// In en, this message translates to:
  /// **'MEDIUM'**
  String get difficultyMedium;

  /// No description provided for @difficultyHard.
  ///
  /// In en, this message translates to:
  /// **'HARD'**
  String get difficultyHard;

  /// No description provided for @difficultyExpert.
  ///
  /// In en, this message translates to:
  /// **'EXPERT'**
  String get difficultyExpert;

  /// No description provided for @jigsawSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'🧩 Jigsaw Sudoku'**
  String get jigsawSheetTitle;

  /// No description provided for @jigsawSheetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Irregular shaped regions instead of squares! Each size has unique region shapes.'**
  String get jigsawSheetSubtitle;

  /// No description provided for @jigsawSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'{size} Jigsaw'**
  String jigsawSizeLabel(String size);

  /// No description provided for @jigsawMini.
  ///
  /// In en, this message translates to:
  /// **'Mini Challenge'**
  String get jigsawMini;

  /// No description provided for @jigsawQuick.
  ///
  /// In en, this message translates to:
  /// **'Quick Puzzle'**
  String get jigsawQuick;

  /// No description provided for @jigsawBrain.
  ///
  /// In en, this message translates to:
  /// **'Brain Teaser'**
  String get jigsawBrain;

  /// No description provided for @jigsawClassicTwist.
  ///
  /// In en, this message translates to:
  /// **'Classic Twist'**
  String get jigsawClassicTwist;

  /// No description provided for @jigsawBig.
  ///
  /// In en, this message translates to:
  /// **'Big Challenge'**
  String get jigsawBig;

  /// No description provided for @jigsawUltimate.
  ///
  /// In en, this message translates to:
  /// **'Ultimate Test'**
  String get jigsawUltimate;

  /// No description provided for @themesSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Environmental Themes'**
  String get themesSheetTitle;

  /// No description provided for @themeOceanName.
  ///
  /// In en, this message translates to:
  /// **'Ocean'**
  String get themeOceanName;

  /// No description provided for @themeOceanDesc.
  ///
  /// In en, this message translates to:
  /// **'Deep ocean depths'**
  String get themeOceanDesc;

  /// No description provided for @themeForestName.
  ///
  /// In en, this message translates to:
  /// **'Forest'**
  String get themeForestName;

  /// No description provided for @themeForestDesc.
  ///
  /// In en, this message translates to:
  /// **'Mysterious forest'**
  String get themeForestDesc;

  /// No description provided for @themeSpaceName.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get themeSpaceName;

  /// No description provided for @themeSpaceDesc.
  ///
  /// In en, this message translates to:
  /// **'Cosmic adventure'**
  String get themeSpaceDesc;

  /// No description provided for @themeFireName.
  ///
  /// In en, this message translates to:
  /// **'Fire'**
  String get themeFireName;

  /// No description provided for @themeFireDesc.
  ///
  /// In en, this message translates to:
  /// **'Volcanic eruption'**
  String get themeFireDesc;

  /// No description provided for @themeIceName.
  ///
  /// In en, this message translates to:
  /// **'Ice'**
  String get themeIceName;

  /// No description provided for @themeIceDesc.
  ///
  /// In en, this message translates to:
  /// **'Frozen tundra'**
  String get themeIceDesc;

  /// No description provided for @achievementsSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get achievementsSheetTitle;

  /// No description provided for @achFirstStepsName.
  ///
  /// In en, this message translates to:
  /// **'First Steps'**
  String get achFirstStepsName;

  /// No description provided for @achFirstStepsDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete your first puzzle'**
  String get achFirstStepsDesc;

  /// No description provided for @achSpeedDemonName.
  ///
  /// In en, this message translates to:
  /// **'Speed Demon'**
  String get achSpeedDemonName;

  /// No description provided for @achSpeedDemonDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete a puzzle in under 3 minutes'**
  String get achSpeedDemonDesc;

  /// No description provided for @achPuzzleMasterName.
  ///
  /// In en, this message translates to:
  /// **'Puzzle Master'**
  String get achPuzzleMasterName;

  /// No description provided for @achPuzzleMasterDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete 10 puzzles'**
  String get achPuzzleMasterDesc;

  /// No description provided for @achPureLogicName.
  ///
  /// In en, this message translates to:
  /// **'Pure Logic'**
  String get achPureLogicName;

  /// No description provided for @achPureLogicDesc.
  ///
  /// In en, this message translates to:
  /// **'Complete a hard puzzle without hints'**
  String get achPureLogicDesc;

  /// No description provided for @achStreakMasterName.
  ///
  /// In en, this message translates to:
  /// **'Streak Master'**
  String get achStreakMasterName;

  /// No description provided for @achStreakMasterDesc.
  ///
  /// In en, this message translates to:
  /// **'Solve 5 puzzles in a row'**
  String get achStreakMasterDesc;

  /// No description provided for @achMarathonName.
  ///
  /// In en, this message translates to:
  /// **'Marathon'**
  String get achMarathonName;

  /// No description provided for @achMarathonDesc.
  ///
  /// In en, this message translates to:
  /// **'Reach a 10-puzzle streak'**
  String get achMarathonDesc;

  /// No description provided for @achievementRewardTheme.
  ///
  /// In en, this message translates to:
  /// **'Reward: {theme} theme'**
  String achievementRewardTheme(String theme);

  /// No description provided for @statsSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsSheetTitle;

  /// No description provided for @statPuzzlesSolved.
  ///
  /// In en, this message translates to:
  /// **'Puzzles solved'**
  String get statPuzzlesSolved;

  /// No description provided for @statWinRate.
  ///
  /// In en, this message translates to:
  /// **'Win rate'**
  String get statWinRate;

  /// No description provided for @statCurrentStreak.
  ///
  /// In en, this message translates to:
  /// **'Current streak'**
  String get statCurrentStreak;

  /// No description provided for @statLongestStreak.
  ///
  /// In en, this message translates to:
  /// **'Longest streak'**
  String get statLongestStreak;

  /// No description provided for @statGamesLost.
  ///
  /// In en, this message translates to:
  /// **'Games lost'**
  String get statGamesLost;

  /// No description provided for @statBestTime.
  ///
  /// In en, this message translates to:
  /// **'Best time'**
  String get statBestTime;

  /// No description provided for @statDailyPuzzlesDone.
  ///
  /// In en, this message translates to:
  /// **'Daily puzzles done'**
  String get statDailyPuzzlesDone;

  /// No description provided for @statHintsUsed.
  ///
  /// In en, this message translates to:
  /// **'Hints used'**
  String get statHintsUsed;

  /// No description provided for @statAchievements.
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get statAchievements;

  /// No description provided for @generatingPuzzle.
  ///
  /// In en, this message translates to:
  /// **'Generating puzzle...'**
  String get generatingPuzzle;

  /// No description provided for @mainMenuTooltip.
  ///
  /// In en, this message translates to:
  /// **'Main Menu'**
  String get mainMenuTooltip;

  /// No description provided for @scoreLabel.
  ///
  /// In en, this message translates to:
  /// **'Score: {score}'**
  String scoreLabel(int score);

  /// No description provided for @mistakesLabel.
  ///
  /// In en, this message translates to:
  /// **'Mistakes'**
  String get mistakesLabel;

  /// No description provided for @mistakesCount.
  ///
  /// In en, this message translates to:
  /// **'{mistakes}/{max}'**
  String mistakesCount(int mistakes, int max);

  /// No description provided for @mistakesCountUnlimited.
  ///
  /// In en, this message translates to:
  /// **'{mistakes} / ∞'**
  String mistakesCountUnlimited(int mistakes);

  /// No description provided for @logicRatingPill.
  ///
  /// In en, this message translates to:
  /// **'🧠 {rating}'**
  String logicRatingPill(String rating);

  /// No description provided for @hintButtonLabel.
  ///
  /// In en, this message translates to:
  /// **'Hint'**
  String get hintButtonLabel;

  /// No description provided for @hintButtonWithCount.
  ///
  /// In en, this message translates to:
  /// **'Hint ({count})'**
  String hintButtonWithCount(int count);

  /// No description provided for @noHintsLabel.
  ///
  /// In en, this message translates to:
  /// **'No Hints'**
  String get noHintsLabel;

  /// No description provided for @notesModeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Notes mode'**
  String get notesModeTooltip;

  /// No description provided for @undoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undoTooltip;

  /// No description provided for @eraseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Erase'**
  String get eraseTooltip;

  /// No description provided for @explainSolveTooltip.
  ///
  /// In en, this message translates to:
  /// **'Explain solve'**
  String get explainSolveTooltip;

  /// No description provided for @failedToCreatePuzzle.
  ///
  /// In en, this message translates to:
  /// **'Failed to create puzzle. Please restart.'**
  String get failedToCreatePuzzle;

  /// No description provided for @smartHintsTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Hints'**
  String get smartHintsTitle;

  /// No description provided for @nextLogicalStepTitle.
  ///
  /// In en, this message translates to:
  /// **'Next logical step'**
  String get nextLogicalStepTitle;

  /// No description provided for @nextLogicalStepSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Find and explain the next deduction on the board.'**
  String get nextLogicalStepSubtitle;

  /// No description provided for @penaltyLabel.
  ///
  /// In en, this message translates to:
  /// **'-{penalty}'**
  String penaltyLabel(int penalty);

  /// No description provided for @noHintsLeftSnackbar.
  ///
  /// In en, this message translates to:
  /// **'No hints left for this puzzle!'**
  String get noHintsLeftSnackbar;

  /// No description provided for @possibleNumbersSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Possible Numbers: {numbers}'**
  String possibleNumbersSnackbar(String numbers);

  /// No description provided for @noStepFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'No logical step found'**
  String get noStepFoundTitle;

  /// No description provided for @noStepFoundBody.
  ///
  /// In en, this message translates to:
  /// **'No straightforward deduction is available from the current board — it may need a more advanced technique or contain a wrong entry. Try clearing any conflicts first.'**
  String get noStepFoundBody;

  /// No description provided for @okButton.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okButton;

  /// No description provided for @cancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButton;

  /// No description provided for @placeItButton.
  ///
  /// In en, this message translates to:
  /// **'Place it (-{penalty})'**
  String placeItButton(int penalty);

  /// No description provided for @gotItButton.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotItButton;

  /// No description provided for @confirmButton.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmButton;

  /// No description provided for @useHintConfirm.
  ///
  /// In en, this message translates to:
  /// **'Use this hint for a -{penalty} score penalty?'**
  String useHintConfirm(int penalty);

  /// No description provided for @techniqueNakedSingle.
  ///
  /// In en, this message translates to:
  /// **'Naked Single'**
  String get techniqueNakedSingle;

  /// No description provided for @techniqueHiddenSingle.
  ///
  /// In en, this message translates to:
  /// **'Hidden Single'**
  String get techniqueHiddenSingle;

  /// No description provided for @techniqueLockedCandidates.
  ///
  /// In en, this message translates to:
  /// **'Locked Candidates'**
  String get techniqueLockedCandidates;

  /// No description provided for @techniqueNakedPair.
  ///
  /// In en, this message translates to:
  /// **'Naked Pair'**
  String get techniqueNakedPair;

  /// No description provided for @techniqueNakedTriple.
  ///
  /// In en, this message translates to:
  /// **'Naked Triple'**
  String get techniqueNakedTriple;

  /// No description provided for @techniqueHiddenPair.
  ///
  /// In en, this message translates to:
  /// **'Hidden Pair'**
  String get techniqueHiddenPair;

  /// No description provided for @techniqueXWing.
  ///
  /// In en, this message translates to:
  /// **'X-Wing'**
  String get techniqueXWing;

  /// No description provided for @techniqueNextStep.
  ///
  /// In en, this message translates to:
  /// **'Next Step'**
  String get techniqueNextStep;

  /// No description provided for @dailyCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'🎉 Daily Complete!'**
  String get dailyCompleteTitle;

  /// No description provided for @completedTitle.
  ///
  /// In en, this message translates to:
  /// **'🎉 Completed!'**
  String get completedTitle;

  /// No description provided for @scoreResult.
  ///
  /// In en, this message translates to:
  /// **'Score: {score}'**
  String scoreResult(int score);

  /// No description provided for @timeResult.
  ///
  /// In en, this message translates to:
  /// **'Time: {time}  •  Bonus: +{bonus}'**
  String timeResult(String time, int bonus);

  /// No description provided for @logicRatingResult.
  ///
  /// In en, this message translates to:
  /// **'Logic rating: {rating}'**
  String logicRatingResult(String rating);

  /// No description provided for @dailyComeBackNote.
  ///
  /// In en, this message translates to:
  /// **'Come back tomorrow for a new daily!'**
  String get dailyComeBackNote;

  /// No description provided for @mainMenuButton.
  ///
  /// In en, this message translates to:
  /// **'Main Menu'**
  String get mainMenuButton;

  /// No description provided for @nextPuzzleButton.
  ///
  /// In en, this message translates to:
  /// **'Next Puzzle'**
  String get nextPuzzleButton;

  /// No description provided for @gameOverTitle.
  ///
  /// In en, this message translates to:
  /// **'💥 Game Over'**
  String get gameOverTitle;

  /// No description provided for @reachedMistakesMessage.
  ///
  /// In en, this message translates to:
  /// **'You reached {max} mistakes.'**
  String reachedMistakesMessage(int max);

  /// No description provided for @streakResetMessage.
  ///
  /// In en, this message translates to:
  /// **'Your streak has been reset.'**
  String get streakResetMessage;

  /// No description provided for @tryAgainButton.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get tryAgainButton;

  /// No description provided for @explainAppBarTitle.
  ///
  /// In en, this message translates to:
  /// **'Explain the solve'**
  String get explainAppBarTitle;

  /// No description provided for @explainStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get explainStart;

  /// No description provided for @explainStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {index} / {count}'**
  String explainStepOf(int index, int count);

  /// No description provided for @explainNoStepsNeeded.
  ///
  /// In en, this message translates to:
  /// **'No logical steps were needed.'**
  String get explainNoStepsNeeded;

  /// No description provided for @explainStartingPosition.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{Starting position — 1 step to go.} other{Starting position — {count} steps to go.}}'**
  String explainStartingPosition(int count);

  /// No description provided for @explainSolvedNote.
  ///
  /// In en, this message translates to:
  /// **'✅ Solved with logic — hardest technique: {technique}.'**
  String explainSolvedNote(String technique);

  /// No description provided for @explainStuckNote.
  ///
  /// In en, this message translates to:
  /// **'⛔ Stuck — needs a technique beyond this solver.'**
  String get explainStuckNote;

  /// No description provided for @explainPreviousTooltip.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get explainPreviousTooltip;

  /// No description provided for @explainPlayTooltip.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get explainPlayTooltip;

  /// No description provided for @explainPauseTooltip.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get explainPauseTooltip;

  /// No description provided for @explainNextTooltip.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get explainNextTooltip;

  /// No description provided for @settingsSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsSheetTitle;

  /// No description provided for @settingsLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageGerman.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get settingsLanguageGerman;

  /// No description provided for @settingsUnlimitedMistakes.
  ///
  /// In en, this message translates to:
  /// **'Unlimited mistakes'**
  String get settingsUnlimitedMistakes;

  /// No description provided for @settingsUnlimitedMistakesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play without a mistake limit (Infinite Errors mode)'**
  String get settingsUnlimitedMistakesSubtitle;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @aboutServiceProvider.
  ///
  /// In en, this message translates to:
  /// **'Service provider'**
  String get aboutServiceProvider;

  /// No description provided for @aboutContact.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get aboutContact;

  /// No description provided for @aboutPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get aboutPrivacy;

  /// No description provided for @aboutDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Disclaimer'**
  String get aboutDisclaimer;

  /// No description provided for @aboutLicense.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get aboutLicense;

  /// No description provided for @aboutTagline.
  ///
  /// In en, this message translates to:
  /// **'Classic, jigsaw, Sudoku-X & Killer puzzles with a daily challenge.'**
  String get aboutTagline;

  /// No description provided for @aboutPrivacyText.
  ///
  /// In en, this message translates to:
  /// **'CrispSudoku runs entirely on-device. Your games, statistics and settings never leave your device — there is no account, no analytics and no contact with remote services.'**
  String get aboutPrivacyText;

  /// No description provided for @aboutDisclaimerText.
  ///
  /// In en, this message translates to:
  /// **'CrispSudoku is provided \"as is\", without warranty of any kind. Every generated puzzle is verified to have a unique solution, but use the app at your own discretion.'**
  String get aboutDisclaimerText;

  /// No description provided for @aboutLicenseText.
  ///
  /// In en, this message translates to:
  /// **'CrispSudoku is free software, distributed under the GNU Affero General Public License version 3 or later. As the sole copyright holder, the author additionally makes official binary distributions (e.g. via the Apple App Store and Google Play) available under those stores’ standard terms; this does not affect your rights to the source under AGPL-3.0.'**
  String get aboutLicenseText;

  /// No description provided for @aboutVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {v}'**
  String aboutVersionLabel(String v);

  /// No description provided for @aboutOpenSourceLicenses.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get aboutOpenSourceLicenses;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
