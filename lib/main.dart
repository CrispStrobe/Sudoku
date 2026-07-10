import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'about_screen.dart';
import 'l10n/app_localizations.dart';
import 'sudoku_game.dart';
import 'technique_solver.dart';
import 'variant_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PuzzleCache().initialize();
  await GameStats.load();
  runApp(const SudokuApp());
}

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: GameStats.localeNotifier,
      builder: (context, localeCode, _) {
        return MaterialApp(
          title: 'CrispSudoku',
          theme: ThemeData(
            primarySwatch: Colors.indigo,
            fontFamily: 'Roboto',
            fontFamilyFallback: const ['Apple Color Emoji', 'Noto Color Emoji'],
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          locale: localeCode == null ? null : Locale(localeCode),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}

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

  /// Whether the daily puzzle for [date] has already been completed.
  static bool isDailyDoneOn(DateTime date) =>
      lastDailyDate == dailyDateKey(date);

  static Set<String> unlockedAchievements = {};

  /// Admin panel + all-themes-unlocked only in debug builds.
  static const bool debugMode = kDebugMode;

  static bool useSavedPuzzles = true;

  static Set<String> unlockedThemes = debugMode
      ? {'Ocean', 'Forest', 'Space', 'Fire', 'Ice'}
      : {'Ocean'};

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

class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool Function() isUnlocked;
  final String? rewardTheme;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.isUnlocked,
    this.rewardTheme,
  });
}

class AchievementSystem {
  static List<Achievement> achievements = [
    Achievement(
      id: 'first_solve',
      name: 'First Steps',
      description: 'Complete your first puzzle',
      icon: '🎯',
      isUnlocked: () => GameStats.totalPuzzlesSolved >= 1,
    ),
    Achievement(
      id: 'speed_demon',
      name: 'Speed Demon',
      description: 'Complete a puzzle in under 3 minutes',
      icon: '⚡',
      isUnlocked: () => GameStats.bestTime.inMinutes < 3,
      rewardTheme: 'Space',
    ),
    Achievement(
      id: 'puzzle_master',
      name: 'Puzzle Master',
      description: 'Complete 10 puzzles',
      icon: '🧩',
      isUnlocked: () => GameStats.totalPuzzlesSolved >= 10,
      rewardTheme: 'Forest',
    ),
    Achievement(
      id: 'no_hints_hero',
      name: 'Pure Logic',
      description: 'Complete a hard puzzle without hints',
      icon: '🧠',
      isUnlocked: () =>
          GameStats.unlockedAchievements.contains('no_hints_hard'),
      rewardTheme: 'Fire',
    ),
    Achievement(
      id: 'streak_master',
      name: 'Streak Master',
      description: 'Solve 5 puzzles in a row',
      icon: '🔥',
      isUnlocked: () => GameStats.currentStreak >= 5,
      rewardTheme: 'Ice',
    ),
    Achievement(
      id: 'marathon',
      name: 'Marathon',
      description: 'Reach a 10-puzzle streak',
      icon: '🏅',
      isUnlocked: () => GameStats.longestStreak >= 10,
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
      _ => '',
    };
  }
}

// ---------------------------------------------------------------------------
// Particles (isolated layer — see ParticleLayer)
// ---------------------------------------------------------------------------

class Particle {
  double x, y;
  double vx, vy;
  String emoji;
  double life;
  double maxLife;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.emoji,
    required this.maxLife,
  }) : life = maxLife;

  void update() {
    x += vx;
    y += vy;
    life -= 1.0;
    vy += 0.1; // gravity
  }

  bool get isDead => life <= 0;
  double get opacity => life / maxLife;
}

/// A self-contained particle overlay. It owns its own animation controller and
/// only ticks (and rebuilds) while particles are alive, so it never forces the
/// rest of the screen to rebuild at 60fps.
class ParticleLayer extends StatefulWidget {
  const ParticleLayer({super.key});

  @override
  State<ParticleLayer> createState() => ParticleLayerState();
}

