import 'dart:async';

import 'package:flutter/foundation.dart';

/// Wall-time clock while running. The screen stops it when not playing.
/// All methods safely ignore calls after disposal.
class GameClock {
  final DateTime Function() now;
  final ValueNotifier<Duration> elapsed = ValueNotifier(Duration.zero);
  Timer? _timer;
  DateTime? _startTime;
  bool _disposed = false;

  GameClock({DateTime Function()? now}) : now = now ?? DateTime.now;

  /// Start a fresh run, or continue from a previously saved active duration.
  void start({Duration initialElapsed = Duration.zero}) {
    if (_disposed) return;
    _timer?.cancel();
    _startTime = now().subtract(initialElapsed);
    elapsed.value = initialElapsed;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsed.value = currentElapsed;
    });
  }

  /// Includes the partial second since the last delivered display tick.
  Duration get currentElapsed =>
      _timer?.isActive == true ? now().difference(_startTime!) : elapsed.value;

  void stop() {
    if (_disposed) return;
    elapsed.value = currentElapsed;
    _timer?.cancel();
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    elapsed.dispose();
  }
}
