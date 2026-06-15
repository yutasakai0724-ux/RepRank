// 時間表示のフォーマットユーティリティ。
// 全画面で同じ表記を使うためにここに集約する。

String _pad(int n) => n.toString().padLeft(2, '0');

/// 秒数 → "MM:SS" 形式
String formatMMSS(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '${_pad(m)}:${_pad(s)}';
}

/// Duration → "MM:SS" または 1時間超なら "HH:MM:SS"
String formatHMS(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  if (h > 0) {
    return '${_pad(h)}:${_pad(m)}:${_pad(s)}';
  }
  return '${_pad(m)}:${_pad(s)}';
}

/// DateTime → "HH:MM"（時刻のみ）
String formatHM(DateTime dt) => '${_pad(dt.hour)}:${_pad(dt.minute)}';

/// DateTime → "YYYY-MM-DD"（日付キー用）
String formatYMD(DateTime dt) =>
    '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';

/// DateTime → "M月D日(曜)"（表示用）
String formatJpDate(DateTime dt) {
  const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
  final w = weekdays[dt.weekday - 1];
  return '${dt.month}月${dt.day}日($w)';
}
