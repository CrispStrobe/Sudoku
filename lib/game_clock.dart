import 'dart:async';

import 'package:flutter/foundation.dart';

/// Owns the per-game timer and the [elapsed] notifier.
///
/// Elapsed time is read off the clock ([now], injectable for tests) at every
/// one-second tick, so time the app spends suspended mid-game still counts —
/// the next tick after resuming catches up to elapsed wall time.
///
/// Extracted from GameScreen so the tick rule is enforced in one place: the
/// periodic timer is cancelled in [dispose] BEFORE the notifier is disposed,
/// so a tick can never fire on a disposed notifier (which throws in debug
/// builds and was reachable by leaving the screen while a puzzle generated).
/// All methods are safe no-ops after [dispose], so a late [start] from an
/// async completion path cannot resurrect a disposed clock either.
class GameClock {
  /// Injectable clock source; defaults to the system time.
  final DateTime Function() now;

  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);

  Timer? _timer;
  DateTime? _startTime;
  bool _disposed = false;

  GameClock({DateTime Function()? now}) : now = now ?? DateTime.now;

  /// Start (or restart) the clock; elapsed resets to zero.
  void start() {
    if (_disposed) return;
    _timer?.cancel();
    _startTime = now();
    elapsed.value = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsed.value = now().difference(_startTime!);
    });
  }

  /// Stop ticking but keep the current [elapsed] reading (final time).
  void stop() => _timer?.cancel();

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    elapsed.dispose();
  }
}
