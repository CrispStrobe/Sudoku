// Run on hardware in profile mode with the existing integration driver.
// flutter drive --profile --driver=test_driver/integration_test.dart \
//   --target=integration_test/performance_test.dart -d <device-id>
import 'dart:convert';
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
  testWidgets('profile cached 12x12 jigsaw and 9x9 Killer interactions', (
    tester,
  ) async {
    // Do not change the player's persisted preferences or saved game.
    SharedPreferences.setMockInitialValues({});
    await ReadyPuzzleCache().initialize();
    final report = <String, dynamic>{};
    for (final killer in [false, true]) {
      final label = killer ? 'killer9' : 'jigsaw12';
      final frames = <FrameTiming>[];
      void record(List<FrameTiming> timings) => frames.addAll(timings);
      binding.addTimingsCallback(record);
      try {
        final watch = Stopwatch()..start();
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: GameScreen(
              key: ValueKey(label),
              difficulty: SudokuDifficulty.expert,
              gridSize: killer ? GridSize.standard : GridSize.mega,
              gridShape: killer ? GridShape.classic : GridShape.jigsaw,
              gameMode: GameMode.classic,
              variant: killer ? SudokuVariant.killer : SudokuVariant.classic,
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
        final startMs = watch.elapsedMicroseconds / 1000;
        final box = tester.renderObject<RenderBox>(board);
        final origin = box.localToGlobal(Offset.zero);
        final dim = killer ? 9 : 12;
        final cell = box.size.width / dim;
        for (var i = 0; i < 30; i++) {
          await tester.tapAt(
            origin + Offset((i % dim + 0.5) * cell, (i ~/ dim + 0.5) * cell),
          );
          for (var j = 0; j < 12; j++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
        }
        await tester.pump(const Duration(seconds: 1));
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
