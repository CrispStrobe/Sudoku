// Store-screenshot capture. Runs the real app, navigates the key screens, and
// prints a `SHOT:<name>` marker while holding each screen so an external
// capturer (xcrun simctl io booted screenshot) can grab a clean frame — far
// more reliable on the iOS Simulator than binding.takeScreenshot.
//
//   xcrun simctl boot "iPhone 17 Pro Max"
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshot_test.dart -d "iPhone 17 Pro Max"
//
// while a monitor tails the log for `SHOT:` lines and runs simctl screenshot.
//
// Note: this uses `print` (markers must reach the drive log) and bounded pumps
// (NOT pumpAndSettle — the in-game 1s timer never lets pumpAndSettle settle).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:sudoku/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Finder boardFinder() => find.byWidgetPredicate(
    (w) => w is CustomPaint && w.painter is SudokuGridPainter,
  );

  // Bounded "settle": pump real frames for ~2.4s. Never hangs (unlike
  // pumpAndSettle when a periodic timer is alive).
  Future<void> settle(WidgetTester tester, {int steps = 12}) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 150));
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  }

  Future<void> mark(WidgetTester tester, String name) async {
    await settle(tester, steps: 3);
    // ignore: avoid_print
    print('SHOT:$name');
    await settle(tester, steps: 18); // hold ~4s for the external capturer
  }

  Future<void> waitForBoard(WidgetTester tester) async {
    for (var i = 0; i < 90; i++) {
      if (boardFinder().evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 150));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await settle(tester, steps: 4);
  }

  Future<void> startGame(
    WidgetTester tester, {
    required String size,
    String? variantChip,
    String difficulty = 'MEDIUM',
  }) async {
    await tester.tap(find.text('🎯 CLASSIC MODE'));
    await settle(tester);
    await tester.tap(find.text(size));
    await settle(tester);
    if (variantChip != null) {
      await tester.tap(find.textContaining(variantChip));
      await settle(tester, steps: 3);
    }
    await tester.tap(find.text(difficulty));
    await settle(tester, steps: 6);
    await waitForBoard(tester);
  }

  Future<void> goHome(WidgetTester tester) async {
    final home = find.byTooltip('Main Menu');
    if (home.evaluate().isNotEmpty) {
      await tester.tap(home);
      await settle(tester);
    }
  }

  testWidgets('capture store screenshots', (tester) async {
    await tester.pumpWidget(const SudokuApp());
    await settle(tester);
    await mark(tester, '01-home');

    // Classic 9×9 — select a centre cell to show selection + number pad.
    await startGame(tester, size: '9×9');
    final box = tester.renderObject<RenderBox>(boardFinder().first);
    final tl = box.localToGlobal(Offset.zero);
    final cell = box.size.width / 9;
    await tester.tapAt(tl + Offset(cell * 4.5, cell * 4.5));
    await settle(tester, steps: 4);
    await mark(tester, '02-classic');

    // Explain-the-solve walkthrough.
    final explain = find.byTooltip('Explain solve');
    if (explain.evaluate().isNotEmpty) {
      await tester.tap(explain);
      await settle(tester, steps: 5);
      final next = find.byTooltip('Next');
      for (var i = 0; i < 3 && next.evaluate().isNotEmpty; i++) {
        await tester.tap(next);
        await settle(tester, steps: 3);
      }
      await mark(tester, '03-explain');
      final back = find.byTooltip('Back');
      if (back.evaluate().isNotEmpty) {
        await tester.tap(back);
        await settle(tester);
      }
    }
    await goHome(tester);

    // Killer 9×9 — cages + sums.
    await startGame(tester, size: '9×9', variantChip: 'Killer');
    await mark(tester, '04-killer');
    await goHome(tester);

    // Statistics sheet.
    await tester.tap(find.text('Stats'));
    await settle(tester);
    await mark(tester, '05-stats');
    await tester.tapAt(const Offset(30, 60));
    await settle(tester);

    // Themes sheet.
    await tester.tap(find.text('Themes'));
    await settle(tester);
    await mark(tester, '06-themes');
  });
}
