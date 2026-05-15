import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di.dart';
import '../../../core/screen_recording_service.dart';

part 'recording_event.dart';
part 'recording_state.dart';

class RecordingBloc extends Bloc<RecordingEvent, RecordingState> {
  Timer? _durationTimer;
  StreamSubscription<String>? _errorSub;

  RecordingBloc() : super(RecordingIdle()) {
    on<StartRecording>(_onStart);
    on<StopRecording>(_onStop);
    on<_DurationTick>(_onTick);
    on<_RecordingError>(_onError);

    _errorSub = DI.screenRecordingService.errorStream.listen(
      (msg) => add(_RecordingError(msg)),
    );
  }

  Future<void> _onStart(StartRecording event, Emitter<RecordingState> emit) async {
    if (state is RecordingActive) return;

    final settings = DI.settingsService.load();
    final outputDir = settings.outputDir.isEmpty ? _defaultOutputDir() : settings.outputDir;

    final quality = switch (settings.quality) {
      'low' => RecordingQuality.low,
      'high' => RecordingQuality.high,
      _ => RecordingQuality.medium,
    };

    emit(RecordingStarting());

    final filePath = await DI.screenRecordingService.start(
      outputDir: outputDir,
      ffmpegPath: settings.ffmpegPath,
      quality: quality,
      frameRate: settings.frameRate,
      maxResolution: settings.maxResolution,
      useHevc: settings.useHevc,
    );

    if (filePath == null) return;

    emit(RecordingActive(filePath: filePath, duration: Duration.zero));
    _durationTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => add(_DurationTick()),
    );
  }

  Future<void> _onStop(StopRecording event, Emitter<RecordingState> emit) async {
    _durationTimer?.cancel();
    _durationTimer = null;

    final file = await DI.screenRecordingService.stop();
    emit(RecordingIdle(lastFile: file));
  }

  void _onError(_RecordingError event, Emitter<RecordingState> emit) {
    _durationTimer?.cancel();
    _durationTimer = null;
    emit(RecordingError(event.message));
  }

  void _onTick(_DurationTick event, Emitter<RecordingState> emit) {
    final s = state;
    if (s is RecordingActive) {
      emit(RecordingActive(
        filePath: s.filePath,
        duration: s.duration + const Duration(seconds: 1),
      ));
    }
  }

  static String _defaultOutputDir() {
    final sep = Platform.isWindows ? '\\' : '/';
    final home = Platform.isWindows
        ? (Platform.environment['USERPROFILE'] ??
            '${Platform.environment['HOMEDRIVE']}${Platform.environment['HOMEPATH']}')
        : (Platform.environment['HOME'] ?? '/tmp');
    return '$home${sep}ScreenRecordings';
  }

  @override
  Future<void> close() {
    _durationTimer?.cancel();
    _errorSub?.cancel();
    return super.close();
  }
}
