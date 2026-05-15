part of 'recording_bloc.dart';

abstract class RecordingState {}

class RecordingIdle extends RecordingState {
  final String? lastFile;
  RecordingIdle({this.lastFile});
}

class RecordingStarting extends RecordingState {}

class RecordingActive extends RecordingState {
  final String filePath;
  final Duration duration;
  RecordingActive({required this.filePath, required this.duration});
}

class RecordingError extends RecordingState {
  final String message;
  RecordingError(this.message);
}
