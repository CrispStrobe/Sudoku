import 'package:flutter_test/flutter_test.dart';

import 'support/independent_uniqueness.dart';

void main() {
  const regions = [
    [0, 0, 1, 1],
    [0, 0, 1, 1],
    [2, 2, 3, 3],
    [2, 2, 3, 3],
  ];
  const solved = [
    [1, 2, 3, 4],
    [3, 4, 1, 2],
    [2, 1, 4, 3],
    [4, 3, 2, 1],
  ];

  test('rejects conflicting givens as unsatisfiable, not unique', () {
    final givens = solved.map((row) => row.toList()).toList();
    givens[0][0] = 2;
    final result = verifyUnique(givens, regions);
    expect(result.solutionsFound, 0);
    expect(result.budgetExhausted, isFalse);
    expect(result.isUnique, isFalse);
  });

  test('stops at two completions for an ambiguous board', () {
    final result = verifyUnique(
      List.generate(4, (_) => List.filled(4, 0)),
      regions,
    );
    expect(result.solutionsFound, 2);
    expect(result.budgetExhausted, isFalse);
    expect(result.isUnique, isFalse);
  });

  test('exhaustion before a solution never proves uniqueness', () {
    final result = verifyUnique(solved, regions, maxNodes: 0);
    expect(result.visitedNodes, 0);
    expect(result.solutionsFound, 0);
    expect(result.budgetExhausted, isTrue);
    expect(result.isUnique, isFalse);
  });

  test('exhaustion after one completion never proves uniqueness', () {
    final result = verifyUnique(
      List.generate(4, (_) => List.filled(4, 0)),
      regions,
      maxNodes: 17,
    );
    expect(result.visitedNodes, 17);
    expect(result.solutionsFound, 1);
    expect(result.budgetExhausted, isTrue);
    expect(result.isUnique, isFalse);
  });

  test('finishing at the node limit is a proof, not exhaustion', () {
    final result = verifyUnique(solved, regions, maxNodes: 17);
    expect(result.visitedNodes, 17);
    expect(result.budgetExhausted, isFalse);
    expect(result.isUnique, isTrue);
  });

  test('uses supplied regions rather than assuming rectangular boxes', () {
    // A Latin square invalid for 2x2 boxes, valid for these irregular regions.
    const latin = [
      [1, 2, 3, 4],
      [2, 3, 4, 1],
      [3, 4, 1, 2],
      [4, 1, 2, 3],
    ];
    const irregular = [
      [0, 0, 0, 0],
      [1, 1, 2, 1],
      [2, 1, 2, 2],
      [3, 3, 3, 3],
    ];
    expect(verifyUnique(latin, irregular).isUnique, isTrue);
    expect(verifyUnique(latin, regions).isUnique, isFalse);
  });

  test('rejects malformed dimensions, values, regions and budgets', () {
    expect(() => verifyUnique([], []), throwsArgumentError);
    expect(
      () => verifyUnique([
        [1],
      ], regions),
      throwsArgumentError,
    );
    expect(
      () => verifyUnique(
        [
          [2],
        ],
        [
          [0],
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => verifyUnique(
        [
          [0],
        ],
        [
          [1],
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => verifyUnique(solved, List.generate(4, (_) => List.filled(4, 0))),
      throwsArgumentError,
    );
    expect(
      () => verifyUnique(solved, regions, maxNodes: -1),
      throwsArgumentError,
    );
  });

  test('independent verifier proves a one-hole board unique', () {
    final givens = solved.map((row) => row.toList()).toList();
    givens[0][0] = 0;
    final result = verifyUnique(givens, regions);
    expect(result.isUnique, isTrue);
    expect(result.solutionsFound, 1);
    expect(result.budgetExhausted, isFalse);
    expect(result.firstSolution, solved);
    expect(givens[0][0], 0, reason: 'Verification must not mutate the input');
  });
}
