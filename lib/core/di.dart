import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screen_recording_service.dart';
import 'settings_service.dart';

class DI {
  DI._();

  static late final ScreenRecordingService screenRecordingService;
  static late final SettingsService settingsService;

  static Future<void> init() async {
    final appDir = await getApplicationSupportDirectory();
    Hive.init(appDir.path);

    settingsService = SettingsService();
    await settingsService.init();

    screenRecordingService = ScreenRecordingService();
  }
}
