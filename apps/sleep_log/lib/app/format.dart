/// 화면에 쓰는 시간 표기.
library;

/// `7시간`, `7시간 30분`, `45분`.
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  if (hours == 0) {
    return '$minutes분';
  }
  return minutes == 0 ? '$hours시간' : '$hours시간 $minutes분';
}
