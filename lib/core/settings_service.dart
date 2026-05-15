import 'package:hive/hive.dart';

class RecorderSettings {
  final String outputDir;
  final String ffmpegPath;
  final String quality;      // 'low' | 'medium' | 'high'
  final bool alwaysOnTop;
  final String frameRate;    // '15' | '30'
  final String maxResolution; // 'original' | '1080p' | '720p'
  final bool useHevc;        // macOS only — H.265 vs H.264
  final String serverControlUrl; // URL polling kontrol server (kosong = nonaktif)

  const RecorderSettings({
    this.outputDir = '',
    this.ffmpegPath = '',
    this.quality = 'medium',
    this.alwaysOnTop = false,
    this.frameRate = '30',
    this.maxResolution = 'original',
    this.useHevc = false,
    this.serverControlUrl = '',
  });

  RecorderSettings copyWith({
    String? outputDir,
    String? ffmpegPath,
    String? quality,
    bool? alwaysOnTop,
    String? frameRate,
    String? maxResolution,
    bool? useHevc,
    String? serverControlUrl,
  }) =>
      RecorderSettings(
        outputDir: outputDir ?? this.outputDir,
        ffmpegPath: ffmpegPath ?? this.ffmpegPath,
        quality: quality ?? this.quality,
        alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
        frameRate: frameRate ?? this.frameRate,
        maxResolution: maxResolution ?? this.maxResolution,
        useHevc: useHevc ?? this.useHevc,
        serverControlUrl: serverControlUrl ?? this.serverControlUrl,
      );

  Map<String, dynamic> toMap() => {
        'outputDir': outputDir,
        'ffmpegPath': ffmpegPath,
        'quality': quality,
        'alwaysOnTop': alwaysOnTop,
        'frameRate': frameRate,
        'maxResolution': maxResolution,
        'useHevc': useHevc,
        'serverControlUrl': serverControlUrl,
      };

  factory RecorderSettings.fromMap(Map<dynamic, dynamic> m) => RecorderSettings(
        outputDir: m['outputDir'] as String? ?? '',
        ffmpegPath: m['ffmpegPath'] as String? ?? '',
        quality: m['quality'] as String? ?? 'medium',
        alwaysOnTop: m['alwaysOnTop'] as bool? ?? false,
        frameRate: m['frameRate'] as String? ?? '30',
        maxResolution: m['maxResolution'] as String? ?? 'original',
        useHevc: m['useHevc'] as bool? ?? false,
        serverControlUrl: m['serverControlUrl'] as String? ?? '',
      );
}

class SettingsService {
  static const _boxName = 'settings';
  static const _key = 'recorder_v1';

  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  RecorderSettings load() {
    final raw = _box.get(_key);
    if (raw == null) return const RecorderSettings();
    return RecorderSettings.fromMap(raw as Map);
  }

  Future<void> save(RecorderSettings s) async {
    await _box.put(_key, s.toMap());
  }
}
