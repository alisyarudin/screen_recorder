import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'logger.dart';

enum RecordingQuality { low, medium, high }

class ScreenRecordingService {
  bool _nativeRecording = false;
  String? _nativeFile;

  Process? _process;
  String? _currentFile;

  final _errorController = StreamController<String>.broadcast();
  Stream<String> get errorStream => _errorController.stream;

  static const _channel = MethodChannel('com.jasnita/screen_recording');

  bool get isRecording => Platform.isMacOS ? _nativeRecording : _process != null;
  String? get currentFile => Platform.isMacOS ? _nativeFile : _currentFile;

  ScreenRecordingService() {
    if (Platform.isMacOS) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onRecordingError') {
          _nativeRecording = false;
          _nativeFile = null;
          _errorController.add(call.arguments as String? ?? 'Rekaman berhenti tak terduga');
        }
      });
    }
  }

  // ─── macOS: native ScreenCaptureKit ───────────────────────────────────────

  Future<String?> _macosStart(
    String outputPath,
    RecordingQuality quality, {
    String frameRate = '30',
    String maxResolution = 'original',
    bool useHevc = false,
  }) async {
    final qualityStr = switch (quality) {
      RecordingQuality.low => 'low',
      RecordingQuality.high => 'high',
      RecordingQuality.medium => 'medium',
    };

    try {
      final result = await _channel.invokeMethod<Map>('startNativeRecording', {
        'outputPath': outputPath,
        'quality': qualityStr,
        'frameRate': frameRate,
        'maxResolution': maxResolution,
        'useHevc': useHevc,
      });
      final success = result?['success'] as bool? ?? false;
      if (success) {
        _nativeRecording = true;
        _nativeFile = outputPath;
        appLogger.i('ScreenRecording (native): started → $outputPath');
        return outputPath;
      } else {
        final err = result?['error'] as String? ?? 'Rekaman gagal dimulai';
        appLogger.w('ScreenRecording (native): start failed — $err');
        _errorController.add(err);
        return null;
      }
    } catch (e) {
      appLogger.e('ScreenRecording (native): channel error — $e');
      _errorController.add('Gagal memulai rekaman: $e');
      return null;
    }
  }

  Future<String?> _macosStop() async {
    _nativeRecording = false;
    _nativeFile = null;
    try {
      final path = await _channel.invokeMethod<String?>('stopNativeRecording');
      appLogger.i('ScreenRecording (native): stopped → $path');
      return path;
    } catch (e) {
      appLogger.e('ScreenRecording (native): stop error — $e');
      return null;
    }
  }

  // ─── Windows: FFmpeg ───────────────────────────────────────────────────────

  Future<String?> findFfmpeg(String customPath) async {
    if (customPath.isNotEmpty && await _tryExe(customPath)) return customPath;
    final bundled = bundledFfmpegPath();
    if (bundled != null && await _tryExe(bundled)) return bundled;
    if (await _tryExe('ffmpeg')) return 'ffmpeg';
    for (final p in _commonPaths()) {
      if (await _tryExe(p)) return p;
    }
    return null;
  }

  /// Path to ffmpeg.exe shipped next to the runner (CMake install step).
  /// Returns null if running on a non-Windows platform.
  String? bundledFfmpegPath() {
    if (!Platform.isWindows) return null;
    final dir = File(Platform.resolvedExecutable).parent.path;
    return '$dir${Platform.pathSeparator}ffmpeg.exe';
  }

  Future<bool> checkAvailability(String ffmpegPath) async =>
      (await findFfmpeg(ffmpegPath)) != null;

  Future<bool> _tryExe(String path) async {
    try {
      final r = await Process.run(path, ['-version']);
      return r.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  List<String> _commonPaths() {
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
    final programFiles = Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
    final programData = Platform.environment['ProgramData'] ?? r'C:\ProgramData';
    return [
      r'C:\ffmpeg\bin\ffmpeg.exe',
      '$programFiles\\ffmpeg\\bin\\ffmpeg.exe',
      '$programData\\chocolatey\\bin\\ffmpeg.exe',
      '$localAppData\\Microsoft\\WinGet\\Links\\ffmpeg.exe',
    ];
  }

  Future<String?> _windowsStart(
    String outputPath,
    String ffmpegPath,
    RecordingQuality quality, {
    String frameRate = '30',
    String maxResolution = 'original',
  }) async {
    final exe = await findFfmpeg(ffmpegPath);
    if (exe == null) {
      _errorController.add('ffmpeg_not_found');
      return null;
    }

    final args = _windowsArgs(outputPath, quality, frameRate, maxResolution);
    appLogger.d('ScreenRecording (FFmpeg): ${([exe] + args).join(' ')}');

    final stderrLines = <String>[];
    try {
      _process = await Process.start(exe, args);
      _currentFile = outputPath;
      appLogger.i('ScreenRecording (FFmpeg): started → $outputPath');

      _process!.stderr
          .transform(const SystemEncoding().decoder)
          .listen((chunk) {
        appLogger.d('FFmpeg: $chunk');
        stderrLines.add(chunk);
      });

      final proc = _process!;
      proc.exitCode.then((code) {
        if (_process != proc) return;
        _process = null;
        _currentFile = null;
        if (code != 0) {
          final stderr = stderrLines.join();
          _errorController.add('FFmpeg berhenti (code $code):\n$stderr');
        }
      });

      return outputPath;
    } catch (e) {
      appLogger.e('ScreenRecording (FFmpeg): start failed — $e');
      _process = null;
      _currentFile = null;
      return null;
    }
  }

  Future<String?> _windowsStop() async {
    final proc = _process;
    final file = _currentFile;
    if (proc == null) return null;

    _process = null;
    _currentFile = null;

    try {
      proc.stdin.write('q');
      await proc.stdin.flush();
      await proc.stdin.close();
      await proc.exitCode.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          proc.kill();
          return -1;
        },
      );
    } catch (_) {
      proc.kill();
    }

    if (file != null) {
      try {
        final f = File(file);
        if (await f.exists() && await f.length() > 0) return file;
      } catch (_) {}
    }
    return null;
  }

  List<String> _windowsArgs(
    String outputPath,
    RecordingQuality quality,
    String frameRate,
    String maxResolution,
  ) {
    final (preset, crf) = switch (quality) {
      RecordingQuality.low => ('ultrafast', '35'),
      RecordingQuality.medium => ('fast', '28'),
      RecordingQuality.high => ('medium', '23'),
    };
    final scaleFilter = switch (maxResolution) {
      '1080p' => 'scale=1920:-2,',
      '720p' => 'scale=1280:-2,',
      _ => '',
    };
    return [
      '-f', 'gdigrab',
      '-framerate', frameRate,
      '-i', 'desktop',
      '-vcodec', 'libx264',
      '-preset', preset,
      '-crf', crf,
      '-vf', '${scaleFilter}format=yuv420p',
      '-y', outputPath,
    ];
  }

  // ─── Permission ───────────────────────────────────────────────────────────

  Future<bool> checkPermission() async {
    if (!Platform.isMacOS) return true;
    try {
      final granted = await _channel.invokeMethod<bool>('requestPermission');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  // ─── Unified API ──────────────────────────────────────────────────────────

  Future<String?> start({
    required String outputDir,
    String ffmpegPath = '',
    RecordingQuality quality = RecordingQuality.medium,
    String frameRate = '30',
    String maxResolution = 'original',
    bool useHevc = false,
  }) async {
    if (isRecording) return currentFile;

    final now    = DateTime.now();
    final year   = now.year.toString();
    final month  = now.month.toString().padLeft(2, '0');
    final day    = now.day.toString().padLeft(2, '0');
    final sep    = Platform.pathSeparator;
    final dailyDir = '$outputDir$sep$year$sep$month$sep$day';

    final dir = Directory(dailyDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(now);
    final outputPath = '$dailyDir${sep}REC_$timestamp.mp4';

    if (Platform.isMacOS) {
      return _macosStart(
        outputPath,
        quality,
        frameRate: frameRate,
        maxResolution: maxResolution,
        useHevc: useHevc,
      );
    } else {
      return _windowsStart(
        outputPath,
        ffmpegPath,
        quality,
        frameRate: frameRate,
        maxResolution: maxResolution,
      );
    }
  }

  Future<String?> stop() async {
    if (Platform.isMacOS) return _macosStop();
    return _windowsStop();
  }
}
