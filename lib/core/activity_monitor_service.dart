import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'logger.dart';

class ActivityMonitorService {
  static const _channel = MethodChannel('com.jasnita/activity_monitor');

  // Platforms with a native MethodChannel implementation backing this service.
  static bool get _hasNative => Platform.isMacOS || Platform.isWindows;

  final _appChangedController = StreamController<String>.broadcast();
  final _idleChangedController = StreamController<bool>.broadcast();
  final _screenshotController = StreamController<String>.broadcast();
  final _urlChangedController = StreamController<String>.broadcast();

  Stream<String> get onAppChanged => _appChangedController.stream;
  Stream<bool> get onIdleChanged => _idleChangedController.stream;
  Stream<String> get onScreenshotTaken => _screenshotController.stream;
  // Empty string means "no URL" (e.g. user switched to a non-browser window).
  Stream<String> get onUrlChanged => _urlChangedController.stream;

  Timer? _idleTimer;
  Timer? _screenshotTimer;
  Timer? _foregroundPollTimer;

  bool _wasIdle = false;
  int _idleThresholdSeconds = 60;
  String? _outputBaseDir;
  String _lastForegroundApp = '';
  String _lastUrl = '';

  ActivityMonitorService() {
    if (_hasNative) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onAppChanged') {
          final app = call.arguments as String? ?? '';
          if (app.isEmpty || app == _lastForegroundApp) return;
          _lastForegroundApp = app;
          appLogger.d('[Monitor] App changed → $app');
          _appChangedController.add(app);
        }
      });
    }
  }

  Future<void> startMonitoring({
    required String outputBaseDir,
    int idleThresholdSeconds = 60,
    int screenshotIntervalSeconds = 60,
  }) async {
    _idleThresholdSeconds = idleThresholdSeconds;
    _outputBaseDir = outputBaseDir;

    if (_hasNative) {
      await _channel.invokeMethod('startActivityMonitoring');
      appLogger.i('[Monitor] Native monitoring started');
    }

    // Poll idle time every 5 s
    _idleTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!_hasNative) return;
      try {
        final idle =
            await _channel.invokeMethod<double>('getIdleSeconds') ?? 0.0;
        final isIdle = idle >= _idleThresholdSeconds;
        if (isIdle != _wasIdle) {
          _wasIdle = isIdle;
          _idleChangedController.add(isIdle);
          appLogger.d('[Monitor] Idle → $isIdle (${idle.toStringAsFixed(0)}s)');
        }
      } catch (e) {
        appLogger.e('[Monitor] getIdleSeconds error: $e');
      }
    });

    // Windows: poll foreground app every 2 s as a safety net alongside the
    // native WinEventHook. The hook delivers push events but may miss focus
    // changes if the message loop is busy; polling guarantees the UI updates.
    // Same loop also polls the active browser tab's URL via UIA — empty string
    // means "current window isn't a known browser" (or URL unavailable).
    if (Platform.isWindows) {
      _foregroundPollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
        try {
          final app =
              await _channel.invokeMethod<String>('getForegroundApp') ?? '';
          if (app.isNotEmpty && app != _lastForegroundApp) {
            _lastForegroundApp = app;
            appLogger.d('[Monitor] Foreground (poll) → $app');
            _appChangedController.add(app);
          }
          final url =
              await _channel.invokeMethod<String>('getActiveBrowserUrl') ?? '';
          if (url != _lastUrl) {
            _lastUrl = url;
            if (url.isNotEmpty) appLogger.d('[Monitor] URL → $url');
            _urlChangedController.add(url);
          }
        } catch (e) {
          appLogger.e('[Monitor] poll error: $e');
        }
      });
    }

    // Screenshot timer
    _startScreenshotTimer(screenshotIntervalSeconds);
  }

  void setScreenshotInterval(int seconds, String outputBaseDir) {
    _outputBaseDir = outputBaseDir;
    _screenshotTimer?.cancel();
    _screenshotTimer = null;
    _startScreenshotTimer(seconds);
  }

  void _startScreenshotTimer(int seconds) {
    if (seconds <= 0 || !_hasNative) return;
    _screenshotTimer = Timer.periodic(Duration(seconds: seconds), (_) async {
      await _captureScreenshot();
    });
  }

  Future<void> _captureScreenshot() async {
    final base = _outputBaseDir;
    if (base == null) return;
    try {
      final now = DateTime.now();
      final year  = now.year.toString();
      final month = now.month.toString().padLeft(2, '0');
      final day   = now.day.toString().padLeft(2, '0');
      final sep   = Platform.pathSeparator;
      final dailyDir = '$base$sep$year$sep$month$sep$day';

      final d = Directory(dailyDir);
      if (!await d.exists()) await d.create(recursive: true);

      final ts   = DateFormat('yyyyMMdd_HHmmss').format(now);
      final path = '$dailyDir${sep}SCR_$ts.jpg';

      final ok =
          await _channel.invokeMethod<bool>('takeScreenshot', {'outputPath': path}) ??
              false;
      if (ok) {
        appLogger.i('[Monitor] Screenshot → $path');
        _screenshotController.add(path);
      }
    } catch (e) {
      appLogger.e('[Monitor] Screenshot error: $e');
    }
  }

  Future<void> stopMonitoring() async {
    _idleTimer?.cancel();
    _screenshotTimer?.cancel();
    _foregroundPollTimer?.cancel();
    _idleTimer = null;
    _screenshotTimer = null;
    _foregroundPollTimer = null;
    _wasIdle = false;
    _lastForegroundApp = '';
    _lastUrl = '';

    if (_hasNative) {
      try {
        await _channel.invokeMethod('stopActivityMonitoring');
        appLogger.i('[Monitor] Native monitoring stopped');
      } catch (e) {
        appLogger.e('[Monitor] stop error: $e');
      }
    }
  }

  void dispose() {
    _idleTimer?.cancel();
    _screenshotTimer?.cancel();
    _foregroundPollTimer?.cancel();
    _appChangedController.close();
    _idleChangedController.close();
    _screenshotController.close();
    _urlChangedController.close();
  }
}
