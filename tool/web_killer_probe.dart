// Runs the Killer generator under the **web** number semantics.
//
// `flutter test` runs on the Dart VM, where `int` is a true 64-bit integer.
// dart2js compiles `int` to a JS double and cannot allocate a `Uint64List` at
// all, so code that is correct on the VM can throw in a browser — which is
// exactly what happened to the CSP solver's domain representation, silently
// breaking Killer on the web for a whole release while every VM test stayed
// green.
//
// This probe compiles the real generator with dart2js and runs it, so that
// class of failure shows up in a second instead of needing a full web build
// and a browser:
//
//   dart compile js -o /tmp/probe.js tool/web_killer_probe.dart
//   node -e 'globalThis.self = globalThis; require("/tmp/probe.js")'
//
// (dart2js's `print` writes to `self.console`, hence the shim.)
import 'package:sudoku/sudoku_game.dart';
import 'package:sudoku/variant_engine.dart';

Future<void> main() async {
  var failures = 0;
  for (final size in [GridSize.small, GridSize.medium, GridSize.standard]) {
    for (final difficulty in SudokuDifficulty.values) {
      final sw = Stopwatch()..start();
      try {
        final puzzle = await VariantEngine.generateKiller(
          gridSize: size,
          difficulty: difficulty,
          seed: 12345,
        );
        // ignore: avoid_print
        print(
          'OK   ${size.name}/${difficulty.name}: ${puzzle.cages.length} cages '
          'in ${sw.elapsedMilliseconds}ms',
        );
      } catch (e) {
        failures++;
        // ignore: avoid_print
        print('FAIL ${size.name}/${difficulty.name}: $e');
      }
    }
  }
  // ignore: avoid_print
  print(failures == 0 ? 'all generations succeeded' : '$failures failed');
}
