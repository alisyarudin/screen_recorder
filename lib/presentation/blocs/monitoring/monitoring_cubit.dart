import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di.dart';
import '../../../data/models/activity_entry.dart';
import '../../../data/models/history_entry.dart';
import 'monitoring_state.dart';

export 'monitoring_state.dart';

class MonitoringCubit extends Cubit<MonitoringState> {
  StreamSubscription<String>? _appSub;
  StreamSubscription<bool>? _idleSub;
  StreamSubscription<String>? _screenshotSub;
  StreamSubscription<String>? _urlSub;
  Timer? _tickTimer;

  MonitoringCubit() : super(MonitoringState.initial());

  Future<void> startMonitoring() async {
    if (state.isMonitoring) return;

    final settings = DI.settingsService.load();
    final outputDir =
        settings.outputDir.isEmpty ? _defaultOutputDir() : settings.outputDir;

    await DI.activityMonitorService.startMonitoring(
      outputBaseDir: outputDir,
      screenshotIntervalSeconds: state.screenshotInterval,
    );

    emit(state.copyWith(
      isMonitoring: true,
      sessionStart: DateTime.now(),
      appLog: [],
      screenshots: [],
      totalIdle: Duration.zero,
      clearIdleStart: true,
      isIdle: false,
      currentApp: '',
    ));

    _appSub = DI.activityMonitorService.onAppChanged.listen(_onAppChanged);
    _idleSub = DI.activityMonitorService.onIdleChanged.listen(_onIdleChanged);
    _screenshotSub =
        DI.activityMonitorService.onScreenshotTaken.listen(_onScreenshotTaken);
    _urlSub = DI.activityMonitorService.onUrlChanged.listen(_onUrlChanged);

    // Tick setiap detik agar durasi di UI ikut update
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.isMonitoring) emit(state.copyWith());
    });
  }

  Future<void> stopMonitoring() async {
    _cancelSubs();

    final now = DateTime.now();
    final newLog = List<AppUsageEntry>.from(state.appLog);
    if (newLog.isNotEmpty && newLog.last.endTime == null) {
      newLog[newLog.length - 1] = newLog.last.copyWith(endTime: now);
    }

    // Tutup idle period yang sedang berjalan
    final extraIdle = state.isIdle && state.idleStart != null
        ? now.difference(state.idleStart!)
        : Duration.zero;

    // Save session to history
    if (state.sessionStart != null) {
      final totalIdleFinal = state.totalIdle + extraIdle;
      final sessionDur = now.difference(state.sessionStart!);
      final activeDur = sessionDur - totalIdleFinal;
      final appSummary = state.appUsageSummary
          .map((e) => AppUsageSummary(appName: e.key, duration: e.value))
          .toList();
      final session = HistorySession(
        startTime: state.sessionStart!,
        endTime: now,
        activeDuration: activeDur > Duration.zero ? activeDur : Duration.zero,
        idleDuration: totalIdleFinal,
        appUsage: appSummary,
        screenshotCount: state.screenshots.length,
        recordingPaths: [],
      );
      await DI.historyService.saveSession(session);
    }

    await DI.activityMonitorService.stopMonitoring();

    emit(state.copyWith(
      isMonitoring: false,
      isIdle: false,
      clearIdleStart: true,
      currentApp: '',
      appLog: newLog,
      totalIdle: state.totalIdle + extraIdle,
    ));
  }

  void setScreenshotInterval(int seconds) {
    final settings = DI.settingsService.load();
    final outputDir =
        settings.outputDir.isEmpty ? _defaultOutputDir() : settings.outputDir;

    DI.activityMonitorService.setScreenshotInterval(seconds, outputDir);
    emit(state.copyWith(screenshotInterval: seconds));
  }

  void clearSession() {
    if (state.isMonitoring) return;
    emit(MonitoringState.initial().copyWith(
      screenshotInterval: state.screenshotInterval,
    ));
  }

  // ── Private ────────────────────────────────────────────────────────────────

  void _onAppChanged(String appName) {
    final now = DateTime.now();
    final newLog = List<AppUsageEntry>.from(state.appLog);
    if (newLog.isNotEmpty && newLog.last.endTime == null) {
      newLog[newLog.length - 1] = newLog.last.copyWith(endTime: now);
    }
    newLog.add(AppUsageEntry(appName: appName, startTime: now));
    emit(state.copyWith(currentApp: appName, appLog: newLog));
  }

  void _onUrlChanged(String url) {
    // Refresh the current (still-open) app log entry's URL. Empty incoming
    // string means we left a browser window — clear the URL on the entry.
    if (state.appLog.isEmpty) return;
    final newLog = List<AppUsageEntry>.from(state.appLog);
    final last = newLog.last;
    if (last.endTime != null) return; // not the active entry anymore
    newLog[newLog.length - 1] = url.isEmpty
        ? last.copyWith(clearUrl: true)
        : last.copyWith(url: url);
    emit(state.copyWith(appLog: newLog));
  }

  void _onIdleChanged(bool isIdle) {
    final now = DateTime.now();
    if (isIdle && !state.isIdle) {
      emit(state.copyWith(isIdle: true, idleStart: now));
    } else if (!isIdle && state.isIdle) {
      final extra = state.idleStart != null
          ? now.difference(state.idleStart!)
          : Duration.zero;
      emit(state.copyWith(
        isIdle: false,
        clearIdleStart: true,
        totalIdle: state.totalIdle + extra,
      ));
    }
  }

  void _onScreenshotTaken(String path) {
    final shots = [
      ScreenshotEntry(
        path: path,
        timestamp: DateTime.now(),
        appName: state.currentApp,
      ),
      ...state.screenshots,
    ];
    emit(state.copyWith(screenshots: shots));
  }

  void _cancelSubs() {
    _appSub?.cancel();
    _idleSub?.cancel();
    _screenshotSub?.cancel();
    _urlSub?.cancel();
    _tickTimer?.cancel();
    _appSub = null;
    _idleSub = null;
    _screenshotSub = null;
    _urlSub = null;
    _tickTimer = null;
  }

  static String _defaultOutputDir() {
    final sep = Platform.isWindows ? '\\' : '/';
    final home = Platform.isWindows
        ? (Platform.environment['USERPROFILE'] ??
            '${Platform.environment['HOMEDRIVE']}${Platform.environment['HOMEPATH']}')
        : (Platform.environment['HOME'] ?? '/tmp');
    return '$home${sep}Jasnita Screen Recorder';
  }

  @override
  Future<void> close() {
    _cancelSubs();
    return super.close();
  }
}
