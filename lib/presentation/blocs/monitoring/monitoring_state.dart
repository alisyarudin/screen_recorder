import '../../../data/models/activity_entry.dart';

class MonitoringState {
  final bool isMonitoring;
  final bool isIdle;
  final String currentApp;
  final List<AppUsageEntry> appLog;
  final List<ScreenshotEntry> screenshots;
  final DateTime? sessionStart;
  final DateTime? idleStart;
  final Duration totalIdle;
  final int screenshotInterval; // detik, 0 = off

  const MonitoringState({
    required this.isMonitoring,
    required this.isIdle,
    required this.currentApp,
    required this.appLog,
    required this.screenshots,
    this.sessionStart,
    this.idleStart,
    this.totalIdle = Duration.zero,
    this.screenshotInterval = 60,
  });

  factory MonitoringState.initial() => const MonitoringState(
        isMonitoring: false,
        isIdle: false,
        currentApp: '',
        appLog: [],
        screenshots: [],
      );

  Duration get sessionDuration =>
      sessionStart != null ? DateTime.now().difference(sessionStart!) : Duration.zero;

  Duration get currentIdleDuration =>
      isIdle && idleStart != null ? DateTime.now().difference(idleStart!) : Duration.zero;

  Duration get totalIdleDuration => totalIdle + currentIdleDuration;

  Duration get totalActiveDuration =>
      sessionDuration > totalIdleDuration
          ? sessionDuration - totalIdleDuration
          : Duration.zero;

  // Agregasi durasi per app (diurutkan terlama)
  List<MapEntry<String, Duration>> get appUsageSummary {
    final map = <String, Duration>{};
    for (final e in appLog) {
      map[e.appName] = (map[e.appName] ?? Duration.zero) + e.duration;
    }
    return map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
  }

  MonitoringState copyWith({
    bool? isMonitoring,
    bool? isIdle,
    String? currentApp,
    List<AppUsageEntry>? appLog,
    List<ScreenshotEntry>? screenshots,
    DateTime? sessionStart,
    DateTime? idleStart,
    bool clearIdleStart = false,
    Duration? totalIdle,
    int? screenshotInterval,
  }) =>
      MonitoringState(
        isMonitoring: isMonitoring ?? this.isMonitoring,
        isIdle: isIdle ?? this.isIdle,
        currentApp: currentApp ?? this.currentApp,
        appLog: appLog ?? this.appLog,
        screenshots: screenshots ?? this.screenshots,
        sessionStart: sessionStart ?? this.sessionStart,
        idleStart: clearIdleStart ? null : (idleStart ?? this.idleStart),
        totalIdle: totalIdle ?? this.totalIdle,
        screenshotInterval: screenshotInterval ?? this.screenshotInterval,
      );
}
