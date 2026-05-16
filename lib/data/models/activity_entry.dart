class AppUsageEntry {
  final String appName;
  final DateTime startTime;
  final DateTime? endTime;
  // Latest URL captured for this entry (only set when the app is a known
  // browser and UIA could read the address bar). Null otherwise.
  final String? url;

  const AppUsageEntry({
    required this.appName,
    required this.startTime,
    this.endTime,
    this.url,
  });

  Duration get duration =>
      (endTime ?? DateTime.now()).difference(startTime);

  AppUsageEntry copyWith({
    DateTime? endTime,
    String? url,
    bool clearUrl = false,
  }) =>
      AppUsageEntry(
        appName: appName,
        startTime: startTime,
        endTime: endTime ?? this.endTime,
        url: clearUrl ? null : (url ?? this.url),
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
