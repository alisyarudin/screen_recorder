class AppUsageEntry {
  final String appName;
  final DateTime startTime;
  final DateTime? endTime;

  const AppUsageEntry({
    required this.appName,
    required this.startTime,
    this.endTime,
  });

  Duration get duration =>
      (endTime ?? DateTime.now()).difference(startTime);

  AppUsageEntry copyWith({DateTime? endTime}) => AppUsageEntry(
        appName: appName,
        startTime: startTime,
        endTime: endTime ?? this.endTime,
      );
}

class ScreenshotEntry {
  final String path;
  final DateTime timestamp;
  final String appName;

  const ScreenshotEntry({
    required this.path,
    required this.timestamp,
    required this.appName,
  });
}
