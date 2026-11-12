/// Android lets a foreground app start only 4 Wi-Fi scans per 2 minutes. This tracks
/// our own scan requests so the app can wait instead of being refused.
class ScanThrottle {
  ScanThrottle({this.maxScans = 4, this.window = const Duration(minutes: 2)});

  final int maxScans;
  final Duration window;
  final List<DateTime> _starts = [];

  void _prune(DateTime now) => _starts.removeWhere((t) => now.difference(t) >= window);

  /// Scans still allowed right now.
  int remaining(DateTime now) {
    _prune(now);
    return maxScans - _starts.length;
  }

  /// Time until the next scan is allowed, or null when one is allowed now.
  Duration? waitTime(DateTime now) {
    _prune(now);
    if (_starts.length < maxScans) return null;
    return window - now.difference(_starts.first);
  }

  void record(DateTime now) {
    _prune(now);
    _starts.add(now);
  }
}
