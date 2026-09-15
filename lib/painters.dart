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
    const inset = 4.0;
    final paint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1.0
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
          _dash(canvas, Offset(left, top), Offset(right, top), paint);
        }
        if (!same(r + 1, c, i)) {
          _dash(canvas, Offset(left, bottom), Offset(right, bottom), paint);
        }
        if (!same(r, c - 1, i)) {
          _dash(canvas, Offset(left, top), Offset(left, bottom), paint);
        }
        if (!same(r, c + 1, i)) {
          _dash(canvas, Offset(right, top), Offset(right, bottom), paint);
        }
      }
      final anchor = cages[i].labelCell;
      final tp = TextPainter(
        text: TextSpan(
          text: '${cages[i].sum}',
          style: TextStyle(
            fontSize: cell * 0.24,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(anchor[1] * cell + inset + 1, anchor[0] * cell + inset),
      );
    }
  }

  void _dash(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 4.0, gap = 3.0;
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
