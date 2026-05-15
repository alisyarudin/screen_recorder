import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di.dart';
import '../../../core/settings_service.dart';

class SettingsCubit extends Cubit<RecorderSettings> {
  SettingsCubit() : super(DI.settingsService.load());

  Future<void> update(RecorderSettings s) async {
    await DI.settingsService.save(s);
    emit(s);
  }

  Future<void> setOutputDir(String dir) => update(state.copyWith(outputDir: dir));
  Future<void> setFfmpegPath(String path) => update(state.copyWith(ffmpegPath: path));
  Future<void> setQuality(String q) => update(state.copyWith(quality: q));
  Future<void> setAlwaysOnTop(bool v) => update(state.copyWith(alwaysOnTop: v));
  Future<void> setFrameRate(String v) => update(state.copyWith(frameRate: v));
  Future<void> setMaxResolution(String v) => update(state.copyWith(maxResolution: v));
  Future<void> setUseHevc(bool v) => update(state.copyWith(useHevc: v));
  Future<void> setServerControlUrl(String v) => update(state.copyWith(serverControlUrl: v));
}
