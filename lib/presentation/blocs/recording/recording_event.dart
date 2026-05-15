part of 'recording_bloc.dart';

abstract class RecordingEvent {}

class StartRecording extends RecordingEvent {}

class StopRecording extends RecordingEvent {}

class _DurationTick extends RecordingEvent {}

class _RecordingError extends RecordingEvent {
  final String message;
  _RecordingError(this.message);
}
