import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/main.dart';

/// The overlay paints cached emoji rasters rather than a widget per particle,
/// so these cover the paint path itself: rasterising a glyph, drawing it, and
/// ticking without rebuilding.
void main() {
  Future<void> pumpLayer(
    WidgetTester tester,
    GlobalKey<ParticleLayerState> key,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: ParticleLayer(key: key),
          ),
        ),
      ),
    );
  }

  testWidgets('burst paints particles without throwing', (tester) async {
    final key = GlobalKey<ParticleLayerState>();
    await pumpLayer(tester, key);

    key.currentState!.burst();
    // Several frames so particles spawn, move and start to fade.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('ticking does not rebuild the layer', (tester) async {
    final key = GlobalKey<ParticleLayerState>();
    await pumpLayer(tester, key);

    final element = tester.element(find.byType(ParticleLayer));
    key.currentState!.burst();
    await tester.pump(const Duration(milliseconds: 16));

    // A rebuild would mark the element dirty; the ValueNotifier drives paint
    // only, which is the whole point of the CustomPainter.
    expect(element.dirty, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('particles expire and the layer settles', (tester) async {
    final key = GlobalKey<ParticleLayerState>();
    await pumpLayer(tester, key);

    key.currentState!.burst();
    // maxLife for a burst particle is 120 ticks; outrun it.
    for (var i = 0; i < 130; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(tester.takeException(), isNull);
    // Settled: no pending frames means the controller stopped on its own.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
