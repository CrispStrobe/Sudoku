import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'dart:async';

void main() {
  runApp(SudokuApp());
}

class PuzzleBlueprint {
  final List<List<int>> solutionGrid;
  final List<List<int>> regions;
  final GridSize gridSize;
  final GridShape gridShape;

  PuzzleBlueprint({
    required this.solutionGrid,
    required this.regions,
    required this.gridSize,
    required this.gridShape,
  });
}

class SudokuApp extends StatelessWidget {
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
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

enum GridSize { small, medium, large, standard, big, mega }
enum SudokuDifficulty { easy, medium, hard, expert }
enum GridShape { classic, jigsaw }
enum GameMode { classic }
enum HintType { showPossible, giveAnswer, nakedSingle, hiddenSingle, conflict }

class EnvironmentalTheme {
  final String name;
  final List<Color> gradient;
  final Color primary;
  final Color accent;
  final Color cellHighlight;
  final List<String> particleEmojis;
  final String description;
  
  EnvironmentalTheme({
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
  static Duration bestTime = Duration(hours: 99);
  static int currentStreak = 0;
  static Set<String> unlockedAchievements = {};
  
  static bool debugMode = true; // Set to false for production
  
  // Modify the themes initialization
  static Set<String> unlockedThemes = debugMode 
    ? {'Ocean', 'Forest', 'Space', 'Fire', 'Ice'} // All themes unlocked in debug
    : {'Ocean'}; // Only Ocean in production
  
  static String currentTheme = 'Ocean';
  
  static Map<String, EnvironmentalTheme> themes = {
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
}

class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool Function() isUnlocked;
  final String? rewardTheme;
  
  Achievement({
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
      isUnlocked: () => GameStats.unlockedAchievements.contains('no_hints_hard'),
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
    for (var achievement in achievements) {
      if (!GameStats.unlockedAchievements.contains(achievement.id) && achievement.isUnlocked()) {
        GameStats.unlockedAchievements.add(achievement.id);
        if (achievement.rewardTheme != null) {
          GameStats.unlockedThemes.add(achievement.rewardTheme!);
        }
      }
    }
  }
}

class DebugLogger {
  static void log(String message) {
    print('[SUDOKU DEBUG] $message');
  }
  
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    print('[SUDOKU ERROR] $message');
    if (error != null) print('Error: $error');
    if (stackTrace != null) print('Stack: $stackTrace');
  }
}

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

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final currentScheme = GameStats.themes[GameStats.currentTheme]!;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: currentScheme.gradient,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
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
                        SizedBox(height: 10),
                        Text(
                          'Puzzles Solved: ${GameStats.totalPuzzlesSolved} | Streak: ${GameStats.currentStreak}',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        SizedBox(height: 5),
                        Text(
                          currentScheme.description,
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 30),
                  
                  // Quick Actions
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickButton(
                          'Themes',
                          Icons.palette,
                          () => _showThemes(),
                        ),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: _buildQuickButton(
                          'Achievements',
                          Icons.emoji_events,
                          () => _showAchievements(),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: 30),
                  
                  // Game Modes
                  Text(
                    'GAME MODES',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  _buildModeButton('🎯 CLASSIC MODE', 'Traditional Sudoku', Colors.indigo.shade800, () => _showClassicOptions()),
                  
                  SizedBox(height: 30),
                  
                  // Jigsaw Mode
                  Container(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () => _showJigsawOptions(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        foregroundColor: Colors.white,
                        elevation: 12,
                      ),
                      child: Row(
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

                  SizedBox(height: 30),

                  if (GameStats.debugMode)
                    ElevatedButton.icon(
                      icon: Icon(Icons.admin_panel_settings),
                      label: Text('Admin Panel'),
                      onPressed: _navigateToAdmin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade700,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
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

  Widget _buildQuickButton(String label, IconData icon, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.2),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 15),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 24),
          SizedBox(height: 5),
          Text(label, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildModeButton(String title, String subtitle, Color color, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      height: 70,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 12,
          shadowColor: color.withOpacity(0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white70,
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
      MaterialPageRoute(builder: (context) => AdminScreen()),
    );
  }

  void _showClassicOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Classic Sudoku',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  _buildGridSizeCard(GridSize.small, '4×4', 'SMALL', Colors.green.shade500),
                  _buildGridSizeCard(GridSize.medium, '6×6', 'MEDIUM', Colors.blue.shade400),
                  _buildGridSizeCard(GridSize.large, '8×8', 'LARGE', Colors.orange.shade400),
                  _buildGridSizeCard(GridSize.standard, '9×9', 'CLASSIC', Colors.red.shade400),
                  _buildGridSizeCard(GridSize.big, '10×10', 'BIG', Colors.purple.shade400),
                  _buildGridSizeCard(GridSize.mega, '12×12', 'MEGA', Colors.red.shade600),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridSizeCard(GridSize size, String sizeLabel, String difficulty, Color color) {
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
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              sizeLabel,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 5),
            Text(
              difficulty,
              style: TextStyle(
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

  void _showDifficultySelection(GridSize gridSize, GameMode gameMode, {GridShape gridShape = GridShape.classic}) {
    DebugLogger.log('Showing difficulty selection for ${gridSize.name} ${gridShape.name}');
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select Difficulty',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (gridShape == GridShape.jigsaw)
              Container(
                margin: EdgeInsets.only(top: 10),
                padding: EdgeInsets.all(8),
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
            SizedBox(height: 20),
            ...[
              _buildDifficultyOption('EASY', Colors.green, SudokuDifficulty.easy, gridSize, gameMode, gridShape),
              _buildDifficultyOption('MEDIUM', Colors.orange, SudokuDifficulty.medium, gridSize, gameMode, gridShape),
              _buildDifficultyOption('HARD', Colors.red, SudokuDifficulty.hard, gridSize, gameMode, gridShape),
              _buildDifficultyOption('EXPERT', Colors.purple, SudokuDifficulty.expert, gridSize, gameMode, gridShape),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildDifficultyOption(String label, Color color, SudokuDifficulty difficulty, GridSize gridSize, GameMode gameMode, GridShape gridShape) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10),
      child: ElevatedButton(
        onPressed: () {
          DebugLogger.log('Selected: ${gridSize.name} ${difficulty.name} ${gridShape.name}');
          Navigator.pop(context);
          _startGame(difficulty, gridSize, gridShape, gameMode);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 15),
        ),
        child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _startGame(SudokuDifficulty difficulty, GridSize gridSize, GridShape gridShape, GameMode gameMode) {
    try {
      DebugLogger.log('Starting game: ${gridSize.name} ${difficulty.name} ${gridShape.name} ${gameMode.name}');
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
      );
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to start game', e, stackTrace);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start game. Please try again.')),
      );
    }
  }

  void _showJigsawOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🧩 Jigsaw Sudoku',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Irregular shaped regions instead of squares! Each size has unique region shapes.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (GameStats.debugMode)
              Container(
                margin: EdgeInsets.symmetric(vertical: 10),
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'DEBUG MODE: All sizes available & verbose logging enabled',
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 12),
                ),
              ),
            SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                childAspectRatio: 1.8,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildJigsawOption('4×4 Jigsaw', GridSize.small, 'Mini Challenge'),
                  _buildJigsawOption('6×6 Jigsaw', GridSize.medium, 'Quick Puzzle'),
                  _buildJigsawOption('8×8 Jigsaw', GridSize.large, 'Brain Teaser'),
                  _buildJigsawOption('9×9 Jigsaw', GridSize.standard, 'Classic Twist'),
                  _buildJigsawOption('10×10 Jigsaw', GridSize.big, 'Big Challenge'),
                  _buildJigsawOption('12×12 Jigsaw', GridSize.mega, 'Ultimate Test'),
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
        _showDifficultySelection(gridSize, GameMode.classic, gridShape: GridShape.jigsaw);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange.shade600, Colors.orange.shade800],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.3),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white70,
                ),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Environmental Themes',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  childAspectRatio: 4,
                  mainAxisSpacing: 10,
                ),
                itemCount: GameStats.themes.length,
                itemBuilder: (context, index) {
                  final theme = GameStats.themes.values.elementAt(index);
                  final isUnlocked = GameStats.unlockedThemes.contains(theme.name);
                  final isSelected = GameStats.currentTheme == theme.name;
                  
                  return GestureDetector(
                    onTap: isUnlocked ? () {
                      setState(() {
                        GameStats.currentTheme = theme.name;
                      });
                      Navigator.pop(context);
                    } : null,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: theme.gradient),
                        borderRadius: BorderRadius.circular(15),
                        border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          theme.name,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        Text(
                                          theme.description,
                                          style: TextStyle(
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
                                      style: TextStyle(fontSize: 24),
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
                              child: Center(
                                child: Icon(Icons.lock, color: Colors.white, size: 32),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Achievements',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: AchievementSystem.achievements.length,
                itemBuilder: (context, index) {
                  final achievement = AchievementSystem.achievements[index];
                  final isUnlocked = GameStats.unlockedAchievements.contains(achievement.id);
                  
                  return Card(
                    margin: EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Text(
                        achievement.icon,
                        style: TextStyle(fontSize: 30),
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
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                        ],
                      ),
                      trailing: isUnlocked 
                          ? Icon(Icons.check_circle, color: Colors.green)
                          : Icon(Icons.lock, color: Colors.grey),
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

class GameScreen extends StatefulWidget {
  final SudokuDifficulty difficulty;
  final GridSize gridSize;
  final GridShape gridShape;
  final GameMode gameMode;

  GameScreen({
    required this.difficulty,
    required this.gridSize,
    required this.gridShape,
    required this.gameMode,
  });

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  SudokuGame? game; // Primary game - nullable until initialized
  int? selectedRow;
  int? selectedCol;
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late AnimationController _scoreController;
  late AnimationController _particleController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<Offset> _scoreAnimation;
  List<Particle> particles = [];
  int hintsUsed = 0;
  int score = 1000;
  bool _showingScore = false;
  Timer? _nextGameTimer;
  String? _errorMessage; // For delayed error display
  
  @override
  void initState() {
    super.initState();
    DebugLogger.log('Initializing game screen');
    _initializeAnimations();
    _startParticleSystem();
    // Delay game initialization to avoid ScaffoldMessenger issues
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGame();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Show any delayed error messages here where context is safe
    if (_errorMessage != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_errorMessage!)),
          );
          _errorMessage = null;
        }
      });
    }
  }

