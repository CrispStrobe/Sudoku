import 'dart:async';

import 'package:flutter/material.dart';

import 'game_stats.dart';
import 'l10n/app_localizations.dart';
import 'painters.dart';
import 'technique_labels.dart';
import 'technique_solver.dart';

// ---------------------------------------------------------------------------
// Explain-the-solve walkthrough
// ---------------------------------------------------------------------------

/// A read-only, step-by-step replay that solves a board with human techniques
/// (via [TechniqueSolver]) and narrates each deduction. Navigate with
/// prev/next or auto-play.
class ExplainScreen extends StatefulWidget {
  final List<List<int>> grid;
  final List<List<int>> regions;
  final int gridDim;
  final bool jigsaw;
  final bool diagonal;
  final EnvironmentalTheme scheme;

  const ExplainScreen({
    super.key,
    required this.grid,
    required this.regions,
    required this.gridDim,
    required this.jigsaw,
    required this.diagonal,
    required this.scheme,
  });

  @override
  State<ExplainScreen> createState() => _ExplainScreenState();
}

class _ExplainScreenState extends State<ExplainScreen> {
  late final TechniqueSolveResult _result;

  /// Board snapshots: `_boards[i]` is the grid after `i` steps (index 0 = start).
  late final List<List<List<int>>> _boards;

  int _index = 0;
  Timer? _autoplay;

  @override
  void initState() {
    super.initState();
    _result = TechniqueSolver(
      widget.grid,
      widget.regions,
      diagonal: widget.diagonal,
    ).solve();
    _boards = [widget.grid.map((r) => List<int>.from(r)).toList()];
    for (final step in _result.steps) {
      final next = _boards.last.map((r) => List<int>.from(r)).toList();
      if (step.value != null) next[step.cell[0]][step.cell[1]] = step.value!;
      _boards.add(next);
    }
  }

  @override
  void dispose() {
    _autoplay?.cancel();
    super.dispose();
  }

  int get _stepCount => _result.steps.length;

  void _go(int to) {
    setState(() => _index = to.clamp(0, _stepCount));
  }

  void _toggleAutoplay() {
    if (_autoplay != null) {
      _autoplay!.cancel();
      setState(() => _autoplay = null);
      return;
    }
    if (_index >= _stepCount) _go(0);
    setState(() {
      _autoplay = Timer.periodic(const Duration(milliseconds: 1100), (t) {
        if (_index >= _stepCount) {
          t.cancel();
          setState(() => _autoplay = null);
        } else {
          _go(_index + 1);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = widget.scheme;
    // The step that produced the current board (null at the start position).
    final step = _index == 0 ? null : _result.steps[_index - 1];
    final caption = step == null
        ? (_stepCount == 0
              ? l10n.explainNoStepsNeeded
              : l10n.explainStartingPosition(_stepCount))
        : step.explanationFor(l10n.localeName);
    final atEnd = _index >= _stepCount;
    final finishedNote = atEnd && _stepCount > 0
        ? (_result.solved
              ? l10n.explainSolvedNote(techniqueLabel(context, _result.hardest))
              : l10n.explainStuckNote)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.explainAppBarTitle),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: scheme.gradient,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  _index == 0
                      ? l10n.explainStart
                      : l10n.explainStepOf(_index, _stepCount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: _ExplainGrid(
                        board: _boards[_index],
                        regions: widget.regions,
                        gridDim: widget.gridDim,
                        jigsaw: widget.jigsaw,
                        diagonal: widget.diagonal,
                        highlight: step?.cell,
                        eliminations: step?.eliminations ?? const [],
                        scheme: scheme,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (step != null)
                          Text(
                            techniqueLabel(context, step.technique),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: scheme.primary,
                            ),
                          ),
                        Text(caption, textAlign: TextAlign.center),
                        if (finishedNote != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            finishedNote,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton.filled(
                      onPressed: _index > 0 ? () => _go(_index - 1) : null,
                      icon: const Icon(Icons.skip_previous),
                      tooltip: l10n.explainPreviousTooltip,
                    ),
                    IconButton.filled(
                      onPressed: _stepCount == 0 ? null : _toggleAutoplay,
                      icon: Icon(
                        _autoplay == null ? Icons.play_arrow : Icons.pause,
                      ),
                      tooltip: _autoplay == null
                          ? l10n.explainPlayTooltip
                          : l10n.explainPauseTooltip,
                    ),
                    IconButton.filled(
                      onPressed: _index < _stepCount
                          ? () => _go(_index + 1)
                          : null,
                      icon: const Icon(Icons.skip_next),
                      tooltip: l10n.explainNextTooltip,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Read-only Sudoku grid for the explain screen: values + a highlighted cell
/// and any eliminated-candidate cells, drawn over [SudokuGridPainter] lines.
class _ExplainGrid extends StatelessWidget {
  final List<List<int>> board;
  final List<List<int>> regions;
  final int gridDim;
  final bool jigsaw;
  final bool diagonal;
  final List<int>? highlight;
  final List<List<int>> eliminations;
  final EnvironmentalTheme scheme;

  const _ExplainGrid({
    required this.board,
    required this.regions,
    required this.gridDim,
    required this.jigsaw,
    required this.diagonal,
    required this.highlight,
    required this.eliminations,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final elimCells = {for (final e in eliminations) '${e[0]}-${e[1]}'};
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, border: Border.all()),
      child: Stack(
        children: [
          Column(
            children: [
              for (var r = 0; r < gridDim; r++)
                Expanded(
                  child: Row(
                    children: [
                      for (var c = 0; c < gridDim; c++)
                        Expanded(child: _cell(r, c, elimCells)),
                    ],
                  ),
                ),
            ],
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: SudokuGridPainter(gridDim, regions, jigsaw: jigsaw),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(int r, int c, Set<String> elimCells) {
    final isHighlight =
        highlight != null && highlight![0] == r && highlight![1] == c;
    final isElim = elimCells.contains('$r-$c');
    final onDiag = diagonal && (r == c || r + c == gridDim - 1);
    final v = board[r][c];
    return Container(
      alignment: Alignment.center,
      color: isHighlight
          ? scheme.accent
          : (isElim
                ? Colors.red.shade100
                : (onDiag ? const Color(0xFFEDE7F6) : Colors.transparent)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          v == 0 ? '' : '$v',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isHighlight ? Colors.black : Colors.black87,
          ),
        ),
      ),
    );
  }
}
