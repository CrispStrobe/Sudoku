// Grid and Killer-cage painters, split out of main.dart: they are pure
// drawing code with no dependency on the screens that mount them.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'sudoku_game.dart';
import 'variant_engine.dart';
// ---------------------------------------------------------------------------

/// Draws Killer cages: a dashed inset border along each cage boundary and the
/// cage sum in the top-left cell.
class KillerCagePainter extends CustomPainter {
  final List<KillerCage> cages;
  final int gridDim;

  KillerCagePainter(this.cages, this.gridDim);

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / gridDim;
    // Everything here used to be a constant: a 4pt inset and a 1pt stroke,
    // whatever the cell. That is proportionate on the ~50pt cell of a 9x9
    // board on a tablet and absurd on the ~21pt cell of a 12x12 board on a
    // 320pt phone, where 4pt off each side eats two fifths of the cell and
    // leaves the cage outline a cramped box sitting inside the grid line.
    // Scale with the cell, with floors so the dashes stay visible at all.
    final inset = math.max(1.5, cell * 0.11);
    final stroke = math.max(0.8, cell * 0.025);
    // The sum label was `cell * 0.24` — about 5pt on that same 12x12 phone
    // cell, which is not readable, and the sum is the entire clue in Killer.
    final labelSize = math.max(7.0, cell * 0.3);
    final paint = Paint()
      ..color = Colors.black54
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;

    final cageOf = List.generate(gridDim, (_) => List.filled(gridDim, -1));
    for (var i = 0; i < cages.length; i++) {
      for (final c in cages[i].cells) {
        cageOf[c[0]][c[1]] = i;
      }
    }
    bool same(int r, int c, int idx) =>
        r >= 0 && r < gridDim && c >= 0 && c < gridDim && cageOf[r][c] == idx;

    for (var i = 0; i < cages.length; i++) {
      for (final pos in cages[i].cells) {
        final r = pos[0], c = pos[1];
        final left = c * cell + inset;
        final top = r * cell + inset;
        final right = (c + 1) * cell - inset;
        final bottom = (r + 1) * cell - inset;
        if (!same(r - 1, c, i)) {
          _dash(canvas, Offset(left, top), Offset(right, top), paint, cell);
        }
        if (!same(r + 1, c, i)) {
          _dash(
            canvas,
            Offset(left, bottom),
            Offset(right, bottom),
            paint,
            cell,
          );
        }
        if (!same(r, c - 1, i)) {
          _dash(canvas, Offset(left, top), Offset(left, bottom), paint, cell);
        }
        if (!same(r, c + 1, i)) {
          _dash(canvas, Offset(right, top), Offset(right, bottom), paint, cell);
        }
      }
      final anchor = cages[i].labelCell;
      final tp = TextPainter(
        text: TextSpan(
          text: '${cages[i].sum}',
          style: TextStyle(
            fontSize: labelSize,
            height: 1,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // A small white pad behind the label: the sum is drawn on top of the
      // cage's own dashed corner, and at a small cell size the two overlap
      // into an unreadable smudge.
      final origin = Offset(
        anchor[1] * cell + inset * 0.5,
        anchor[0] * cell + inset * 0.3,
      );
      canvas.drawRect(
        Rect.fromLTWH(origin.dx, origin.dy, tp.width + 1, tp.height),
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
      tp.paint(canvas, origin);
    }
  }

  void _dash(Canvas canvas, Offset a, Offset b, Paint paint, double cell) {
    // Dash and gap scale too, so a small cell gets a few clear dashes rather
    // than one long one, and a large cell does not look like a dotted line.
    final dash = math.max(2.0, cell * 0.14);
    final gap = math.max(1.5, cell * 0.1);
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final start = a + dir * d;
      final end = a + dir * math.min(d + dash, total);
      canvas.drawLine(start, end, paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant KillerCagePainter old) =>
      old.cages != cages || old.gridDim != gridDim;
}

class SudokuGridPainter extends CustomPainter {
  final int gridDim;
  final List<List<int>> regions;
  final bool jigsaw;

  SudokuGridPainter(this.gridDim, this.regions, {this.jigsaw = false});

  @override
  void paint(Canvas canvas, Size size) {
    final cellSize = size.width / gridDim;
    if (jigsaw) {
      _drawJigsawGrid(canvas, size, cellSize);
    } else {
      _drawStandardGrid(canvas, size, cellSize);
    }
  }

  void _drawStandardGrid(Canvas canvas, Size size, double cellSize) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1;
    final thickPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3;

    final box = boxDimensionsFor(gridDim);
    final rowsPerBox = box[0];
    final colsPerBox = box[1];

    for (var i = 0; i <= gridDim; i++) {
      canvas.drawLine(
        Offset(i * cellSize, 0),
        Offset(i * cellSize, size.height),
        i % colsPerBox == 0 ? thickPaint : paint,
      );
      canvas.drawLine(
        Offset(0, i * cellSize),
        Offset(size.width, i * cellSize),
        i % rowsPerBox == 0 ? thickPaint : paint,
      );
    }
  }

  void _drawJigsawGrid(Canvas canvas, Size size, double cellSize) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var row = 0; row < gridDim; row++) {
      for (var col = 0; col < gridDim; col++) {
        final region = regions[row][col];
        final left = col * cellSize;
        final top = row * cellSize;
        final right = left + cellSize;
        final bottom = top + cellSize;

        if (row == 0 || regions[row - 1][col] != region) {
          canvas.drawLine(Offset(left, top), Offset(right, top), paint);
        }
        if (row == gridDim - 1 || regions[row + 1][col] != region) {
          canvas.drawLine(Offset(left, bottom), Offset(right, bottom), paint);
        }
        if (col == 0 || regions[row][col - 1] != region) {
          canvas.drawLine(Offset(left, top), Offset(left, bottom), paint);
        }
        if (col == gridDim - 1 || regions[row][col + 1] != region) {
          canvas.drawLine(Offset(right, top), Offset(right, bottom), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(SudokuGridPainter oldDelegate) =>
      oldDelegate.gridDim != gridDim ||
      oldDelegate.jigsaw != jigsaw ||
      !identical(oldDelegate.regions, regions);
}