  void _applyHint(SmartHint hint) {
    setState(() {
      score = math.max(0, score - hint.penalty);
      hintsUsed++;
      GameStats.totalHintsUsed++;

      switch (hint.type) {
        case HintType.showPossible:
          final numbers = (hint.data as List<int>).join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Possible Numbers: $numbers')),
          );
          break;
        case HintType.giveAnswer:
        case HintType.nakedSingle:
        case HintType.hiddenSingle:
          // THE FIX IS HERE: We now correctly call the method on the 'game' object.
          game!.setCell(selectedRow!, selectedCol!, hint.data as int);
          break;
        default:
          break;
      }
    });

    if (game!.isCompleted()) {
      _completeGame();
    }
  }

  void _showHintConfirmation(SmartHint hint) {
    if (hint.penalty == 0) return; // Don't show confirmation for informational hints

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(hint.title),
        content: Text('Are you sure you want to use this hint for a -${hint.penalty} score penalty?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Confirm'),
            onPressed: () {
              Navigator.pop(context); // Close the confirmation dialog
              _applyHint(hint); // Apply the hint
            },
          ),
        ],
      ),
    );
  }

  Future<SudokuGame> _generatePuzzleWithRetries({
    required SudokuDifficulty difficulty,
    required GridSize gridSize,
    required GridShape gridShape,
  }) async {
    final totalTimeBudget = const Duration(seconds: 10);
    final singleAttemptTimeout = const Duration(seconds: 3);
    final stopwatch = Stopwatch()..start();
    int attempt = 0;

    DebugLogger.log('--- STARTING ROBUST GENERATION with a ${totalTimeBudget.inSeconds}s total budget ---');

    while (stopwatch.elapsed < totalTimeBudget) {
      attempt++;
      final timeRemaining = (totalTimeBudget - stopwatch.elapsed).inSeconds;
      DebugLogger.log('--- Generation attempt $attempt. Time remaining: $timeRemaining seconds. ---');
      
      try {
        // Try to create a puzzle within the individual attempt timeout.
        final game = await SudokuGame.create(difficulty, gridSize, gridShape)
            .timeout(singleAttemptTimeout);
        
        stopwatch.stop();
        DebugLogger.log('--- SUCCESS! Puzzle generated after ${stopwatch.elapsed.inSeconds}s on attempt $attempt. ---');
        return game; // Success! Return the generated game.
      } catch (e) {
        // This attempt failed (likely timed out). Log it and the loop will try again.
        DebugLogger.log('Attempt $attempt failed. Trying again...');
      }
    }

    // If the while loop finishes, it means the total time budget was exceeded.
    stopwatch.stop();
    throw TimeoutException('Failed to generate a puzzle within the total ${totalTimeBudget.inSeconds}s budget.');
  }

  void _initializeGame() async {
    try {
      // Immediately show a loading state to the user.
      setState(() {
        game = null; // Ensure the loading indicator is shown
      });

      // Step 1: Try to load from the cache first.
      final blueprint = PuzzleCache().get(widget.gridSize, widget.gridShape);

      if (blueprint != null) {
        game = SudokuGame.fromBlueprint(blueprint, widget.difficulty);
      } else {
        // Step 2: If cache misses, use our new robust generator.
        DebugLogger.log('No blueprint found. Generating puzzle on the fly...');
        game = await _generatePuzzleWithRetries(
          difficulty: widget.difficulty,
          gridSize: widget.gridSize,
          gridShape: widget.gridShape,
        );
        
        // Step 3: If generation was successful, create and save its blueprint.
        final newBlueprint = PuzzleBlueprint(
          solutionGrid: game!.solution,
          regions: game!.regions,
          gridSize: widget.gridSize,
          gridShape: widget.gridShape,
        );
        PuzzleCache().set(newBlueprint);
      }
      
      // Step 4: Start the timer and update the UI.
      game!.startTimer();
      score = _calculateInitialScore();

      if (mounted) {
        setState(() {});
        DebugLogger.log('Game initialized successfully with score: $score');
      }
    } catch (e, stackTrace) {
      // This block now only runs if the entire 10-second process fails.
      DebugLogger.error('All generation attempts failed within the time budget.', e, stackTrace);
      
      try {
        DebugLogger.log('Attempting fallback initialization to a standard puzzle.');
        game = await SudokuGame.create(widget.difficulty, widget.gridSize, GridShape.classic);
        game!.startTimer();
        score = _calculateInitialScore();
        if (mounted) {
          setState(() {});
          DebugLogger.log('Fallback initialization successful');
        }
      } catch (e2, stackTrace2) {
        DebugLogger.error('FATAL: Fallback initialization also failed.', e2, stackTrace2);
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to create puzzle. Please restart the app.';
          });
        }
      }
    }
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    
    _shakeController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _scoreController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: Duration(milliseconds: 16),
      vsync: this,
    )..repeat();
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _scoreAnimation = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(0, -0.5),
    ).animate(CurvedAnimation(parent: _scoreController, curve: Curves.easeOut));

    _particleController.addListener(() {
      setState(() {
        particles.removeWhere((p) => p.isDead);
        for (var particle in particles) {
          particle.update();
        }
      });
    });
  }

  void _startParticleSystem() {
    Timer.periodic(Duration(milliseconds: 2000), (timer) {
      if (mounted) {
        _addRandomParticle();
      } else {
        timer.cancel();
      }
    });
  }

  void _addRandomParticle() {
    final currentTheme = GameStats.themes[GameStats.currentTheme]!;
    final random = math.Random();
    
    particles.add(Particle(
      x: random.nextDouble() * MediaQuery.of(context).size.width,
      y: MediaQuery.of(context).size.height,
      vx: (random.nextDouble() - 0.5) * 2,
      vy: -random.nextDouble() * 3 - 1,
      emoji: currentTheme.particleEmojis[random.nextInt(currentTheme.particleEmojis.length)],
      maxLife: 180.0,
    ));
  }

  void _addCompletionParticles() {
    final currentTheme = GameStats.themes[GameStats.currentTheme]!;
    final random = math.Random();
    
    for (int i = 0; i < 20; i++) {
      particles.add(Particle(
        x: MediaQuery.of(context).size.width / 2,
        y: MediaQuery.of(context).size.height / 2,
        vx: (random.nextDouble() - 0.5) * 8,
        vy: -random.nextDouble() * 6 - 2,
        emoji: currentTheme.particleEmojis[random.nextInt(currentTheme.particleEmojis.length)],
        maxLife: 120.0,
      ));
    }
  }

  int _calculateInitialScore() {
    int base = 500;
    
    // Grid size multiplier
    switch (widget.gridSize) {
      case GridSize.small: base += 200; break;
      case GridSize.medium: base += 400; break;
      case GridSize.large: base += 600; break;
      case GridSize.standard: base += 800; break;
      case GridSize.big: base += 1000; break;
      case GridSize.mega: base += 1200; break;
    }
    
    // Difficulty multiplier
    switch (widget.difficulty) {
      case SudokuDifficulty.easy: base += 100; break;
      case SudokuDifficulty.medium: base += 300; break;
      case SudokuDifficulty.hard: base += 500; break;
      case SudokuDifficulty.expert: base += 800; break;
    }
    
    // Mode bonuses
    if (widget.gridShape == GridShape.jigsaw) base += 200;
    
    return base;
  }

  @override
  void dispose() {
    _nextGameTimer?.cancel();
    _pulseController.dispose();
    _shakeController.dispose();
    _scoreController.dispose();
    _particleController.dispose();
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

  void _inputNumber(int number) {
    if (selectedRow != null && selectedCol != null) {
      _placeNumber(selectedRow!, selectedCol!, number);
    }
  }

  void _placeNumberAt(int row, int col, int number) {
    _placeNumber(row, col, number);
  }

  void _placeNumber(int row, int col, int number) {
    if (game == null) return;

    if (game!.isValidMove(row, col, number)) {
      setState(() {
        game!.setCell(row, col, number);
      });

      if (_isGameCompleted()) {
        _completeGame();
      }
    } else {
      _shakeController.forward().then((_) => _shakeController.reverse());
      setState(() {
        score = math.max(0, score - 25); // Penalty for wrong move
      });
    }
  }

  bool _isGameCompleted() {
    return game?.isCompleted() ?? false;
  }

  void _clearCell() {
    if (selectedRow != null && selectedCol != null) {
      setState(() {
        game?.clearCell(selectedRow!, selectedCol!);
      });
    }
  }

  void _showHint() {
    if (selectedRow != null && selectedCol != null && game != null) {
      _showHintDialog();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Select a cell first!')),
      );
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
          children: hints.map((hint) => Card(
            child: ListTile(
              title: Text(hint.title),
              subtitle: Text(hint.description),
              trailing: Text(
                hint.penalty > 0 ? '-${hint.penalty}' : '',
                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              onTap: () {
                Navigator.pop(context); // Close this dialog
                _showHintConfirmation(hint); // Open the confirmation dialog
              },
            ),
          )).toList(),
        ),
      ),
    );
  }

  void _completeGame() {
    if (game == null) return;
    
    final completionTime = DateTime.now().difference(game!.startTime);
    final timeBonus = math.max(0, 300 - completionTime.inSeconds ~/ 2);
    final finalScore = score + timeBonus;
    
    DebugLogger.log('Game completed! Score: $finalScore, Time: ${game!.getFormattedTime()}');
    
    // Update statistics
    GameStats.totalPuzzlesSolved++;
    if (completionTime < GameStats.bestTime) {
      GameStats.bestTime = completionTime;
    }
    GameStats.currentStreak++;
    
    // Check for special achievements
    if (hintsUsed == 0 && widget.difficulty == SudokuDifficulty.hard) {
      GameStats.unlockedAchievements.add('no_hints_hard');
    }
    
    AchievementSystem.checkAchievements();
    
    // Add completion particles
    _addCompletionParticles();
    
    // Show floating score instead of modal
    _showFloatingScore(finalScore, completionTime, timeBonus);
    
    // Auto-advance to next level after 3 seconds
    _nextGameTimer = Timer(Duration(seconds: 3), () {
      if (mounted) {
        _startNextLevel();
      }
    });
  }

  void _showFloatingScore(int finalScore, Duration completionTime, int timeBonus) {
    setState(() {
      _showingScore = true;
    });
    
    _scoreController.forward().then((_) {
      Timer(Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _showingScore = false;
          });
          _scoreController.reset();
        }
      });
    });
  }

  void _startNextLevel() {
    DebugLogger.log('Starting next level');
    try {
      _initializeGame();
      setState(() {
        selectedRow = null;
        selectedCol = null;
        hintsUsed = 0;
        _showingScore = false;
        particles.clear();
      });
      _scoreController.reset();
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to start next level', e, stackTrace);
      _errorMessage = 'Failed to generate next puzzle. Please try again.';
    }
  }

  void _goToMainMenu() {
    _nextGameTimer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen if game is not initialized yet
    if (game == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: GameStats.themes[GameStats.currentTheme]!.gradient,
            ),
          ),
          child: Center(
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
    final currentScheme = GameStats.themes[GameStats.currentTheme]!;
    
    return Scaffold(
      appBar: AppBar(
        // title: Text('${widget.gridSize.name.toUpperCase()} ${widget.gameMode.name.toUpperCase()}'),
        title: Text('${widget.gridSize.name.toUpperCase()} ${widget.gridShape.name.toUpperCase()}'),

        backgroundColor: currentScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          
          IconButton(
            onPressed: _goToMainMenu,
            icon: Icon(Icons.home),
            tooltip: 'Main Menu',
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text(
                'Score: $score',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.only(right: 16),
              child: StreamBuilder<String>(
                stream: game!.timeStream,
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? '00:00',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  );
                },
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
            colors: currentScheme.gradient,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Particle background
              ...particles.map((particle) => Positioned(
                left: particle.x,
                top: particle.y,
                child: Opacity(
                  opacity: particle.opacity * 0.7,
                  child: Text(
                    particle.emoji,
                    style: TextStyle(fontSize: 20),
                  ),
                ),
              )),
              
              Padding(
                padding: EdgeInsets.all(isTablet ? 24 : 16),
                child: Column(
                  children: [
                    
                    Expanded(
                      flex: isTablet ? 3 : 2,
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _shakeAnimation,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(_shakeAnimation.value, 0),
                              child: _buildSudokuGrid(isTablet, currentScheme),
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _showHint,
                            icon: Icon(Icons.lightbulb),
                            label: Text('Smart Hint'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: _clearCell,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                          ),
                          child: Icon(Icons.clear),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      flex: 1,
                      child: _buildNumberPad(isTablet),
                    ),
                  ],
                ),
              ),
              // Floating score display
              if (_showingScore)
                AnimatedBuilder(
                  animation: _scoreAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        0,
                        _scoreAnimation.value.dy * MediaQuery.of(context).size.height,
                      ),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '🎉 COMPLETED!',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: currentScheme.primary,
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Score: $score',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Time: ${game!.getFormattedTime()}',
                                style: TextStyle(fontSize: 16),
                              ),
                              
                              SizedBox(height: 10),
                              Text(
                                'Next puzzle in 3s...',
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSudokuGrid(bool isTablet, EnvironmentalTheme colorScheme) {
    final gridDim = game!.gridDim;
    final maxGridSize = isTablet ? 450.0 : 320.0;
    final gridSize = math.min(maxGridSize, MediaQuery.of(context).size.width - 32);
    final cellSize = gridSize / gridDim;
    
    return Container(
      width: gridSize,
      height: gridSize,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Grid lines
            CustomPaint(
              size: Size(gridSize, gridSize),
              painter: SudokuGridPainter(game!.gridDim, game!.regions),
            ),
            // Cells
            for (int row = 0; row < gridDim; row++)
              for (int col = 0; col < gridDim; col++)
                Positioned(
                  left: (col * cellSize).toDouble(),
                  top: (row * cellSize).toDouble(),
                  width: cellSize,
                  height: cellSize,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      final isSelected = selectedRow == row && selectedCol == col;
                      return Transform.scale(
                        scale: isSelected ? _pulseAnimation.value : 1.0,
                        child: DragTarget<int>(
                          onAccept: (number) {
                            _placeNumberAt(row, col, number);
                          },
                          onWillAccept: (number) => number != null,
                          builder: (context, candidateData, rejectedData) {
                            final isHovered = candidateData.isNotEmpty;
                            return GestureDetector(
                              onTap: () => _selectCell(row, col),
                              child: Container(
                                margin: EdgeInsets.all(0.5),
                                decoration: BoxDecoration(
                                  color: isHovered 
                                      ? colorScheme.accent.withOpacity(0.7)
                                      : _getCellColor(row, col, colorScheme),
                                  border: Border.all(
                                    color: isSelected 
                                        ? colorScheme.primary
                                        : (isHovered ? colorScheme.primary.withOpacity(0.5) : Colors.transparent),
                                    width: isSelected ? 3 : (isHovered ? 2 : 0),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    game!.grid[row][col] == 0 ? '' : '${game!.grid[row][col]}',
                                    style: TextStyle(
                                      fontSize: isTablet ? 28 : 20,
                                      fontWeight: game!.isOriginal[row][col] 
                                          ? FontWeight.bold 
                                          : FontWeight.w500,
                                      color: game!.isOriginal[row][col] 
                                          ? Colors.black 
                                          : colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
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

  Color _getCellColor(int row, int col, EnvironmentalTheme colorScheme) {
    if (selectedRow == row && selectedCol == col) {
      return colorScheme.accent;
    }
    if (selectedRow == row || selectedCol == col) {
      return Colors.grey.shade200;
    }
    
    if (widget.gridShape == GridShape.jigsaw) {
      // Color jigsaw regions differently
      final regionId = game!.regions[row][col];
      final colors = [
        Colors.grey.shade50,
        Colors.blue.shade50,
        Colors.green.shade50,
        Colors.orange.shade50,
        Colors.purple.shade50,
        Colors.red.shade50,
      ];
      return colors[regionId % colors.length];
    } else {
      // Standard box coloring - use region ID for alternating colors
      final regionId = game!.regions[row][col];
      if (regionId % 2 == 0) {
        return colorScheme.cellHighlight;
      }
    }
    return Colors.white;
  }

  Widget _buildNumberPad(bool isTablet) {
    final buttonSize = isTablet ? 50.0 : 40.0;
    final fontSize = isTablet ? 20.0 : 16.0;
    final maxNumber = game!.gridDim;
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
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
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: GameStats.themes[GameStats.currentTheme]!.primary,
                  ),
                ),
              ),
            ),
            childWhenDragging: Container(
              child: ElevatedButton(
                onPressed: null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.5),
                  foregroundColor: GameStats.themes[GameStats.currentTheme]!.primary.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            ),
            child: Container(
              child: ElevatedButton(
                onPressed: () => _inputNumber(number),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: GameStats.themes[GameStats.currentTheme]!.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
            ),
          );
        },
      ),
    );
  }
}

class BoundaryCell {
  final int row;
  final int col;
  final int currentRegion;
  final int neighborRegion;
  final List<int> direction;
  
  BoundaryCell({
    required this.row,
    required this.col,
    required this.currentRegion,
    required this.neighborRegion,
    required this.direction,
  });
}

class PuzzleCache {
  static final PuzzleCache _instance = PuzzleCache._internal();
  factory PuzzleCache() => _instance;
  PuzzleCache._internal();

  final Map<String, PuzzleBlueprint> _cache = {};

  String _getKey(GridSize size, GridShape shape) {
    return '${size.name}-${shape.name}';
  }

  PuzzleBlueprint? get(GridSize size, GridShape shape) {
    final key = _getKey(size, shape);
    if (_cache.containsKey(key)) {
      DebugLogger.log('--- Blueprint found in CACHE! ---');
      return _cache[key];
    }
    return null;
  }

  void set(PuzzleBlueprint blueprint) {
    final key = _getKey(blueprint.gridSize, blueprint.gridShape);
    DebugLogger.log('--- Saving blueprint to CACHE for $key. ---');
    _cache[key] = blueprint;
  }
}

class SudokuGridPainter extends CustomPainter {
  final int gridDim;
  final List<List<int>>? regions;
  
  SudokuGridPainter(this.gridDim, [this.regions]);

  @override
  void paint(Canvas canvas, Size size) {
    try {
      final paint = Paint()
        ..color = Colors.black
        ..strokeWidth = 1;

      final thickPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 3;

      final cellSize = size.width / gridDim;

      if (regions != null) {
        // Draw jigsaw regions
        _drawJigsawGrid(canvas, size, cellSize);
      } else {
        // Draw standard grid
        _drawStandardGrid(canvas, size, cellSize);
      }
    } catch (e, stackTrace) {
      DebugLogger.error('Error painting grid', e, stackTrace);
    }
  }

  void _drawStandardGrid(Canvas canvas, Size size, double cellSize) {
    final paint = Paint()..color = Colors.black..strokeWidth = 1;
    final thickPaint = Paint()..color = Colors.black..strokeWidth = 3;
    
    // Get region dimensions based on grid size
    List<int> regionSizes;
    switch (gridDim) {
      case 4: regionSizes = [2, 2]; break;
      case 6: regionSizes = [2, 3]; break;
      case 8: regionSizes = [2, 4]; break;
      case 9: regionSizes = [3, 3]; break;
      case 10: regionSizes = [2, 5]; break;
      case 12: regionSizes = [3, 4]; break;
      default: regionSizes = [2, 2]; break;
    }
    
    final rowsPerRegion = regionSizes[0];
    final colsPerRegion = regionSizes[1];

    for (int i = 0; i <= gridDim; i++) {
      final isThickHorizontal = i % rowsPerRegion == 0;
      final isThickVertical = i % colsPerRegion == 0;
      
      // Vertical lines
      canvas.drawLine(
        Offset(i * cellSize, 0),
        Offset(i * cellSize, size.height),
        isThickVertical ? thickPaint : paint,
      );
      
      // Horizontal lines
      canvas.drawLine(
        Offset(0, i * cellSize),
        Offset(size.width, i * cellSize),
        isThickHorizontal ? thickPaint : paint,
      );
    }
  }

  void _drawJigsawGrid(Canvas canvas, Size size, double cellSize) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw region boundaries
    for (int row = 0; row < gridDim; row++) {
      for (int col = 0; col < gridDim; col++) {
        final currentRegion = regions![row][col];
        
        // Check each direction and draw border if different region
        final left = col * cellSize;
        final top = row * cellSize;
        final right = left + cellSize;
        final bottom = top + cellSize;

        // Top border
        if (row == 0 || regions![row - 1][col] != currentRegion) {
          canvas.drawLine(Offset(left, top), Offset(right, top), paint);
        }
        
        // Bottom border
        if (row == gridDim - 1 || regions![row + 1][col] != currentRegion) {
          canvas.drawLine(Offset(left, bottom), Offset(right, bottom), paint);
        }
        
        // Left border
        if (col == 0 || regions![row][col - 1] != currentRegion) {
          canvas.drawLine(Offset(left, top), Offset(left, bottom), paint);
        }
        
        // Right border
        if (col == gridDim - 1 || regions![row][col + 1] != currentRegion) {
          canvas.drawLine(Offset(right, top), Offset(right, bottom), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class SmartHint {
  final HintType type;
  final String title;
  final String description;
  final int penalty;
  final dynamic data; // To hold the solution data (e.g., list of numbers, single number)

  SmartHint({
    required this.type,
    required this.title,
    required this.description,
    required this.penalty,
    this.data,
  });
}

Future<SudokuGame> _generateSudokuInBackground(Map<String, dynamic> params) async {
  final difficulty = params['difficulty'] as SudokuDifficulty;
  final gridSize = params['gridSize'] as GridSize;
  final gridShape = params['gridShape'] as GridShape;

  // This will run in a separate thread and can't hang the UI
  // The fix is to call the private constructor `SudokuGame._` here
  return SudokuGame._(difficulty, gridSize, gridShape);
}

class SudokuGame {
  late List<List<int>> grid;
  late List<List<bool>> isOriginal;
  late List<List<int>> solution;
  late List<List<int>> regions; // For jigsaw puzzles
  late int gridDim;
  late DateTime startTime;
  late Stream<String> timeStream;
  final SudokuDifficulty difficulty;

  SudokuGame.fromExisting(SudokuGame other) : difficulty = other.difficulty { // <-- Added initializer
    gridDim = other.gridDim;
    // This constructor is used when loading from the cache.
    // We copy the SOLUTION, not the unsolved grid.
    grid = other.solution.map((row) => List<int>.from(row)).toList();
    isOriginal = List.generate(gridDim, (_) => List.filled(gridDim, false));
    solution = other.solution.map((row) => List<int>.from(row)).toList();
    regions = other.regions.map((row) => List<int>.from(row)).toList();

    // IMPORTANT: We re-puzzlify the loaded solution. This makes the cached puzzle
    // feel new each time by removing a different set of numbers.
    _puzzlify();
  }

  SudokuGame.fromBlueprint(PuzzleBlueprint blueprint, this.difficulty) {
    gridDim = blueprint.gridSize.index == 0 ? 4 : blueprint.gridSize.index == 1 ? 6 : blueprint.gridSize.index == 2 ? 8 : blueprint.gridSize.index == 3 ? 9 : blueprint.gridSize.index == 4 ? 10 : 12;
    grid = blueprint.solutionGrid.map((row) => List<int>.from(row)).toList();
    solution = blueprint.solutionGrid.map((row) => List<int>.from(row)).toList();
    regions = blueprint.regions.map((row) => List<int>.from(row)).toList();
    isOriginal = List.generate(gridDim, (_) => List.filled(gridDim, false));

    _puzzlify(); // Turn the solved grid into a playable puzzle
  }

  void _puzzlify() {
  DebugLogger.log('Puzzlifying grid: Saving solution and removing cells...');
  
  // Step 1: Save the complete grid as the solution.
  for (int i = 0; i < gridDim; i++) {
    for (int j = 0; j < gridDim; j++) {
      solution[i][j] = grid[i][j];
    }
  }

  // Step 2: Remove a number of cells based on the difficulty.
    int cellsToRemove = _getCellsToRemove(difficulty);
    _removeRandomCells(cellsToRemove);

    // Step 3: Mark the remaining numbers as original (not editable by the player).
    for (int i = 0; i < gridDim; i++) {
      for (int j = 0; j < gridDim; j++) {
        isOriginal[i][j] = grid[i][j] != 0;
      }
    }
  }

  void startTimer() {
    startTime = DateTime.now();
    timeStream = Stream.periodic(const Duration(seconds: 1), (_) => getFormattedTime());
  }
  
  // SudokuGame(SudokuDifficulty difficulty, GridSize gridSize, GridShape gridShape) {
  // we make that async
  SudokuGame._(this.difficulty, GridSize gridSize, GridShape gridShape) { // <-- Added `this.difficulty`
    try {
      DebugLogger.log('Initializing sudoku game with ${gridSize.name} ${difficulty.name} ${gridShape.name}');
      _initializeGrid(gridSize);
      
      if (gridShape == GridShape.jigsaw) {
        _generateJigsawPuzzle();
      } else {
        _generatePuzzle();
      }
      
      // we call the puzzlify method AFTER a solution is generated
      _puzzlify();
      
      DebugLogger.log('Sudoku game initialized successfully');
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to initialize sudoku game', e, stackTrace);
      rethrow;
    }
  }

  static Future<SudokuGame> create(
      SudokuDifficulty difficulty, GridSize gridSize, GridShape gridShape) async {
    
    final params = {
      'difficulty': difficulty,
      'gridSize': gridSize,
      'gridShape': gridShape,
    };

    // Run the generation in an isolate with a 3-second timeout.
    // If it hangs, it will throw an error instead of freezing the app.
    return await compute(_generateSudokuInBackground, params)
        .timeout(const Duration(seconds: 3));
  }

  void _initializeGrid(GridSize gridSize) {
    switch (gridSize) {
      case GridSize.small:
        gridDim = 4;
        break;
      case GridSize.medium:
        gridDim = 6;
        break;
      case GridSize.large:
        gridDim = 8;
        break;
      case GridSize.standard:
        gridDim = 9;
        break;
      case GridSize.big:
        gridDim = 10;
        break;
      case GridSize.mega:
        gridDim = 12;
        break;
    }
    
    DebugLogger.log('Grid dimension: $gridDim');
    grid = List.generate(gridDim, (_) => List.filled(gridDim, 0));
    isOriginal = List.generate(gridDim, (_) => List.filled(gridDim, false));
    solution = List.generate(gridDim, (_) => List.filled(gridDim, 0));
    regions = List.generate(gridDim, (_) => List.filled(gridDim, 0));
  }

  void _generatePuzzle() { // <-- Removed `difficulty` parameter
    try {
      DebugLogger.log('Generating ${difficulty.name} puzzle');
      _initializeStandardRegions();
      
      int attempts = 0;
      bool success = false;
      while (attempts < 10 && !success) {
        attempts++;
        DebugLogger.log('Generation attempt $attempts');
        
        for (int i = 0; i < gridDim; i++) {
          for (int j = 0; j < gridDim; j++) {
            grid[i][j] = 0;
          }
        }
        
        success = _generateCompleteSudoku();
        if (!success) {
          DebugLogger.log('Attempt $attempts failed, retrying...');
        }
      }
      
      if (!success) {
        throw Exception('Failed to generate complete sudoku after $attempts attempts');
      }
      
      DebugLogger.log('Puzzle grid generated successfully');
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to generate puzzle', e, stackTrace);
      rethrow;
    }
  }

  void _generateJigsawPuzzle() { // <-- Removed `difficulty` parameter
    DebugLogger.log('--- STARTING JIGSAW PUZZLE GENERATION ($gridDim x $gridDim) ---');

    if (gridDim >= 10) {
      _generateSimplifiedJigsawRegions();
    } else {
      _generateJigsawRegions();
    }

    for (int i = 0; i < gridDim; i++) {
      for (int j = 0; j < gridDim; j++) {
        grid[i][j] = 0;
      }
    }
    
    DebugLogger.log('Starting solver...');
    if (!_generateCompleteJigsawSudoku()) {
      throw Exception('Solver failed to generate a puzzle for the given shape.');
    }
    
    DebugLogger.log('--- Jigsaw Generation SUCCEEDED on this attempt! ---');
  }

  void _initializeStandardRegions() {
    final regionSizes = _getRegionSize();
    final rowsPerRegion = regionSizes[0];
    final colsPerRegion = regionSizes[1];
    
    DebugLogger.log('Region size: ${rowsPerRegion}x${colsPerRegion}');
    
    for (int row = 0; row < gridDim; row++) {
      for (int col = 0; col < gridDim; col++) {
        final regionRow = row ~/ rowsPerRegion;
        final regionCol = col ~/ colsPerRegion;
        regions[row][col] = regionRow * (gridDim ~/ colsPerRegion) + regionCol;
      }
    }
  }

  List<int> _getRegionSize() {
    // Returns [rows, cols] for each region
    switch (gridDim) {
      case 4: return [2, 2]; // 2x2 regions
      case 6: return [2, 3]; // 2x3 regions  
      case 8: return [2, 4]; // 2x4 regions
      case 9: return [3, 3]; // 3x3 regions
      case 10: return [2, 5]; // 2x5 regions
      case 12: return [3, 4]; // 3x4 regions
      default: return [2, 2];
    }
  }


  bool _attemptJigsawGeneration() {
    DebugLogger.log('Using controlled adjacent region swapping');
    
    // Start with standard regions
    _initializeStandardRegions();
    
    math.Random random = math.Random();
    int totalSwaps = 0;
    
    // For each pair of adjacent regions, perform controlled swaps
    for (int regionA = 0; regionA < gridDim; regionA++) {
      for (int regionB = regionA + 1; regionB < gridDim; regionB++) {
        int swapsForThisPair = _performControlledSwaps(regionA, regionB, random);
        totalSwaps += swapsForThisPair;
      }
    }
    
    DebugLogger.log('Completed $totalSwaps total controlled swaps');
    return true; // Always succeeds since we start from valid state
  }

  int _performLimitedSwaps(int regionA, int regionB, math.Random random, int maxSwaps) {
    // Same as _performControlledSwaps but limited to maxSwaps
    List<List<int>> boundaryA = [];
    List<List<int>> boundaryB = [];
    
    for (int row = 0; row < gridDim; row++) {
      for (int col = 0; col < gridDim; col++) {
        if (regions[row][col] == regionA) {
          if (_isAdjacentToRegion(row, col, regionB)) {
            boundaryA.add([row, col]);
          }
        } else if (regions[row][col] == regionB) {
          if (_isAdjacentToRegion(row, col, regionA)) {
            boundaryB.add([row, col]);
          }
        }
      }
    }
    
    if (boundaryA.isEmpty || boundaryB.isEmpty) return 0;
    
    int swapsToPerform = math.min(maxSwaps, math.min(boundaryA.length, boundaryB.length));
    int successfulSwaps = 0;
    
    boundaryA.shuffle(random);
    boundaryB.shuffle(random);
    
    for (int i = 0; i < swapsToPerform; i++) {
      List<int> cellA = boundaryA[i];
      List<int> cellB = boundaryB[i];
      
      if (_canSwapCells(cellA[0], cellA[1], regionA, cellB[0], cellB[1], regionB)) {
        regions[cellA[0]][cellA[1]] = regionB;
        regions[cellB[0]][cellB[1]] = regionA;
        successfulSwaps++;
      }
    }
    
    return successfulSwaps;
  }

  int _performControlledSwaps(int regionA, int regionB, math.Random random) {
    // Find boundary cells between these two specific regions
    List<List<int>> boundaryA = []; // Cells in regionA adjacent to regionB
    List<List<int>> boundaryB = []; // Cells in regionB adjacent to regionA
    
    for (int row = 0; row < gridDim; row++) {
      for (int col = 0; col < gridDim; col++) {
        if (regions[row][col] == regionA) {
          if (_isAdjacentToRegion(row, col, regionB)) {
            boundaryA.add([row, col]);
          }
        } else if (regions[row][col] == regionB) {
          if (_isAdjacentToRegion(row, col, regionA)) {
            boundaryB.add([row, col]);
          }
        }
      }
    }
    
    if (boundaryA.isEmpty || boundaryB.isEmpty) {
      return 0; // These regions aren't adjacent
    }
    
    DebugLogger.log('Region $regionA<->$regionB: ${boundaryA.length} and ${boundaryB.length} boundary cells');
    
    // Perform 1-3 swaps between these regions
    int swapsToPerform = math.min(3, math.min(boundaryA.length, boundaryB.length));
    int successfulSwaps = 0;
    
    for (int i = 0; i < swapsToPerform; i++) {
      if (boundaryA.isEmpty || boundaryB.isEmpty) break;
      
      // Pick random cells from each boundary
      boundaryA.shuffle(random);
      boundaryB.shuffle(random);
      
      List<int> cellA = boundaryA[0];
      List<int> cellB = boundaryB[0];
      
      if (_canSwapCells(cellA[0], cellA[1], regionA, cellB[0], cellB[1], regionB)) {
        // Perform the swap
        regions[cellA[0]][cellA[1]] = regionB;
        regions[cellB[0]][cellB[1]] = regionA;
        
        successfulSwaps++;
        DebugLogger.log('Swapped (${cellA[0]},${cellA[1]}) and (${cellB[0]},${cellB[1]}) between regions $regionA<->$regionB');
        
        // Update boundary lists
        boundaryA.removeAt(0);
        boundaryB.removeAt(0);
      }
    }
    
    return successfulSwaps;
  }

  bool _isAdjacentToRegion(int row, int col, int targetRegion) {
    List<List<int>> directions = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    
    for (List<int> dir in directions) {
      int newRow = row + dir[0];
      int newCol = col + dir[1];
      
      if (newRow >= 0 && newRow < gridDim && 
          newCol >= 0 && newCol < gridDim &&
          regions[newRow][newCol] == targetRegion) {
        return true;
      }
    }
    
    return false;
  }

  bool _canSwapCells(int rowA, int colA, int regionA, int rowB, int colB, int regionB) {
    // Temporarily perform the swap
    regions[rowA][colA] = regionB;
    regions[rowB][colB] = regionA;
    
    // Check if both regions remain connected
    bool regionAConnected = _isRegionConnected(regionA);
    bool regionBConnected = _isRegionConnected(regionB);
    
    // Revert the swap
    regions[rowA][colA] = regionA;
    regions[rowB][colB] = regionB;
    
    return regionAConnected && regionBConnected;
  }

  void _generateSimplifiedJigsawRegions() {
    DebugLogger.log('Generating simplified jigsaw regions for large grid');
    
    _initializeStandardRegions();
    
    math.Random random = math.Random();
    
    // For the EXTREMELY complex 12x12 grid, we only do a few swaps
    // to keep the regions simple and ensure the solver can finish in time.
    int limitedSwaps = (gridDim == 12) ? 4 : gridDim; 
    
    int successfulSwaps = 0;
    
    for (int regionA = 0; regionA < gridDim && successfulSwaps < limitedSwaps; regionA++) {
      for (int regionB = regionA + 1; regionB < gridDim && successfulSwaps < limitedSwaps; regionB++) {
        int swaps = _performLimitedSwaps(regionA, regionB, random, 1);
        successfulSwaps += swaps;
      }
    }
    
    DebugLogger.log('Simplified jigsaw: $successfulSwaps swaps completed');
  }

  void _generateJigsawRegions() {
    DebugLogger.log('=== STARTING CONTROLLED ADJACENT SWAPPING ===');
    
    bool success = _attemptJigsawGeneration();
    
    if (!success) {
      DebugLogger.log('Controlled swapping failed, using standard regions');
      _initializeStandardRegions();
    } else {
      DebugLogger.log('=== JIGSAW GENERATION SUCCESSFUL ===');
      _validateJigsawRegions();
    }
  }
  
  
  bool _buildSingleRegion(int regionId, math.Random random) {
    // Find all unassigned cells
    List<List<int>> availableCells = [];
    for (int row = 0; row < gridDim; row++) {
      for (int col = 0; col < gridDim; col++) {
        if (regions[row][col] == -1) {
          availableCells.add([row, col]);
        }
      }
    }
    
    DebugLogger.log('Building region $regionId: ${availableCells.length} cells available, need $gridDim');
    
    if (availableCells.length < gridDim) {
      DebugLogger.log('ERROR: Not enough cells for region $regionId');
      return false;
    }
    
    // Try multiple seed positions
    availableCells.shuffle(random);
    int seedAttempts = math.min(15, availableCells.length);
    
    for (int attempt = 0; attempt < seedAttempts; attempt++) {
      List<int> seedCell = availableCells[attempt];
      DebugLogger.log('Region $regionId attempt ${attempt + 1}: trying seed (${seedCell[0]}, ${seedCell[1]})');
      
      if (_growRegionFromSeed(regionId, seedCell[0], seedCell[1], random)) {
        DebugLogger.log('Region $regionId SUCCESS on attempt ${attempt + 1}');
        return true;
      }
    }
    
    DebugLogger.log('Region $regionId FAILED after $seedAttempts attempts');
    return false;
  }

  bool _growRegionFromSeed(int regionId, int seedRow, int seedCol, math.Random random) {
    if (regions[seedRow][seedCol] != -1) return false;
    
    List<List<int>> regionCells = [[seedRow, seedCol]];
    regions[seedRow][seedCol] = regionId;
    
    while (regionCells.length < gridDim) {
      List<List<int>> candidates = [];
      Set<String> checked = {};
      
      for (List<int> cell in regionCells) {
        int row = cell[0];
        int col = cell[1];
        
        List<List<int>> directions = [[-1, 0], [1, 0], [0, -1], [0, 1]];
        for (List<int> dir in directions) {
          int newRow = row + dir[0];
          int newCol = col + dir[1];
          String key = '$newRow,$newCol';
          
          if (newRow >= 0 && newRow < gridDim && 
              newCol >= 0 && newCol < gridDim &&
              regions[newRow][newCol] == -1 &&
              !checked.contains(key)) {
            candidates.add([newRow, newCol]);
            checked.add(key);
          }
        }
      }
      
      if (candidates.isEmpty) {
        DebugLogger.log('Region $regionId stuck at size ${regionCells.length}/$gridDim - no adjacent cells');
        // Backtrack
        for (List<int> cell in regionCells) {
          regions[cell[0]][cell[1]] = -1;
        }
        return false;
      }
      
      candidates.shuffle(random);
      List<int> nextCell = candidates[0];
      
      regions[nextCell[0]][nextCell[1]] = regionId;
      regionCells.add(nextCell);
    }
    
    return true;
  }
  
  bool _attemptDeadlockRecovery(List<List<List<int>>> regionCells, List<List<int>> availableCells, math.Random random) {
    // Try to redistribute cells from oversized regions
    for (int regionId = 0; regionId < gridDim; regionId++) {
      if (regionCells[regionId].length > 1) {
        // Find boundary cells that could be reassigned
        List<List<int>> boundaryCells = [];
        
        for (List<int> cell in regionCells[regionId]) {
          int row = cell[0];
          int col = cell[1];
          
          // Check if this cell has unassigned neighbors
          bool hasFreeNeighbor = false;
          List<List<int>> directions = [[-1, 0], [1, 0], [0, -1], [0, 1]];
          
          for (List<int> dir in directions) {
            int newRow = row + dir[0];
            int newCol = col + dir[1];
            
            if (newRow >= 0 && newRow < gridDim && 
                newCol >= 0 && newCol < gridDim &&
                regions[newRow][newCol] == -1) {
              hasFreeNeighbor = true;
              break;
            }
          }
          
          if (hasFreeNeighbor) {
            boundaryCells.add([row, col]);
          }
        }
        
        if (boundaryCells.isNotEmpty) {
          // Remove a boundary cell and make it available
          boundaryCells.shuffle(random);
          List<int> cellToRemove = boundaryCells[0];
          int row = cellToRemove[0];
          int col = cellToRemove[1];
          
          regions[row][col] = -1;
          regionCells[regionId].removeWhere((cell) => cell[0] == row && cell[1] == col);
          availableCells.add([row, col]);
          
          return true; // Recovery successful
        }
      }
    }
    
    return false; // Recovery failed
  }


  void _clearRegions() {
    for (int row = 0; row < gridDim; row++) {
      for (int col = 0; col < gridDim; col++) {
        regions[row][col] = -1;
      }
    }
  }

  void _validateJigsawRegions() {
    DebugLogger.log('=== VALIDATING JIGSAW REGIONS ===');
    
    Map<int, int> regionSizes = {};
    Map<int, List<String>> regionCells = {};
    
    for (int row = 0; row < gridDim; row++) {
      for (int col = 0; col < gridDim; col++) {
        int regionId = regions[row][col];
        regionSizes[regionId] = (regionSizes[regionId] ?? 0) + 1;
        
        if (!regionCells.containsKey(regionId)) {
          regionCells[regionId] = [];
        }
        regionCells[regionId]!.add('($row,$col)');
      }
    }
    
    bool valid = true;
    
    for (int regionId = 0; regionId < gridDim; regionId++) {
      int size = regionSizes[regionId] ?? 0;
      DebugLogger.log('Region $regionId: $size cells - ${regionCells[regionId]?.join(', ') ?? 'EMPTY'}');
      
      if (size != gridDim) {
        DebugLogger.log('ERROR: Region $regionId has wrong size!');
        valid = false;
      }
      
      // Check connectivity
      if (!_isRegionConnected(regionId)) {
        DebugLogger.log('ERROR: Region $regionId is not connected!');
        valid = false;
      }
    }
    
    if (valid) {
      DebugLogger.log('All regions are valid and connected!');
    } else {
      DebugLogger.log('VALIDATION FAILED!');
    }
  }

  bool _isRegionConnected(int regionId) {
    List<List<int>> regionCells = [];
    
    for (int row = 0; row < gridDim; row++) {
      for (int col = 0; col < gridDim; col++) {
        if (regions[row][col] == regionId) {
          regionCells.add([row, col]);
        }
      }
    }
    
    if (regionCells.isEmpty) return false;
    if (regionCells.length == 1) return true;
    
    // Use BFS to check connectivity
    Set<String> visited = {};
    List<List<int>> queue = [regionCells[0]];
    visited.add('${regionCells[0][0]},${regionCells[0][1]}');
    
    while (queue.isNotEmpty) {
      List<int> current = queue.removeAt(0);
      int row = current[0];
      int col = current[1];
      
      // Check 4 directions
      List<List<int>> directions = [[-1, 0], [1, 0], [0, -1], [0, 1]];
      
      for (List<int> dir in directions) {
        int newRow = row + dir[0];
        int newCol = col + dir[1];
        String key = '$newRow,$newCol';
        
        if (newRow >= 0 && newRow < gridDim && 
            newCol >= 0 && newCol < gridDim &&
            regions[newRow][newCol] == regionId &&
            !visited.contains(key)) {
          
          visited.add(key);
          queue.add([newRow, newCol]);
        }
      }
    }
    
    return visited.length == regionCells.length;
  }

  List<List<int>> _getAdjacentUnassignedCells(int regionId) {
    List<List<int>> adjacent = [];
    Set<String> checked = {};
    
    for (int row = 0; row < gridDim; row++) {
      for (int col = 0; col < gridDim; col++) {
        if (regions[row][col] == regionId) {
          // Check all 4 directions
          List<List<int>> directions = [
            [-1, 0], [1, 0], [0, -1], [0, 1]
          ];
          
          for (List<int> dir in directions) {
            int newRow = row + dir[0];
            int newCol = col + dir[1];
            String key = '$newRow,$newCol';
            
            if (newRow >= 0 && newRow < gridDim && 
                newCol >= 0 && newCol < gridDim &&
                regions[newRow][newCol] == -1 &&
                !checked.contains(key)) {
              
              adjacent.add([newRow, newCol]);
              checked.add(key);
            }
          }
        }
      }
    }
    
    return adjacent;
  }

  void _fillRegion(int startRow, int startCol, int regionId, List<List<bool>> visited, math.Random random) {
    List<List<int>> stack = [[startRow, startCol]];
    List<List<int>> regionCells = [];
    
    while (stack.isNotEmpty && regionCells.length < gridDim) {
      final current = stack.removeLast();
      final row = current[0];
      final col = current[1];
      
      if (row >= 0 && row < gridDim && col >= 0 && col < gridDim && !visited[row][col]) {
        visited[row][col] = true;
        regions[row][col] = regionId;
        regionCells.add([row, col]);
        
        // Add neighbors randomly
        List<List<int>> neighbors = [
          [row - 1, col], [row + 1, col], [row, col - 1], [row, col + 1]
        ];
        neighbors.shuffle(random);
        
        for (var neighbor in neighbors) {
          if (regionCells.length < gridDim) {
            stack.add(neighbor);
          }
        }
      }
    }
  }

  int _getCellsToRemove(SudokuDifficulty difficulty) {
    final totalCells = gridDim * gridDim;
    switch (difficulty) {
      case SudokuDifficulty.easy:
        return (totalCells * 0.4).round();
      case SudokuDifficulty.medium:
        return (totalCells * 0.5).round();
      case SudokuDifficulty.hard:
        return (totalCells * 0.6).round();
      case SudokuDifficulty.expert:
        return (totalCells * 0.7).round();
    }
  }

  bool _generateCompleteSudoku() {
    try {
      return _fillGridWithBacktracking(0, 0);
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to generate complete sudoku', e, stackTrace);
      return false;
    }
  }

  bool _fillGridWithBacktracking(int row, int col) {
    if (row == gridDim) return true;
    
    int nextRow = col == gridDim - 1 ? row + 1 : row;
    int nextCol = col == gridDim - 1 ? 0 : col + 1;
    
    List<int> numbers = List.generate(gridDim, (i) => i + 1);
    numbers.shuffle(math.Random());
    
    for (int num in numbers) {
      if (_isSafeForGeneration(row, col, num)) {
        grid[row][col] = num;
        if (_fillGridWithBacktracking(nextRow, nextCol)) return true;
        grid[row][col] = 0;
      }
    }
    return false;
  }

  bool _isSafeForGeneration(int row, int col, int num) {
    // Check row
    for (int c = 0; c < gridDim; c++) {
      if (grid[row][c] == num) return false;
    }
    
    // Check column
    for (int r = 0; r < gridDim; r++) {
      if (grid[r][col] == num) return false;
    }
    
    // Check region
    final currentRegion = regions[row][col];
    for (int r = 0; r < gridDim; r++) {
      for (int c = 0; c < gridDim; c++) {
        if (regions[r][c] == currentRegion && grid[r][c] == num) {
          return false;
        }
      }
    }
    
    return true;
  }

  bool _generateCompleteJigsawSudoku() {
    try {
      // Add timeout for large grids
      int maxAttempts = gridDim <= 9 ? 10000 : 5000;
      
      return _fillJigsawGridWithTimeout(maxAttempts, 0);
    } catch (e, stackTrace) {
      DebugLogger.error('Failed to generate complete jigsaw sudoku', e, stackTrace);
      return false;
    }
  }

  List<int>? _findMostConstrainedCell() {
    int minPossibilities = gridDim + 1;
    List<int>? bestCell;

    for (int r = 0; r < gridDim; r++) {
      for (int c = 0; c < gridDim; c++) {
        if (grid[r][c] == 0) {
          int possibilities = 0;
          for (int num = 1; num <= gridDim; num++) {
            if (_isJigsawSafe(r, c, num)) {
              possibilities++;
            }
          }
          if (possibilities < minPossibilities) {
            minPossibilities = possibilities;
            bestCell = [r, c];
          }
        }
      }
    }
    return bestCell;
  }

  bool _fillJigsawGridWithTimeout(int maxAttempts, int attempts) {
    // VERBOSE LOGGING: Show that the solver is still alive during deep recursion.
    if (attempts > 0 && attempts % 1000 == 0) {
      DebugLogger.log('... Solver deep in recursion: $attempts steps...');
    }
    
    if (attempts >= maxAttempts) {
      DebugLogger.log('Solver timeout after $attempts attempts. This puzzle shape is likely too complex.');
      return false;
    }

    final cell = _findMostConstrainedCell();
    
    if (cell == null) return true; // Success, grid is full.

    int row = cell[0];
    int col = cell[1];

    List<int> numbers = List.generate(gridDim, (i) => i + 1)..shuffle();

    for (int num in numbers) {
      if (_isJigsawSafe(row, col, num)) {
        grid[row][col] = num;
        if (_fillJigsawGridWithTimeout(maxAttempts, attempts + 1)) {
          return true;
        }
        grid[row][col] = 0; // Backtrack
      }
    }
    return false;
  }

  bool _fillJigsawGrid(int row, int col) {
    if (row == gridDim) return true;
    
    int nextRow = col == gridDim - 1 ? row + 1 : row;
    int nextCol = col == gridDim - 1 ? 0 : col + 1;
    
    List<int> numbers = List.generate(gridDim, (i) => i + 1);
    numbers.shuffle(math.Random());
    
    for (int num in numbers) {
      if (_isJigsawSafe(row, col, num)) {
        grid[row][col] = num;
        if (_fillJigsawGrid(nextRow, nextCol)) return true;
        grid[row][col] = 0;
      }
    }
    return false;
  }

  bool _isJigsawSafe(int row, int col, int num) {
    // Check row
    for (int c = 0; c < gridDim; c++) {
      if (grid[row][c] == num) return false;
    }
    
    // Check column
    for (int r = 0; r < gridDim; r++) {
      if (grid[r][col] == num) return false;
    }
    
    // Check region
    final currentRegion = regions[row][col];
    for (int r = 0; r < gridDim; r++) {
      for (int c = 0; c < gridDim; c++) {
        if (regions[r][c] == currentRegion && grid[r][c] == num) {
          return false;
        }
      }
    }
    
    return true;
  }

  void _removeRandomCells(int cellsToRemove) {
    math.Random random = math.Random();
    int removed = 0;
    
    while (removed < cellsToRemove) {
      int row = random.nextInt(gridDim);
      int col = random.nextInt(gridDim);
      
      if (grid[row][col] != 0) {
        grid[row][col] = 0;
        removed++;
      }
    }
  }

  bool isValidMove(int row, int col, int num) {
    if (isOriginal[row][col]) return false;
    
    // Check row
    for (int c = 0; c < gridDim; c++) {
      if (c != col && grid[row][c] == num) return false;
    }
    
    // Check column
    for (int r = 0; r < gridDim; r++) {
      if (r != row && grid[r][col] == num) return false;
    }
    
    // Check region (box or jigsaw)
    final currentRegion = regions[row][col];
    for (int r = 0; r < gridDim; r++) {
      for (int c = 0; c < gridDim; c++) {
        if ((r != row || c != col) && regions[r][c] == currentRegion && grid[r][c] == num) {
          return false;
        }
      }
    }
    
    return true;
  }

  List<SmartHint> getSmartHints(int row, int col) {
    List<SmartHint> hints = [];
    
    if (isOriginal[row][col] || grid[row][col] != 0) {
      hints.add(SmartHint(
        type: HintType.conflict,
        title: 'Cell Occupied',
        description: 'This cell is already filled or is part of the original puzzle.',
        penalty: 0,
      ));
      return hints;
    }
    
    List<int> possibleNumbers = _getPossibleNumbers(row, col);
    
    if (possibleNumbers.isEmpty) {
      hints.add(SmartHint(
        type: HintType.conflict,
        title: 'Conflict Detected',
        description: 'No numbers can legally be placed in this cell. Check the row, column, or region for an error.',
        penalty: 0,
      ));
    } else if (possibleNumbers.length == 1) {
      hints.add(SmartHint(
        type: HintType.nakedSingle,
        title: 'Only Choice (Naked Single)',
        description: 'There is only one possible number that can fit in this cell.',
        penalty: 25,
        data: possibleNumbers[0],
      ));
    } else {
      // Check for a hidden single before offering other hints
      for (int num in possibleNumbers) {
        if (_isHiddenSingle(row, col, num)) {
          hints.add(SmartHint(
            type: HintType.hiddenSingle,
            title: 'Hidden Single',
            description: 'This is the only cell in its row, column, or region where a specific number can go.',
            penalty: 30,
            data: num,
          ));
          break; // A hidden single is a great hint, so we can stop here
        }
      }

      hints.add(SmartHint(
        type: HintType.showPossible,
        title: 'Show Possible Numbers',
        description: 'Reveals all numbers that can legally be placed in this cell.',
        penalty: 15,
        data: possibleNumbers, // Pack the answer into the data field
      ));
      
      hints.add(SmartHint(
        type: HintType.giveAnswer,
        title: 'Give Answer',
        description: 'Fills the correct number into the cell.',
        penalty: 50,
        data: solution[row][col], // Pack the answer into the data field
      ));
    }
    
    return hints;
  }

  List<int> _getPossibleNumbers(int row, int col) {
    List<int> possible = [];
    for (int num = 1; num <= gridDim; num++) {
      if (isValidMove(row, col, num)) {
        possible.add(num);
      }
    }
    return possible;
  }

  bool _isHiddenSingle(int row, int col, int num) {
    final currentRegion = regions[row][col];
    
    // Check if num can only go in this position in the region
    int possiblePositions = 0;
    for (int r = 0; r < gridDim; r++) {
      for (int c = 0; c < gridDim; c++) {
        if (regions[r][c] == currentRegion && grid[r][c] == 0 && isValidMove(r, c, num)) {
          possiblePositions++;
        }
      }
    }
    
    return possiblePositions == 1;
  }

  void setCell(int row, int col, int value) {
    if (!isOriginal[row][col]) {
      grid[row][col] = value;
    }
  }

  void clearCell(int row, int col) {
    if (!isOriginal[row][col]) {
      grid[row][col] = 0;
    }
  }

  bool isCompleted() {
    for (int row = 0; row < gridDim; row++) {
      for (int col = 0; col < gridDim; col++) {
        if (grid[row][col] == 0) return false;
      }
    }
    return true;
  }

  String getFormattedTime() {
    final elapsed = DateTime.now().difference(startTime);
    final minutes = elapsed.inMinutes;
    final seconds = elapsed.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _isGenerating = false;
  int _generatedCount = 0;
  String _currentStatus = "Idle. Ready to generate puzzles for the cache.";

  Future<void> _startGeneration() async {
    setState(() {
      _isGenerating = true;
      _generatedCount = 0;
    });

    // Loop through every combination of size and shape
    for (final size in GridSize.values) {
      for (final shape in GridShape.values) {
        if (!_isGenerating) break; // Allow user to stop

        final key = PuzzleCache()._getKey(size, shape);
        
        // Skip if this blueprint is already in the cache
        if (PuzzleCache().get(size, shape) != null) {
          DebugLogger.log('Blueprint for $key already exists. Skipping.');
          continue;
        }

        setState(() {
          _currentStatus = "Generating blueprint for: $key";
        });

        try {
          // We generate with a single difficulty; it doesn't matter which one.
          SudokuGame? solvedGame = await SudokuGame.create(SudokuDifficulty.easy, size, shape)
              .timeout(const Duration(seconds: 5)); // More time for complex blueprints
          
          // Create and save the blueprint from the solved game.
          final blueprint = PuzzleBlueprint(
            solutionGrid: solvedGame.solution,
            regions: solvedGame.regions,
            gridSize: size,
            gridShape: shape,
          );
          PuzzleCache().set(blueprint);
          
          setState(() {
            _generatedCount++;
          });

        } catch (e) {
          DebugLogger.error("Admin generator timed out or failed for $key. It will be skipped.");
        }
        
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    setState(() {
      _isGenerating = false;
      _currentStatus = "Finished. Generated $_generatedCount new blueprints.";
    });
  }

  void _stopGeneration() {
    setState(() {
      _isGenerating = false;
    });
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
                style: const TextStyle(fontSize: 52, fontWeight: FontWeight.bold, color: Colors.indigo),
              ),
              const SizedBox(height: 20),
              const Text(
                'Status:',
                style: TextStyle(fontSize: 16),
              ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                child: Text(_isGenerating ? 'Stop Generation' : 'Start Generation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}