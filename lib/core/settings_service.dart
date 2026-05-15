import 'package:hive/hive.dart';

class RecorderSettings {
  final String outputDir;
  final String ffmpegPath;
  final String quality; // 'low' | 'medium' | 'high'
  final bool alwaysOnTop;

  const RecorderSettings({
    this.outputDir = '',
    this.ffmpegPath = '',
    this.quality = 'medium',
    this.alwaysOnTop = false,
  });

  RecorderSettings copyWith({
    String? outputDir,
    String? ffmpegPath,
    String? quality,
    bool? alwaysOnTop,
  }) =>
      RecorderSettings(
        outputDir: outputDir ?? this.outputDir,
        ffmpegPath: ffmpegPath ?? this.ffmpegPath,
        quality: quality ?? this.quality,
        alwaysOnTop: alwaysOnTop ?? this.alwaysOnTop,
      );

  Map<String, dynamic> toMap() => {
        'outputDir': outputDir,
        'ffmpegPath': ffmpegPath,
        'quality': quality,
        'alwaysOnTop': alwaysOnTop,
      };

  factory RecorderSettings.fromMap(Map<dynamic, dynamic> m) => RecorderSettings(
        outputDir: m['outputDir'] as String? ?? '',
        ffmpegPath: m['ffmpegPath'] as String? ?? '',
        quality: m['quality'] as String? ?? 'medium',
        alwaysOnTop: m['alwaysOnTop'] as bool? ?? false,
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
