import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'achievements.dart';
import 'clock_format.dart';
import 'explain_screen.dart';
import 'game_clock.dart';
import 'game_stats.dart';
import 'l10n/app_localizations.dart';
import 'painters.dart';
import 'particles.dart';
import 'ready_puzzle.dart';
import 'services.dart';
import 'saved_game.dart';
import 'saved_game_service.dart';
import 'sudoku_game.dart';
import 'technique_labels.dart';
import 'technique_solver.dart';
import 'variant_engine.dart';

// ---------------------------------------------------------------------------
// Game screen
// ---------------------------------------------------------------------------

/// Number-pad metrics, shared between the height [_GameScreenState.build]
/// reserves for the pad and the grid laid out inside it — computing them in two
/// places is how the pad ends up sized for tiles it does not actually draw.
const double _kPadSpacing = 8.0;
const double _kPadPadding = 16.0;

/// The chrome metrics that surround the board, derived from the viewport.
///
/// On a roomy phone every one of these can afford its comfortable value. On a
/// small/old iPhone (a 320x568 SE, a 375x667 6/7/8) they cannot: the padding,
/// the inter-row gaps and the number pad were together eating roughly 300 of
/// the 512 points below the app bar, which left the board — the only thing on
/// the screen anyone is actually looking at — about 160 points to live in, half
/// the available width, with slack it was not allowed to use. Every point these
/// give back goes straight into [_GameScreenState._buildSudokuGrid].
class _ChromeMetrics {
  const _ChromeMetrics({
    required this.isTablet,
    required this.isCompact,
    required this.outerPadding,
    required this.gap,
    required this.padPadding,
    required this.padSpacing,
    required this.idealPadTile,
    required this.controlDiameter,
    required this.controlIconSize,
    required this.maxGridSize,
  });

  /// Chooses the metrics for a viewport of [size] (the whole window, which is
  /// what the outer padding is applied to — the board's own box is measured
  /// separately by its `LayoutBuilder`).
  factory _ChromeMetrics.forViewport(Size size) {
    final isTablet = size.width > 600;
    // "Compact" is the small/old iPhone class and any short landscape window:
    // not enough height to spend on chrome, and not enough width for the
    // control row's five buttons at their comfortable size.
    final isCompact =
        !isTablet &&
        (size.width < 400 || size.shortestSide < 360 || size.height < 700);
    if (isTablet) {
      return const _ChromeMetrics(
        isTablet: true,
        isCompact: false,
        outerPadding: 24,
        gap: 12,
        padPadding: _kPadPadding,
        padSpacing: _kPadSpacing,
        idealPadTile: 64,
        controlDiameter: 52,
        controlIconSize: 24,
        maxGridSize: 560,
      );
    }
    if (isCompact) {
      return const _ChromeMetrics(
        isTablet: false,
        isCompact: true,
        outerPadding: 10,
        // 6pt between blocks instead of 8/16/10: three gaps, ~22 points back.
        gap: 6,
        padPadding: 10,
        padSpacing: 6,
        // Still above Apple's 44pt minimum tap target.
        idealPadTile: 46,
        // A 40pt circle keeps the five-button row inside 320 points while
        // staying tappable.
        controlDiameter: 40,
        controlIconSize: 20,
        maxGridSize: 420,
      );
    }
    return const _ChromeMetrics(
      isTablet: false,
      isCompact: false,
      outerPadding: 16,
      gap: 10,
      padPadding: _kPadPadding,
      padSpacing: _kPadSpacing,
      idealPadTile: 52,
      controlDiameter: 48,
      controlIconSize: 24,
      maxGridSize: 460,
    );
  }

  final bool isTablet;
  final bool isCompact;
  final double outerPadding;
  final double gap;
  final double padPadding;
  final double padSpacing;
  final double idealPadTile;
  final double controlDiameter;
  final double controlIconSize;

  /// Upper bound on the board's edge. It exists only to stop the board turning
  /// into a wall-sized grid on a desktop window; on a phone the viewport is
  /// always the binding constraint, so this must never be the thing that caps
  /// a phone board (the old 320pt phone cap did exactly that on a 390pt or
  /// 430pt iPhone).
  final double maxGridSize;
}

class GameScreen extends StatefulWidget {
  final SudokuDifficulty difficulty;
  final GridSize gridSize;
  final GridShape gridShape;
  final GameMode gameMode;
  final SavedGame? savedGame;

  /// When set, the board is generated deterministically from this seed (the
  /// daily puzzle) instead of pulled from the random cache/generator.
  final int? dailySeed;

  /// `YYYY-MM-DD` of the daily puzzle; non-null marks this as the daily run.
  final String? dailyKey;

  /// Rule variant (classic or Sudoku-X).
  final SudokuVariant variant;

  const GameScreen({
    super.key,
    required this.difficulty,
    required this.gridSize,
    required this.gridShape,
    required this.gameMode,
    this.savedGame,
    this.dailySeed,
    this.dailyKey,
    this.variant = SudokuVariant.classic,
  });

  GameScreen.resume(SavedGame saved, {super.key})
    : savedGame = saved,
      difficulty = saved.difficulty,
      gridSize = saved.size,
      gridShape = saved.shape,
      gameMode = saved.gameMode,
      dailySeed = saved.dailySeed,
      dailyKey = saved.dailyKey,
      variant = saved.variant;

  bool get isDaily => dailyKey != null;
  bool get isDiagonal => variant == SudokuVariant.x;
  bool get isKiller => variant == SudokuVariant.killer;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  SudokuGame? game;
  int? selectedRow;
  int? selectedCol;

  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;

  final GlobalKey<ParticleLayerState> _particleKey =
      GlobalKey<ParticleLayerState>();

  int hintsUsed = 0;
  int score = 1000;
  int mistakes = 0;
  bool _notesMode = false;

  /// Difficulty of the current board as rated by the logical-technique solver
  /// (distinct from the generation difficulty, which is hole-count based).
  SudokuDifficulty? _logicRating;

  /// Killer cages for the current board (empty unless the Killer variant).
  List<KillerCage> _cages = const [];

  /// Score cost of revealing the next logical step.
  static const int _nextStepPenalty = 40;

  int get _maxMistakes => maxMistakesFor(widget.difficulty);
  int get _maxHints => maxHintsFor(widget.difficulty);
  int get _hintsRemaining => math.max(0, _maxHints - hintsUsed);

  final GameClock _clock = GameClock();

