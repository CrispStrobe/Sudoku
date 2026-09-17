import 'package:flutter/material.dart';

import 'about_screen.dart';
import 'achievements.dart';
import 'admin_screen.dart';
import 'clock_format.dart';
import 'game_screen.dart';
import 'game_stats.dart';
import 'l10n/app_localizations.dart';
import 'sudoku_game.dart';
import 'saved_game.dart';
import 'saved_game_service.dart';

// ---------------------------------------------------------------------------
// Home
// ---------------------------------------------------------------------------

/// The daily challenge is a fixed shape/size/difficulty so every player's board
/// for a given day is identical (only the date-derived seed varies).
const GridSize kDailyGridSize = GridSize.standard;
const GridShape kDailyGridShape = GridShape.classic;
const SudokuDifficulty kDailyDifficulty = SudokuDifficulty.medium;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  /// Drives the sheen that sweeps across the wordmark.
  late final AnimationController _sheen;

  /// The sheen plays a few times on arrival and then stops for good.
  ///
  /// Repeating forever would animate a screen that is otherwise completely
  /// static — a real battery cost for decoration — and would also mean the
  /// home route never stops scheduling frames, which hangs any
  /// `pumpAndSettle` in a test.
  static const int _maxSweeps = 3;
  int _sweeps = 0;
  SavedGame? _savedGame;

  Future<void> _refreshSavedGame() async {
    final saved = await SavedGameService().load();
    if (mounted) setState(() => _savedGame = saved);
  }

  Future<void> _resumeGame() async {
    final saved = _savedGame;
    if (saved == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => GameScreen.resume(saved)),
    );
    await _refreshSavedGame();
  }

  @override
  void initState() {
    super.initState();
    _sheen =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2600),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && _sweeps < _maxSweeps - 1) {
            _sweeps++;
            _sheen.forward(from: 0);
          }
        });
    _sheen.forward();
    _refreshSavedGame();
  }

  @override
  void dispose() {
    _sheen.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = GameStats.current;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: scheme.gradient,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildWordmarkHeader(context, l10n, scheme),
                  if (_savedGame != null) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        key: const ValueKey('resume-game'),
                        onPressed: _resumeGame,
                        icon: const Icon(Icons.play_arrow),
                        label: Text(l10n.homeResumeButton),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final buttons = [
                        _buildQuickButton(
                          l10n.homeStatsButton,
                          Icons.bar_chart,
                          _showStats,
                        ),
                        _buildQuickButton(
                          l10n.homeThemesButton,
                          Icons.palette,
                          _showThemes,
                        ),
                        _buildQuickButton(
                          l10n.homeAchievementsButton,
                          Icons.emoji_events,
                          _showAchievements,
                        ),
                        _buildQuickButton(
                          l10n.homeSettingsButton,
                          Icons.settings,
                          _showSettings,
                        ),
                      ];
                      // Four buttons comfortably fit one row only past ~500dp;
                      // below that (narrow phones) fall back to a 2x2 grid so
                      // none of them get squeezed unreadably thin.
                      if (constraints.maxWidth >= 500) {
                        return Row(
                          children: [
                            for (var i = 0; i < buttons.length; i++) ...[
                              if (i > 0) const SizedBox(width: 10),
                              Expanded(child: buttons[i]),
                            ],
                          ],
                        );
                      }
                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: buttons[0]),
                              const SizedBox(width: 10),
                              Expanded(child: buttons[1]),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: buttons[2]),
                              const SizedBox(width: 10),
                              Expanded(child: buttons[3]),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  _buildModeButton(
                    GameStats.isDailyDoneOn(DateTime.now())
                        ? l10n.homeDailyChallengeDone
                        : l10n.homeDailyChallenge,
                    GameStats.isDailyDoneOn(DateTime.now())
                        ? l10n.homeDailyCompletedSubtitle
                        : l10n.homeDailySubtitle,
                    GameStats.isDailyDoneOn(DateTime.now())
                        ? Colors.green.shade700
                        : Colors.teal.shade700,
                    _startDaily,
                  ),
                  const SizedBox(height: 30),
                  Text(
                    l10n.homeGameModes,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildModeButton(
                    l10n.homeClassicMode,
                    l10n.homeClassicModeSubtitle,
                    Colors.indigo.shade800,
                    _showClassicOptions,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _showJigsawOptions,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        foregroundColor: Colors.white,
                        elevation: 12,
                      ),
                      // scaleDown keeps the icon + label on one line on narrow
                      // phones instead of overflowing the row.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.extension, size: 24),
                            const SizedBox(width: 10),
                            Text(
                              l10n.homeJigsawMode,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (GameStats.debugMode)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.admin_panel_settings),
                      label: Text(l10n.homeAdminPanel),
                      onPressed: _navigateToAdmin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                    icon: const Icon(Icons.info_outline, color: Colors.white70),
                    label: Text(
                      l10n.homeAboutLicenses,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The start-screen wordmark.
  ///
  /// Three layers, painted back to front: a soft radial bloom in the theme's
  /// accent so the type sits in light rather than on a flat panel; the letters
  /// themselves filled with a gradient via [ShaderMask]; and a narrow
  /// translucent band swept across them by [_sheen]. The band is clipped to the
  /// glyphs by a second ShaderMask, so it lights up the letterforms instead of
  /// sliding over the background.
  Widget _buildWordmarkHeader(
    BuildContext context,
    AppLocalizations l10n,
    EnvironmentalTheme scheme,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The wordmark is the loudest thing on the screen, so it scales with
        // the viewport instead of sitting at one size and overflowing narrow
        // phones or looking lost on a tablet.
        final titleSize = (constraints.maxWidth * 0.125).clamp(28.0, 56.0);

        return Column(
          children: [
            SizedBox(
              // Two lines at `height: 0.98` occupy ~1.96x the font size;
              // the rest is breathing room for the bloom.
              height: titleSize * 2.25,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Bloom behind the type.
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            scheme.accent.withValues(alpha: 0.30),
                            scheme.accent.withValues(alpha: 0.10),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.45, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // Reduce Motion turns the sweep off entirely; the gradient
                  // fill and bloom carry the design without it.
                  if (MediaQuery.disableAnimationsOf(context))
                    _wordmarkText(titleSize, scheme)
                  else
                    AnimatedBuilder(
                      animation: _sheen,
                      builder: (context, child) {
                        // -0.4 .. 1.4 keeps the band fully off-glyph at both
                        // ends, which is the pause between sweeps.
                        final t = _sheen.value * 1.8 - 0.4;
                        return ShaderMask(
                          blendMode: BlendMode.srcATop,
                          shaderCallback: (rect) => LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.55),
                              Colors.transparent,
                            ],
                            stops: [
                              (t - 0.10).clamp(0.0, 1.0),
                              t.clamp(0.0, 1.0),
                              (t + 0.10).clamp(0.0, 1.0),
                            ],
                          ).createShader(rect),
                          child: child,
                        );
                      },
                      child: _wordmarkText(titleSize, scheme),
                    ),
                ],
              ),
            ),
            // Hairline rule, brightest under the wordmark and fading out.
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildStatChips(context, l10n, scheme),
            const SizedBox(height: 8),
            Text(
              GameStats.themeDescriptionText(context, scheme.name),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        );
      },
    );
  }

  /// The gradient-filled letterforms, shared by the animated and
  /// reduced-motion branches of [_buildWordmarkHeader].
  Widget _wordmarkText(double titleSize, EnvironmentalTheme scheme) {
    return ShaderMask(
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white,
          scheme.accent,
          Colors.white.withValues(alpha: 0.92),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(rect),
      child: Text(
        'CRISP\nSUDOKU',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: titleSize,
          fontWeight: FontWeight.w900,
          // Tight leading with wide tracking is what makes a stacked wordmark
          // read as a mark rather than a two-line heading.
          height: 0.98,
          letterSpacing: titleSize * 0.16,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            Shadow(
              color: scheme.accent.withValues(alpha: 0.45),
              blurRadius: 28,
            ),
          ],
        ),
      ),
    );
  }

  /// Solved / streak / best as separate chips rather than one run-on line, so
  /// each number is legible at a glance.
  Widget _buildStatChips(
    BuildContext context,
    AppLocalizations l10n,
    EnvironmentalTheme scheme,
  ) {
    Widget chip(IconData icon, String value, String label) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: scheme.accent),
              const SizedBox(width: 5),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 9,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    final best = GameStats.bestTime.inHours >= 99
        ? '—'
        : formatClock(GameStats.bestTime);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        chip(
          Icons.check_circle_outline,
          '${GameStats.totalPuzzlesSolved}',
          l10n.statsSolvedLabel,
        ),
        chip(
          Icons.local_fire_department,
          '${GameStats.currentStreak}',
          l10n.statsStreakLabel,
        ),
        chip(Icons.timer_outlined, best, l10n.statsBestLabel),
        if (AchievementSystem.unlockedCount > 0)
          chip(
            Icons.emoji_events_outlined,
            '${AchievementSystem.unlockedCount}',
            l10n.statsAwardsLabel,
          ),
      ],
    );
  }

  Widget _buildQuickButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildModeButton(
    String title,
    String subtitle,
    Color color,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 70,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 12,
          shadowColor: color.withValues(alpha: 0.5),
        ),
        // Stretch + scaleDown so long titles/subtitles shrink to fit a narrow
        // phone on one line each, rather than wrapping and overflowing the
        // fixed 70px height.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToAdmin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminScreen()),
    );
  }

  void _showClassicOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.classicSheetTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  children: [
                    _buildGridSizeCard(
                      GridSize.small,
                      '4×4',
                      l10n.sizeSmallDifficulty,
                      Colors.green.shade500,
                    ),
                    _buildGridSizeCard(
                      GridSize.medium,
                      '6×6',
                      l10n.sizeMediumDifficulty,
                      Colors.blue.shade400,
                    ),
                    _buildGridSizeCard(
                      GridSize.large,
                      '8×8',
                      l10n.sizeLargeDifficulty,
                      Colors.orange.shade400,
                    ),
                    _buildGridSizeCard(
                      GridSize.standard,
                      '9×9',
                      l10n.sizeStandardDifficulty,
                      Colors.red.shade400,
                    ),
                    _buildGridSizeCard(
                      GridSize.big,
                      '10×10',
                      l10n.sizeBigDifficulty,
                      Colors.purple.shade400,
                    ),
                    _buildGridSizeCard(
                      GridSize.mega,
                      '12×12',
                      l10n.sizeMegaDifficulty,
                      Colors.red.shade600,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGridSizeCard(
    GridSize size,
    String sizeLabel,
    String difficulty,
    Color color,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _showDifficultySelection(size, GameMode.classic);
      },
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              sizeLabel,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              difficulty,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDifficultySelection(
    GridSize gridSize,
    GameMode gameMode, {
    GridShape gridShape = GridShape.classic,
  }) {
    var variant = SudokuVariant.classic;
    final killerAllowed = gridDimensionFor(gridSize) <= 9;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return StatefulBuilder(
          builder: (context, setSheetState) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.selectDifficultyTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (gridShape == GridShape.jigsaw)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l10n.jigsawIrregularNote,
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                // Variants are offered on the regular box layout.
                if (gridShape == GridShape.classic) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      l10n.variantLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(l10n.variantClassic),
                        selected: variant == SudokuVariant.classic,
                        onSelected: (_) => setSheetState(
                          () => variant = SudokuVariant.classic,
                        ),
                      ),
                      ChoiceChip(
                        label: Text(l10n.variantSudokuX),
                        selected: variant == SudokuVariant.x,
                        onSelected: (_) =>
                            setSheetState(() => variant = SudokuVariant.x),
                      ),
                      if (killerAllowed)
                        ChoiceChip(
                          label: Text(l10n.variantKiller),
                          selected: variant == SudokuVariant.killer,
                          onSelected: (_) => setSheetState(
                            () => variant = SudokuVariant.killer,
                          ),
                        ),
                    ],
                  ),
                  if (variant == SudokuVariant.x)
                    _variantNote(l10n.variantXNote),
                  if (variant == SudokuVariant.killer)
                    _variantNote(l10n.variantKillerNote),
                ],
                const SizedBox(height: 12),
                for (final opt in [
                  (l10n.difficultyEasy, SudokuDifficulty.easy),
                  (l10n.difficultyMedium, SudokuDifficulty.medium),
                  (l10n.difficultyHard, SudokuDifficulty.hard),
                  (l10n.difficultyExpert, SudokuDifficulty.expert),
                ])
                  _buildDifficultyOption(
                    opt.$1,
                    _difficultyColor(opt.$2),
                    opt.$2,
                    gridSize,
                    gameMode,
                    gridShape,
                    variant,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _difficultyColor(SudokuDifficulty d) => switch (d) {
    SudokuDifficulty.easy => Colors.green,
    SudokuDifficulty.medium => Colors.orange,
    SudokuDifficulty.hard => Colors.red,
    SudokuDifficulty.expert => Colors.purple,
  };

  Widget _variantNote(String text) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.blue.shade50,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(color: Colors.blue.shade700, fontSize: 12),
      textAlign: TextAlign.center,
    ),
  );

  Widget _buildDifficultyOption(
    String label,
    Color color,
    SudokuDifficulty difficulty,
    GridSize gridSize,
    GameMode gameMode,
    GridShape gridShape,
    SudokuVariant variant,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          _startGame(
            difficulty,
            gridSize,
            gridShape,
            gameMode,
            variant: variant,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  bool _startingGame = false;

  /// Check storage, not just the asynchronously refreshed Resume button.
  /// Keep the old slot until the replacement board has actually been built.
  Future<void> _openNewGame(GameScreen screen) async {
    if (_startingGame) return;
    _startingGame = true;
    try {
      final saved = await SavedGameService().load();
      if (!mounted) return;
      if (saved != null) {
        final l10n = AppLocalizations.of(context)!;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            scrollable: true,
            title: Text(l10n.replaceSavedGameTitle),
            content: Text(l10n.replaceSavedGameBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(l10n.cancelButton),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(l10n.startNewGameButton),
              ),
            ],
          ),
        );
        if (!mounted || confirmed != true) return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
      if (mounted) await _refreshSavedGame();
    } finally {
      _startingGame = false;
    }
  }

  void _startGame(
    SudokuDifficulty difficulty,
    GridSize gridSize,
    GridShape gridShape,
    GameMode gameMode, {
    SudokuVariant variant = SudokuVariant.classic,
  }) {
    _openNewGame(
      GameScreen(
        difficulty: difficulty,
        gridSize: gridSize,
        gridShape: gridShape,
        gameMode: gameMode,
        variant: variant,
      ),
    );
  }

  void _startDaily() {
    final now = DateTime.now();
    _openNewGame(
      GameScreen(
        difficulty: kDailyDifficulty,
        gridSize: kDailyGridSize,
        gridShape: kDailyGridShape,
        gameMode: GameMode.classic,
        dailySeed: dailySeed(now),
        dailyKey: dailyDateKey(now),
      ),
    );
  }

  void _showJigsawOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.jigsawSheetTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.jigsawSheetSubtitle,
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.8,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: [
                    _buildJigsawOption(
                      l10n.jigsawSizeLabel('4×4'),
                      GridSize.small,
                      l10n.jigsawMini,
                    ),
                    _buildJigsawOption(
                      l10n.jigsawSizeLabel('6×6'),
                      GridSize.medium,
                      l10n.jigsawQuick,
                    ),
                    _buildJigsawOption(
                      l10n.jigsawSizeLabel('8×8'),
                      GridSize.large,
                      l10n.jigsawBrain,
                    ),
                    _buildJigsawOption(
                      l10n.jigsawSizeLabel('9×9'),
                      GridSize.standard,
                      l10n.jigsawClassicTwist,
                    ),
                    _buildJigsawOption(
                      l10n.jigsawSizeLabel('10×10'),
                      GridSize.big,
                      l10n.jigsawBig,
                    ),
                    _buildJigsawOption(
                      l10n.jigsawSizeLabel('12×12'),
                      GridSize.mega,
                      l10n.jigsawUltimate,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJigsawOption(String label, GridSize gridSize, String subtitle) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        _showDifficultySelection(
          gridSize,
          GameMode.classic,
          gridShape: GridShape.jigsaw,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade600, Colors.orange.shade800],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 10, color: Colors.white70),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showThemes() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.themesSheetTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    childAspectRatio: 4,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: GameStats.themes.length,
                  itemBuilder: (context, index) {
                    final theme = GameStats.themes.values.elementAt(index);
                    final isUnlocked = GameStats.unlockedThemes.contains(
                      theme.name,
                    );
                    final isSelected = GameStats.currentTheme == theme.name;

                    return GestureDetector(
                      onTap: isUnlocked
                          ? () {
                              setState(() {
                                GameStats.currentTheme = theme.name;
                              });
                              GameStats.save();
                              Navigator.pop(context);
                            }
                          : null,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: theme.gradient),
                          borderRadius: BorderRadius.circular(15),
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            GameStats.themeDisplayName(
                                              context,
                                              theme.name,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          Text(
                                            GameStats.themeDescriptionText(
                                              context,
                                              theme.name,
                                            ),
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        theme.particleEmojis.join(' '),
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isUnlocked)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.lock,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAchievements() {
    AchievementSystem.checkAchievements();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final grouped = AchievementSystem.byTier();
        final total = AchievementSystem.achievements.length;
        final unlocked = AchievementSystem.unlockedCount;

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.achievementsSheetTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.achievementsUnlockedCount(unlocked, total),
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : unlocked / total,
                  minHeight: 6,
                  backgroundColor: Colors.black.withValues(alpha: 0.06),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    for (final entry in grouped.entries) ...[
                      _achievementTierHeader(context, entry.key),
                      for (final achievement in entry.value)
                        _achievementTile(context, l10n, achievement),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _achievementTierHeader(BuildContext context, int tier) {
    final color = AchievementSystem.tierColor(tier);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            AchievementSystem.tierName(context, tier).toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(color: color.withValues(alpha: 0.25))),
        ],
      ),
    );
  }

  Widget _achievementTile(
    BuildContext context,
    AppLocalizations l10n,
    Achievement achievement,
  ) {
    final isUnlocked = GameStats.unlockedAchievements.contains(achievement.id);
    final color = AchievementSystem.tierColor(achievement.tier);
    // Locked achievements with a countable goal show how far along you are;
    // one-shot ones ("solve a Killer board") would learn nothing from a bar.
    final fraction = isUnlocked ? null : achievement.fraction;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnlocked
            ? color.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isUnlocked
              ? color.withValues(alpha: 0.45)
              : Colors.black.withValues(alpha: 0.07),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Locked icons are desaturated rather than hidden, so the list reads
          // as a ladder to climb instead of a wall of question marks.
          Opacity(
            opacity: isUnlocked ? 1 : 0.35,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(
                achievement.icon,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AchievementSystem.displayName(context, achievement.id),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isUnlocked
                              ? Colors.black87
                              : Colors.grey.shade600,
                        ),
                      ),
                    ),
                    Icon(
                      isUnlocked ? Icons.check_circle : Icons.lock_outline,
                      size: 18,
                      color: isUnlocked ? color : Colors.grey.shade400,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  AchievementSystem.description(context, achievement.id),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                if (fraction != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 5,
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.06,
                            ),
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${achievement.progress!().clamp(0, achievement.goal!)}'
                        '/${achievement.goal}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
                if (achievement.rewardTheme != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.palette, size: 13, color: color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          l10n.achievementRewardTheme(
                            GameStats.themeDisplayName(
                              context,
                              achievement.rewardTheme!,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStats() {
    final l10n = AppLocalizations.of(context)!;
    final solved = GameStats.totalPuzzlesSolved;
    final lost = GameStats.gamesLost;
    final finished = solved + lost;
    final winRate = finished == 0
        ? '—'
        : '${(solved * 100 / finished).round()}%';
    final hasBest = GameStats.bestTime.inHours < 99;
    final unlocked = GameStats.unlockedAchievements.length;
    final totalAchievements = AchievementSystem.achievements.length;

    final rows = <_Stat>[
      _Stat(Icons.check_circle_outline, l10n.statPuzzlesSolved, '$solved'),
      _Stat(Icons.percent, l10n.statWinRate, winRate),
      _Stat(
        Icons.local_fire_department,
        l10n.statCurrentStreak,
        '${GameStats.currentStreak}',
      ),
      _Stat(
        Icons.emoji_events_outlined,
        l10n.statLongestStreak,
        '${GameStats.longestStreak}',
      ),
      _Stat(Icons.heart_broken_outlined, l10n.statGamesLost, '$lost'),
      _Stat(
        Icons.timer_outlined,
        l10n.statBestTime,
        hasBest ? formatClock(GameStats.bestTime) : '—',
      ),
      _Stat(
        Icons.calendar_today,
        l10n.statDailyPuzzlesDone,
        '${GameStats.dailyCompletedCount}',
      ),
      _Stat(
        Icons.lightbulb_outline,
        l10n.statHintsUsed,
        '${GameStats.totalHintsUsed}',
      ),
      _Stat(
        Icons.military_tech_outlined,
        l10n.statAchievements,
        '$unlocked / $totalAchievements',
      ),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.statsSheetTitle,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final stat = rows[index];
                  return ListTile(
                    leading: Icon(stat.icon, color: GameStats.current.primary),
                    title: Text(stat.label),
                    trailing: Text(
                      stat.value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return StatefulBuilder(
          builder: (context, setSheetState) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsSheetTitle,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.settingsLanguageLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.settingsLanguageSystem),
                      selected: GameStats.localeCode == null,
                      onSelected: (_) => setSheetState(() {
                        GameStats.localeCode = null;
                        GameStats.save();
                      }),
                    ),
                    ChoiceChip(
                      label: Text(l10n.settingsLanguageEnglish),
                      selected: GameStats.localeCode == 'en',
                      onSelected: (_) => setSheetState(() {
                        GameStats.localeCode = 'en';
                        GameStats.save();
                      }),
                    ),
                    ChoiceChip(
                      label: Text(l10n.settingsLanguageGerman),
                      selected: GameStats.localeCode == 'de',
                      onSelected: (_) => setSheetState(() {
                        GameStats.localeCode = 'de';
                        GameStats.save();
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.settingsUnlimitedMistakes),
                  subtitle: Text(l10n.settingsUnlimitedMistakesSubtitle),
                  value: GameStats.unlimitedMistakes,
                  onChanged: (value) => setSheetState(() {
                    GameStats.unlimitedMistakes = value;
                    GameStats.save();
                  }),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One row in the statistics sheet.
class _Stat {
  final IconData icon;
  final String label;
  final String value;
  const _Stat(this.icon, this.label, this.value);
}
