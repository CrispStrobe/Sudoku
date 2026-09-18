import 'dart:async';

import 'package:dart_csp/dart_csp.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku/variant_engine.dart';

Future<int> microtasksFor(Future<void> Function() action) async {
  var count = 0;
  await runZoned(
    action,
    zoneSpecification: ZoneSpecification(
      scheduleMicrotask: (self, parent, zone, task) {
        count++;
        parent.scheduleMicrotask(zone, task);
      },
    ),
  );
  return count;
}

void main() {
  // A complete 1-cell CSP isolates the duplicate-search overhead without
  // wall-clock thresholds, CPU load, random search trees, or solver mocks.
  test('uniqueness uses no more work than one bounded enumeration', () async {
    final problem = Problem()
      ..addVariable('r0c0', [1])
      ..addAllDifferent(['r0c0'], label: 'row0')
      ..addAllDifferent(['r0c0'], label: 'col0')
      ..addAllDifferent(['r0c0'], label: 'region0')
      ..addExactSum(['r0c0'], 1, label: 'cageSum0');
    final reference = await microtasksFor(() async {
      expect(await problem.getFirstNSolutions(2), hasLength(1));
    });
    final actual = await microtasksFor(() async {
      expect(
        await VariantEngine.killerHasUniqueSolution(
          gridDim: 1,
          regions: [
            [0],
          ],
          cages: [
            const KillerCage(
              cells: [
                [0, 0],
              ],
              sum: 1,
            ),
          ],
          givens: [
            [0],
          ],
        ),
        isTrue,
      );
    });
    expect(
      actual,
      lessThanOrEqualTo(reference),
      reason: 'Do not solve once before enumerating the same CSP again',
    );
  });

  for (final entry in {'zero': 3, 'one': 1, 'multiple': null}.entries) {
    test('${entry.key} solutions are classified correctly', () async {
      final unique = await VariantEngine.killerHasUniqueSolution(
        gridDim: 2,
        regions: [
          [0, 0],
          [1, 1],
        ],
        cages: entry.value == null
            ? []
            : [
                KillerCage(
                  cells: [
                    [0, 0],
                  ],
                  sum: entry.value!,
                ),
              ],
        givens: [
          [0, 0],
          [0, 0],
        ],
      );
      expect(unique, entry.key == 'one');
    });
  }
}
