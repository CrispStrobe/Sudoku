import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'game_stats.dart';

// ---------------------------------------------------------------------------
// Particles (isolated layer — see ParticleLayer)
// ---------------------------------------------------------------------------

class Particle {
  double x, y;
  double vx, vy;
  String emoji;
  double life;
  double maxLife;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.emoji,
    required this.maxLife,
  }) : life = maxLife;

  void update() {
    x += vx;
    y += vy;
    life -= 1.0;
    vy += 0.1; // gravity
  }

  bool get isDead => life <= 0;
  double get opacity => life / maxLife;
}

/// Emoji glyphs rasterised once and reused for every frame they appear in.
///
/// Painting a particle as text costs a [TextPainter] layout per glyph per
/// frame; painting a cached image is a blit. The themes between them use only a
/// couple of dozen distinct emoji, so the cache is small and permanently warm.
class _EmojiGlyph {
  const _EmojiGlyph(this.image, this.size);

  final ui.Image image;
  final Size size; // logical, i.e. the image's size divided by the DPR

  static const double fontSize = 20;
  static final Map<String, _EmojiGlyph> _cache = {};

  /// Rasterised at [dpr] so the glyph stays sharp on high-density screens; the
  /// key includes the ratio because moving to another display changes it.
  static _EmojiGlyph? of(String emoji, double dpr) {
    final key = '$emoji@${dpr.toStringAsFixed(2)}';
    final hit = _cache[key];
    if (hit != null) return hit;

    final painter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: const TextStyle(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    if (painter.width <= 0 || painter.height <= 0) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(dpr);
    painter.paint(canvas, Offset.zero);
    final picture = recorder.endRecording();
    final glyph = _EmojiGlyph(
      picture.toImageSync(
        (painter.width * dpr).ceil(),
        (painter.height * dpr).ceil(),
      ),
      Size(painter.width, painter.height),
    );
    picture.dispose();
    painter.dispose();
    return _cache[key] = glyph;
  }
}

/// Alpha applied by multiplying the glyph's own alpha — unlike [Opacity] (or a
/// bare `canvas.saveLayer`) this needs no offscreen layer, which is what made
/// the old widget-per-particle overlay expensive. Quantised into buckets so the
/// filters can be built once instead of per particle per frame.
class _ParticleFade {
  static const int _buckets = 32;
  static final List<ColorFilter> _filters = List.generate(
    _buckets + 1,
    (i) => ColorFilter.mode(
      Color.fromRGBO(255, 255, 255, i / _buckets),
      BlendMode.modulate,
    ),
  );

  static ColorFilter of(double opacity) =>
      _filters[(opacity.clamp(0.0, 1.0) * _buckets).round()];
}

/// A self-contained particle overlay. It owns its own animation controller and
/// only ticks while particles are alive, so it never forces the rest of the
/// screen to rebuild at 60fps.
///
/// Ticks repaint but do not *rebuild*: the particle list is mutated in place
/// and a [ValueNotifier] drives [CustomPaint] straight to the paint phase,
/// skipping the widget, element and layout work that a `setState` per frame
/// used to redo for every live particle.
class ParticleLayer extends StatefulWidget {
  const ParticleLayer({super.key});

  @override
  State<ParticleLayer> createState() => ParticleLayerState();
}

class ParticleLayerState extends State<ParticleLayer>
    with SingleTickerProviderStateMixin {
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();

  /// Bumped once per tick; the painter listens to it instead of us calling
  /// `setState`.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  late final AnimationController _controller;
  Timer? _spawnTimer;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 16),
      vsync: this,
    )..addListener(_tick);
    _spawnTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) _spawnAmbient();
    });
  }

  void _ensureRunning() {
    if (!_controller.isAnimating) _controller.repeat();
  }

  void _tick() {
    if (_particles.isEmpty) {
      _controller.stop();
      return;
    }
    _particles.removeWhere((p) => p.isDead);
    for (final p in _particles) {
      p.update();
    }
    // Bump before the stop check below, so emptying the list still paints one
    // final (clear) frame rather than leaving the last particles on screen.
    _frame.value++;
    if (_particles.isEmpty) _controller.stop();
  }

  void _spawnAmbient() {
    if (_size == Size.zero) return;
    final emojis = GameStats.current.particleEmojis;
    _particles.add(
      Particle(
        x: _random.nextDouble() * _size.width,
        y: _size.height,
        vx: (_random.nextDouble() - 0.5) * 2,
        vy: -_random.nextDouble() * 3 - 1,
        emoji: emojis[_random.nextInt(emojis.length)],
        maxLife: 180.0,
      ),
    );
    _ensureRunning();
  }

  /// Celebratory burst from the centre of the layer.
  void burst() {
    if (_size == Size.zero) return;
    final emojis = GameStats.current.particleEmojis;
    for (var i = 0; i < 20; i++) {
      _particles.add(
        Particle(
          x: _size.width / 2,
          y: _size.height / 2,
          vx: (_random.nextDouble() - 0.5) * 8,
          vy: -_random.nextDouble() * 6 - 2,
          emoji: emojis[_random.nextInt(emojis.length)],
          maxLife: 120.0,
        ),
      );
    }
    _ensureRunning();
  }

  @override
  void dispose() {
    _spawnTimer?.cancel();
    _controller.dispose();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        return IgnorePointer(
          child: RepaintBoundary(
            child: CustomPaint(
              size: constraints.biggest,
              painter: _ParticlePainter(
                particles: _particles,
                devicePixelRatio: dpr,
                repaint: _frame,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({
    required this.particles,
    required this.devicePixelRatio,
    required Listenable repaint,
  }) : super(repaint: repaint);

  /// Mutated in place by [ParticleLayerState]; never copied per frame.
  final List<Particle> particles;
  final double devicePixelRatio;

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;
    final paint = Paint()..filterQuality = FilterQuality.low;
    for (final p in particles) {
      final glyph = _EmojiGlyph.of(p.emoji, devicePixelRatio);
      if (glyph == null) continue;
      paint.colorFilter = _ParticleFade.of(p.opacity * 0.7);
      canvas.drawImageRect(
        glyph.image,
        Rect.fromLTWH(
          0,
          0,
          glyph.image.width.toDouble(),
          glyph.image.height.toDouble(),
        ),
        Rect.fromLTWH(p.x, p.y, glyph.size.width, glyph.size.height),
        paint,
      );
    }
  }

  // Repaints are driven by the `repaint` listenable above, not by the painter
  // being rebuilt — the particle list keeps the same identity throughout.
  @override
  bool shouldRepaint(_ParticlePainter old) =>
      old.devicePixelRatio != devicePixelRatio ||
      !identical(old.particles, particles);
}
