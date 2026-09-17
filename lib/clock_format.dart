/// `MM:SS` clock formatting (minutes are not capped at 60), shared by the
/// in-game timer and the stats screen.
String formatClock(Duration d) {
  final m = d.inMinutes.toString().padLeft(2, '0');
  final s = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}
