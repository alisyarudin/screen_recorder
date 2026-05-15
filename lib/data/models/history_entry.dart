class AppUsageSummary {
  final String appName;
  final Duration duration;
  const AppUsageSummary({required this.appName, required this.duration});

  Map<String, dynamic> toMap() =>
      {'appName': appName, 'durationSeconds': duration.inSeconds};

  factory AppUsageSummary.fromMap(Map m) => AppUsageSummary(
        appName: m['appName'] as String,
        duration: Duration(seconds: m['durationSeconds'] as int),
      );
}

class HistorySession {
  final DateTime startTime;
  final DateTime endTime;
  final Duration activeDuration;
  final Duration idleDuration;
  final List<AppUsageSummary> appUsage;
  final int screenshotCount;
  final List<String> recordingPaths;

  const HistorySession({
    required this.startTime,
    required this.endTime,
    required this.activeDuration,
    required this.idleDuration,
    required this.appUsage,
    required this.screenshotCount,
    required this.recordingPaths,
  });

  Duration get totalDuration => endTime.difference(startTime);

  Map<String, dynamic> toMap() => {
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'activeSecs': activeDuration.inSeconds,
        'idleSecs': idleDuration.inSeconds,
        'appUsage': appUsage.map((a) => a.toMap()).toList(),
        'screenshotCount': screenshotCount,
        'recordingPaths': recordingPaths,
      };

  factory HistorySession.fromMap(Map m) => HistorySession(
        startTime: DateTime.fromMillisecondsSinceEpoch(m['startTime'] as int),
        endTime: DateTime.fromMillisecondsSinceEpoch(m['endTime'] as int),
        activeDuration: Duration(seconds: m['activeSecs'] as int),
        idleDuration: Duration(seconds: m['idleSecs'] as int),
        appUsage: (m['appUsage'] as List)
            .map((e) => AppUsageSummary.fromMap(e as Map))
            .toList(),
        screenshotCount: m['screenshotCount'] as int,
        recordingPaths: List<String>.from(m['recordingPaths'] as List),
      );
}

class HistoryDay {
  final String dateKey; // 'YYYY-MM-DD'
  final DateTime date;
  final List<HistorySession> sessions;

  const HistoryDay({
    required this.dateKey,
    required this.date,
    required this.sessions,
  });

  Duration get totalActive =>
      sessions.fold(Duration.zero, (s, e) => s + e.activeDuration);

  Duration get totalIdle =>
      sessions.fold(Duration.zero, (s, e) => s + e.idleDuration);

  int get totalScreenshots =>
      sessions.fold(0, (s, e) => s + e.screenshotCount);

  int get totalRecordings =>
      sessions.fold(0, (s, e) => s + e.recordingPaths.length);

  double get activityIntensity {
    final hours = totalActive.inMinutes / 60;
    return (hours / 9.0).clamp(0.0, 1.0);
  }

  List<AppUsageSummary> get topApps {
    final map = <String, Duration>{};
    for (final s in sessions) {
      for (final a in s.appUsage) {
        map[a.appName] = (map[a.appName] ?? Duration.zero) + a.duration;
      }
    }
    final list = map.entries
        .map((e) => AppUsageSummary(appName: e.key, duration: e.value))
        .toList()
      ..sort((a, b) => b.duration.compareTo(a.duration));
    return list;
  }

  List<String> get allRecordings =>
      sessions.expand((s) => s.recordingPaths).toList();
}
