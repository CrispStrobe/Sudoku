import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'game_stats.dart';
import 'services.dart';
import 'sudoku_game.dart';

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
