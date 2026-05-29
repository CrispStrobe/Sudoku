import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sudoku_game.dart';

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
    return MaterialApp(
      title: 'Sudoku Master Pro',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: 'Roboto',
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
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
  static Set<String> unlockedAchievements = {};

  /// Admin panel + all-themes-unlocked only in debug builds.
  static const bool debugMode = kDebugMode;

  static bool useSavedPuzzles = true;

  static Set<String> unlockedThemes = debugMode
      ? {'Ocean', 'Forest', 'Space', 'Fire', 'Ice'}
      : {'Ocean'};

  static String currentTheme = 'Ocean';

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

  // --- Persistence ---------------------------------------------------------

  static final StatsService _store = StatsService();

  static Map<String, dynamic> toJson() => {
    'totalPuzzlesSolved': totalPuzzlesSolved,
    'totalHintsUsed': totalHintsUsed,
    'bestTimeMs': bestTime.inMilliseconds,
    'currentStreak': currentStreak,
    'unlockedAchievements': unlockedAchievements.toList(),
    'unlockedThemes': unlockedThemes.toList(),
    'currentTheme': currentTheme,
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
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
                          'SUDOKU\nMASTER',
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
                          'Puzzles Solved: ${GameStats.totalPuzzlesSolved} | '
                          'Streak: ${GameStats.currentStreak}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          scheme.description,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickButton(
                          'Themes',
                          Icons.palette,
                          _showThemes,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildQuickButton(
                          'Achievements',
                          Icons.emoji_events,
                          _showAchievements,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'GAME MODES',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildModeButton(
                    '🎯 CLASSIC MODE',
                    'Traditional Sudoku',
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
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.extension, size: 24),
                          SizedBox(width: 10),
                          Text(
                            '🧩 JIGSAW MODE',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (GameStats.debugMode)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.admin_panel_settings),
                      label: const Text('Admin Panel'),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
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
            const Text(
              'Classic Sudoku',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                    'SMALL',
                    Colors.green.shade500,
                  ),
                  _buildGridSizeCard(
                    GridSize.medium,
                    '6×6',
                    'MEDIUM',
                    Colors.blue.shade400,
                  ),
                  _buildGridSizeCard(
                    GridSize.large,
                    '8×8',
                    'LARGE',
                    Colors.orange.shade400,
                  ),
                  _buildGridSizeCard(
                    GridSize.standard,
                    '9×9',
                    'CLASSIC',
                    Colors.red.shade400,
                  ),
                  _buildGridSizeCard(
                    GridSize.big,
                    '10×10',
                    'BIG',
                    Colors.purple.shade400,
                  ),
                  _buildGridSizeCard(
                    GridSize.mega,
                    '12×12',
                    'MEGA',
                    Colors.red.shade600,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
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
            const Text(
              'Select Difficulty',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
                  'Jigsaw mode: Regions have irregular shapes!',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            _buildDifficultyOption(
              'EASY',
              Colors.green,
              SudokuDifficulty.easy,
              gridSize,
              gameMode,
              gridShape,
            ),
            _buildDifficultyOption(
              'MEDIUM',
              Colors.orange,
              SudokuDifficulty.medium,
              gridSize,
              gameMode,
              gridShape,
            ),
            _buildDifficultyOption(
              'HARD',
              Colors.red,
              SudokuDifficulty.hard,
              gridSize,
              gameMode,
              gridShape,
            ),
            _buildDifficultyOption(
              'EXPERT',
              Colors.purple,
              SudokuDifficulty.expert,
              gridSize,
              gameMode,
              gridShape,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyOption(
    String label,
    Color color,
    SudokuDifficulty difficulty,
    GridSize gridSize,
    GameMode gameMode,
    GridShape gridShape,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          _startGame(difficulty, gridSize, gridShape, gameMode);
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
    GameMode gameMode,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          difficulty: difficulty,
          gridSize: gridSize,
          gridShape: gridShape,
          gameMode: gameMode,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {}); // refresh stats shown on home
    });
  }

  void _showJigsawOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🧩 Jigsaw Sudoku',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Irregular shaped regions instead of squares! Each size has '
              'unique region shapes.',
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
                    '4×4 Jigsaw',
                    GridSize.small,
                    'Mini Challenge',
                  ),
                  _buildJigsawOption(
                    '6×6 Jigsaw',
                    GridSize.medium,
                    'Quick Puzzle',
                  ),
                  _buildJigsawOption(
                    '8×8 Jigsaw',
                    GridSize.large,
                    'Brain Teaser',
                  ),
                  _buildJigsawOption(
                    '9×9 Jigsaw',
                    GridSize.standard,
                    'Classic Twist',
                  ),
                  _buildJigsawOption(
                    '10×10 Jigsaw',
                    GridSize.big,
                    'Big Challenge',
                  ),
                  _buildJigsawOption(
                    '12×12 Jigsaw',
                    GridSize.mega,
                    'Ultimate Test',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Environmental Themes',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                                          theme.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        Text(
                                          theme.description,
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
      ),
    );
  }

  void _showAchievements() {
    AchievementSystem.checkAchievements();
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
            const Text(
              'Achievements',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                        achievement.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isUnlocked ? Colors.black : Colors.grey,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(achievement.description),
                          if (achievement.rewardTheme != null)
                            Text(
                              'Reward: ${achievement.rewardTheme} theme',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      trailing: isUnlocked
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.lock, color: Colors.grey),
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
}

// ---------------------------------------------------------------------------
// Game screen
// ---------------------------------------------------------------------------

class GameScreen extends StatefulWidget {
  final SudokuDifficulty difficulty;
  final GridSize gridSize;
  final GridShape gridShape;
  final GameMode gameMode;

  const GameScreen({
    super.key,
    required this.difficulty,
    required this.gridSize,
    required this.gridShape,
    required this.gameMode,
  });

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
  bool _notesMode = false;

  Timer? _gameTimer;
  final ValueNotifier<Duration> _elapsed = ValueNotifier(Duration.zero);
  DateTime? _startTime;

  String? _errorMessage;

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

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_errorMessage != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_errorMessage!)));
          _errorMessage = null;
        }
      });
    }
  }

  Future<SudokuGame> _generatePuzzleWithRetries() async {
    const totalBudget = Duration(seconds: 10);
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
          timeout: const Duration(seconds: 4),
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
      if (GameStats.useSavedPuzzles) {
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
        if (GameStats.useSavedPuzzles) {
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
      if (mounted) setState(() {});
    } catch (e, st) {
      DebugLogger.error('Generation failed; falling back to classic.', e, st);
      try {
        game = await SudokuGame.create(
          widget.difficulty,
          widget.gridSize,
          GridShape.classic,
        );
        _startGameTimer();
        score = _calculateInitialScore();
        if (mounted) setState(() {});
      } catch (e2, st2) {
        DebugLogger.error('Fallback also failed.', e2, st2);
        if (mounted) {
          setState(
            () => _errorMessage = 'Failed to create puzzle. Please restart.',
          );
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
    final wasValid = g.isValidMove(row, col, number);
    setState(() => g.setCell(row, col, number));
    if (!wasValid) {
      _shakeController.forward().then((_) => _shakeController.reverse());
      setState(() => score = math.max(0, score - 25));
    }
    if (g.isSolved()) _completeGame();
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
    if (selectedRow != null && selectedCol != null && game != null) {
      _showHintDialog();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a cell first!')));
    }
  }

  void _showHintDialog() {
    final hints = game!.getSmartHints(selectedRow!, selectedCol!);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lightbulb, color: Colors.orange),
            SizedBox(width: 10),
            Text('Smart Hints'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: hints
              .map(
                (hint) => Card(
                  child: ListTile(
                    title: Text(hint.title),
                    subtitle: Text(hint.description),
                    trailing: Text(
                      hint.penalty > 0 ? '-${hint.penalty}' : '',
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
              )
              .toList(),
        ),
      ),
    );
  }

  void _showHintConfirmation(SmartHint hint) {
    if (hint.penalty == 0) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(hint.title),
        content: Text('Use this hint for a -${hint.penalty} score penalty?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Confirm'),
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
    final g = game;
    if (g == null) return;
    setState(() {
      score = math.max(0, score - hint.penalty);
      hintsUsed++;
      GameStats.totalHintsUsed++;
      switch (hint.type) {
        case HintType.showPossible:
          final numbers = (hint.data as List<int>).join(', ');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Possible Numbers: $numbers')));
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
    if (g.isSolved()) _completeGame();
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
    if (hintsUsed == 0 && widget.difficulty == SudokuDifficulty.hard) {
      GameStats.unlockedAchievements.add('no_hints_hard');
    }
    AchievementSystem.checkAchievements();
    GameStats.save(); // persist solved count, streak, best time, unlocks

    setState(() => score = finalScore);
    _particleKey.currentState?.burst();
    _showCompletionDialog(finalScore, completionTime, timeBonus);
  }

  void _showCompletionDialog(int finalScore, Duration time, int timeBonus) {
    final scheme = GameStats.current;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '🎉 Completed!',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, color: scheme.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Score: $finalScore',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text('Time: ${_formatDuration(time)}  •  Bonus: +$timeBonus'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _goToMainMenu();
            },
            child: const Text('Main Menu'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _startNextLevel();
            },
            child: const Text('Next Puzzle'),
          ),
        ],
      ),
    );
  }

  void _startNextLevel() {
    setState(() {
      selectedRow = null;
      selectedCol = null;
      hintsUsed = 0;
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
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 20),
                Text(
                  'Generating puzzle...',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
            tooltip: 'Main Menu',
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                'Score: $score',
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

  Widget _buildControls(EnvironmentalTheme scheme) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _showHint,
            icon: const Icon(Icons.lightbulb),
            label: const Text('Hint'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _circleButton(
          icon: Icons.edit,
          tooltip: 'Notes mode',
          active: _notesMode,
          activeColor: scheme.primary,
          onPressed: _toggleNotesMode,
        ),
        const SizedBox(width: 8),
        _circleButton(
          icon: Icons.undo,
          tooltip: 'Undo',
          onPressed: (game?.canUndo ?? false) ? _undo : null,
        ),
        const SizedBox(width: 8),
        _circleButton(
          icon: Icons.clear,
          tooltip: 'Erase',
          activeColor: Colors.red,
          active: true,
          onPressed: _clearCell,
        ),
      ],
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
    final gridPixels = math.min(
      maxGridSize,
      MediaQuery.of(context).size.width - 32,
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
          ],
        ),
      ),
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
    final conflict = g.hasConflict(row, col);

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
    final buttonSize = isTablet ? 50.0 : 40.0;
    final fontSize = isTablet ? 20.0 : 16.0;
    final maxNumber = game!.gridDim;
    final primary = GameStats.current.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: math.min(6, maxNumber),
          childAspectRatio: 1,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: maxNumber,
        itemBuilder: (context, index) {
          final number = index + 1;
          return Draggable<int>(
            data: number,
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
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Grid painter
// ---------------------------------------------------------------------------

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

  final Map<String, List<PuzzleBlueprint>> _cache = {};
  final StorageService _storage = StorageService();
  final math.Random _random = math.Random();

  Future<void> initialize() async {
    final blueprints = await _storage.loadBlueprints();
    for (final bp in blueprints) {
      _cache.putIfAbsent(_key(bp.gridSize, bp.gridShape), () => []).add(bp);
    }
    DebugLogger.log('Puzzle cache initialized: ${_cache.length} types.');
  }

  String _key(GridSize size, GridShape shape) => '${size.name}-${shape.name}';

  PuzzleBlueprint? getRandom(GridSize size, GridShape shape) {
    final list = _cache[_key(size, shape)];
    if (list == null || list.isEmpty) return null;
    return list[_random.nextInt(list.length)];
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
