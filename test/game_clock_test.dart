import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/game_clock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('clock ticks while running and freezes after dispose', (
    tester,
  ) async {
    final clock = GameClock();
    clock.start();
    expect(clock.elapsed.value, Duration.zero);

    await tester.pump(const Duration(seconds: 2));
    expect(clock.elapsed.value, const Duration(seconds: 2));

    clock.dispose();
    // A periodic tick arriving after dispose must not throw and must not
    // advance the disposed notifier.
    await tester.pump(const Duration(seconds: 2));
    expect(clock.elapsed.value, const Duration(seconds: 2));
  });

  testWidgets('restarting resets elapsed to zero', (tester) async {
    final clock = GameClock();
    clock.start();
    await tester.pump(const Duration(seconds: 3));
    expect(clock.elapsed.value, const Duration(seconds: 3));

    clock.start();
    expect(clock.elapsed.value, Duration.zero);

    await tester.pump(const Duration(seconds: 1));
    expect(clock.elapsed.value, const Duration(seconds: 1));
    clock.dispose();
  });
}