class ParticleLayerState extends State<ParticleLayer>
    with SingleTickerProviderStateMixin {
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();
  late final AnimationController _controller;
  Timer? _spawnTimer;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    )..addListener(_tick);
    _spawnTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _spawnAmbient();
    });
  }

  void _ensureRunning() {
    if (!_controller.isAnimating) _controller.repeat();
  }

  void _tick() {
    if (_particles.isEmpty) {
      _controller.stop();
      return;
    }
    setState(() {
      _particles.removeWhere((p) => p.isDead);
      for (final p in _particles) {
        p.update();
      }
    });
    if (_particles.isEmpty) _controller.stop();
  }

  void _spawnAmbient() {
    if (_size == Size.zero) return;
    final emojis = GameStats.current.particleEmojis;
    _particles.add(
      Particle(
        x: _random.nextDouble() * _size.width,
        y: _size.height,
        vx: (_random.nextDouble() - 0.5) * 2,
        vy: -_random.nextDouble() * 3 - 1,
        emoji: emojis[_random.nextInt(emojis.length)],
        maxLife: 180.0,
      ),
    );
    _ensureRunning();
  }

  /// Celebratory burst from the centre of the layer.
  void burst() {
    if (_size == Size.zero) return;
    final emojis = GameStats.current.particleEmojis;
    for (var i = 0; i < 20; i++) {
      _particles.add(
        Particle(
          x: _size.width / 2,
          y: _size.height / 2,
          vx: (_random.nextDouble() - 0.5) * 8,
          vy: -_random.nextDouble() * 6 - 2,
          emoji: emojis[_random.nextInt(emojis.length)],
          maxLife: 120.0,
        ),
      );
    }
    _ensureRunning();
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return IgnorePointer(
          child: RepaintBoundary(
            child: Stack(
              children: [
                for (final p in _particles)
                  Positioned(
                    left: p.x,
                    top: p.y,
                    child: Opacity(
                      opacity: (p.opacity * 0.7).clamp(0.0, 1.0),
                      child: Text(
                        p.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Home
// ---------------------------------------------------------------------------

/// The daily challenge is a fixed shape/size/difficulty so every player's board
/// for a given day is identical (only the date-derived seed varies).
const GridSize kDailyGridSize = GridSize.standard;
const GridShape kDailyGridShape = GridShape.classic;
const SudokuDifficulty kDailyDifficulty = SudokuDifficulty.medium;

/// `MM:SS` clock formatting (minutes are not capped at 60), shared by the
/// in-game timer and the stats screen.
String formatClock(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'CRISP\nSUDOKU',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 3,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.homeStatsLine(
                            GameStats.totalPuzzlesSolved,
                            GameStats.currentStreak,
                            GameStats.longestStreak,
                          ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        if (GameStats.gamesLost > 0) ...[
                          const SizedBox(height: 2),
                          Text(
                            l10n.homeLossesLine(GameStats.gamesLost),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 5),
                        Text(
                          GameStats.themeDescriptionText(context, scheme.name),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
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

  void _startGame(
    SudokuDifficulty difficulty,
    GridSize gridSize,
    GridShape gridShape,
    GameMode gameMode, {
    SudokuVariant variant = SudokuVariant.classic,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          difficulty: difficulty,
          gridSize: gridSize,
          gridShape: gridShape,
          gameMode: gameMode,
          variant: variant,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {}); // refresh stats shown on home
    });
  }

  void _startDaily() {
    final now = DateTime.now();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          difficulty: kDailyDifficulty,
          gridSize: kDailyGridSize,
          gridShape: kDailyGridShape,
          gameMode: GameMode.classic,
          dailySeed: dailySeed(now),
          dailyKey: dailyDateKey(now),
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {}); // refresh daily/stats shown on home
    });
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
                                    flex: 1,
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
                l10n.achievementsSheetTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: AchievementSystem.achievements.length,
                  itemBuilder: (context, index) {
                    final achievement = AchievementSystem.achievements[index];
                    final isUnlocked = GameStats.unlockedAchievements.contains(
                      achievement.id,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Text(
                          achievement.icon,
                          style: const TextStyle(fontSize: 30),
                        ),
                        title: Text(
                          AchievementSystem.displayName(
                            context,
                            achievement.id,
                          ),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isUnlocked ? Colors.black : Colors.grey,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AchievementSystem.description(
                                context,
                                achievement.id,
                              ),
                            ),
                            if (achievement.rewardTheme != null)
                              Text(
                                l10n.achievementRewardTheme(
                                  GameStats.themeDisplayName(
                                    context,
                                    achievement.rewardTheme!,
                                  ),
                                ),
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        trailing: isUnlocked
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                            : const Icon(Icons.lock, color: Colors.grey),
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

// ---------------------------------------------------------------------------
// Game screen
// ---------------------------------------------------------------------------

class GameScreen extends StatefulWidget {
  final SudokuDifficulty difficulty;
  final GridSize gridSize;
  final GridShape gridShape;
  final GameMode gameMode;

  /// When set, the board is generated deterministically from this seed (the
  /// daily puzzle) instead of pulled from the random cache/generator.
  final int? dailySeed;

  /// `YYYY-MM-DD` of the daily puzzle; non-null marks this as the daily run.
  final String? dailyKey;

  /// Rule variant (classic or Sudoku-X).
  final SudokuVariant variant;

  const GameScreen({
    super.key,
    required this.difficulty,
    required this.gridSize,
    required this.gridShape,
    required this.gameMode,
    this.dailySeed,
    this.dailyKey,
    this.variant = SudokuVariant.classic,
  });

  bool get isDaily => dailyKey != null;
  bool get isDiagonal => variant == SudokuVariant.x;
  bool get isKiller => variant == SudokuVariant.killer;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  SudokuGame? game;
  int? selectedRow;
  int? selectedCol;

  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;

  final GlobalKey<ParticleLayerState> _particleKey =
      GlobalKey<ParticleLayerState>();

  int hintsUsed = 0;
  int score = 1000;
  int mistakes = 0;
  bool _notesMode = false;

  /// Difficulty of the current board as rated by the logical-technique solver
  /// (distinct from the generation difficulty, which is hole-count based).
  SudokuDifficulty? _logicRating;

  /// Killer cages for the current board (empty unless the Killer variant).
  List<KillerCage> _cages = const [];

  /// Score cost of revealing the next logical step.
  static const int _nextStepPenalty = 40;

  int get _maxMistakes => maxMistakesFor(widget.difficulty);
  int get _maxHints => maxHintsFor(widget.difficulty);
  int get _hintsRemaining => math.max(0, _maxHints - hintsUsed);

  Timer? _gameTimer;
  final ValueNotifier<Duration> _elapsed = ValueNotifier(Duration.zero);
  DateTime? _startTime;

  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeGame());
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  void _startGameTimer() {
    _gameTimer?.cancel();
    _startTime = DateTime.now();
    _elapsed.value = Duration.zero;
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed.value = DateTime.now().difference(_startTime!);
    });
  }

  void _stopGameTimer() => _gameTimer?.cancel();

  String _formatDuration(Duration d) => formatClock(d);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasError && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.failedToCreatePuzzle),
            ),
          );
          _hasError = false;
        }
      });
    }
  }

  Future<SudokuGame> _generatePuzzleWithRetries() async {
    // The web has no Isolate.spawn, so generate inline on the main thread
    // (bounded by the engine's internal budgets). A microtask yield lets the
    // loading indicator paint first.
    if (kIsWeb) {
      await Future<void>.delayed(Duration.zero);
      return SudokuGame.generate(
        widget.difficulty,
        widget.gridSize,
        widget.gridShape,
        variant: widget.variant,
      );
    }

    const totalBudget = Duration(seconds: 24);
    const maxAttempts = 3;
    final stopwatch = Stopwatch()..start();
    Object? lastError;
    for (
      var attempt = 1;
      attempt <= maxAttempts && stopwatch.elapsed < totalBudget;
      attempt++
    ) {
      try {
        return await SudokuGame.create(
          widget.difficulty,
          widget.gridSize,
          widget.gridShape,
          timeout: const Duration(seconds: 12),
          variant: widget.variant,
        );
      } catch (e) {
        lastError = e;
        DebugLogger.log('Generation attempt $attempt failed; retrying.');
      }
    }
    throw TimeoutException('Failed to generate a puzzle: $lastError');
  }

  Future<void> _initializeGame() async {
    try {
      setState(() => game = null);

      SudokuGame? built;
      _cages = const [];
      if (widget.isKiller) {
        // Killer is generated outside the bitmask engine (cage sums need the
        // CSP solver). Fast enough (~100ms) to run inline behind the spinner.
        final puzzle = await VariantEngine.generateKiller(
          gridSize: widget.gridSize,
          difficulty: widget.difficulty,
        );
        _cages = puzzle.cages;
        built = SudokuGame.fromState(
          givens: puzzle.givens,
          solution: puzzle.solution,
          regions: puzzle.regions,
          difficulty: widget.difficulty,
          variant: SudokuVariant.killer,
        );
      } else if (widget.dailySeed != null) {
        // Deterministic, cache-free generation so the daily board is identical
        // for every player and every replay. 9×9 classic generates instantly.
        built = SudokuGame.generate(
          widget.difficulty,
          widget.gridSize,
          widget.gridShape,
          seed: widget.dailySeed,
        );
      } else if (GameStats.useSavedPuzzles &&
          widget.variant == SudokuVariant.classic) {
        // The cache holds only classic-rule boards; variants always generate.
        final blueprint = PuzzleCache().getRandom(
          widget.gridSize,
          widget.gridShape,
        );
        if (blueprint != null) {
          built = SudokuGame.fromBlueprint(blueprint, widget.difficulty);
        }
      }

      if (built == null) {
        built = await _generatePuzzleWithRetries();
        // Cache the freshly generated solution so future plays are instant.
        if (GameStats.useSavedPuzzles &&
            widget.variant == SudokuVariant.classic) {
          await PuzzleCache().set(
            PuzzleBlueprint(
              solutionGrid: built.solution,
              regions: built.regions,
              gridSize: widget.gridSize,
              gridShape: widget.gridShape,
            ),
          );
        }
      }

      game = built;
      _startGameTimer();
      score = _calculateInitialScore();
      mistakes = 0;
      _updateLogicRating();
      if (mounted) setState(() {});
    } catch (e, st) {
      DebugLogger.error('Generation failed; falling back to classic.', e, st);
      try {
        game = kIsWeb
            ? SudokuGame.generate(
                widget.difficulty,
                widget.gridSize,
                GridShape.classic,
              )
            : await SudokuGame.create(
                widget.difficulty,
                widget.gridSize,
                GridShape.classic,
              );
        _startGameTimer();
        score = _calculateInitialScore();
        mistakes = 0;
        _updateLogicRating();
        if (mounted) setState(() {});
      } catch (e2, st2) {
        DebugLogger.error('Fallback also failed.', e2, st2);
        if (mounted) {
          setState(() => _hasError = true);
        }
      }
    }
  }

  int _calculateInitialScore() {
    var base = 500;
    base += switch (widget.gridSize) {
      GridSize.small => 200,
      GridSize.medium => 400,
      GridSize.large => 600,
      GridSize.standard => 800,
      GridSize.big => 1000,
      GridSize.mega => 1200,
    };
    base += switch (widget.difficulty) {
      SudokuDifficulty.easy => 100,
      SudokuDifficulty.medium => 300,
      SudokuDifficulty.hard => 500,
      SudokuDifficulty.expert => 800,
    };
    if (widget.gridShape == GridShape.jigsaw) base += 200;
    return base;
  }

  /// Rate the current board by the hardest human technique it requires. Cheap
  /// (a few ms); recomputed whenever a new board is built.
  void _updateLogicRating() {
    final g = game;
    // The technique solver doesn't model cage sums, so it can't rate Killer.
    if (g == null || widget.isKiller) {
      _logicRating = null;
      return;
    }
    try {
      _logicRating = TechniqueSolver(
        g.grid,
        g.regions,
        diagonal: widget.isDiagonal,
      ).solve().rating;
    } catch (_) {
      _logicRating = null;
    }
  }

  /// Title-case difficulty label ("Easy", "Medium", ...) reusing the same
  /// localized difficulty strings as the picker sheet (which are all-caps,
  /// for buttons) rather than a separate set of ARB keys.
  static String _ratingLabel(BuildContext context, SudokuDifficulty d) {
    final l10n = AppLocalizations.of(context)!;
    final upper = switch (d) {
      SudokuDifficulty.easy => l10n.difficultyEasy,
      SudokuDifficulty.medium => l10n.difficultyMedium,
      SudokuDifficulty.hard => l10n.difficultyHard,
      SudokuDifficulty.expert => l10n.difficultyExpert,
    };
    final lower = upper.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  @override
  void dispose() {
    _stopGameTimer();
    _elapsed.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _selectCell(int row, int col) {
    setState(() {
      if (selectedRow == row && selectedCol == col) {
        selectedRow = null;
        selectedCol = null;
      } else {
        selectedRow = row;
        selectedCol = col;
      }
    });
    _pulseController.forward().then((_) => _pulseController.reverse());
  }

  /// Number-pad tap: toggles a note in notes mode, otherwise places the value.
  void _inputNumber(int number) {
    if (selectedRow == null || selectedCol == null) return;
    if (_notesMode) {
      setState(() => game?.toggleNote(selectedRow!, selectedCol!, number));
    } else {
      _placeValue(selectedRow!, selectedCol!, number);
    }
  }

  /// Places [number] at (row,col). Wrong (conflicting) moves are allowed — they
  /// stay on the board (highlighted) and cost score; the puzzle is won only
  /// when [SudokuGame.isSolved] holds.
  void _placeValue(int row, int col, int number) {
    final g = game;
    if (g == null || g.isOriginal[row][col]) return;
    final wasValid =
        g.isValidMove(row, col, number) &&
        _killerPlacementValid(row, col, number);
    setState(() => g.setCell(row, col, number));
    if (!wasValid) {
      _shakeController.forward().then((_) => _shakeController.reverse());
      setState(() {
        score = math.max(0, score - 25);
        mistakes++;
      });
      if (!GameStats.unlimitedMistakes && mistakes >= _maxMistakes) {
        _gameOver();
        return;
      }
    }
    if (_isWon()) _completeGame();
  }

  /// The cage containing (row,col), or null (always null off the Killer variant).
  KillerCage? _cageAt(int row, int col) {
    for (final cage in _cages) {
      if (cage.contains(row, col)) return cage;
    }
    return null;
  }

  /// True unless placing [number] would break (row,col)'s Killer cage (repeat
  /// digit or sum overflow). Always true off the Killer variant.
  bool _killerPlacementValid(int row, int col, int number) {
    if (!widget.isKiller) return true;
    final cage = _cageAt(row, col);
    if (cage == null) return true;
    final g = game!;
    final seen = <int>{number};
    var total = number, filled = 1;
    for (final cell in cage.cells) {
      if (cell[0] == row && cell[1] == col) continue;
      final v = g.grid[cell[0]][cell[1]];
      if (v == 0) continue;
      filled++;
      total += v;
      if (!seen.add(v)) return false;
    }
    if (total > cage.sum) return false;
    if (filled == cage.cells.length && total != cage.sum) return false;
    return true;
  }

  /// Win condition: standard full-and-consistent, plus every cage satisfied
  /// for Killer.
  bool _isWon() {
    final g = game;
    if (g == null || !g.isSolved()) return false;
    return !widget.isKiller || cagesSatisfied(_cages, g.grid);
  }

  /// Conflict highlight for a cell: standard conflicts, plus a Killer cage that
  /// currently has a repeated digit or an over/wrong sum.
  bool _cellConflict(int row, int col) {
    final g = game!;
    if (g.hasConflict(row, col)) return true;
    if (widget.isKiller) {
      final cage = _cageAt(row, col);
      if (cage != null && cage.hasError(g.grid)) return true;
    }
    return false;
  }

  void _clearCell() {
    if (selectedRow != null && selectedCol != null) {
      setState(() => game?.clearCell(selectedRow!, selectedCol!));
    }
  }

  void _undo() {
    final cell = game?.undo();
    if (cell != null) {
      setState(() {
        selectedRow = cell[0];
        selectedCol = cell[1];
      });
    }
  }

  void _toggleNotesMode() => setState(() => _notesMode = !_notesMode);

  void _showHint() {
    if (_hintsRemaining == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.noHintsLeftSnackbar),
        ),
      );
      return;
    }
    if (game != null) _showHintDialog();
  }

  void _showHintDialog() {
    final l10n = AppLocalizations.of(context)!;
    // A board-wide "next logical step" (works with no cell selected), plus the
    // per-cell smart hints when a cell is selected.
    final perCell = (selectedRow != null && selectedCol != null)
        ? game!.getSmartHints(selectedRow!, selectedCol!)
        : <SmartHint>[];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lightbulb, color: Colors.orange),
            const SizedBox(width: 10),
            Text(l10n.smartHintsTitle),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                color: GameStats.current.cellHighlight,
                child: ListTile(
                  leading: const Icon(
                    Icons.auto_awesome,
                    color: Colors.deepPurple,
                  ),
                  title: Text(l10n.nextLogicalStepTitle),
                  subtitle: Text(l10n.nextLogicalStepSubtitle),
                  trailing: Text(
                    l10n.penaltyLabel(_nextStepPenalty),
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showNextStepHint();
                  },
                ),
              ),
              // hint.title / hint.description are dynamically-composed solver
              // prose — left in English for now (see plan notes on
              // technique_solver.dart / sudoku_game.dart scope).
              for (final hint in perCell)
                Card(
                  child: ListTile(
                    title: Text(hint.title),
                    subtitle: Text(hint.description),
                    trailing: Text(
                      hint.penalty > 0 ? l10n.penaltyLabel(hint.penalty) : '',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showHintConfirmation(hint);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compute the next logical deduction from the current board and present it.
  void _showNextStepHint() {
    final l10n = AppLocalizations.of(context)!;
    final g = game;
    if (g == null) return;
    final step = TechniqueSolver(
      g.grid,
      g.regions,
      diagonal: widget.isDiagonal,
    ).nextStep();
    if (step == null) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(l10n.noStepFoundTitle),
          content: Text(l10n.noStepFoundBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.okButton),
            ),
          ],
        ),
      );
      return;
    }
    final isPlacement = step.value != null;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_techniqueLabel(context, step.technique)),
        content: Text(step.explanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelButton),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyNextStep(step);
            },
            child: Text(
              isPlacement
                  ? l10n.placeItButton(_nextStepPenalty)
                  : l10n.gotItButton,
            ),
          ),
        ],
      ),
    );
  }

  /// Charge a hint and apply [step] — placing its value (placement steps) or
  /// just selecting the cell so the player can act on the explanation.
  void _applyNextStep(SolveStep step) {
    final g = game;
    if (g == null) return;
    setState(() {
      hintsUsed++;
      GameStats.totalHintsUsed++;
      score = math.max(0, score - _nextStepPenalty);
      selectedRow = step.cell[0];
      selectedCol = step.cell[1];
      if (step.value != null) {
        g.setCell(step.cell[0], step.cell[1], step.value!);
      }
    });
    if (_isWon()) _completeGame();
  }

  static String _techniqueLabel(BuildContext context, Technique t) {
    final l10n = AppLocalizations.of(context)!;
    switch (t) {
      case Technique.nakedSingle:
        return l10n.techniqueNakedSingle;
      case Technique.hiddenSingle:
        return l10n.techniqueHiddenSingle;
      case Technique.lockedCandidates:
        return l10n.techniqueLockedCandidates;
      case Technique.nakedPair:
        return l10n.techniqueNakedPair;
      case Technique.nakedTriple:
        return l10n.techniqueNakedTriple;
      case Technique.hiddenPair:
        return l10n.techniqueHiddenPair;
      case Technique.xWing:
        return l10n.techniqueXWing;
      case Technique.guess:
        return l10n.techniqueNextStep;
    }
  }

  void _showHintConfirmation(SmartHint hint) {
    if (hint.penalty == 0) return;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(hint.title),
        content: Text(l10n.useHintConfirm(hint.penalty)),
        actions: [
          TextButton(
            child: Text(l10n.cancelButton),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text(l10n.confirmButton),
            onPressed: () {
              Navigator.pop(context);
              _applyHint(hint);
            },
          ),
        ],
      ),
    );
  }

  void _applyHint(SmartHint hint) {
    final l10n = AppLocalizations.of(context)!;
    final g = game;
    if (g == null) return;
    setState(() {
      score = math.max(0, score - hint.penalty);
      hintsUsed++;
      GameStats.totalHintsUsed++;
      switch (hint.type) {
        case HintType.showPossible:
          final numbers = (hint.data as List<int>).join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.possibleNumbersSnackbar(numbers))),
          );
          break;
        case HintType.giveAnswer:
        case HintType.nakedSingle:
        case HintType.hiddenSingle:
          g.setCell(selectedRow!, selectedCol!, hint.data as int);
          break;
        case HintType.conflict:
          break;
      }
    });
    if (_isWon()) _completeGame();
  }

  void _completeGame() {
    final g = game;
    if (g == null) return;
    _stopGameTimer();

    final completionTime = _elapsed.value;
    final timeBonus = math.max(0, 300 - completionTime.inSeconds ~/ 2);
    final finalScore = score + timeBonus;

    GameStats.totalPuzzlesSolved++;
    if (completionTime < GameStats.bestTime) {
      GameStats.bestTime = completionTime;
    }
    GameStats.currentStreak++;
    if (GameStats.currentStreak > GameStats.longestStreak) {
      GameStats.longestStreak = GameStats.currentStreak;
    }
    if (hintsUsed == 0 && widget.difficulty == SudokuDifficulty.hard) {
      GameStats.unlockedAchievements.add('no_hints_hard');
    }
    if (widget.isDaily && GameStats.lastDailyDate != widget.dailyKey) {
      GameStats.lastDailyDate = widget.dailyKey;
      GameStats.dailyCompletedCount++;
    }
    AchievementSystem.checkAchievements();
    GameStats.save(); // persist solved count, streak, best time, unlocks

    setState(() => score = finalScore);
    _particleKey.currentState?.burst();
    _showCompletionDialog(finalScore, completionTime, timeBonus);
  }

  void _showCompletionDialog(int finalScore, Duration time, int timeBonus) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = GameStats.current;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          widget.isDaily ? l10n.dailyCompleteTitle : l10n.completedTitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, color: scheme.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.scoreResult(finalScore),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(l10n.timeResult(_formatDuration(time), timeBonus)),
            if (_logicRating != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.logicRatingResult(_ratingLabel(context, _logicRating!)),
                ),
              ),
            if (widget.isDaily)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.dailyComeBackNote),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _goToMainMenu();
            },
            child: Text(l10n.mainMenuButton),
          ),
          // The daily is one board per day — no "Next Puzzle".
          if (!widget.isDaily)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _startNextLevel();
              },
              child: Text(l10n.nextPuzzleButton),
            ),
        ],
      ),
    );
  }

  /// The player has used up their mistake allowance. End the run, break the
  /// streak, and offer a retry of the same board or a return to the menu.
  void _gameOver() {
    _stopGameTimer();
    GameStats.currentStreak = 0;
    GameStats.gamesLost++;
    GameStats.save(); // persist the broken streak + loss count
    _showGameOverDialog();
  }

  void _showGameOverDialog() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = GameStats.current;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.gameOverTitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, color: scheme.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.reachedMistakesMessage(_maxMistakes),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(l10n.streakResetMessage, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _goToMainMenu();
            },
            child: Text(l10n.mainMenuButton),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _retrySamePuzzle();
            },
            child: Text(l10n.tryAgainButton),
          ),
        ],
      ),
    );
  }

  /// Replay the current board from its givens (no new generation).
  void _retrySamePuzzle() {
    final g = game;
    if (g == null) return;
    setState(() {
      g.reset();
      selectedRow = null;
      selectedCol = null;
      hintsUsed = 0;
      mistakes = 0;
      _notesMode = false;
      score = _calculateInitialScore();
    });
    _startGameTimer();
  }

  void _startNextLevel() {
    setState(() {
      selectedRow = null;
      selectedCol = null;
      hintsUsed = 0;
      mistakes = 0;
      _notesMode = false;
    });
    _initializeGame();
  }

  void _goToMainMenu() {
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (game == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: GameStats.current.gradient,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context)!.generatingPuzzle,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final scheme = GameStats.current;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.gridSize.name.toUpperCase()} '
          '${widget.gridShape.name.toUpperCase()}',
        ),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _goToMainMenu,
            icon: const Icon(Icons.home),
            tooltip: l10n.mainMenuTooltip,
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                l10n.scoreLabel(score),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ValueListenableBuilder<Duration>(
                valueListenable: _elapsed,
                builder: (context, value, _) => Text(
                  _formatDuration(value),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: scheme.gradient,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: ParticleLayer(key: _particleKey)),
              Padding(
                padding: EdgeInsets.all(isTablet ? 24 : 16),
                child: Column(
                  children: [
                    _buildStatusStrip(),
                    const SizedBox(height: 8),
                    Expanded(
                      flex: isTablet ? 3 : 2,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(_shakeAnimation.value, 0),
                            child: child,
                          ),
                          child: _buildSudokuGrid(isTablet, scheme),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildControls(scheme),
                    const SizedBox(height: 10),
                    Expanded(flex: 1, child: _buildNumberPad(isTablet)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Slim "Mistakes ✕ ✕ ○ ○ ○ (n/max)" strip above the grid. The pips fill in
  /// as mistakes accrue and turn red on the final life so the lose condition is
  /// visible at a glance.
  /// The status row above the grid: the logic-rating pill (when known) beside
  /// the mistakes strip. Wrapped in a scaleDown FittedBox so both fit on a
  /// narrow phone without overflowing.
  Widget _buildStatusStrip() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_logicRating != null) ...[
            _buildLogicPill(),
            const SizedBox(width: 8),
          ],
          _buildMistakesIndicator(),
        ],
      ),
    );
  }

  Widget _buildLogicPill() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Text(
          AppLocalizations.of(
            context,
          )!.logicRatingPill(_ratingLabel(context, _logicRating!)),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildMistakesIndicator() {
    final unlimited = GameStats.unlimitedMistakes;
    final atRisk = !unlimited && mistakes >= _maxMistakes - 1;
    final accent = atRisk ? Colors.red.shade300 : Colors.white;
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.mistakesLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 10),
            if (!unlimited)
              for (var i = 0; i < _maxMistakes; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    i < mistakes ? Icons.close : Icons.radio_button_unchecked,
                    size: 15,
                    color: i < mistakes ? accent : Colors.white54,
                  ),
                ),
            const SizedBox(width: 8),
            Text(
              unlimited
                  ? l10n.mistakesCountUnlimited(mistakes)
                  : l10n.mistakesCount(mistakes, _maxMistakes),
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(EnvironmentalTheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            // Logic hints don't model cage sums, so they're off for Killer.
            onPressed: (!widget.isKiller && _hintsRemaining > 0)
                ? _showHint
                : null,
            icon: const Icon(Icons.lightbulb),
            label: Text(
              widget.isKiller
                  ? l10n.hintButtonLabel
                  : (_hintsRemaining > 0
                        ? l10n.hintButtonWithCount(_hintsRemaining)
                        : l10n.noHintsLabel),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade400,
              disabledForegroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _circleButton(
          icon: Icons.edit,
          tooltip: l10n.notesModeTooltip,
          active: _notesMode,
          activeColor: scheme.primary,
          onPressed: _toggleNotesMode,
        ),
        const SizedBox(width: 8),
        _circleButton(
          icon: Icons.undo,
          tooltip: l10n.undoTooltip,
          onPressed: (game?.canUndo ?? false) ? _undo : null,
        ),
        const SizedBox(width: 8),
        _circleButton(
          icon: Icons.clear,
          tooltip: l10n.eraseTooltip,
          activeColor: Colors.red,
          active: true,
          onPressed: _clearCell,
        ),
        const SizedBox(width: 8),
        _circleButton(
          icon: Icons.school,
          tooltip: l10n.explainSolveTooltip,
          onPressed: (game == null || widget.isKiller) ? null : _openExplain,
        ),
      ],
    );
  }

  /// Opens a step-by-step walkthrough that solves the current board with
  /// human techniques, explaining each deduction.
  void _openExplain() {
    final g = game;
    if (g == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExplainScreen(
          grid: g.grid,
          regions: g.regions,
          gridDim: g.gridDim,
          jigsaw: widget.gridShape == GridShape.jigsaw,
          diagonal: widget.isDiagonal,
          scheme: GameStats.current,
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool active = false,
    Color activeColor = Colors.white,
  }) {
    return Tooltip(
      message: tooltip,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? activeColor : Colors.white,
          foregroundColor: active ? Colors.white : Colors.black87,
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(12),
        ),
        child: Icon(icon),
      ),
    );
  }

  Widget _buildSudokuGrid(bool isTablet, EnvironmentalTheme scheme) {
    final g = game!;
    final gridDim = g.gridDim;
    final maxGridSize = isTablet ? 450.0 : 320.0;

    // Both width AND height must be consulted: the old version only read
    // MediaQuery's screen width, so on a wide-but-height-constrained viewport
    // (iPad, a resized browser window, landscape) the surrounding Expanded/
    // Center would clamp the actual rendered box down, but the Positioned
    // cells below were still placed using the un-clamped size — pushing the
    // last row(s) outside the ClipRRect. Using LayoutBuilder's own
    // constraints keeps the two in sync in both axes.
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridPixels = math.min(
          maxGridSize,
          math.min(constraints.maxWidth, constraints.maxHeight),
        );
        final cellSize = gridPixels / gridDim;

        return Container(
          width: gridPixels,
          height: gridPixels,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(gridPixels, gridPixels),
                  painter: SudokuGridPainter(
                    g.gridDim,
                    g.regions,
                    jigsaw: widget.gridShape == GridShape.jigsaw,
                  ),
                ),
                for (int row = 0; row < gridDim; row++)
                  for (int col = 0; col < gridDim; col++)
                    Positioned(
                      left: col * cellSize,
                      top: row * cellSize,
                      width: cellSize,
                      height: cellSize,
                      child: _buildCell(row, col, isTablet, scheme),
                    ),
                if (widget.isKiller)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        size: Size(gridPixels, gridPixels),
                        painter: KillerCagePainter(_cages, gridDim),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(
    int row,
    int col,
    bool isTablet,
    EnvironmentalTheme scheme,
  ) {
    final g = game!;
    final isSelected = selectedRow == row && selectedCol == col;

    final value = g.grid[row][col];
    final conflict = _cellConflict(row, col);

    Widget cell = DragTarget<int>(
      onAcceptWithDetails: (details) => _placeValue(row, col, details.data),
      onWillAcceptWithDetails: (_) => true,
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return GestureDetector(
          onTap: () => _selectCell(row, col),
          child: Container(
            margin: const EdgeInsets.all(0.5),
            decoration: BoxDecoration(
              color: isHovered
                  ? scheme.accent.withValues(alpha: 0.7)
                  : (conflict
                        ? const Color(0xFFFFCDD2) // red tint for conflicts
                        : _getCellColor(row, col, scheme)),
              border: Border.all(
                color: isSelected
                    ? scheme.primary
                    : (isHovered
                          ? scheme.primary.withValues(alpha: 0.5)
                          : Colors.transparent),
                width: isSelected ? 3 : (isHovered ? 2 : 0),
              ),
            ),
            child: Center(
              child: value != 0
                  ? Text(
                      '$value',
                      style: TextStyle(
                        fontSize: isTablet ? 28 : 20,
                        fontWeight: g.isOriginal[row][col]
                            ? FontWeight.bold
                            : FontWeight.w500,
                        color: g.isOriginal[row][col]
                            ? Colors.black
                            : (conflict ? Colors.red.shade800 : scheme.primary),
                      ),
                    )
                  : _buildNotes(g.notes[row][col], g.gridDim),
            ),
          ),
        );
      },
    );

    // Only the selected cell pulses, so only it is wrapped in an
    // AnimatedBuilder — the rest of the grid stays static.
    if (isSelected) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _pulseAnimation.value, child: child),
        child: cell,
      );
    }
    return cell;
  }

  Color _getCellColor(int row, int col, EnvironmentalTheme scheme) {
    if (selectedRow == row && selectedCol == col) return scheme.accent;
    if (selectedRow == row || selectedCol == col) return Colors.grey.shade200;

    // Faint tint marks the two diagonals so the Sudoku-X constraint is visible.
    if (widget.isDiagonal) {
      final dim = game!.gridDim;
      if (row == col || row + col == dim - 1) return const Color(0xFFEDE7F6);
    }

    final regionId = game!.regions[row][col];
    if (widget.gridShape == GridShape.jigsaw) {
      const colors = [
        Color(0xFFFAFAFA),
        Color(0xFFE3F2FD),
        Color(0xFFE8F5E9),
        Color(0xFFFFF3E0),
        Color(0xFFF3E5F5),
        Color(0xFFFFEBEE),
      ];
      return colors[regionId % colors.length];
    }
    if (regionId % 2 == 0) return scheme.cellHighlight;
    return Colors.white;
  }

  /// Renders pencil-mark candidates as a compact grid inside an empty cell.
  Widget _buildNotes(Set<int> notes, int gridDim) {
    if (notes.isEmpty) return const SizedBox.shrink();
    final perRow = math.sqrt(gridDim).ceil();
    final sorted = notes.toList()..sort();
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = (constraints.maxWidth / perRow) * 0.5;
        return Padding(
          padding: const EdgeInsets.all(1),
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (final n in sorted)
                SizedBox(
                  width: constraints.maxWidth / perRow,
                  child: Text(
                    '$n',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize.clamp(6, 12),
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNumberPad(bool isTablet) {
    final maxNumber = game!.gridDim;
    final primary = GameStats.current.primary;
    final crossAxisCount = math.min(6, maxNumber);
    const spacing = 8.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      // The number tiles must actually fit the available space and scale
      // with it (previously buttonSize/fontSize only depended on the binary
      // isTablet flag, completely disconnected from what GridView actually
      // rendered — on a 4x4 board on a tablet that meant tiny digits in huge
      // empty tiles, and on 12x12 boards, digits shrinking arbitrarily as
      // more rows got squeezed into the same space). Deriving both from the
      // real computed cell width keeps them proportionate on any device.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rows = (maxNumber / crossAxisCount).ceil();
          final cellWidth =
              (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
              crossAxisCount;
          final cellHeight =
              (constraints.maxHeight - spacing * (rows - 1)) / rows;
          final buttonSize = math.min(cellWidth, cellHeight);
          final fontSize = (buttonSize * 0.4).clamp(12.0, 28.0);

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: maxNumber,
            itemBuilder: (context, index) {
              final number = index + 1;
              return Draggable<int>(
                data: number,
                // Anchor the feedback's centre on the pointer so the floating
                // tile stays under the finger/cursor (and thus over the
                // highlighted target cell). The default
                // childDragAnchorStrategy offsets it by the grab point within
                // the number-pad cell, which is sized independently of the
                // fixed-size feedback and pushed it off-cursor.
                dragAnchorStrategy: (draggable, context, position) =>
                    Offset(buttonSize / 2, buttonSize / 2),
                feedback: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '$number',
                      style: TextStyle(
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                  ),
                ),
                childWhenDragging: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.5),
                    foregroundColor: primary.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 4,
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                child: ElevatedButton(
                  onPressed: () => _inputNumber(number),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 8,
                    padding: EdgeInsets.zero,
                  ),
                  child: Text(
                    '$number',
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Explain-the-solve walkthrough
// ---------------------------------------------------------------------------

/// A read-only, step-by-step replay that solves a board with human techniques
/// (via [TechniqueSolver]) and narrates each deduction. Navigate with
/// prev/next or auto-play.
class ExplainScreen extends StatefulWidget {
  final List<List<int>> grid;
  final List<List<int>> regions;
  final int gridDim;
  final bool jigsaw;
  final bool diagonal;
  final EnvironmentalTheme scheme;

  const ExplainScreen({
    super.key,
    required this.grid,
    required this.regions,
    required this.gridDim,
    required this.jigsaw,
    required this.diagonal,
    required this.scheme,
  });

  @override
  State<ExplainScreen> createState() => _ExplainScreenState();
}

class _ExplainScreenState extends State<ExplainScreen> {
  late final TechniqueSolveResult _result;

  /// Board snapshots: `_boards[i]` is the grid after `i` steps (index 0 = start).
  late final List<List<List<int>>> _boards;

  int _index = 0;
  Timer? _autoplay;

  @override
  void initState() {
    super.initState();
    _result = TechniqueSolver(
      widget.grid,
      widget.regions,
      diagonal: widget.diagonal,
    ).solve();
    _boards = [widget.grid.map((r) => List<int>.from(r)).toList()];
    for (final step in _result.steps) {
      final next = _boards.last.map((r) => List<int>.from(r)).toList();
      if (step.value != null) next[step.cell[0]][step.cell[1]] = step.value!;
      _boards.add(next);
    }
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    super.dispose();
  }

  int get _stepCount => _result.steps.length;

  void _go(int to) {
    setState(() => _index = to.clamp(0, _stepCount));
  }

  void _toggleAutoplay() {
    if (_autoplay != null) {
      _autoplay!.cancel();
      setState(() => _autoplay = null);
      return;
    }
    if (_index >= _stepCount) _go(0);
    setState(() {
      _autoplay = Timer.periodic(const Duration(milliseconds: 1100), (t) {
        if (_index >= _stepCount) {
          t.cancel();
          setState(() => _autoplay = null);
        } else {
          _go(_index + 1);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = widget.scheme;
    // The step that produced the current board (null at the start position).
    final step = _index == 0 ? null : _result.steps[_index - 1];
    // step.explanation is dynamically-composed solver prose — left in English
    // for now (see appstore/plan notes: localizing it means restructuring the
    // solver to emit structured reasoning data instead of pre-written text).
    final caption = step == null
        ? (_stepCount == 0
              ? l10n.explainNoStepsNeeded
              : l10n.explainStartingPosition(_stepCount))
        : step.explanation;
    final atEnd = _index >= _stepCount;
    final finishedNote = atEnd && _stepCount > 0
        ? (_result.solved
              ? l10n.explainSolvedNote(
                  _GameScreenState._techniqueLabel(context, _result.hardest),
                )
              : l10n.explainStuckNote)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.explainAppBarTitle),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: scheme.gradient,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  _index == 0
                      ? l10n.explainStart
                      : l10n.explainStepOf(_index, _stepCount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _ExplainGrid(
                        board: _boards[_index],
                        regions: widget.regions,
                        gridDim: widget.gridDim,
                        jigsaw: widget.jigsaw,
                        diagonal: widget.diagonal,
                        highlight: step?.cell,
                        eliminations: step?.eliminations ?? const [],
                        scheme: scheme,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (step != null)
                          Text(
                            _GameScreenState._techniqueLabel(
                              context,
                              step.technique,
                            ),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        Text(caption, textAlign: TextAlign.center),
                        if (finishedNote != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            finishedNote,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton.filled(
                      onPressed: _index > 0 ? () => _go(_index - 1) : null,
                      icon: const Icon(Icons.skip_previous),
                      tooltip: l10n.explainPreviousTooltip,
                    ),
                    IconButton.filled(
                      onPressed: _stepCount == 0 ? null : _toggleAutoplay,
                      icon: Icon(
                        _autoplay == null ? Icons.play_arrow : Icons.pause,
                      ),
                      tooltip: _autoplay == null
                          ? l10n.explainPlayTooltip
                          : l10n.explainPauseTooltip,
                    ),
                    IconButton.filled(
                      onPressed: _index < _stepCount
                          ? () => _go(_index + 1)
                          : null,
                      icon: const Icon(Icons.skip_next),
                      tooltip: l10n.explainNextTooltip,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Read-only Sudoku grid for the explain screen: values + a highlighted cell
/// and any eliminated-candidate cells, drawn over [SudokuGridPainter] lines.
class _ExplainGrid extends StatelessWidget {
  final List<List<int>> board;
  final List<List<int>> regions;
  final int gridDim;
  final bool jigsaw;
  final bool diagonal;
  final List<int>? highlight;
  final List<List<int>> eliminations;
  final EnvironmentalTheme scheme;

  const _ExplainGrid({
    required this.board,
    required this.regions,
    required this.gridDim,
    required this.jigsaw,
    required this.diagonal,
    required this.highlight,
    required this.eliminations,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final elimCells = {for (final e in eliminations) '${e[0]}-${e[1]}'};
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, border: Border.all()),
      child: Stack(
        children: [
          Column(
            children: [
              for (var r = 0; r < gridDim; r++)
                Expanded(
                  child: Row(
                    children: [
                      for (var c = 0; c < gridDim; c++)
                        Expanded(child: _cell(r, c, elimCells)),
                    ],
                  ),
                ),
            ],
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: SudokuGridPainter(gridDim, regions, jigsaw: jigsaw),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(int r, int c, Set<String> elimCells) {
    final isHighlight =
        highlight != null && highlight![0] == r && highlight![1] == c;
    final isElim = elimCells.contains('$r-$c');
    final onDiag = diagonal && (r == c || r + c == gridDim - 1);
    final v = board[r][c];
    return Container(
      alignment: Alignment.center,
      color: isHighlight
          ? scheme.accent
          : (isElim
                ? Colors.red.shade100
                : (onDiag ? const Color(0xFFEDE7F6) : Colors.transparent)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          v == 0 ? '' : '$v',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isHighlight ? Colors.black : Colors.black87,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid painter
// ---------------------------------------------------------------------------

/// Draws Killer cages: a dashed inset border along each cage boundary and the
/// cage sum in the top-left cell.
class KillerCagePainter extends CustomPainter {
  final List<KillerCage> cages;
  final int gridDim;

  KillerCagePainter(this.cages, this.gridDim);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / gridDim;
    const inset = 4.0;
    final paint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final cageOf = List.generate(gridDim, (_) => List.filled(gridDim, -1));
    for (var i = 0; i < cages.length; i++) {
      for (final c in cages[i].cells) {
        cageOf[c[0]][c[1]] = i;
      }
    }
    bool same(int r, int c, int idx) =>
        r >= 0 && r < gridDim && c >= 0 && c < gridDim && cageOf[r][c] == idx;

    for (var i = 0; i < cages.length; i++) {
      for (final pos in cages[i].cells) {
        final r = pos[0], c = pos[1];
        final left = c * cell + inset;
        final top = r * cell + inset;
        final right = (c + 1) * cell - inset;
        final bottom = (r + 1) * cell - inset;
        if (!same(r - 1, c, i)) {
          _dash(canvas, Offset(left, top), Offset(right, top), paint);
        }
        if (!same(r + 1, c, i)) {
          _dash(canvas, Offset(left, bottom), Offset(right, bottom), paint);
        }
        if (!same(r, c - 1, i)) {
          _dash(canvas, Offset(left, top), Offset(left, bottom), paint);
        }
        if (!same(r, c + 1, i)) {
          _dash(canvas, Offset(right, top), Offset(right, bottom), paint);
        }
      }
      final anchor = cages[i].labelCell;
      final tp = TextPainter(
        text: TextSpan(
          text: '${cages[i].sum}',
          style: TextStyle(
            fontSize: cell * 0.24,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(anchor[1] * cell + inset + 1, anchor[0] * cell + inset),
      );
    }
  }

  void _dash(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0, gap = 3.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final start = a + dir * d;
      final end = a + dir * math.min(d + dash, total);
      canvas.drawLine(start, end, paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant KillerCagePainter old) =>
      old.cages != cages || old.gridDim != gridDim;
}

class SudokuGridPainter extends CustomPainter {
  final int gridDim;
  final List<List<int>> regions;
  final bool jigsaw;

  SudokuGridPainter(this.gridDim, this.regions, {this.jigsaw = false});

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / gridDim;
    if (jigsaw) {
      _drawJigsawGrid(canvas, size, cellSize);
    } else {
      _drawStandardGrid(canvas, size, cellSize);
    }
  }

  void _drawStandardGrid(Canvas canvas, Size size, double cellSize) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;
    final thickPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3;

    final box = boxDimensionsFor(gridDim);
    final rowsPerBox = box[0];
    final colsPerBox = box[1];

    for (var i = 0; i <= gridDim; i++) {
      canvas.drawLine(
        Offset(i * cellSize, 0),
        Offset(i * cellSize, size.height),
        i % colsPerBox == 0 ? thickPaint : paint,
      );
      canvas.drawLine(
        Offset(0, i * cellSize),
        Offset(size.width, i * cellSize),
        i % rowsPerBox == 0 ? thickPaint : paint,
      );
    }
  }

  void _drawJigsawGrid(Canvas canvas, Size size, double cellSize) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var row = 0; row < gridDim; row++) {
      for (var col = 0; col < gridDim; col++) {
        final region = regions[row][col];
        final left = col * cellSize;
        final top = row * cellSize;
        final right = left + cellSize;
        final bottom = top + cellSize;

        if (row == 0 || regions[row - 1][col] != region) {
          canvas.drawLine(Offset(left, top), Offset(right, top), paint);
        }
        if (row == gridDim - 1 || regions[row + 1][col] != region) {
          canvas.drawLine(Offset(left, bottom), Offset(right, bottom), paint);
        }
        if (col == 0 || regions[row][col - 1] != region) {
          canvas.drawLine(Offset(left, top), Offset(left, bottom), paint);
        }
        if (col == gridDim - 1 || regions[row][col + 1] != region) {
          canvas.drawLine(Offset(right, top), Offset(right, bottom), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(SudokuGridPainter oldDelegate) =>
      oldDelegate.gridDim != gridDim ||
      oldDelegate.jigsaw != jigsaw ||
      !identical(oldDelegate.regions, regions);
}

// ---------------------------------------------------------------------------
// Puzzle cache + storage
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
      final List<dynamic> list = jsonDecode(data);
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

  Future<List<PuzzleBlueprint>> loadBlueprints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final contents = prefs.getString(_key);
      if (contents == null || contents.isEmpty) return [];
      final List<dynamic> jsonList = jsonDecode(contents);
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
      await prefs.setString(
        _key,
        jsonEncode(blueprints.map((bp) => bp.toJson()).toList()),
      );
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

// ---------------------------------------------------------------------------
// Admin (debug only): pre-generate puzzles into the cache
// ---------------------------------------------------------------------------

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isGenerating = false;
  int _generatedCount = 0;
  String _currentStatus = 'Idle. Ready to generate puzzles for the cache.';

  Future<void> _startGeneration() async {
    setState(() {
      _isGenerating = true;
      _generatedCount = 0;
    });

    final random = math.Random();
    while (_isGenerating) {
      final size = GridSize.values[random.nextInt(GridSize.values.length)];
      final shape = GridShape.values[random.nextInt(GridShape.values.length)];
      setState(
        () => _currentStatus =
            'Generating new blueprint for: ${size.name}-${shape.name}',
      );

      try {
        final solved = await SudokuGame.create(
          SudokuDifficulty.easy,
          size,
          shape,
          timeout: const Duration(seconds: 5),
        );
        await PuzzleCache().set(
          PuzzleBlueprint(
            solutionGrid: solved.solution,
            regions: solved.regions,
            gridSize: size,
            gridShape: shape,
          ),
        );
        setState(() => _generatedCount++);
      } catch (e) {
        DebugLogger.error(
          'Admin generator skipped ${size.name}-${shape.name}.',
        );
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    setState(() {
      _isGenerating = false;
      _currentStatus = 'Stopped. Generated $_generatedCount new blueprints.';
    });
  }

  void _stopGeneration() => setState(() => _isGenerating = false);

  @override
  void dispose() {
    _isGenerating = false; // stop the loop if the screen is closed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Puzzle Generator'),
        backgroundColor: Colors.grey.shade800,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Puzzle Cache Pre-Generator',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              const Text(
                'Puzzles Generated in this Session:',
                style: TextStyle(fontSize: 16),
              ),
              Text(
                '$_generatedCount',
                style: const TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 20),
              const Text('Status:', style: TextStyle(fontSize: 16)),
              Text(
                _currentStatus,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isGenerating ? _stopGeneration : _startGeneration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isGenerating ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 50,
                    vertical: 15,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text(
                  _isGenerating ? 'Stop Generation' : 'Start Generation',
                ),
              ),
              const SizedBox(height: 40),
              SwitchListTile(
                title: const Text('Load puzzles from storage'),
                subtitle: const Text(
                  'If off, puzzles are always generated on-the-fly.',
                ),
                value: GameStats.useSavedPuzzles,
                onChanged: (value) =>
                    setState(() => GameStats.useSavedPuzzles = value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
