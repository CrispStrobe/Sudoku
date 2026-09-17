import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/game_clock.dart';

void main() {
  testWidgets(
    'resume starts at saved elapsed and stop captures partial ticks',
    (tester) async {
      var now = DateTime(2026);
      final clock = GameClock(now: () => now);
      clock.start(initialElapsed: const Duration(seconds: 42));
      expect(clock.elapsed.value, const Duration(seconds: 42));
      now = now.add(const Duration(milliseconds: 1500));
      clock.stop();
      expect(clock.elapsed.value, const Duration(milliseconds: 43500));
      now = now.add(const Duration(hours: 3));
      clock.start(initialElapsed: clock.elapsed.value);
      now = now.add(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 1));
      expect(clock.elapsed.value, const Duration(milliseconds: 45500));
      clock.dispose();
    },
  );

  testWidgets('elapsed follows time, not number of delivered ticks', (
    tester,
  ) async {
    var now = DateTime(2026);
    final clock = GameClock(now: () => now);
    addTearDown(clock.dispose);
    clock.start();

    now = now.add(const Duration(seconds: 30));
    await tester.pump(const Duration(seconds: 1));
    expect(clock.elapsed.value, const Duration(seconds: 30));

    clock.stop();
    now = now.add(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(clock.elapsed.value, const Duration(seconds: 30));

    clock.start();
    expect(clock.elapsed.value, Duration.zero);
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(clock.elapsed.value, const Duration(seconds: 2));
    clock.dispose(); // Flutter checks pending timers before addTearDown runs.
  });

  testWidgets('a disposed clock ignores start/stop/dispose', (tester) async {
    final clock = GameClock();
    clock.dispose();
    clock.start(); // must be a no-op: no timer may be scheduled
    clock.stop();
    clock.dispose(); // idempotent
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
  });
}
