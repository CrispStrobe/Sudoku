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

  /// The family the cage sums are drawn in.
  ///
  /// A `TextPainter` never sees the widget tree, so with this left null the
  /// sums render in whatever the platform's default happens to be — which
  /// matches the rest of the UI on a device by luck rather than by
  /// construction, and does not match it at all under a renderer that
  /// substitutes its own default (the App Store screenshot harness drew every
  /// sum as a filled box). The screen passes the theme's family in.
  final String? fontFamily;

  KillerCagePainter(this.cages, this.gridDim, {this.fontFamily});

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
            fontFamily: fontFamily,
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
      old.cages != cages ||
      old.gridDim != gridDim ||
      old.fontFamily != fontFamily;
}

/// Draws Thermo thermometers: a filled bulb at the start of each line and a
/// rounded bar running through the cells to the tip.
///
/// Painted *under* the cells rather than over them, which is the opposite of
/// [KillerCagePainter]. A cage is a thin dashed outline near the cell edges and
/// can sit on top without hiding anything; a thermometer is a thick bar through
/// the middle of the cell, exactly where the digit goes. Cells on a line render
/// their background translucent so this shows through (see
/// `_GameScreenState._getCellColor`), and the digits stay fully opaque on top.
class ThermoPainter extends CustomPainter {
  final List<ThermoLine> thermos;
  final int gridDim;
  final Color color;

  ThermoPainter(this.thermos, this.gridDim, {required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / gridDim;
    // Everything scales with the cell, for the reason recorded in
    // KillerCagePainter: a constant looks right at one grid size only.
    final barWidth = cell * 0.42;
    final bulbRadius = cell * 0.32;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bulbPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    Offset centre(List<int> c) =>
        Offset((c[1] + 0.5) * cell, (c[0] + 0.5) * cell);

    for (final thermo in thermos) {
      if (thermo.cells.length < 2) continue;
      final path = Path()
        ..moveTo(centre(thermo.cells.first).dx, centre(thermo.cells.first).dy);
      for (final c in thermo.cells.skip(1)) {
        final o = centre(c);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, paint);
      // The bulb marks which end is the small one — without it the line is
      // ambiguous, and a thermometer read backwards is a different puzzle.
      canvas.drawCircle(centre(thermo.cells.first), bulbRadius, bulbPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ThermoPainter old) =>
      old.thermos != thermos || old.gridDim != gridDim || old.color != color;
}

/// Draws KenKen cages: a heavy solid border around each cage and its clue
/// ("12+", "3−", "2÷") in the cage's top-left cell.
///
/// Solid and on the cell boundary, where [KillerCagePainter] is dashed and
/// inset. The two variants look different on purpose: a Killer cage sits
/// *inside* a grid whose boxes are already drawn, so it has to be visually
/// distinct from them, while a KenKen board has no boxes at all and its cage
/// borders are the only heavy lines on it.
class KenKenCagePainter extends CustomPainter {
  final List<KenKenCage> cages;
  final int gridDim;
  final String? fontFamily;

  KenKenCagePainter(this.cages, this.gridDim, {this.fontFamily});

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / gridDim;
    final stroke = math.max(1.5, cell * 0.055);
    final clueSize = math.max(7.0, cell * 0.27);
    final paint = Paint()
      ..color = Colors.black87
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square
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
        final left = c * cell;
        final top = r * cell;
        final right = left + cell;
        final bottom = top + cell;
        if (!same(r - 1, c, i)) {
          canvas.drawLine(Offset(left, top), Offset(right, top), paint);
        }
        if (!same(r + 1, c, i)) {
          canvas.drawLine(Offset(left, bottom), Offset(right, bottom), paint);
        }
        if (!same(r, c - 1, i)) {
          canvas.drawLine(Offset(left, top), Offset(left, bottom), paint);
        }
        if (!same(r, c + 1, i)) {
          canvas.drawLine(Offset(right, top), Offset(right, bottom), paint);
        }
      }

      final anchor = cages[i].labelCell;
      TextPainter clueAt(double fontSize) => TextPainter(
        text: TextSpan(
          text: cages[i].clue,
          style: TextStyle(
            fontSize: fontSize,
            height: 1,
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            // Explicit, for the reason recorded on KillerCagePainter: a
            // TextPainter never sees the theme.
            fontFamily: fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      var tp = clueAt(clueSize);
      // A clue is as wide as its number, and a five-cell multiplication cage
      // reaches five digits: "24192x" is six characters in a cell that is 33pt
      // on a 9x9 phone board. Size the label from the cell it has to live in,
      // not from a constant — otherwise the widest clues run into the next
      // cage, and one that lands in the last column runs off the board. (Same
      // rule as the number pad and the pencil marks: size from the box.)
      final maxClueWidth = cell - stroke - 3;
      if (tp.width > maxClueWidth) {
        tp = clueAt(clueSize * maxClueWidth / tp.width);
      }
      final origin = Offset(
        anchor[1] * cell + stroke + 1,
        anchor[0] * cell + stroke,
      );
      // The clue sits over the cage's own corner; a pad keeps it readable.
      canvas.drawRect(
        Rect.fromLTWH(origin.dx, origin.dy, tp.width + 2, tp.height),
        Paint()..color = Colors.white.withValues(alpha: 0.85),
      );
      tp.paint(canvas, origin);
    }
  }

  @override
  bool shouldRepaint(covariant KenKenCagePainter old) =>
      old.cages != cages ||
      old.gridDim != gridDim ||
      old.fontFamily != fontFamily;
}

class SudokuGridPainter extends CustomPainter {
  final int gridDim;
  final List<List<int>> regions;
  final bool jigsaw;

  /// Draw a plain lattice with no box emphasis.
  ///
  /// KenKen is a Latin square: it has rows and columns and no boxes at all, so
  /// the heavy every-third-line rule would draw a structure the puzzle does not
  /// have, and the player would reasonably read it as a rule.
  final bool latin;

  SudokuGridPainter(
    this.gridDim,
    this.regions, {
    this.jigsaw = false,
    this.latin = false,
  });

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
    // In latin mode only the outer edge is heavy; the cage painter draws the
    // structure that actually matters.
    final rowsPerBox = latin ? gridDim : box[0];
    final colsPerBox = latin ? gridDim : box[1];

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
      oldDelegate.latin != latin ||
      !identical(oldDelegate.regions, regions);
}
