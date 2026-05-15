import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'activity_monitor_service.dart';
import 'admin_service.dart';
import 'history_service.dart';
import 'screen_recording_service.dart';
import 'settings_service.dart';

class DI {
  DI._();

  static late final ScreenRecordingService screenRecordingService;
  static late final SettingsService settingsService;
  static late final ActivityMonitorService activityMonitorService;
  static late final AdminService adminService;
  static late final HistoryService historyService;

  static Future<void> init() async {
    final appDir = await getApplicationSupportDirectory();
    Hive.init(appDir.path);

    settingsService = SettingsService();
    await settingsService.init();

    historyService = HistoryService();
    await historyService.init();

    screenRecordingService = ScreenRecordingService();
    activityMonitorService = ActivityMonitorService();
    adminService = AdminService();
  }
}
