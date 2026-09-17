import 'dart:async';

import 'package:flutter/foundation.dart';

/// Owns the per-game timer and the [elapsed] notifier.
///
/// Elapsed time accumulates one second per periodic tick rather than being
/// read off a wall clock: it is deterministic under fake-async tests and
/// matches the clock display's 1-second granularity. (Tradeoff: time spent
/// with the app suspended mid-game is not counted — the previous
/// wall-clock implementation would have jumped after resuming.)
///
/// Extracted from GameScreen so the tick rule is enforced in one place: the
/// periodic timer is cancelled in [dispose] BEFORE the notifier is disposed,
/// so a tick can never fire on a disposed notifier (which throws in debug
/// builds and was reachable by leaving the screen while a puzzle generated).
class GameClock {
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);

  Timer? _timer;
  int _seconds = 0;

  /// Start (or restart) the clock; elapsed resets to zero.
  void start() {
    _timer?.cancel();
    _seconds = 0;
    elapsed.value = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _seconds++;
      elapsed.value = Duration(seconds: _seconds);
    });
  }

  /// Stop ticking but keep the current [elapsed] reading (final time).
  void stop() => _timer?.cancel();

  void dispose() {
    _timer?.cancel();
    _timer = null;
    elapsed.dispose();
  }
}
