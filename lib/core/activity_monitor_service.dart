import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'logger.dart';

class ActivityMonitorService {
  static const _channel = MethodChannel('com.jasnita/activity_monitor');

  final _appChangedController = StreamController<String>.broadcast();
  final _idleChangedController = StreamController<bool>.broadcast();
  final _screenshotController = StreamController<String>.broadcast();

  Stream<String> get onAppChanged => _appChangedController.stream;
  Stream<bool> get onIdleChanged => _idleChangedController.stream;
  Stream<String> get onScreenshotTaken => _screenshotController.stream;

  Timer? _idleTimer;
  Timer? _screenshotTimer;

  bool _wasIdle = false;
  int _idleThresholdSeconds = 60;

  ActivityMonitorService() {
    if (Platform.isMacOS) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onAppChanged') {
          final app = call.arguments as String? ?? '';
          appLogger.d('[Monitor] App changed → $app');
          _appChangedController.add(app);
        }
      });
    }
  }

  Future<void> startMonitoring({
    required String screenshotDir,
    int idleThresholdSeconds = 60,
    int screenshotIntervalSeconds = 60,
  }) async {
    _idleThresholdSeconds = idleThresholdSeconds;

    if (Platform.isMacOS) {
      await _channel.invokeMethod('startActivityMonitoring');
      appLogger.i('[Monitor] Native monitoring started');
    }

    // Poll idle time every 5 s
    _idleTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!Platform.isMacOS) return;
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

    // Screenshot timer
    _startScreenshotTimer(screenshotDir, screenshotIntervalSeconds);
  }

  void setScreenshotInterval(int seconds, String screenshotDir) {
    _screenshotTimer?.cancel();
    _screenshotTimer = null;
    _startScreenshotTimer(screenshotDir, seconds);
  }

  void _startScreenshotTimer(String dir, int seconds) {
    if (seconds <= 0 || !Platform.isMacOS) return;
    _screenshotTimer = Timer.periodic(Duration(seconds: seconds), (_) async {
      await _captureScreenshot(dir);
    });
  }

  Future<void> _captureScreenshot(String outputDir) async {
    try {
      final d = Directory(outputDir);
      if (!await d.exists()) await d.create(recursive: true);

      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final path = '$outputDir${Platform.pathSeparator}SCR_$ts.jpg';

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
    _idleTimer = null;
    _screenshotTimer = null;
    _wasIdle = false;

    if (Platform.isMacOS) {
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
    _appChangedController.close();
    _idleChangedController.close();
    _screenshotController.close();
  }
}