  bool _hasError = false;
  bool _finished = false;
  bool _background = false;
  bool _explaining = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _background =
        WidgetsBinding.instance.lifecycleState != null &&
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed;
    _initializeAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeGame());
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
  }

  void _startGameTimer({Duration initialElapsed = Duration.zero}) {
    _clock.start(initialElapsed: initialElapsed);
    if (_background || _explaining || _finished) _clock.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasBackground = _background;
    _background = state != AppLifecycleState.resumed;
    if (_background) {
      _stopGameTimer();
      _saveGame();
    } else if (wasBackground && !_finished && !_explaining && game != null) {
      _startGameTimer(initialElapsed: _clock.elapsed.value);
    }
  }

  void _finishRun() {
    _finished = true;
    _stopGameTimer();
    unawaited(SavedGameService().clear());
  }

  void _stopGameTimer() => _clock.stop();

  void _saveGame() {
    final g = game;
    if (g == null || _finished) return;
    unawaited(
      SavedGameService().save(
        SavedGame.capture(
          game: g,
          size: widget.gridSize,
          shape: widget.gridShape,
          gameMode: widget.gameMode,
          elapsed: _clock.currentElapsed,
          score: score,
          mistakes: mistakes,
          hintsUsed: hintsUsed,
          dailySeed: widget.dailySeed,
          dailyKey: widget.dailyKey,
          rating: _logicRating,
          cages: _cages,
          notesMode: _notesMode,
        ),
      ),
    );
  }

  String _formatDuration(Duration d) => formatClock(d);

  /// The variant's own name, for the app-bar title. Classic never reaches here
  /// (the title omits the variant entirely for it).
  String _variantLabel(AppLocalizations l10n) {
    switch (widget.variant) {
      case SudokuVariant.classic:
        return l10n.variantClassic;
      case SudokuVariant.x:
        return l10n.variantSudokuX;
      case SudokuVariant.killer:
        return l10n.variantKiller;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_hasError && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.failedToCreatePuzzle),
            ),
          );
          _hasError = false;
        }
      });
    }
  }

  Future<SudokuGame> _generatePuzzleWithRetries() async {
    // The web has no Isolate.spawn, so generate inline on the main thread
    // (bounded by the engine's internal budgets). A microtask yield lets the
    // loading indicator paint first.
    if (kIsWeb) {
      await Future<void>.delayed(Duration.zero);
      return SudokuGame.generate(
        widget.difficulty,
        widget.gridSize,
        widget.gridShape,
        variant: widget.variant,
      );
    }

    const totalBudget = Duration(seconds: 24);
    const maxAttempts = 3;
    final stopwatch = Stopwatch()..start();
    Object? lastError;
    for (
      var attempt = 1;
      attempt <= maxAttempts && stopwatch.elapsed < totalBudget;
      attempt++
    ) {
      try {
        return await SudokuGame.create(
          widget.difficulty,
          widget.gridSize,
          widget.gridShape,
          timeout: const Duration(seconds: 12),
          variant: widget.variant,
        );
      } catch (e) {
        lastError = e;
        DebugLogger.log('Generation attempt $attempt failed; retrying.');
      }
    }
    throw TimeoutException('Failed to generate a puzzle: $lastError');
  }

  Future<void> _initializeGame() async {
    if (!mounted) return;
    final saved = widget.savedGame;
    if (saved != null && game == null) {
      game = saved.createGame();
      score = saved.score;
      mistakes = saved.mistakes;
      hintsUsed = saved.hintsUsed;
      _cages = saved.cages;
      _logicRating = saved.rating;
      _notesMode = saved.notesMode;
      _startGameTimer(initialElapsed: saved.elapsed);
      setState(() {});
      return;
    }
    _finished = false;
    try {
      setState(() => game = null);

      SudokuGame? built;
      ReadyPuzzle? ready;
      _cages = const [];
      if (widget.isKiller) {
        // Killer uses the CSP solver for cage sums, without the classic cache.
        // Search time depends on the partition and can take several seconds.
        final puzzle = await VariantEngine.generateKiller(
          gridSize: widget.gridSize,
          difficulty: widget.difficulty,
        );
        if (!mounted) return;
        _cages = puzzle.cages;
        built = SudokuGame.fromState(
          givens: puzzle.givens,
          solution: puzzle.solution,
          regions: puzzle.regions,
          difficulty: widget.difficulty,
          variant: SudokuVariant.killer,
        );
      } else if (widget.dailySeed != null) {
        // Deterministic, cache-free generation so the daily board is identical
        // for every player and every replay. 9×9 classic generates instantly.
        built = SudokuGame.generate(
          widget.difficulty,
          widget.gridSize,
          widget.gridShape,
          seed: widget.dailySeed,
        );
      } else if (GameStats.useSavedPuzzles &&
          widget.variant == SudokuVariant.classic) {
        ready = ReadyPuzzleCache().get(
          widget.gridSize,
          widget.gridShape,
          widget.difficulty,
        );
        if (ready != null) {
          built = ready.createGame();
        } else {
          final blueprint = PuzzleCache().getRandom(
            widget.gridSize,
            widget.gridShape,
          );
          if (blueprint != null) {
            built = SudokuGame.fromBlueprint(blueprint, widget.difficulty);
          }
        }
      }

      if (built == null) {
        built = await _generatePuzzleWithRetries();
        if (!mounted) return;
        // Cache the freshly generated solution so future plays are instant.
        if (GameStats.useSavedPuzzles &&
            widget.variant == SudokuVariant.classic) {
          await PuzzleCache().set(
            PuzzleBlueprint(
              solutionGrid: built.solution,
              regions: built.regions,
              gridSize: widget.gridSize,
              gridShape: widget.gridShape,
            ),
          );
        }
      }

      // The await above may have resolved after this State was disposed
      // (left screen mid-generation): commit nothing to the disposed clock.
      if (!mounted) return;
      game = built;
      _startGameTimer();
      score = _calculateInitialScore();
      mistakes = 0;
      if (ready != null) {
        _logicRating = ready.rating;
      } else {
        _updateLogicRating();
      }
      setState(() {});
      _saveGame();
      if (ready == null &&
          GameStats.useSavedPuzzles &&
          widget.dailySeed == null &&
          widget.variant == SudokuVariant.classic) {
        unawaited(
          ReadyPuzzleCache().add(
            ReadyPuzzle.fromGame(
              built,
              widget.gridSize,
              widget.gridShape,
              rating: _logicRating,
            ),
          ),
        );
      }
    } catch (e, st) {
      if (!mounted) return;
      if (widget.isKiller) {
        // A Killer board without cages is not a Killer board — it is a classic
        // puzzle wearing the label, with the hint and explain buttons disabled
        // because the screen still believes it is Killer. That is strictly
        // worse than an error: it looks like a working game and is not the one
        // the player asked for, so it hid a dart2js crash in the CSP solver
        // for an entire release. Surface the failure instead.
        DebugLogger.error(
          'Killer generation failed; no classic fallback.',
          e,
          st,
        );
        setState(() => _hasError = true);
        return;
      }
      DebugLogger.error('Generation failed; falling back to classic.', e, st);
      try {
        final SudokuGame fallback = kIsWeb
            ? SudokuGame.generate(
                widget.difficulty,
                widget.gridSize,
                GridShape.classic,
              )
            : await SudokuGame.create(
                widget.difficulty,
                widget.gridSize,
                GridShape.classic,
              );
        if (!mounted) return;
        game = fallback;
        _cages = const [];
        _startGameTimer();
        score = _calculateInitialScore();
        mistakes = 0;
        _updateLogicRating();
        setState(() {});
        _saveGame();
      } catch (e2, st2) {
        DebugLogger.error('Fallback also failed.', e2, st2);
        if (mounted) {
          setState(() => _hasError = true);
        }
      }
    }
  }

  int _calculateInitialScore() {
    var base = 500;
    base += switch (widget.gridSize) {
      GridSize.small => 200,
      GridSize.medium => 400,
      GridSize.large => 600,
      GridSize.standard => 800,
      GridSize.big => 1000,
      GridSize.mega => 1200,
    };
    base += switch (widget.difficulty) {
      SudokuDifficulty.easy => 100,
      SudokuDifficulty.medium => 300,
      SudokuDifficulty.hard => 500,
      SudokuDifficulty.expert => 800,
    };
    if (widget.gridShape == GridShape.jigsaw) base += 200;
    return base;
  }

  /// Rate the current board by the hardest human technique it requires. Cheap
  /// (a few ms); recomputed whenever a new board is built.
  void _updateLogicRating() {
    final g = game;
    // The technique solver doesn't model cage sums, so it can't rate Killer.
    if (g == null || widget.isKiller) {
      _logicRating = null;
      return;
    }
    try {
      _logicRating = TechniqueSolver(
        g.grid,
        g.regions,
        diagonal: widget.isDiagonal,
      ).solve().rating;
    } catch (_) {
      _logicRating = null;
    }
  }

  /// Title-case difficulty label ("Easy", "Medium", ...) reusing the same
  /// localized difficulty strings as the picker sheet (which are all-caps,
  /// for buttons) rather than a separate set of ARB keys.
  static String _ratingLabel(BuildContext context, SudokuDifficulty d) {
    final l10n = AppLocalizations.of(context)!;
    final upper = switch (d) {
      SudokuDifficulty.easy => l10n.difficultyEasy,
      SudokuDifficulty.medium => l10n.difficultyMedium,
      SudokuDifficulty.hard => l10n.difficultyHard,
      SudokuDifficulty.expert => l10n.difficultyExpert,
    };
    final lower = upper.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopGameTimer();
    _saveGame();
    _clock.dispose();
    _pulseController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _selectCell(int row, int col) {
    setState(() {
      if (selectedRow == row && selectedCol == col) {
        selectedRow = null;
        selectedCol = null;
      } else {
        selectedRow = row;
        selectedCol = col;
      }
    });
    _pulseController.forward().then((_) => _pulseController.reverse());
  }

  /// Number-pad tap: toggles a note in notes mode, otherwise places the value.
  void _inputNumber(int number) {
    if (selectedRow == null || selectedCol == null) return;
    if (_notesMode) {
      setState(() => game?.toggleNote(selectedRow!, selectedCol!, number));
      _saveGame();
    } else {
      _placeValue(selectedRow!, selectedCol!, number);
    }
  }

  /// Places [number] at (row,col). Wrong (conflicting) moves are allowed — they
  /// stay on the board (highlighted) and cost score; the puzzle is won only
  /// when [SudokuGame.isSolved] holds.
  void _placeValue(int row, int col, int number) {
    final g = game;
    if (g == null || _finished || g.isOriginal[row][col]) return;
    final wasValid =
        g.isValidMove(row, col, number) &&
        _killerPlacementValid(row, col, number);
    setState(() => g.setCell(row, col, number));
    if (!wasValid) {
      _shakeController.forward().then((_) => _shakeController.reverse());
      setState(() {
        score = math.max(0, score - 25);
        mistakes++;
      });
      if (!GameStats.unlimitedMistakes && mistakes >= _maxMistakes) {
        _gameOver();
        return;
      }
    }
    if (_isWon()) _completeGame();
    _saveGame();
  }

  /// The cage containing (row,col), or null (always null off the Killer variant).
  KillerCage? _cageAt(int row, int col) {
    for (final cage in _cages) {
      if (cage.contains(row, col)) return cage;
    }
    return null;
  }

  /// True unless placing [number] would break (row,col)'s Killer cage (repeat
  /// digit or sum overflow). Always true off the Killer variant.
  bool _killerPlacementValid(int row, int col, int number) {
    if (!widget.isKiller) return true;
    final cage = _cageAt(row, col);
    if (cage == null) return true;
    final g = game!;
    final seen = <int>{number};
    var total = number, filled = 1;
    for (final cell in cage.cells) {
      if (cell[0] == row && cell[1] == col) continue;
      final v = g.grid[cell[0]][cell[1]];
      if (v == 0) continue;
      filled++;
      total += v;
      if (!seen.add(v)) return false;
    }
    if (total > cage.sum) return false;
    if (filled == cage.cells.length && total != cage.sum) return false;
    return true;
  }

  /// Win condition: standard full-and-consistent, plus every cage satisfied
  /// for Killer.
  bool _isWon() {
    final g = game;
    if (g == null || !g.isSolved()) return false;
    return !widget.isKiller || cagesSatisfied(_cages, g.grid);
  }

  /// Conflict highlight for a cell: standard conflicts, plus a Killer cage that
  /// currently has a repeated digit or an over/wrong sum.
  bool _cellConflict(int row, int col) {
    final g = game!;
    if (g.hasConflict(row, col)) return true;
    if (widget.isKiller) {
      final cage = _cageAt(row, col);
      if (cage != null && cage.hasError(g.grid)) return true;
    }
    return false;
  }

  void _clearCell() {
    if (selectedRow != null && selectedCol != null) {
      setState(() => game?.clearCell(selectedRow!, selectedCol!));
      _saveGame();
    }
  }

  void _undo() {
    final cell = game?.undo();
    if (cell != null) {
      setState(() {
        selectedRow = cell[0];
        selectedCol = cell[1];
      });
      _saveGame();
    }
  }

  void _toggleNotesMode() {
    setState(() => _notesMode = !_notesMode);
    _saveGame();
  }

  void _showHint() {
    if (_hintsRemaining == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.noHintsLeftSnackbar),
        ),
      );
      return;
    }
    if (game != null) _showHintDialog();
  }

  void _showHintDialog() {
    final l10n = AppLocalizations.of(context)!;
    // A board-wide "next logical step" (works with no cell selected), plus the
    // per-cell smart hints when a cell is selected.
    final perCell = (selectedRow != null && selectedCol != null)
        ? game!.getSmartHints(selectedRow!, selectedCol!)
        : <SmartHint>[];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.lightbulb, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(child: Text(l10n.smartHintsTitle)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                color: GameStats.current.cellHighlight,
                child: ListTile(
                  leading: const Icon(
                    Icons.auto_awesome,
                    color: Colors.deepPurple,
                  ),
                  title: Text(l10n.nextLogicalStepTitle),
                  subtitle: Text(l10n.nextLogicalStepSubtitle),
                  trailing: Text(
                    l10n.penaltyLabel(_nextStepPenalty),
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showNextStepHint();
                  },
                ),
              ),
              for (final hint in perCell)
                Card(
                  child: ListTile(
                    title: Text(hint.titleFor(l10n.localeName)),
                    subtitle: Text(hint.descriptionFor(l10n.localeName)),
                    trailing: Text(
                      hint.penalty > 0 ? l10n.penaltyLabel(hint.penalty) : '',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showHintConfirmation(hint);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compute the next logical deduction from the current board and present it.
  void _showNextStepHint() {
    final l10n = AppLocalizations.of(context)!;
    final g = game;
    if (g == null) return;
    final step = TechniqueSolver(
      g.grid,
      g.regions,
      diagonal: widget.isDiagonal,
    ).nextStep();
    if (step == null) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(l10n.noStepFoundTitle),
          content: Text(l10n.noStepFoundBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.okButton),
            ),
          ],
        ),
      );
      return;
    }
    final isPlacement = step.value != null;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(techniqueLabel(context, step.technique)),
        content: Text(step.explanationFor(l10n.localeName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancelButton),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _applyNextStep(step);
            },
            child: Text(
              isPlacement
                  ? l10n.placeItButton(_nextStepPenalty)
                  : l10n.gotItButton,
            ),
          ),
        ],
      ),
    );
  }

  /// Charge a hint and apply [step] — placing its value (placement steps) or
  /// just selecting the cell so the player can act on the explanation.
  void _applyNextStep(SolveStep step) {
    final g = game;
    if (g == null) return;
    setState(() {
      hintsUsed++;
      GameStats.totalHintsUsed++;
      score = math.max(0, score - _nextStepPenalty);
      selectedRow = step.cell[0];
      selectedCol = step.cell[1];
      if (step.value != null) {
        g.setCell(step.cell[0], step.cell[1], step.value!);
      }
    });
    if (_isWon()) _completeGame();
    _saveGame();
  }

  void _showHintConfirmation(SmartHint hint) {
    if (hint.penalty == 0) return;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(hint.titleFor(l10n.localeName)),
        content: Text(l10n.useHintConfirm(hint.penalty)),
        actions: [
          TextButton(
            child: Text(l10n.cancelButton),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: Text(l10n.confirmButton),
            onPressed: () {
              Navigator.pop(context);
              _applyHint(hint);
            },
          ),
        ],
      ),
    );
  }

  void _applyHint(SmartHint hint) {
    final l10n = AppLocalizations.of(context)!;
    final g = game;
    if (g == null) return;
    setState(() {
      score = math.max(0, score - hint.penalty);
      hintsUsed++;
      GameStats.totalHintsUsed++;
      switch (hint.type) {
        case HintType.showPossible:
          final numbers = (hint.data as List<int>).join(', ');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.possibleNumbersSnackbar(numbers))),
          );
          break;
        case HintType.giveAnswer:
        case HintType.nakedSingle:
        case HintType.hiddenSingle:
          g.setCell(selectedRow!, selectedCol!, hint.data as int);
          break;
        case HintType.conflict:
          break;
      }
    });
    if (_isWon()) _completeGame();
    _saveGame();
  }

  void _completeGame() {
    final g = game;
    if (g == null || _finished) return;
    _finishRun();

    final completionTime = _clock.elapsed.value;
    final timeBonus = math.max(0, 300 - completionTime.inSeconds ~/ 2);
    final finalScore = score + timeBonus;

    GameStats.totalPuzzlesSolved++;
    if (completionTime < GameStats.bestTime) {
      GameStats.bestTime = completionTime;
    }
    GameStats.currentStreak++;
    if (GameStats.currentStreak > GameStats.longestStreak) {
      GameStats.longestStreak = GameStats.currentStreak;
    }
    if (hintsUsed == 0 && widget.difficulty == SudokuDifficulty.hard) {
      GameStats.unlockedAchievements.add('no_hints_hard');
    }
    GameStats.recordSolve(
      difficulty: widget.difficulty,
      variant: widget.variant,
      size: widget.gridSize,
      shape: widget.gridShape,
      mistakes: mistakes,
      hintsUsed: hintsUsed,
    );
    if (widget.isDaily && GameStats.lastDailyDate != widget.dailyKey) {
      GameStats.lastDailyDate = widget.dailyKey;
      GameStats.dailyCompletedCount++;
    }
    AchievementSystem.checkAchievements();
    GameStats.save(); // persist solved count, streak, best time, unlocks

    setState(() => score = finalScore);
    _particleKey.currentState?.burst();
    _showCompletionDialog(finalScore, completionTime, timeBonus);
  }

  void _showCompletionDialog(int finalScore, Duration time, int timeBonus) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = GameStats.current;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          widget.isDaily ? l10n.dailyCompleteTitle : l10n.completedTitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, color: scheme.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.scoreResult(finalScore),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(l10n.timeResult(_formatDuration(time), timeBonus)),
            if (_logicRating != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.logicRatingResult(_ratingLabel(context, _logicRating!)),
                ),
              ),
            if (widget.isDaily)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.dailyComeBackNote),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _goToMainMenu();
            },
            child: Text(l10n.mainMenuButton),
          ),
          // The daily is one board per day — no "Next Puzzle".
          if (!widget.isDaily)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _startNextLevel();
              },
              child: Text(l10n.nextPuzzleButton),
            ),
        ],
      ),
    );
  }

  /// The player has used up their mistake allowance. End the run, break the
  /// streak, and offer a retry of the same board or a return to the menu.
  void _gameOver() {
    if (_finished) return;
    _finishRun();
    GameStats.currentStreak = 0;
    GameStats.gamesLost++;
    GameStats.save(); // persist the broken streak + loss count
    _showGameOverDialog();
  }

  void _showGameOverDialog() {
    final l10n = AppLocalizations.of(context)!;
    final scheme = GameStats.current;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          l10n.gameOverTitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, color: scheme.primary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.reachedMistakesMessage(_maxMistakes),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(l10n.streakResetMessage, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _goToMainMenu();
            },
            child: Text(l10n.mainMenuButton),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _retrySamePuzzle();
            },
            child: Text(l10n.tryAgainButton),
          ),
        ],
      ),
    );
  }

  /// Replay the current board from its givens (no new generation).
  void _retrySamePuzzle() {
    final g = game;
    if (g == null) return;
    setState(() {
      g.reset();
      selectedRow = null;
      selectedCol = null;
      hintsUsed = 0;
      mistakes = 0;
      _notesMode = false;
      score = _calculateInitialScore();
    });
    _finished = false;
    _startGameTimer();
    _saveGame();
  }

  void _startNextLevel() {
    setState(() {
      selectedRow = null;
      selectedCol = null;
      hintsUsed = 0;
      mistakes = 0;
      _notesMode = false;
    });
    _initializeGame();
  }

  void _goToMainMenu() {
    _stopGameTimer();
    _saveGame();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (game == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: GameStats.current.gradient,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context)!.generatingPuzzle,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final l10n = AppLocalizations.of(context)!;
    final metrics = _ChromeMetrics.forViewport(MediaQuery.of(context).size);
    final scheme = GameStats.current;

    return Scaffold(
      appBar: AppBar(
        // The title competed with three actions for a 320pt bar and lost,
        // ellipsising to a single "S…". Let it shrink to fit instead, and give
        // it a flexible share rather than its intrinsic width.
        titleSpacing: metrics.isCompact ? 8 : NavigationToolbar.kMiddleSpacing,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            // The shape alone read "STANDARD CLASSIC" on a Killer board — the
            // one screen where knowing the variant matters, since Killer is
            // also why the hint and explain buttons are disabled.
            '${widget.gridSize.name.toUpperCase()} '
            '${widget.gridShape.name.toUpperCase()}'
            '${widget.variant == SudokuVariant.classic ? '' : ' · ${_variantLabel(l10n)}'}',
            maxLines: 1,
          ),
        ),
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _goToMainMenu,
            icon: const Icon(Icons.home),
            iconSize: metrics.isCompact ? 22 : 24,
            visualDensity: metrics.isCompact
                ? VisualDensity.compact
                : VisualDensity.standard,
            tooltip: l10n.mainMenuTooltip,
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.only(right: metrics.isCompact ? 6 : 8),
              child: Text(
                l10n.scoreLabel(score),
                style: TextStyle(
                  fontSize: metrics.isCompact ? 13 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.only(right: metrics.isCompact ? 10 : 16),
              child: ValueListenableBuilder<Duration>(
                valueListenable: _clock.elapsed,
                builder: (context, value, _) => Text(
                  _formatDuration(value),
                  style: TextStyle(
                    fontSize: metrics.isCompact ? 13 : 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
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
          child: Stack(
            children: [
              Positioned.fill(child: ParticleLayer(key: _particleKey)),
              Padding(
                padding: EdgeInsets.all(metrics.outerPadding),
                // A fixed flex split (3:1 on tablet, 2:1 on phone) starved the
                // number pad on short viewports: its share worked out to a
                // couple of dozen pixels per tile, so the digits shrank to the
                // clamp floor and stopped being either legible or tappable,
                // while the board sat centred in slack it could not use
                // because maxGridSize caps it anyway. The pad's height is not
                // a proportion of the screen — it is whatever its rows need at
                // a sane tile size — so derive it, and let the board take the
                // remainder.
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Stacking everything vertically is right when the window
                    // is taller than it is wide. In landscape it is the worst
                    // possible choice: the board competes with the chrome for
                    // the scarce axis (on a 568x320 phone that left it ~90pt)
                    // while the plentiful one sits empty on both sides. Put
                    // the chrome beside the board there instead.
                    final landscape =
                        constraints.maxWidth > constraints.maxHeight * 1.1;
                    return landscape
                        ? _buildLandscapeBody(constraints, metrics, scheme)
                        : _buildPortraitBody(constraints, metrics, scheme);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The height the number pad gets for [padRows] rows: what those rows want
  /// at [metrics]' ideal tile size, capped at [ceilingFraction] of the
  /// available height so the pad can never crowd the board out of a short
  /// window.
  double _padHeightFor(
    int padRows,
    BoxConstraints constraints,
    _ChromeMetrics metrics, {
    required double ceilingFraction,
  }) {
    final wanted =
        padRows * metrics.idealPadTile +
        (padRows - 1) * metrics.padSpacing +
        metrics.padPadding * 2;
    return math.min(wanted, constraints.maxHeight * ceilingFraction);
  }

  /// Portrait: status strip, board, controls, pad — top to bottom.
  ///
  /// A fixed flex split (3:1 on tablet, 2:1 on phone) used to starve the
  /// number pad on short viewports: its share worked out to a couple of dozen
  /// pixels per tile, so the digits shrank to the clamp floor and stopped
  /// being either legible or tappable, while the board sat centred in slack it
  /// could not use. The pad's height is not a proportion of the screen — it is
  /// whatever its rows need at a sane tile size — so derive it, and let the
  /// board take the remainder.
  Widget _buildPortraitBody(
    BoxConstraints constraints,
    _ChromeMetrics metrics,
    EnvironmentalTheme scheme,
  ) {
    final padCols = _padColumnsFor(constraints, metrics);
    final padRows = (game!.gridDim / padCols).ceil();
    // The ceiling is tighter when compact: on a 568pt screen 42% of the body
    // is 200 points for two rows of digits, which is space the board needs far
    // more than the pad does.
    final padHeight = _padHeightFor(
      padRows,
      constraints,
      metrics,
      ceilingFraction: metrics.isCompact ? 0.3 : 0.42,
    );

    return Column(
      children: [
        _buildStatusStrip(metrics),
        SizedBox(height: metrics.gap),
        Expanded(child: Center(child: _shakeableGrid(metrics, scheme))),
        SizedBox(height: metrics.gap),
        _buildControls(scheme, metrics),
        SizedBox(height: metrics.gap),
        SizedBox(height: padHeight, child: _buildNumberPad(metrics, padCols)),
      ],
    );
  }

  /// Landscape: board on the left, the whole chrome stack beside it.
  ///
  /// Height is the scarce axis here, and it is the axis the board needs, so
  /// nothing but the board may spend it. Everything else moves into a side
  /// panel and spends width, of which there is a surplus by definition.
  Widget _buildLandscapeBody(
    BoxConstraints constraints,
    _ChromeMetrics metrics,
    EnvironmentalTheme scheme,
  ) {
    // The board is square and, in landscape, bounded by height — so every
    // point of width beyond its edge is width the board cannot use anyway.
    // Give all of it to the panel rather than a fixed fraction: on a 568x320
    // phone that is the difference between a 3-column pad of 29pt tiles and a
    // 5-column one of 46pt tiles, and it costs the board nothing. The upper
    // clamp is for desktop windows, where the leftover is enormous.
    final gutter = metrics.gap * 2;
    final boardEdge = math.min(metrics.maxGridSize, constraints.maxHeight);
    final panelWidth = (constraints.maxWidth - boardEdge - gutter)
        .clamp(math.min(240.0, constraints.maxWidth / 2), 380.0)
        .toDouble();
    final padCols = _padColumnsFor(
      BoxConstraints(maxWidth: panelWidth, maxHeight: constraints.maxHeight),
      metrics,
    );
    final padRows = (game!.gridDim / padCols).ceil();
    final padWanted =
        padRows * metrics.idealPadTile +
        (padRows - 1) * metrics.padSpacing +
        metrics.padPadding * 2;

    return Row(
      children: [
        Expanded(child: Center(child: _shakeableGrid(metrics, scheme))),
        SizedBox(width: gutter),
        SizedBox(
          width: panelWidth,
          child: Column(
            // Centre the group against the board beside it. `Flexible` is
            // loose, so when the pad wants less than the slack (a desktop
            // window) there is leftover for this to distribute.
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStatusStrip(metrics),
              SizedBox(height: metrics.gap),
              _buildControls(scheme, metrics, stacked: true),
              SizedBox(height: metrics.gap),
              // The pad takes what its rows want, or what is left, whichever
              // is smaller. A plain SizedBox(height: wanted) overflowed the
              // column on a 320pt-tall window, where what it wants is more
              // than what is there.
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: padWanted),
                  child: SizedBox.expand(
                    child: _buildNumberPad(metrics, padCols),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The board, wrapped in the wrong-answer shake.
  Widget _shakeableGrid(_ChromeMetrics metrics, EnvironmentalTheme scheme) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(_shakeAnimation.value, 0),
        child: child,
      ),
      child: _buildSudokuGrid(metrics, scheme),
    );
  }

  /// Slim "Mistakes ✕ ✕ ○ ○ ○ (n/max)" strip above the grid. The pips fill in
  /// as mistakes accrue and turn red on the final life so the lose condition is
  /// visible at a glance.
  /// The status row above the grid: the logic-rating pill (when known) beside
  /// the mistakes strip. Wrapped in a scaleDown FittedBox so both fit on a
  /// narrow phone without overflowing.
  Widget _buildStatusStrip(_ChromeMetrics metrics) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_logicRating != null) ...[
            _buildLogicPill(metrics),
            const SizedBox(width: 8),
          ],
          _buildMistakesIndicator(metrics),
        ],
      ),
    );
  }

  Widget _buildLogicPill(_ChromeMetrics metrics) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: metrics.isCompact ? 10 : 14,
          vertical: metrics.isCompact ? 4 : 6,
        ),
        child: Text(
          AppLocalizations.of(
            context,
          )!.logicRatingPill(_ratingLabel(context, _logicRating!)),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildMistakesIndicator(_ChromeMetrics metrics) {
    final unlimited = GameStats.unlimitedMistakes;
    final atRisk = !unlimited && mistakes >= _maxMistakes - 1;
    final accent = atRisk ? Colors.red.shade300 : Colors.white;
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: metrics.isCompact ? 10 : 14,
          vertical: metrics.isCompact ? 4 : 6,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.mistakesLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 10),
            if (!unlimited)
              for (var i = 0; i < _maxMistakes; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    i < mistakes ? Icons.close : Icons.radio_button_unchecked,
                    size: 15,
                    color: i < mistakes ? accent : Colors.white54,
                  ),
                ),
            const SizedBox(width: 8),
            Text(
              unlimited
                  ? l10n.mistakesCountUnlimited(mistakes)
                  : l10n.mistakesCount(mistakes, _maxMistakes),
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The control row: the hint button plus four circular actions.
  ///
  /// With [stacked] the hint button gets its own full-width row above the
  /// circles. That is for the landscape side panel, which is only ~200pt wide:
  /// four 40pt circles and their gaps already fill it, so sharing a row left
  /// the hint button about 20pt — an unreadable orange stub, and on a slightly
  /// narrower panel nothing at all.
  Widget _buildControls(
    EnvironmentalTheme scheme,
    _ChromeMetrics metrics, {
    bool stacked = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final gap = metrics.isCompact ? 6.0 : 8.0;
    final circles = <Widget>[
      _circleButton(
        metrics: metrics,
        icon: Icons.edit,
        tooltip: l10n.notesModeTooltip,
        active: _notesMode,
        activeColor: scheme.primary,
        onPressed: _toggleNotesMode,
      ),
      _circleButton(
        metrics: metrics,
        icon: Icons.undo,
        tooltip: l10n.undoTooltip,
        onPressed: (game?.canUndo ?? false) ? _undo : null,
      ),
      _circleButton(
        metrics: metrics,
        icon: Icons.clear,
        tooltip: l10n.eraseTooltip,
        activeColor: Colors.red,
        active: true,
        onPressed: _clearCell,
      ),
      _circleButton(
        metrics: metrics,
        icon: Icons.school,
        tooltip: l10n.explainSolveTooltip,
        onPressed: (game == null || widget.isKiller) ? null : _openExplain,
      ),
    ];
    final hintButton = _buildHintButton(l10n, metrics);

    if (stacked) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: double.infinity, child: hintButton),
          SizedBox(height: gap),
          SizedBox(
            height: metrics.controlDiameter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: circles,
            ),
          ),
        ],
      );
    }

    // On a 320pt screen four 48pt circles plus their gaps leave the hint
    // button about 50 points, of which the icon takes 24 — so its label wrapped
    // one character per line and the button grew to five lines tall, stealing
    // the height from the board underneath. Pin the row to one line: the label
    // scales down inside whatever width is left, and never wraps.
    return SizedBox(
      height: metrics.controlDiameter,
      child: Row(
        children: [
          Expanded(child: hintButton),
          for (final circle in circles) ...[SizedBox(width: gap), circle],
        ],
      ),
    );
  }

  Widget _buildHintButton(AppLocalizations l10n, _ChromeMetrics metrics) {
    return ElevatedButton.icon(
      // Logic hints don't model cage sums, so they're off for Killer.
      onPressed: (!widget.isKiller && _hintsRemaining > 0) ? _showHint : null,
      icon: Icon(Icons.lightbulb, size: metrics.controlIconSize),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          widget.isKiller
              ? l10n.hintButtonLabel
              : (_hintsRemaining > 0
                    ? l10n.hintButtonWithCount(_hintsRemaining)
                    : l10n.noHintsLabel),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.clip,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.grey.shade400,
        disabledForegroundColor: Colors.white70,
        padding: EdgeInsets.symmetric(horizontal: metrics.isCompact ? 8 : 16),
        minimumSize: Size(0, metrics.controlDiameter),
        fixedSize: Size.fromHeight(metrics.controlDiameter),
      ),
    );
  }

  /// Opens a step-by-step walkthrough that solves the current board with
  /// human techniques, explaining each deduction.
  Future<void> _openExplain() async {
    final g = game;
    if (g == null) return;
    _explaining = true;
    _stopGameTimer();
    _saveGame();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExplainScreen(
          grid: g.grid,
          regions: g.regions,
          gridDim: g.gridDim,
          jigsaw: widget.gridShape == GridShape.jigsaw,
          diagonal: widget.isDiagonal,
          scheme: GameStats.current,
        ),
      ),
    );
    if (!mounted) return;
    _explaining = false;
    if (!_finished) _startGameTimer(initialElapsed: _clock.elapsed.value);
  }

  Widget _circleButton({
    required _ChromeMetrics metrics,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool active = false,
    Color activeColor = Colors.white,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: metrics.controlDiameter,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: active ? activeColor : Colors.white,
            foregroundColor: active ? Colors.white : Colors.black87,
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            minimumSize: Size.square(metrics.controlDiameter),
          ),
          child: Icon(icon, size: metrics.controlIconSize),
        ),
      ),
    );
  }

  Widget _buildSudokuGrid(_ChromeMetrics metrics, EnvironmentalTheme scheme) {
    final g = game!;
    final gridDim = g.gridDim;
    final maxGridSize = metrics.maxGridSize;

    // Both width AND height must be consulted: the old version only read
    // MediaQuery's screen width, so on a wide-but-height-constrained viewport
    // (iPad, a resized browser window, landscape) the surrounding Expanded/
    // Center would clamp the actual rendered box down, but the Positioned
    // cells below were still placed using the un-clamped size — pushing the
    // last row(s) outside the ClipRRect. Using LayoutBuilder's own
    // constraints keeps the two in sync in both axes.
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridPixels = math.min(
          maxGridSize,
          math.min(constraints.maxWidth, constraints.maxHeight),
        );
        final cellSize = gridPixels / gridDim;

        return Container(
          width: gridPixels,
          height: gridPixels,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(gridPixels, gridPixels),
                  painter: SudokuGridPainter(
                    g.gridDim,
                    g.regions,
                    jigsaw: widget.gridShape == GridShape.jigsaw,
                  ),
                ),
                for (int row = 0; row < gridDim; row++)
                  for (int col = 0; col < gridDim; col++)
                    Positioned(
                      left: col * cellSize,
                      top: row * cellSize,
                      width: cellSize,
                      height: cellSize,
                      child: _buildCell(row, col, cellSize, scheme),
                    ),
                if (widget.isKiller)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        size: Size(gridPixels, gridPixels),
                        painter: KillerCagePainter(_cages, gridDim),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(
    int row,
    int col,
    double cellSize,
    EnvironmentalTheme scheme,
  ) {
    final g = game!;
    final isSelected = selectedRow == row && selectedCol == col;

    // Scale the digit to the cell it actually occupies. This was
    // `isTablet ? 28 : 20` — a binary derived from screen WIDTH, with no
    // relation to the cell's height. The board is capped by whichever of its
    // width or height is smaller, so on a short viewport a 9x9 cell lands near
    // 29px while the digit stayed 28pt, and every row was clipped along its
    // bottom edge. 0.62 leaves room for the 0.5px cell margin and the selected
    // cell's 3px border without the glyph touching either.
    final digitSize = (cellSize * 0.62).clamp(6.0, 48.0);

    final value = g.grid[row][col];
    final conflict = _cellConflict(row, col);

    final Widget cell = DragTarget<int>(
      onAcceptWithDetails: (details) => _placeValue(row, col, details.data),
      onWillAcceptWithDetails: (_) => true,
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return GestureDetector(
          onTap: () => _selectCell(row, col),
          child: Container(
            margin: const EdgeInsets.all(0.5),
            decoration: BoxDecoration(
              color: isHovered
                  ? scheme.accent.withValues(alpha: 0.7)
                  : (conflict
                        ? const Color(0xFFFFCDD2) // red tint for conflicts
                        : _getCellColor(row, col, scheme)),
              border: Border.all(
                color: isSelected
                    ? scheme.primary
                    : (isHovered
                          ? scheme.primary.withValues(alpha: 0.5)
                          : Colors.transparent),
                width: isSelected ? 3 : (isHovered ? 2 : 0),
              ),
            ),
            child: Center(
              child: value != 0
                  // scaleDown guarantees the glyph fits whatever the cell turns
                  // out to be, even at grid sizes the ratio above does not
                  // anticipate.
                  ? FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '$value',
                        style: TextStyle(
                          fontSize: digitSize,
                          fontWeight: g.isOriginal[row][col]
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: g.isOriginal[row][col]
                              ? Colors.black
                              : (conflict
                                    ? Colors.red.shade800
                                    : scheme.primary),
                        ),
                      ),
                    )
                  : _buildNotes(g.notes[row][col], g.gridDim),
            ),
          ),
        );
      },
    );

    // Only the selected cell pulses, so only it is wrapped in an
    // AnimatedBuilder — the rest of the grid stays static.
    if (isSelected) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _pulseAnimation.value, child: child),
        child: cell,
      );
    }
    return cell;
  }

  Color _getCellColor(int row, int col, EnvironmentalTheme scheme) {
    if (selectedRow == row && selectedCol == col) return scheme.accent;
    if (selectedRow == row || selectedCol == col) return Colors.grey.shade200;

    // Faint tint marks the two diagonals so the Sudoku-X constraint is visible.
    if (widget.isDiagonal) {
      final dim = game!.gridDim;
      if (row == col || row + col == dim - 1) return const Color(0xFFEDE7F6);
    }

    final regionId = game!.regions[row][col];
    if (widget.gridShape == GridShape.jigsaw) {
      const colors = [
        Color(0xFFFAFAFA),
        Color(0xFFE3F2FD),
        Color(0xFFE8F5E9),
        Color(0xFFFFF3E0),
        Color(0xFFF3E5F5),
        Color(0xFFFFEBEE),
      ];
      return colors[regionId % colors.length];
    }
    if (regionId % 2 == 0) return scheme.cellHighlight;
    return Colors.white;
  }

  /// Renders pencil-mark candidates as a compact grid inside an empty cell.
  Widget _buildNotes(Set<int> notes, int gridDim) {
    if (notes.isEmpty) return const SizedBox.shrink();
    final perRow = math.sqrt(gridDim).ceil();
    final sorted = notes.toList()..sort();
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = (constraints.maxWidth / perRow) * 0.5;
        return Padding(
          padding: const EdgeInsets.all(1),
          child: Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (final n in sorted)
                SizedBox(
                  width: constraints.maxWidth / perRow,
                  child: Text(
                    '$n',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: fontSize.clamp(6, 12),
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// How many columns the number pad should use for [constraints].
  ///
  /// A hardcoded six wrapped 1-9 onto two rows even in landscape, where the
  /// second row cost the board vertical space the layout had plenty of width
  /// to absorb instead. On a viewport wider than it is tall, spread the digits
  /// across as many columns as still leave a tappable (44pt) tile — usually a
  /// single row — and hand the height back to the grid.
  int _padColumnsFor(BoxConstraints constraints, _ChromeMetrics metrics) {
    final dim = game!.gridDim;
    final innerWidth = constraints.maxWidth - metrics.padPadding * 2;
    final fitsByWidth = math.max(
      1,
      ((innerWidth + metrics.padSpacing) / (44.0 + metrics.padSpacing)).floor(),
    );
    final preferred = constraints.maxWidth > constraints.maxHeight
        ? dim
        : math.min(6, dim);
    final cols = math.min(dim, math.min(fitsByWidth, preferred));
    // Balance the rows. Six columns for nine digits is 6 + 3, which leaves half
    // the last row as a hole; the same two rows spread as 5 + 4 fill it. Take
    // the row count the column count implies, then use the narrowest columns
    // that still need only that many rows.
    final rows = (dim / cols).ceil();
    return math.max(1, (dim / rows).ceil());
  }

  Widget _buildNumberPad(_ChromeMetrics metrics, int crossAxisCount) {
    final maxNumber = game!.gridDim;
    final primary = GameStats.current.primary;
    final spacing = metrics.padSpacing;

    return Container(
      padding: EdgeInsets.all(metrics.padPadding),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(metrics.isCompact ? 14 : 20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      // The number tiles must actually fit the available space and scale
      // with it (previously buttonSize/fontSize only depended on the binary
      // isTablet flag, completely disconnected from what GridView actually
      // rendered — on a 4x4 board on a tablet that meant tiny digits in huge
      // empty tiles, and on 12x12 boards, digits shrinking arbitrarily as
      // more rows got squeezed into the same space). Deriving both from the
      // real computed cell width keeps them proportionate on any device.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rows = (maxNumber / crossAxisCount).ceil();
          final cellWidth =
              (constraints.maxWidth - spacing * (crossAxisCount - 1)) /
              crossAxisCount;
          final cellHeight =
              (constraints.maxHeight - spacing * (rows - 1)) / rows;
          // Size the tiles to the SMALLER of the width- and height-derived
          // dimensions so the pad always fits its box on any aspect ratio.
          // Using width alone (childAspectRatio: 1 on a fixed column count)
          // made the square tiles taller than the available height, turning
          // the GridView into a scroll view that hid the digits.
          final tileSize = math.max(0.0, math.min(cellWidth, cellHeight));
          final buttonSize = tileSize;
          // Proportional to the tile, with no floor that could exceed it: a
          // `.clamp(12, 28)` floor pushed the digit past the height of a small
          // tile, which is what left the numbers sitting off-centre and cut
          // off. Every digit is additionally wrapped in a scaleDown FittedBox
          // below, so overflow is impossible whatever the tile ends up being.
          final fontSize = (buttonSize * 0.45).clamp(8.0, 32.0);
          final gridWidth =
              tileSize * crossAxisCount + spacing * (crossAxisCount - 1);
          final gridHeight = tileSize * rows + spacing * (rows - 1);

          return Center(
            child: SizedBox(
              width: gridWidth,
              height: gridHeight,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                ),
                itemCount: maxNumber,
                itemBuilder: (context, index) {
                  final number = index + 1;
                  return Draggable<int>(
                    data: number,
                    // Anchor the feedback's centre on the pointer so the floating
                    // tile stays under the finger/cursor (and thus over the
                    // highlighted target cell). The default
                    // childDragAnchorStrategy offsets it by the grab point within
                    // the number-pad cell, which is sized independently of the
                    // fixed-size feedback and pushed it off-cursor.
                    dragAnchorStrategy: (draggable, context, position) =>
                        Offset(buttonSize / 2, buttonSize / 2),
                    feedback: Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$number',
                            style: TextStyle(
                              fontSize: fontSize,
                              fontWeight: FontWeight.bold,
                              color: primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: ElevatedButton(
                      onPressed: null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.5),
                        foregroundColor: primary.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 4,
                        padding: EdgeInsets.zero,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$number',
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    child: ElevatedButton(
                      onPressed: () => _inputNumber(number),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 8,
                        padding: EdgeInsets.zero,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$number',
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
