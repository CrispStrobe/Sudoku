// Runs the CSP-backed generators under the **web** number semantics.
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
// Every variant whose generator reaches the CSP solver belongs here, because
// each one uses a different set of constraints and it is the *constraint*
// implementation that trips over dart2js. KenKen was added for exactly that
// reason: it is the only variant using `addExactProduct` and `addTable`, so
// Killer and Thermo passing says nothing about it.
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
          'OK   killer ${size.name}/${difficulty.name}: '
          '${puzzle.cages.length} cages '
          'in ${sw.elapsedMilliseconds}ms',
        );
      } catch (e) {
        failures++;
        // ignore: avoid_print
        print('FAIL killer ${size.name}/${difficulty.name}: $e');
      }
    }
  }

  // KenKen: the only user of addExactProduct (multiplication cages) and
  // addTable (the enumerated pairs behind a - or / clue). Multiplication is
  // the interesting one under dart2js, where a product that overflows 2^53
  // stops being exact — a 9x9 five-cell cage can reach 9*8*7*6*5 = 15120, far
  // short of that, but the check costs nothing and the assumption is worth
  // pinning.
  for (final size in [GridSize.small, GridSize.medium, GridSize.standard]) {
    for (final difficulty in SudokuDifficulty.values) {
      final sw = Stopwatch()..start();
      try {
        final puzzle = await VariantEngine.generateKenKen(
          gridSize: size,
          difficulty: difficulty,
          seed: 12345,
        );
        if (!kenKenCagesSatisfied(puzzle.cages, puzzle.solution)) {
          failures++;
          // ignore: avoid_print
          print(
            'FAIL kenken ${size.name}/${difficulty.name}: the solution does '
            'not satisfy its own cages under dart2js arithmetic',
          );
          continue;
        }
        // ignore: avoid_print
        print(
          'OK   kenken ${size.name}/${difficulty.name}: '
          '${puzzle.cages.length} cages in ${sw.elapsedMilliseconds}ms',
        );
      } catch (e) {
        failures++;
        // ignore: avoid_print
        print('FAIL kenken ${size.name}/${difficulty.name}: $e');
      }
    }
  }

  // ignore: avoid_print
  print(failures == 0 ? 'all generations succeeded' : '$failures failed');
}
