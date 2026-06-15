/// 単純なストップウォッチサービス（シングルトン）。
/// セッション状態とは完全に独立して動作する。
/// 画面が破棄されても状態が保持されるよう、シングルトンで管理。
class StopwatchService {
  StopwatchService._();
  static final StopwatchService instance = StopwatchService._();

  bool _isRunning = false;
  DateTime? _runStartTime;
  Duration _accumulated = Duration.zero;

  bool get isRunning => _isRunning;

  /// 現在の経過時間。実行中なら最後のスタート時刻からの差分を加算する。
  Duration get elapsed {
    if (_isRunning && _runStartTime != null) {
      return _accumulated + DateTime.now().difference(_runStartTime!);
    }
    return _accumulated;
  }

  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _runStartTime = DateTime.now();
  }

  void stop() {
    if (!_isRunning || _runStartTime == null) return;
    _accumulated += DateTime.now().difference(_runStartTime!);
    _isRunning = false;
    _runStartTime = null;
  }

  void reset() {
    _isRunning = false;
    _runStartTime = null;
    _accumulated = Duration.zero;
  }
}
