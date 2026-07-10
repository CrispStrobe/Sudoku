// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get homeStatsButton => 'Statistik';

  @override
  String get homeThemesButton => 'Themen';

  @override
  String get homeAchievementsButton => 'Erfolge';

  @override
  String get homeSettingsButton => 'Einstellungen';

  @override
  String homeStatsLine(int solved, int streak, int best) {
    return 'Gelöst: $solved  |  Serie: $streak  |  Beste: $best';
  }

  @override
  String homeLossesLine(int losses) {
    return 'Niederlagen: $losses';
  }

  @override
  String get homeDailyChallengeDone => '📅 TÄGLICHE HERAUSFORDERUNG ✓';

  @override
  String get homeDailyChallenge => '📅 TÄGLICHE HERAUSFORDERUNG';

  @override
  String get homeDailyCompletedSubtitle =>
      'Abgeschlossen — morgen geht\'s weiter!';

  @override
  String get homeDailySubtitle => 'Das heutige 9×9-Rätsel, für alle gleich';

  @override
  String get homeGameModes => 'SPIELMODI';

  @override
  String get homeClassicMode => '🎯 KLASSISCHER MODUS';

  @override
  String get homeClassicModeSubtitle => 'Traditionelles Sudoku';

  @override
  String get homeJigsawMode => '🧩 JIGSAW-MODUS';

  @override
  String get homeAdminPanel => 'Admin-Bereich';

  @override
  String get homeAboutLicenses => 'Über & Lizenzen';

  @override
  String get classicSheetTitle => 'Klassisches Sudoku';

  @override
  String get sizeSmallDifficulty => 'KLEIN';

  @override
  String get sizeMediumDifficulty => 'MITTEL';

  @override
  String get sizeLargeDifficulty => 'GROSS';

  @override
  String get sizeStandardDifficulty => 'KLASSISCH';

  @override
  String get sizeBigDifficulty => 'RIESIG';

  @override
  String get sizeMegaDifficulty => 'MEGA';

  @override
  String get selectDifficultyTitle => 'Schwierigkeit wählen';

  @override
  String get jigsawIrregularNote =>
      'Jigsaw-Modus: Regionen haben unregelmäßige Formen!';

  @override
  String get variantLabel => 'Variante';

  @override
  String get variantClassic => 'Klassisch';

  @override
  String get variantSudokuX => '⊗ Sudoku-X';

  @override
  String get variantKiller => '🧮 Killer';

  @override
  String get variantXNote =>
      'Beide Hauptdiagonalen müssen ebenfalls 1–N enthalten.';

  @override
  String get variantKillerNote =>
      'Keine Vorgaben — jeder gestrichelte Käfig muss ohne Wiederholungen die angegebene Summe ergeben.';

  @override
  String get difficultyEasy => 'LEICHT';

  @override
  String get difficultyMedium => 'MITTEL';

  @override
  String get difficultyHard => 'SCHWER';

  @override
  String get difficultyExpert => 'EXPERTE';

  @override
  String get jigsawSheetTitle => '🧩 Jigsaw-Sudoku';

  @override
  String get jigsawSheetSubtitle =>
      'Unregelmäßig geformte Regionen statt Quadrate! Jede Größe hat eigene Regionsformen.';

  @override
  String jigsawSizeLabel(String size) {
    return '$size Jigsaw';
  }

  @override
  String get jigsawMini => 'Mini-Herausforderung';

  @override
  String get jigsawQuick => 'Schnelles Rätsel';

  @override
  String get jigsawBrain => 'Denksport';

  @override
  String get jigsawClassicTwist => 'Klassisch mit Dreh';

  @override
  String get jigsawBig => 'Große Herausforderung';

  @override
  String get jigsawUltimate => 'Ultimativer Test';

  @override
  String get themesSheetTitle => 'Umgebungsthemen';

  @override
  String get themeOceanName => 'Ozean';

  @override
  String get themeOceanDesc => 'Tiefen des Ozeans';

  @override
  String get themeForestName => 'Wald';

  @override
  String get themeForestDesc => 'Geheimnisvoller Wald';

  @override
  String get themeSpaceName => 'Weltraum';

  @override
  String get themeSpaceDesc => 'Kosmisches Abenteuer';

  @override
  String get themeFireName => 'Feuer';

  @override
  String get themeFireDesc => 'Vulkanausbruch';

  @override
  String get themeIceName => 'Eis';

  @override
  String get themeIceDesc => 'Gefrorene Tundra';

  @override
  String get achievementsSheetTitle => 'Erfolge';

  @override
  String get achFirstStepsName => 'Erste Schritte';

  @override
  String get achFirstStepsDesc => 'Löse dein erstes Rätsel';

  @override
  String get achSpeedDemonName => 'Blitzschnell';

  @override
  String get achSpeedDemonDesc => 'Löse ein Rätsel in unter 3 Minuten';

  @override
  String get achPuzzleMasterName => 'Rätselmeister';

  @override
  String get achPuzzleMasterDesc => 'Löse 10 Rätsel';

  @override
  String get achPureLogicName => 'Reine Logik';

  @override
  String get achPureLogicDesc => 'Löse ein schweres Rätsel ohne Hinweise';

  @override
  String get achStreakMasterName => 'Serienmeister';

  @override
  String get achStreakMasterDesc => 'Löse 5 Rätsel in Folge';

  @override
  String get achMarathonName => 'Marathon';

  @override
  String get achMarathonDesc => 'Erreiche eine Serie von 10 Rätseln';

  @override
  String achievementRewardTheme(String theme) {
    return 'Belohnung: Thema $theme';
  }

  @override
  String get statsSheetTitle => 'Statistik';

  @override
  String get statPuzzlesSolved => 'Gelöste Rätsel';

  @override
  String get statWinRate => 'Gewinnrate';

  @override
  String get statCurrentStreak => 'Aktuelle Serie';

  @override
  String get statLongestStreak => 'Längste Serie';

  @override
  String get statGamesLost => 'Verlorene Spiele';

  @override
  String get statBestTime => 'Bestzeit';

  @override
  String get statDailyPuzzlesDone => 'Tägliche Rätsel gelöst';

  @override
  String get statHintsUsed => 'Verwendete Hinweise';

  @override
  String get statAchievements => 'Erfolge';

  @override
  String get generatingPuzzle => 'Rätsel wird erstellt …';

  @override
  String get mainMenuTooltip => 'Hauptmenü';

  @override
  String scoreLabel(int score) {
    return 'Punkte: $score';
  }

  @override
  String get mistakesLabel => 'Fehler';

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
  String get hintButtonLabel => 'Hinweis';

  @override
  String hintButtonWithCount(int count) {
    return 'Hinweis ($count)';
  }

  @override
  String get noHintsLabel => 'Keine Hinweise';

  @override
  String get notesModeTooltip => 'Notizmodus';

  @override
  String get undoTooltip => 'Rückgängig';

  @override
  String get eraseTooltip => 'Löschen';

  @override
  String get explainSolveTooltip => 'Lösung erklären';

  @override
  String get failedToCreatePuzzle =>
      'Rätsel konnte nicht erstellt werden. Bitte neu starten.';

  @override
  String get smartHintsTitle => 'Intelligente Hinweise';

  @override
  String get nextLogicalStepTitle => 'Nächster logischer Schritt';

  @override
  String get nextLogicalStepSubtitle =>
      'Findet und erklärt die nächste Ableitung auf dem Spielfeld.';

  @override
  String penaltyLabel(int penalty) {
    return '-$penalty';
  }

  @override
  String get noHintsLeftSnackbar => 'Keine Hinweise mehr für dieses Rätsel!';

  @override
  String possibleNumbersSnackbar(String numbers) {
    return 'Mögliche Zahlen: $numbers';
  }

  @override
  String get noStepFoundTitle => 'Kein logischer Schritt gefunden';

  @override
  String get noStepFoundBody =>
      'Vom aktuellen Spielfeld aus ist keine einfache Ableitung möglich — es könnte eine fortgeschrittenere Technik erfordern oder einen falschen Eintrag enthalten. Prüfe zuerst auf Konflikte.';

  @override
  String get okButton => 'OK';

  @override
  String get cancelButton => 'Abbrechen';

  @override
  String placeItButton(int penalty) {
    return 'Eintragen (-$penalty)';
  }

  @override
  String get gotItButton => 'Verstanden';

  @override
  String get confirmButton => 'Bestätigen';

  @override
  String useHintConfirm(int penalty) {
    return 'Diesen Hinweis für -$penalty Punkte verwenden?';
  }

  @override
  String get techniqueNakedSingle => 'Nacktes Single';

  @override
  String get techniqueHiddenSingle => 'Verstecktes Single';

  @override
  String get techniqueLockedCandidates => 'Gesperrte Kandidaten';

  @override
  String get techniqueNakedPair => 'Nacktes Paar';

  @override
  String get techniqueNakedTriple => 'Nackter Drilling';

  @override
  String get techniqueHiddenPair => 'Verstecktes Paar';

  @override
  String get techniqueXWing => 'X-Wing';

  @override
  String get techniqueNextStep => 'Nächster Schritt';

  @override
  String get dailyCompleteTitle => '🎉 Tägliche Herausforderung geschafft!';

  @override
  String get completedTitle => '🎉 Geschafft!';

  @override
  String scoreResult(int score) {
    return 'Punkte: $score';
  }

  @override
  String timeResult(String time, int bonus) {
    return 'Zeit: $time  •  Bonus: +$bonus';
  }

  @override
  String logicRatingResult(String rating) {
    return 'Logik-Bewertung: $rating';
  }

  @override
  String get dailyComeBackNote =>
      'Komm morgen wieder für eine neue tägliche Herausforderung!';

  @override
  String get mainMenuButton => 'Hauptmenü';

  @override
  String get nextPuzzleButton => 'Nächstes Rätsel';

  @override
  String get gameOverTitle => '💥 Spiel vorbei';

  @override
  String reachedMistakesMessage(int max) {
    return 'Du hast $max Fehler erreicht.';
  }

  @override
  String get streakResetMessage => 'Deine Serie wurde zurückgesetzt.';

  @override
  String get tryAgainButton => 'Erneut versuchen';

  @override
  String get explainAppBarTitle => 'Lösung erklären';

  @override
  String get explainStart => 'Start';

  @override
  String explainStepOf(int index, int count) {
    return 'Schritt $index / $count';
  }

  @override
  String get explainNoStepsNeeded => 'Es waren keine logischen Schritte nötig.';

  @override
  String explainStartingPosition(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Startposition — noch $count Schritte.',
      one: 'Startposition — noch 1 Schritt.',
    );
    return '$_temp0';
  }

  @override
  String explainSolvedNote(String technique) {
    return '✅ Logisch gelöst — schwierigste Technik: $technique.';
  }

  @override
  String get explainStuckNote =>
      '⛔ Festgefahren — erfordert eine Technik, die über diesen Löser hinausgeht.';

  @override
  String get explainPreviousTooltip => 'Zurück';

  @override
  String get explainPlayTooltip => 'Abspielen';

  @override
  String get explainPauseTooltip => 'Pause';

  @override
  String get explainNextTooltip => 'Weiter';

  @override
  String get settingsSheetTitle => 'Einstellungen';

  @override
  String get settingsLanguageLabel => 'Sprache';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsLanguageEnglish => 'Englisch';

  @override
  String get settingsLanguageGerman => 'Deutsch';

  @override
  String get settingsUnlimitedMistakes => 'Unbegrenzte Fehler';

  @override
  String get settingsUnlimitedMistakesSubtitle =>
      'Spiele ohne Fehlerlimit (Modus „Unbegrenzte Fehler“)';

  @override
  String get aboutTitle => 'Über';

  @override
  String get aboutServiceProvider => 'Anbieter';

  @override
  String get aboutContact => 'Kontakt';

  @override
  String get aboutPrivacy => 'Datenschutz';

  @override
  String get aboutDisclaimer => 'Haftungsausschluss';

  @override
  String get aboutLicense => 'Lizenz';

  @override
  String get aboutTagline =>
      'Klassisches, Jigsaw-, Sudoku-X- und Killer-Rätsel mit täglicher Herausforderung.';

  @override
  String get aboutPrivacyText =>
      'CrispSudoku läuft vollständig auf deinem Gerät. Deine Spiele, Statistiken und Einstellungen verlassen niemals dein Gerät — es gibt kein Konto, keine Analyse und keinen Kontakt zu externen Servern.';

  @override
  String get aboutDisclaimerText =>
      'CrispSudoku wird „wie besehen“ ohne jegliche Gewährleistung bereitgestellt. Jedes generierte Rätsel wurde auf eine eindeutige Lösung geprüft, die Nutzung erfolgt dennoch auf eigenes Risiko.';

  @override
  String get aboutLicenseText =>
      'CrispSudoku ist freie Software, lizenziert unter der GNU Affero General Public License Version 3 oder später. Als alleiniger Urheberrechtsinhaber stellt der Autor zusätzlich offizielle Binärversionen (z. B. über den Apple App Store und Google Play) unter den jeweiligen Standardbedingungen dieser Stores bereit; dies berührt nicht deine Rechte am Quellcode unter der AGPL-3.0.';

  @override
  String aboutVersionLabel(String v) {
    return 'Version $v';
  }

  @override
  String get aboutOpenSourceLicenses => 'Open-Source-Lizenzen';
}
