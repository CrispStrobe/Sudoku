// Run on hardware in profile mode with the existing integration driver.
// flutter drive --profile --driver=test_driver/integration_test.dart \
//   --target=integration_test/performance_test.dart -d <device-id>
import 'dart:convert';
import 'dart:developer' show Timeline;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku/l10n/app_localizations.dart';
import 'package:sudoku/main.dart';
import 'package:sudoku/painters.dart';
import 'package:sudoku/ready_puzzle.dart';
import 'package:sudoku/sudoku_game.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('profile cached 12x12 boards and 9x9 Killer interactions', (
    tester,
  ) async {
    // Do not change the player's persisted preferences or saved game.
    SharedPreferences.setMockInitialValues({});
    // ignore: avoid_print
    print('PROBE cache initialization start');
    await ReadyPuzzleCache().initialize().timeout(const Duration(seconds: 15));
    // ignore: avoid_print
    print('PROBE cache initialization complete');
    final report = <String, dynamic>{};
    const scenarios = [
      ('classic12', GridSize.mega, GridShape.classic, SudokuVariant.classic),
      ('jigsaw12', GridSize.mega, GridShape.jigsaw, SudokuVariant.classic),
      ('killer9', GridSize.standard, GridShape.classic, SudokuVariant.killer),
    ];
    for (final (label, gridSize, gridShape, variant) in scenarios) {
      final frames = <FrameTiming>[];
      void record(List<FrameTiming> timings) => frames.addAll(timings);
      binding.addTimingsCallback(record);
      try {
        // ignore: avoid_print
        print('PROBE $label mounting');
        final watch = Stopwatch()..start();
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: GameScreen(
              key: ValueKey(label),
              difficulty: SudokuDifficulty.expert,
              gridSize: gridSize,
              gridShape: gridShape,
              gameMode: GameMode.classic,
              variant: variant,
            ),
          ),
        );
        final board = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is SudokuGridPainter,
        );
        while (board.evaluate().isEmpty &&
            watch.elapsed < const Duration(seconds: 45)) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(board, findsOneWidget);
        // ignore: avoid_print
        print('PROBE $label board ready');
        final startMs = watch.elapsedMicroseconds / 1000;
        // Flush batched startup timings before opening the interaction window.
        await tester.pump(const Duration(seconds: 1));
        final interactionStart = Timeline.now;
        frames.clear();
        final box = tester.renderObject<RenderBox>(board);
        final origin = box.localToGlobal(Offset.zero);
        final dim = gridDimensionFor(gridSize);
        final cell = box.size.width / dim;
        for (var i = 0; i < 30; i++) {
          await tester.tapAt(
            origin + Offset((i % dim + 0.5) * cell, (i ~/ dim + 0.5) * cell),
          );
          for (var j = 0; j < 12; j++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
        }
        final interactionEnd = Timeline.now;
        await tester.pump(const Duration(seconds: 1));
        frames.removeWhere((frame) {
          final start = frame.timestampInMicroseconds(FramePhase.vsyncStart);
          return start < interactionStart || start >= interactionEnd;
        });
        // ignore: avoid_print
        print('PROBE $label collected ${frames.length} interaction frames');
        expect(frames, isNotEmpty);
        double percentile(List<int> values, double p) {
          values.sort();
          return values[((values.length - 1) * p).round()] / 1000;
        }

        report[label] = {
          'start_ms': startMs,
          'frames': frames.length,
          'build_p95_ms': percentile(
            frames.map((f) => f.buildDuration.inMicroseconds).toList(),
            .95,
          ),
          'raster_p95_ms': percentile(
            frames.map((f) => f.rasterDuration.inMicroseconds).toList(),
            .95,
          ),
          'frames_over_16_67ms': frames
              .where(
                (f) =>
                    f.buildDuration.inMicroseconds > 16667 ||
                    f.rasterDuration.inMicroseconds > 16667,
              )
              .length,
        };
      } finally {
        binding.removeTimingsCallback(record);
        await tester.pumpWidget(const SizedBox());
      }
    }
    binding.reportData = report;
    // ignore: avoid_print
    print('PERFORMANCE ${jsonEncode(report)}');
  });
}
